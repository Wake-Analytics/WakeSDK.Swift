extension Wake {

    /// A runtime param value, mirroring `ParamType`.
    public enum ParamValue: Sendable, Hashable {
        case string(String)
        case int(Int)
        case double(Double)
        case bool(Bool)
        case stringArray([String])
        case intArray([Int])
        case doubleArray([Double])
        case boolArray([Bool])

        public var type: ParamType {
            switch self {
            case .string:      return .string
            case .int:         return .int
            case .double:      return .double
            case .bool:        return .bool
            case .stringArray: return .stringArray
            case .intArray:    return .intArray
            case .doubleArray: return .doubleArray
            case .boolArray:   return .boolArray
            }
        }
    }
}
