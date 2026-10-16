extension Wake {

    /// One occurrence of an event, ready for `Wake.log(_:)`. The file Wake generates
    /// declares one per designed event, with the event's properties as arguments.
    public struct Event: Sendable {
        let name: String
        let params: [String: ParamValue]
        /// Property id → the starting point it measures from. Resolved when the event
        /// is logged, not when it is built.
        let screenTimeSince: [String: String]
        let transaction: TransactionIdentity?
        /// The configuration the generated file was cut from. It rides on the event so
        /// Wake can tell a build with the latest design has reported in.
        let config: String?

        /// Not for direct use — backs the generated events.
        public static func _event(
            _ name: String,
            params: [String: ParamValue] = [:],
            screenTimeSince: [String: String] = [:],
            config: String? = nil
        ) -> Event {
            Event(
                name: name,
                params: params,
                screenTimeSince: screenTimeSince,
                transaction: nil,
                config: config
            )
        }
    }

    /// A place in the journey for a screen-time-since property to measure back to,
    /// ready for `Wake.mark(_:)`. Declared by the file Wake generates.
    public struct StartingPoint: Sendable {
        let id: String

        /// Not for direct use — backs the generated starting points.
        public static func _startingPoint(_ id: String) -> StartingPoint {
            StartingPoint(id: id)
        }
    }
}
