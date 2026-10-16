/// Where the logging core hands finished envelopes.
protocol EventSink: AnyObject {
    func receive(_ envelope: Wake.Envelope)
}

/// Drops everything.
final class NoopSink: EventSink {
    func receive(_ envelope: Wake.Envelope) {}
}
