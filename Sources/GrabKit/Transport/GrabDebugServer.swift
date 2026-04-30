import Foundation

public enum GrabTransportError: Error, LocalizedError, Sendable {
    case unavailable
    case invalidPort(UInt16)
    case missingToken
    case badRequest(String)

    public var errorDescription: String? {
        switch self {
        case .unavailable: return "GrabKit local transport is unavailable on this platform."
        case .invalidPort(let port): return "Invalid GrabKit port: \(port)."
        case .missingToken: return "GrabKit local-network transport requires a session token."
        case .badRequest(let message): return "Bad GrabKit request: \(message)."
        }
    }
}

public enum GrabTransportExposure: String, Codable, Sendable, Equatable {
    case disabled
    case loopback
    case localNetwork
}

public struct GrabTransportStatus: Codable, Sendable, Equatable {
    public var isRunning: Bool
    public var exposure: GrabTransportExposure
    public var port: UInt16?
    public var advertisesBonjour: Bool

    public init(isRunning: Bool = false, exposure: GrabTransportExposure = .disabled, port: UInt16? = nil, advertisesBonjour: Bool = false) {
        self.isRunning = isRunning
        self.exposure = exposure
        self.port = port
        self.advertisesBonjour = advertisesBonjour
    }
}

public enum GrabTransportMode: Sendable, Equatable {
    case disabled
    case loopback(port: UInt16 = 9777)
    case localNetwork(port: UInt16 = 9777, token: String)

    public var isEnabled: Bool {
        switch self {
        case .disabled: return false
        case .loopback, .localNetwork: return true
        }
    }

    public var port: UInt16? {
        switch self {
        case .disabled: return nil
        case .loopback(let port), .localNetwork(let port, _): return port
        }
    }

    public var exposure: GrabTransportExposure {
        switch self {
        case .disabled: return .disabled
        case .loopback: return .loopback
        case .localNetwork: return .localNetwork
        }
    }

    var token: String? {
        switch self {
        case .localNetwork(_, let token): return token
        case .disabled, .loopback: return nil
        }
    }

    var advertisesBonjour: Bool {
        exposure == .localNetwork
    }
}

#if canImport(Network)
import Network

/// Tiny debug-only HTTP server for querying the current UI graph.
/// For real team use, prefer an outbound WebSocket broker with auth/session tokens.
public final class GrabDebugServer: @unchecked Sendable {
    public static let shared = GrabDebugServer()

    private let queue = DispatchQueue(label: "dev.grabkit.transport")
    private var listener: NWListener?
    private var mode: GrabTransportMode = .disabled

    public private(set) var isRunning: Bool = false
    public private(set) var port: UInt16?
    public var status: GrabTransportStatus {
        GrabTransportStatus(
            isRunning: isRunning,
            exposure: isRunning ? mode.exposure : .disabled,
            port: isRunning ? port : nil,
            advertisesBonjour: isRunning && mode.advertisesBonjour
        )
    }

    private init() {}

