import Foundation

struct AnyCodable: Codable, @unchecked Sendable {
    let value: Any

    init(_ value: Any) { self.value = value }

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self.value = NSNull() }
        else if let b = try? c.decode(Bool.self) { self.value = b }
        else if let i = try? c.decode(Int.self) { self.value = i }
        else if let d = try? c.decode(Double.self) { self.value = d }
        else if let s = try? c.decode(String.self) { self.value = s }
        else if let a = try? c.decode([AnyCodable].self) { self.value = a }
        else if let o = try? c.decode([String: AnyCodable].self) { self.value = o }
        else { self.value = NSNull() }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch value {
        case is NSNull: try c.encodeNil()
        case let b as Bool: try c.encode(b)
        case let i as Int: try c.encode(i)
        case let d as Double: try c.encode(d)
        case let s as String: try c.encode(s)
        case let a as [Any]: try c.encode(a.map { AnyCodable($0) })
        case let o as [String: Any]: try c.encode(o.mapValues { AnyCodable($0) })
        case let a as [AnyCodable]: try c.encode(a)
        case let o as [String: AnyCodable]: try c.encode(o)
        default: try c.encodeNil()
        }
    }
}
