import Foundation

/// A compact Codable JSON value used for debug metadata.
public enum GrabJSONValue: Codable, Sendable, Equatable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([GrabJSONValue])
    case object([String: GrabJSONValue])

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([GrabJSONValue].self) {
            self = .array(value)
        } else if let value = try? container.decode([String: GrabJSONValue].self) {
            self = .object(value)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null: try container.encodeNil()
        case .bool(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .string(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        }
    }

    public static func from(_ value: Any?) -> GrabJSONValue {
        guard let value else { return .null }
        switch value {
        case let value as GrabJSONValue: return value
        case let value as Bool: return .bool(value)
        case let value as Int: return .number(Double(value))
        case let value as Int8: return .number(Double(value))
        case let value as Int16: return .number(Double(value))
        case let value as Int32: return .number(Double(value))
        case let value as Int64: return .number(Double(value))
        case let value as UInt: return .number(Double(value))
        case let value as UInt8: return .number(Double(value))
        case let value as UInt16: return .number(Double(value))
        case let value as UInt32: return .number(Double(value))
        case let value as UInt64: return .number(Double(value))
        case let value as Float: return .number(Double(value))
        case let value as Double: return .number(value)
        case let value as Decimal: return .string(NSDecimalNumber(decimal: value).stringValue)
        case let value as String: return .string(value)
        case let value as StaticString: return .string(String(describing: value))
        case let value as [Any?]: return .array(value.map { GrabJSONValue.from($0) })
        case let value as [String: Any?]: return .object(value.mapValues { GrabJSONValue.from($0) })
        case let value as [String: Any]: return .object(value.mapValues { GrabJSONValue.from($0) })
        default: return .string(String(describing: value))
        }
    }
}

extension GrabJSONValue: ExpressibleByNilLiteral { public init(nilLiteral: ()) { self = .null } }
extension GrabJSONValue: ExpressibleByBooleanLiteral { public init(booleanLiteral value: Bool) { self = .bool(value) } }
extension GrabJSONValue: ExpressibleByIntegerLiteral { public init(integerLiteral value: Int) { self = .number(Double(value)) } }
extension GrabJSONValue: ExpressibleByFloatLiteral { public init(floatLiteral value: Double) { self = .number(value) } }
extension GrabJSONValue: ExpressibleByStringLiteral { public init(stringLiteral value: String) { self = .string(value) } }
extension GrabJSONValue: ExpressibleByArrayLiteral { public init(arrayLiteral elements: GrabJSONValue...) { self = .array(elements) } }
extension GrabJSONValue: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, GrabJSONValue)...) {
        self = .object(Dictionary(uniqueKeysWithValues: elements))
    }
}
