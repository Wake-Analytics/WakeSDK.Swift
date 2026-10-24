extension Wake {

    /// One occurrence of an event, ready for `Wake.log(_:)`. The file Wake generates
    /// declares one per designed event, with the event's properties as arguments.
    public struct Event: Sendable {
        let name: String
        let params: [String: ParamValue]
        /// Property id → the event it counts from. Resolved when the event is logged,
        /// not when it is built.
        let screenTimeSince: [String: String]
        /// Keys of `params` the rest of the feature takes from this event.
        let carries: [String]
        /// The event whose carried values this one takes, for keys it doesn't pass.
        let carriedFrom: String?
        let transaction: TransactionIdentity?
        /// The configuration the generated file was cut from. It rides on the event so
        /// Wake can tell a build with the latest design has reported in.
        let config: String?

        /// Not for direct use — backs the generated events.
        public static func _event(
            _ name: String,
            params: [String: ParamValue] = [:],
            screenTimeSince: [String: String] = [:],
            carries: [String] = [],
            carriedFrom: String? = nil,
            config: String? = nil
        ) -> Event {
            Event(
                name: name,
                params: params,
                screenTimeSince: screenTimeSince,
                carries: carries,
                carriedFrom: carriedFrom,
                transaction: nil,
                config: config
            )
        }
    }
}
