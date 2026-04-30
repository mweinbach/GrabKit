import Foundation

enum GrabPromptBuilder {
    static func prompt(for node: GrabNode, comment: String) -> String {
        var lines: [String] = [
            "# GrabKit UI Fix Request",
            "",
            "## Request",
            trimmedComment(comment),
            "",
            "## Selected Element",
            "- ID: \(node.id)",
            "- Role: \(node.role.rawValue)"
        ]

        append("Component", node.component, to: &lines)
        append("Parent ID", node.parentID, to: &lines)
        if !node.path.isEmpty {
            lines.append("- Path: \(node.path.joined(separator: " > "))")
        }
        if let frame = node.frame {
            lines.append("- Frame: x \(number(frame.x)), y \(number(frame.y)), width \(number(frame.width)), height \(number(frame.height))")
        }
        if let source = node.source {
            lines.append("- Source: \(source.fileID):\(source.line) in \(source.function)")
        }

        appendAccessibility(node.accessibility, to: &lines)
        appendContent(node.content, to: &lines)
        appendJSONSection(title: "State", value: node.state, to: &lines)
        appendJSONSection(title: "Design", value: node.design, to: &lines)

        lines += [
            "",
            "## Full Node JSON",
            "```json",
            nodeJSON(node),
            "```"
        ]

        return lines.joined(separator: "\n")
    }

    private static func trimmedComment(_ comment: String) -> String {
        let trimmed = comment.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "(No comment provided.)" : trimmed
    }

    private static func append(_ label: String, _ value: String?, to lines: inout [String]) {
        guard let value, !value.isEmpty else { return }
        lines.append("- \(label): \(value)")
    }

    private static func appendAccessibility(_ accessibility: GrabAccessibility, to lines: inout [String]) {
        var parts: [String] = []
        if let identifier = accessibility.identifier { parts.append("identifier \(identifier)") }
        if let label = accessibility.label { parts.append("label \(label)") }
        if let value = accessibility.value { parts.append("value \(value)") }
        if let hint = accessibility.hint { parts.append("hint \(hint)") }
        if !accessibility.traits.isEmpty { parts.append("traits \(accessibility.traits.joined(separator: ", "))") }
        if let isEnabled = accessibility.isEnabled { parts.append("enabled \(isEnabled)") }
        if let isSelected = accessibility.isSelected { parts.append("selected \(isSelected)") }
        if let isFocused = accessibility.isFocused { parts.append("focused \(isFocused)") }
        guard !parts.isEmpty else { return }
        lines.append("- Accessibility: \(parts.joined(separator: "; "))")
    }

    private static func appendContent(_ content: GrabContent, to lines: inout [String]) {
        switch content {
        case .omitted:
            return
        case .redacted(let reason):
            if let reason, !reason.isEmpty {
                lines.append("- Content: redacted (\(reason))")
            } else {
                lines.append("- Content: redacted")
            }
        case .safeText(let text):
            lines.append("- Content: \(text)")
        case .value(let value):
            lines.append("- Content: \(jsonString(value))")
        }
    }

    private static func appendJSONSection(title: String, value: [String: GrabJSONValue], to lines: inout [String]) {
        guard !value.isEmpty else { return }
        lines += [
            "",
            "## \(title)",
            "```json",
            jsonString(value),
            "```"
        ]
    }

    private static func nodeJSON(_ node: GrabNode) -> String {
        do {
            let data = try makeJSONEncoder(prettyPrinted: true).encode(node)
            return String(data: data, encoding: .utf8) ?? "{}"
        } catch {
            return "{\"error\":\"\(String(describing: error))\"}"
        }
    }

    private static func jsonString<T: Encodable>(_ value: T) -> String {
        do {
            let data = try makeJSONEncoder(prettyPrinted: true).encode(value)
            return String(data: data, encoding: .utf8) ?? "{}"
        } catch {
            return "{\"error\":\"\(String(describing: error))\"}"
        }
    }

    private static func makeJSONEncoder(prettyPrinted: Bool) -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = prettyPrinted ? [.prettyPrinted, .sortedKeys] : [.sortedKeys]
        return encoder
    }

    private static func number(_ value: Double) -> String {
        let rounded = value.rounded()
        if abs(value - rounded) < 0.001 {
            return String(Int(rounded))
        }
        return String(format: "%.2f", value)
    }
}
