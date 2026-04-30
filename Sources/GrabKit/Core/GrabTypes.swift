import Foundation

public enum GrabRole: String, Codable, Sendable, Equatable, CaseIterable {
    case view, container, text, button, image, textField, secureTextField, toggle, slider, picker
    case list, row, cell, navigation, tab, menu, custom
}

public struct GrabPoint: Codable, Sendable, Equatable {
    public var x: Double
    public var y: Double
    public var coordinateSpace: String
    public init(x: Double, y: Double, coordinateSpace: String = "windowPoints") {
        self.x = x; self.y = y; self.coordinateSpace = coordinateSpace
    }
}

public struct GrabRect: Codable, Sendable, Equatable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double
    public var coordinateSpace: String
    public var scale: Double?

    public init(x: Double, y: Double, width: Double, height: Double, coordinateSpace: String = "windowPoints", scale: Double? = nil) {
        self.x = x; self.y = y; self.width = width; self.height = height; self.coordinateSpace = coordinateSpace; self.scale = scale
    }

    public var area: Double { max(0, width) * max(0, height) }
    public func contains(_ point: GrabPoint) -> Bool {
        point.x >= x && point.x <= x + width && point.y >= y && point.y <= y + height
    }
}

public struct GrabSource: Codable, Sendable, Equatable {
    public var fileID: String
    public var line: UInt
    public var function: String

    public init(fileID: String, line: UInt, function: String) {
        self.fileID = fileID; self.line = line; self.function = function
    }

    public static func here(fileID: StaticString = #fileID, line: UInt = #line, function: StaticString = #function) -> GrabSource {
        GrabSource(fileID: String(describing: fileID), line: line, function: String(describing: function))
    }
}

public struct GrabAccessibility: Codable, Sendable, Equatable {
    public var identifier: String?
    public var label: String?
    public var value: String?
    public var hint: String?
    public var traits: [String]
    public var isEnabled: Bool?
    public var isSelected: Bool?
    public var isFocused: Bool?

    public init(identifier: String? = nil, label: String? = nil, value: String? = nil, hint: String? = nil, traits: [String] = [], isEnabled: Bool? = nil, isSelected: Bool? = nil, isFocused: Bool? = nil) {
        self.identifier = identifier; self.label = label; self.value = value; self.hint = hint; self.traits = traits; self.isEnabled = isEnabled; self.isSelected = isSelected; self.isFocused = isFocused
    }
}

public enum GrabContent: Codable, Sendable, Equatable {
    case omitted
    case redacted(reason: String?)
    case safeText(String)
    case value(GrabJSONValue)

    private enum CodingKeys: String, CodingKey { case kind, reason, text, value }
    private enum Kind: String, Codable { case omitted, redacted, safeText, value }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        switch try c.decode(Kind.self, forKey: .kind) {
        case .omitted: self = .omitted
        case .redacted: self = .redacted(reason: try c.decodeIfPresent(String.self, forKey: .reason))
        case .safeText: self = .safeText(try c.decode(String.self, forKey: .text))
        case .value: self = .value(try c.decode(GrabJSONValue.self, forKey: .value))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .omitted:
            try c.encode(Kind.omitted, forKey: .kind)
        case .redacted(let reason):
            try c.encode(Kind.redacted, forKey: .kind); try c.encodeIfPresent(reason, forKey: .reason)
        case .safeText(let text):
            try c.encode(Kind.safeText, forKey: .kind); try c.encode(text, forKey: .text)
        case .value(let value):
            try c.encode(Kind.value, forKey: .kind); try c.encode(value, forKey: .value)
        }
    }
}

public struct GrabDescriptor: Sendable, Equatable {
    public var id: String
    public var role: GrabRole
    public var component: String?
    public var parentID: String?
    public var source: GrabSource?
    public var accessibility: GrabAccessibility
    public var design: [String: GrabJSONValue]
    public var state: [String: GrabJSONValue]
    public var content: GrabContent
    public var copy: [String: String]

    public init(id: String, role: GrabRole = .view, component: String? = nil, parentID: String? = nil, source: GrabSource? = nil, accessibility: GrabAccessibility = GrabAccessibility(), design: [String: GrabJSONValue] = [:], state: [String: GrabJSONValue] = [:], content: GrabContent = .omitted, copy: [String: String] = [:]) {
        self.id = id; self.role = role; self.component = component; self.parentID = parentID; self.source = source; self.accessibility = accessibility; self.design = design; self.state = state; self.content = content; self.copy = copy
    }
}

public struct GrabNode: Identifiable, Codable, Sendable, Equatable {
    public var id: String
    public var role: GrabRole
    public var component: String?
    public var parentID: String?
    public var children: [String]
    public var path: [String]
    public var frame: GrabRect?
    public var accessibility: GrabAccessibility
    public var source: GrabSource?
    public var design: [String: GrabJSONValue]
    public var state: [String: GrabJSONValue]
    public var content: GrabContent
    public var copy: [String: String]
    public var isVisible: Bool
    public var renderOrder: Int
    public var updatedAt: Date

    public init(id: String, role: GrabRole, component: String? = nil, parentID: String? = nil, children: [String] = [], path: [String] = [], frame: GrabRect? = nil, accessibility: GrabAccessibility, source: GrabSource? = nil, design: [String: GrabJSONValue] = [:], state: [String: GrabJSONValue] = [:], content: GrabContent = .omitted, copy: [String: String] = [:], isVisible: Bool = true, renderOrder: Int = 0, updatedAt: Date = Date()) {
        self.id = id; self.role = role; self.component = component; self.parentID = parentID; self.children = children; self.path = path; self.frame = frame; self.accessibility = accessibility; self.source = source; self.design = design; self.state = state; self.content = content; self.copy = copy; self.isVisible = isVisible; self.renderOrder = renderOrder; self.updatedAt = updatedAt
    }
}

public struct GrabSelection: Codable, Sendable, Equatable {
    public var selectedID: String?
    public var candidateIDs: [String]
    public init(selectedID: String?, candidateIDs: [String]) { self.selectedID = selectedID; self.candidateIDs = candidateIDs }
}

public struct GrabSnapshot: Codable, Sendable, Equatable {
    public var version: String
    public var generatedAt: Date
    public var isInspecting: Bool
    public var selectedID: String?
    public var transport: GrabTransportStatus
    public var nodes: [GrabNode]
    public init(version: String = GrabKit.version, generatedAt: Date = Date(), isInspecting: Bool, selectedID: String?, transport: GrabTransportStatus = GrabDebugServer.shared.status, nodes: [GrabNode]) {
        self.version = version; self.generatedAt = generatedAt; self.isInspecting = isInspecting; self.selectedID = selectedID; self.transport = transport; self.nodes = nodes
    }
}
