extension Wake {

    /// The closed set of param types; raw values are the wire tokens. What a
    /// value can BE — the SDK no longer holds what an event was declared to take,
    /// since generated code makes that a compile-time question.
    public enum ParamType: String, Sendable, Hashable, Codable, CaseIterable {
        case string
        case int
        case double
        case bool
        case stringArray = "string[]"
        case intArray = "int[]"
        case doubleArray = "double[]"
        case boolArray = "bool[]"
    }
}
