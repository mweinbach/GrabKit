import Foundation

private let protocolVersion = "2025-11-25"

@main
struct GrabKitMCP {
    static func main() {
        let config = MCPConfig(arguments: Array(CommandLine.arguments.dropFirst()), environment: ProcessInfo.processInfo.environment)
        let server = MCPServer(config: config)

        while let line = readLine(strippingNewline: true) {
            guard !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
            server.handle(line: line)
        }
    }
}

private struct MCPConfig {
    var baseURL: URL
    var token: String?

    init(arguments: [String], environment: [String: String]) {
        var base = environment["GRABKIT_URL"] ?? "http://127.0.0.1:9777"
        var token = environment["GRABKIT_TOKEN"]
        var index = 0
        while index < arguments.count {
            let value = arguments[index]
            switch value {
            case "--base-url" where index + 1 < arguments.count:
                base = arguments[index + 1]
                index += 1
            case "--token" where index + 1 < arguments.count:
                token = arguments[index + 1]
                index += 1
            default:
                break
            }
            index += 1
        }
        self.baseURL = URL(string: base) ?? URL(string: "http://127.0.0.1:9777")!
        self.token = token?.isEmpty == true ? nil : token
    }
}

private final class MCPServer {
    private let client: GrabHTTPClient

    init(config: MCPConfig) {
        self.client = GrabHTTPClient(baseURL: config.baseURL, token: config.token)
    }

    func handle(line: String) {
        guard
            let data = line.data(using: .utf8),
            let message = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            write(error: nil, code: -32700, message: "Parse error")
            return
        }

        let id = message["id"]
        guard let method = message["method"] as? String else {
            if id != nil { write(error: id, code: -32600, message: "Invalid request") }
            return
        }