    public func start(_ mode: GrabTransportMode) throws {
        stop()
        guard mode.isEnabled else { return }
        guard let port = mode.port else { throw GrabTransportError.invalidPort(0) }
        if case .localNetwork(_, let token) = mode, token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw GrabTransportError.missingToken
        }
        guard let endpointPort = NWEndpoint.Port(rawValue: port) else { throw GrabTransportError.invalidPort(port) }
        let parameters = NWParameters.tcp
        if mode.exposure == .loopback {
            parameters.requiredLocalEndpoint = .hostPort(host: .ipv4(IPv4Address("127.0.0.1")!), port: .any)
        }
        let listener = try NWListener(using: parameters, on: endpointPort)
        if mode.advertisesBonjour {
            listener.service = NWListener.Service(name: "GrabKit", type: "_grabkit._tcp")
        }
        listener.newConnectionHandler = { [weak self] connection in self?.handle(connection) }
        listener.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready: self?.isRunning = true
            case .failed, .cancelled: self?.isRunning = false
            default: break
            }
        }
        listener.start(queue: queue)
        self.listener = listener
        self.mode = mode
        self.port = port
    }

    public func start(port: UInt16 = 9777) throws {
        try start(.loopback(port: port))
    }

    public func stop() {
        listener?.cancel()
        listener = nil
        isRunning = false
        port = nil
        mode = .disabled
    }

    private func handle(_ connection: NWConnection) {
        connection.start(queue: queue)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 128 * 1024) { [weak self] data, _, _, error in
            guard let self else { return }
            guard error == nil, let data, !data.isEmpty else { connection.cancel(); return }
            let requestText = String(data: data, encoding: .utf8) ?? ""
            Task { @MainActor in
                let response = self.route(HTTPRequest(requestText))
                self.send(response, on: connection)
            }
        }
    }

    @MainActor
    private func route(_ parsed: HTTPRequest) -> HTTPResponse {
        switch (parsed.method, parsed.path) {
        case ("OPTIONS", _):
            return HTTPResponse(statusCode: 204, contentType: "text/plain", body: Data())
        case ("GET", "/grab/health"):
            return json(HealthResponse(ok: true, version: GrabKit.version, nodes: GrabRegistry.shared.snapshot().nodes.count, transport: status))
        default:
            guard isAuthorized(parsed) else {
                return jsonError(GrabTransportError.badRequest("Missing or invalid GrabKit session token"), statusCode: 401)
            }
        }

        switch (parsed.method, parsed.path) {
        case ("GET", "/grab/tree"):
            return json(GrabRegistry.shared.snapshot())
        case ("GET", "/grab/selected"):
            if let node = GrabRegistry.shared.selectedNode() { return json(node) }
            return json(SelectedResponse(selectedID: nil))
        case ("GET", "/grab/mode"):
            return json(ModeResponse(enabled: GrabRegistry.shared.isInspecting))
        case ("POST", "/grab/mode"):
            do {
                let request = try decode(ModeRequest.self, from: parsed.body)
                if let enabled = request.enabled { GrabRegistry.shared.setInspecting(enabled) }
                else { _ = GrabRegistry.shared.toggleInspecting() }
                return json(ModeResponse(enabled: GrabRegistry.shared.isInspecting))
            } catch { return jsonError(error, statusCode: 400) }
        case ("POST", "/grab/select-point"):
            do {
                let request = try decode(SelectPointRequest.self, from: parsed.body)
                return json(GrabRegistry.shared.select(point: GrabPoint(x: request.x, y: request.y, coordinateSpace: request.coordinateSpace ?? "windowPoints")))
            } catch { return jsonError(error, statusCode: 400) }
        case ("POST", "/grab/select-id"):
            do {
                let request = try decode(SelectIDRequest.self, from: parsed.body)
                return json(GrabRegistry.shared.select(id: request.id))
            } catch { return jsonError(error, statusCode: 400) }
        case ("POST", "/grab/stop"):
            let response = json(StopResponse(stopped: true))
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.stop()
                Task { @MainActor in GrabRegistry.shared.refresh() }
            }
            return response
        default:
            return jsonError(GrabTransportError.badRequest("Unknown route \(parsed.method) \(parsed.path)"), statusCode: 404)
        }
    }

    private func isAuthorized(_ request: HTTPRequest) -> Bool {
        guard let token = mode.token else { return true }
        if request.header("x-grabkit-token") == token { return true }
        if request.header("authorization") == "Bearer \(token)" { return true }
        if request.queryValue("token") == token { return true }
        return false
    }

    private func decode<T: Decodable>(_ type: T.Type, from body: Data) throws -> T {
        guard !body.isEmpty else {
            if T.self == ModeRequest.self { return ModeRequest(enabled: nil) as! T }
            throw GrabTransportError.badRequest("Missing JSON body")
        }
        return try JSONDecoder().decode(T.self, from: body)
    }

    private func json<T: Encodable>(_ value: T, statusCode: Int = 200) -> HTTPResponse {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            return HTTPResponse(statusCode: statusCode, contentType: "application/json", body: try encoder.encode(value))
        } catch { return jsonError(error, statusCode: 500) }
    }

    private func jsonError(_ error: Error, statusCode: Int) -> HTTPResponse {
        let escaped = String(describing: error).replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        return HTTPResponse(statusCode: statusCode, contentType: "application/json", body: "{\"error\":\"\(escaped)\"}".data(using: .utf8) ?? Data())
    }

    private func send(_ response: HTTPResponse, on connection: NWConnection) {
        var packet = Data()
        packet.append(response.headerData)
        packet.append(response.body)
        connection.send(content: packet, completion: .contentProcessed { _ in connection.cancel() })
    }

    @MainActor
    func responseForTesting(method: String, path: String, headers: [String: String] = [:], body: Data = Data(), mode: GrabTransportMode = .loopback()) -> (statusCode: Int, body: Data) {
        let oldMode = self.mode
        let oldRunning = isRunning
        let oldPort = port
        self.mode = mode
        self.isRunning = mode.isEnabled
        self.port = mode.port
        defer {
            self.mode = oldMode
            self.isRunning = oldRunning
            self.port = oldPort
        }
        let response = route(HTTPRequest(method: method, path: path, headers: headers, body: body))
        return (response.statusCode, response.body)
    }
}

