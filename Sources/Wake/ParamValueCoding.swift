import Foundation

extension Wake.ParamValue {

    /// Untagged JSON form for the wire.
    var jsonObject: Any {
        switch self {
        case .string(let v):      return v
        case .int(let v):         return v
        case .double(let v):      return v
        case .bool(let v):        return v
        case .stringArray(let v): return v
        case .intArray(let v):    return v
        case .doubleArray(let v): return v
        case .boolArray(let v):   return v
        }
    }
}

/// Tagged Codable form for the on-disk buffer, distinct from the untagged wire form.
extension Wake.ParamValue: Codable {
    private enum CodingKeys: String, CodingKey { case type, value }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(type.rawValue, forKey: .type)
        switch self {
        case .string(let v):      try c.encode(v, forKey: .value)
        case .int(let v):         try c.encode(v, forKey: .value)
        case .double(let v):      try c.encode(v, forKey: .value)
        case .bool(let v):        try c.encode(v, forKey: .value)
        case .stringArray(let v): try c.encode(v, forKey: .value)
        case .intArray(let v):    try c.encode(v, forKey: .value)
        case .doubleArray(let v): try c.encode(v, forKey: .value)
        case .boolArray(let v):   try c.encode(v, forKey: .value)
        }
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let raw = try c.decode(String.self, forKey: .type)
        guard let type = Wake.ParamType(rawValue: raw) else {
            throw DecodingError.dataCorruptedError(
                forKey: .type, in: c, debugDescription: "unknown param type \(raw)"
            )
        }
        switch type {
        case .string:      self = .string(try c.decode(String.self, forKey: .value))
        case .int:         self = .int(try c.decode(Int.self, forKey: .value))
        case .double:      self = .double(try c.decode(Double.self, forKey: .value))
        case .bool:        self = .bool(try c.decode(Bool.self, forKey: .value))
        case .stringArray: self = .stringArray(try c.decode([String].self, forKey: .value))
        case .intArray:    self = .intArray(try c.decode([Int].self, forKey: .value))
        case .doubleArray: self = .doubleArray(try c.decode([Double].self, forKey: .value))
        case .boolArray:   self = .boolArray(try c.decode([Bool].self, forKey: .value))
        }
    }
}
