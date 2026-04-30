import Foundation

public enum GrabTransportError: Error, LocalizedError, Sendable {
    case unavailable
    case invalidPort(UInt16)
    case badRequest(String)

    public var errorDescription: String? {
        switch self {
        case .unavailable: return "GrabKit local transport is unavailable on this platform."
        case .invalidPort(let port): return "Invalid GrabKit port: \(port)."
        case .badRequest(let message): return "Bad GrabKit request: \(message)."
        }
    }
}

#if canImport(Network)
import Network

/// Tiny debug-only HTTP server for querying the current UI graph.
/// For real team use, prefer an outbound WebSocket broker with auth/session tokens.
public final class GrabDebugServer {
    public static let shared = GrabDebugServer()

    private let queue = DispatchQueue(label: "dev.grabkit.transport")
    private var listener: NWListener?

    public private(set) var isRunning: Bool = false
    public private(set) var port: UInt16?

    private init() {}

    public func start(port: UInt16 = 9777) throws {
        stop()
        guard let endpointPort = NWEndpoint.Port(rawValue: port) else { throw GrabTransportError.invalidPort(port) }
        let listener = try NWListener(using: .tcp, on: endpointPort)
        listener.service = NWListener.Service(name: "GrabKit", type: "_grabkit._tcp")
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
        self.port = port
    }

    public func stop() {
        listener?.cancel()
        listener = nil
        isRunning = false
        port = nil
    }

    private func handle(_ connection: NWConnection) {
        connection.start(queue: queue)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 128 * 1024) { [weak self] data, _, _, error in
            guard let self else { return }
            guard error == nil, let data, !data.isEmpty else { connection.cancel(); return }
            let requestText = String(data: data, encoding: .utf8) ?? ""
            Task { @MainActor in
                let response = self.route(requestText)
                self.send(response, on: connection)
            }
        }
    }

    @MainActor
    private func route(_ requestText: String) -> HTTPResponse {
        let parsed = HTTPRequest(requestText)
        switch (parsed.method, parsed.path) {
        case ("OPTIONS", _):
            return HTTPResponse(statusCode: 204, contentType: "text/plain", body: Data())
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
        case ("GET", "/grab/health"):
            return json(HealthResponse(ok: true, version: GrabKit.version, nodes: GrabRegistry.shared.snapshot().nodes.count))
        default:
            return jsonError(GrabTransportError.badRequest("Unknown route \(parsed.method) \(parsed.path)"), statusCode: 404)
        }
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
}

private struct ModeRequest: Codable { var enabled: Bool? }
private struct ModeResponse: Codable { var enabled: Bool }
private struct SelectedResponse: Codable { var selectedID: String? }
private struct HealthResponse: Codable { var ok: Bool; var version: String; var nodes: Int }
private struct SelectPointRequest: Codable { var x: Double; var y: Double; var coordinateSpace: String? }
private struct SelectIDRequest: Codable { var id: String? }

private struct HTTPRequest {
    var method: String = "GET"
    var path: String = "/"
    var body: Data = Data()

    init(_ raw: String) {
        let parts = raw.components(separatedBy: "\r\n\r\n")
        let header = parts.first ?? ""
        let bodyText = parts.dropFirst().joined(separator: "\r\n\r\n")
        body = bodyText.data(using: .utf8) ?? Data()
        let firstLine = header.components(separatedBy: "\r\n").first ?? ""
        let firstLineParts = firstLine.split(separator: " ", maxSplits: 2).map(String.init)
        if firstLineParts.count >= 2 {
            method = firstLineParts[0].uppercased()
            path = firstLineParts[1].components(separatedBy: "?").first ?? firstLineParts[1]
        }
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
        case 404: statusText = "Not Found"
        case 500: statusText = "Internal Server Error"
        default: statusText = "OK"
        }
        let header = [
            "HTTP/1.1 \(statusCode) \(statusText)",
            "Content-Type: \(contentType)",
            "Content-Length: \(body.count)",
            "Access-Control-Allow-Origin: *",
            "Access-Control-Allow-Headers: Content-Type",
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
    private init() {}
    public func start(port: UInt16 = 9777) throws { throw GrabTransportError.unavailable }
    public func stop() { isRunning = false; port = nil }
}

#endif