private struct ModeRequest: Codable { var enabled: Bool? }
private struct ModeResponse: Codable { var enabled: Bool }
private struct SelectedResponse: Codable { var selectedID: String? }
private struct HealthResponse: Codable { var ok: Bool; var version: String; var nodes: Int; var transport: GrabTransportStatus }
private struct StopResponse: Codable { var stopped: Bool }
private struct SelectPointRequest: Codable { var x: Double; var y: Double; var coordinateSpace: String? }
private struct SelectIDRequest: Codable { var id: String? }

private struct HTTPRequest {
    var method: String = "GET"
    var path: String = "/"
    var headers: [String: String] = [:]
    var queryItems: [String: String] = [:]
    var body: Data = Data()

    init(_ raw: String) {
        let parts = raw.components(separatedBy: "\r\n\r\n")
        let header = parts.first ?? ""
        let bodyText = parts.dropFirst().joined(separator: "\r\n\r\n")
        body = bodyText.data(using: .utf8) ?? Data()
        let headerLines = header.components(separatedBy: "\r\n")
        let firstLine = headerLines.first ?? ""
        let firstLineParts = firstLine.split(separator: " ", maxSplits: 2).map(String.init)
        if firstLineParts.count >= 2 {
            method = firstLineParts[0].uppercased()
            parsePath(firstLineParts[1])
        }
        for line in headerLines.dropFirst() {
            let parts = line.split(separator: ":", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { continue }
            headers[parts[0].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()] = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    init(method: String, path: String, headers: [String: String], body: Data) {
        self.method = method.uppercased()
        self.body = body
        self.headers = Dictionary(uniqueKeysWithValues: headers.map { ($0.key.lowercased(), $0.value) })
        parsePath(path)
    }

    func header(_ name: String) -> String? {
        headers[name.lowercased()]
    }

    func queryValue(_ name: String) -> String? {
        queryItems[name]
    }

    private mutating func parsePath(_ rawPath: String) {
        guard let components = URLComponents(string: rawPath) else {
            path = rawPath.components(separatedBy: "?").first ?? rawPath
            return
        }
        path = components.path.isEmpty ? "/" : components.path
        queryItems = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).compactMap { item in
            guard let value = item.value else { return nil }
            return (item.name, value)
        })
    }
}

private struct HTTPResponse {
    var statusCode: Int
    var contentType: String
    var body: Data

    var headerData: Data {
        let statusText: String
        switch statusCode {
        case 200: statusText = "OK"
        case 204: statusText = "No Content"
        case 400: statusText = "Bad Request"
        case 401: statusText = "Unauthorized"
        case 404: statusText = "Not Found"
        case 500: statusText = "Internal Server Error"
        default: statusText = "OK"
        }
        let header = [
            "HTTP/1.1 \(statusCode) \(statusText)",
            "Content-Type: \(contentType)",
            "Content-Length: \(body.count)",
            "Access-Control-Allow-Origin: *",
            "Access-Control-Allow-Headers: Content-Type, Authorization, X-GrabKit-Token",
            "Access-Control-Allow-Methods: GET, POST, OPTIONS",
            "Connection: close",
            "",
            ""
        ].joined(separator: "\r\n")
        return header.data(using: .utf8) ?? Data()
    }
}

#else

public final class GrabDebugServer {
    public static let shared = GrabDebugServer()
    public private(set) var isRunning: Bool = false
    public private(set) var port: UInt16?
    public var status: GrabTransportStatus { GrabTransportStatus() }
    private init() {}
    public func start(_ mode: GrabTransportMode) throws { throw GrabTransportError.unavailable }
    public func start(port: UInt16 = 9777) throws { throw GrabTransportError.unavailable }
    public func stop() { isRunning = false; port = nil }
}

#endif
