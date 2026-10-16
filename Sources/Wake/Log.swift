extension Wake {

    /// Activates collection. Call it once, at the app's own launch.
    ///
    /// Everything the SDK does is behind this call: before it, nothing is written,
    /// nothing is uploaded, and every log call is a no-op. Re-starting is harmless
    /// and keeps the install's identity.
    ///
    /// The package alone is enough to call it — sessions and launches are reported
    /// from here on. Events need the file Wake generates for the app.
    public static func start(apiKey: String) {
        Core.shared.start(apiKey: apiKey)
    }

    /// Stops collection and erases the subject, locally and server-side.
    public static func deleteData() {
        Core.shared.deleteData()
    }

    /// Records one event. Each of the app's events is declared on `Event` by the file
    /// Wake generates, so `Wake.log(.` lists them.
    ///
    /// A screen-time-since property is measured here, as the event is logged. When
    /// its starting point was never marked, the property is left off rather than sent
    /// as zero.
    public static func log(_ event: Event) {
        var params = event.params
        for (paramID, startingPoint) in event.screenTimeSince {
            if let seconds = Core.shared.screenTimeSince(startingPoint) {
                params[paramID] = .double(seconds)
            }
        }
        Core.shared.record(
            name: event.name,
            params: params,
            transaction: event.transaction,
            configID: event.config
        )
    }

    /// Marks a starting point, declared on `StartingPoint` by the generated file.
    ///
    /// A starting point is a place in the journey, not an event: nothing is
    /// recorded, nothing is uploaded, and it never appears in anyone's timeline. All
    /// it does is put a stake in this install's foreground time, for an event to
    /// measure back to. Marking it again moves the stake.
    public static func mark(_ point: StartingPoint) {
        Core.shared.mark(point.id)
    }
}