        switch method {
        case "initialize":
            let requestedVersion = ((message["params"] as? [String: Any])?["protocolVersion"] as? String) ?? protocolVersion
            write(result: id, value: [
                "protocolVersion": requestedVersion,
                "capabilities": [
                    "tools": [:]
                ],
                "serverInfo": [
                    "name": "grabkit-mcp",
                    "title": "GrabKit MCP",
                    "version": "0.1.0"
                ],
                "instructions": "Use these tools only with an explicitly enabled GrabKit debug transport."
            ])
        case "notifications/initialized":
            return
        case "ping":
            write(result: id, value: [:])
        case "tools/list":
            write(result: id, value: ["tools": toolDefinitions])
        case "tools/call":
            handleToolCall(id: id, params: message["params"] as? [String: Any])
        default:
            if id != nil {
                write(error: id, code: -32601, message: "Method not found: \(method)")
            }
        }
    }

    private func handleToolCall(id: Any?, params: [String: Any]?) {
        guard let name = params?["name"] as? String else {
            write(error: id, code: -32602, message: "Missing tool name")
            return
        }
        let arguments = params?["arguments"] as? [String: Any] ?? [:]

        do {
            let value: Any
            switch name {
            case "grab_health":
                value = try client.request(method: "GET", path: "/grab/health")
            case "grab_tree":
                value = try client.request(method: "GET", path: "/grab/tree")
            case "grab_selected":
                value = try client.request(method: "GET", path: "/grab/selected")
            case "grab_prompt":
                let comment = arguments["comment"] as? String
                let query = comment.map { "?comment=\($0.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" } ?? ""
                value = try client.request(method: "GET", path: "/grab/prompt\(query)")
            case "grab_copied":
                value = try client.request(method: "GET", path: "/grab/copied")
            case "grab_set_mode":
                guard let enabled = arguments["enabled"] as? Bool else {
                    throw MCPToolError.invalidArguments("grab_set_mode requires a boolean enabled argument")
                }
                value = try client.request(method: "POST", path: "/grab/mode", jsonBody: ["enabled": enabled])
            case "grab_select_id":
                guard let nodeID = arguments["id"] as? String else {
                    throw MCPToolError.invalidArguments("grab_select_id requires a string id argument")
                }
                value = try client.request(method: "POST", path: "/grab/select-id", jsonBody: ["id": nodeID])
            case "grab_select_point":
                guard let x = numeric(arguments["x"]), let y = numeric(arguments["y"]) else {
                    throw MCPToolError.invalidArguments("grab_select_point requires numeric x and y arguments")
                }
                var body: [String: Any] = ["x": x, "y": y]
                if let coordinateSpace = arguments["coordinateSpace"] as? String {
                    body["coordinateSpace"] = coordinateSpace
                }
                value = try client.request(method: "POST", path: "/grab/select-point", jsonBody: body)
            default:
                write(error: id, code: -32602, message: "Unknown tool: \(name)")
                return
            }
            write(result: id, value: toolResult(value))
        } catch {
            write(result: id, value: [
                "isError": true,
                "content": [
                    [
                        "type": "text",
                        "text": String(describing: error)
                    ]
                ]
            ])
        }
    }

    private func toolResult(_ value: Any) -> [String: Any] {
        let text = (try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]))
            .flatMap { String(data: $0, encoding: .utf8) } ?? String(describing: value)
        return [
            "content": [
                [
                    "type": "text",
                    "text": text
                ]
            ],
            "structuredContent": value
        ]
    }

    private func numeric(_ value: Any?) -> Double? {
        if let value = value as? Double { return value }
        if let value = value as? Int { return Double(value) }
        if let value = value as? NSNumber { return value.doubleValue }
        return nil
    }

    private var toolDefinitions: [[String: Any]] {
        [
            tool("grab_health", "Return GrabKit health and active transport status.", properties: [:]),
            tool("grab_tree", "Return the current GrabKit UI tree snapshot.", properties: [:]),
            tool("grab_selected", "Return the currently selected GrabKit node, if any.", properties: [:]),
            tool(
                "grab_prompt",
                "Return an agent-ready prompt for the currently selected GrabKit node.",
                properties: ["comment": ["type": "string"]]
            ),
            tool("grab_copied", "Return the most recent string copied by GrabKit copy actions.", properties: [:]),
            tool(
                "grab_set_mode",
                "Enable or disable GrabKit inspect mode.",
                properties: ["enabled": ["type": "boolean"]],
                required: ["enabled"]
            ),
            tool(
                "grab_select_id",
                "Select a GrabKit node by stable id.",
                properties: ["id": ["type": "string"]],
                required: ["id"]
            ),
            tool(
                "grab_select_point",
                "Select the top GrabKit node containing a window-space point.",
                properties: [
                    "x": ["type": "number"],
                    "y": ["type": "number"],
                    "coordinateSpace": ["type": "string"]
                ],
                required: ["x", "y"]
            )
        ]
    }

    private func tool(_ name: String, _ description: String, properties: [String: Any], required: [String] = []) -> [String: Any] {
        var schema: [String: Any] = [
            "type": "object",
            "properties": properties,
            "additionalProperties": false
        ]
        if !required.isEmpty {
            schema["required"] = required
        }
        return [
            "name": name,
            "description": description,
            "inputSchema": schema
        ]
    }

    private func write(result id: Any?, value: Any) {
        guard let id else { return }
        writeJSONObject([
            "jsonrpc": "2.0",
            "id": id,
            "result": value
        ])
    }

    private func write(error id: Any?, code: Int, message: String) {
        var response: [String: Any] = [
            "jsonrpc": "2.0",
            "error": [
                "code": code,
                "message": message
            ]
        ]
        if let id {
            response["id"] = id
        }
        writeJSONObject(response)
    }

    private func writeJSONObject(_ object: Any) {
        do {
            let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
            if let line = String(data: data, encoding: .utf8) {
                FileHandle.standardOutput.write((line + "\n").data(using: .utf8)!)
            }
        } catch {
            FileHandle.standardError.write("grabkit-mcp failed to encode response: \(error)\n".data(using: .utf8)!)
        }
    }
}

private final class GrabHTTPClient {
    private let baseURL: URL
    private let token: String?

    init(baseURL: URL, token: String?) {
        self.baseURL = baseURL
        self.token = token
    }

    func request(method: String, path: String, jsonBody: [String: Any]? = nil) throws -> Any {
        let url = baseURL.appendingPathComponent(path.trimmingCharacters(in: CharacterSet(charactersIn: "/")))
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 10
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let jsonBody {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: jsonBody)
        }

        let semaphore = DispatchSemaphore(value: 0)
        var result: Result<(Data, HTTPURLResponse), Error>?
        URLSession.shared.dataTask(with: request) { data, response, error in
            defer { semaphore.signal() }
            if let error {
                result = .failure(error)
                return
            }
            guard let response = response as? HTTPURLResponse else {
                result = .failure(MCPToolError.upstream("GrabKit did not return an HTTP response"))
                return
            }
            result = .success((data ?? Data(), response))
        }.resume()
        semaphore.wait()

        guard let result else {
            throw MCPToolError.upstream("GrabKit request did not complete")
        }
        let (data, response) = try result.get()
        guard (200..<300).contains(response.statusCode) else {
            let text = String(data: data, encoding: .utf8) ?? ""
            throw MCPToolError.upstream("GrabKit HTTP \(response.statusCode): \(text)")
        }
        guard !data.isEmpty else { return [:] }
        return try JSONSerialization.jsonObject(with: data)
    }
}

private enum MCPToolError: Error, CustomStringConvertible {
    case invalidArguments(String)
    case upstream(String)

    var description: String {
        switch self {
        case .invalidArguments(let message), .upstream(let message): return message
        }
    }
}
