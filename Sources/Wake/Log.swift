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
    /// A screen-time-since property is measured here, as the event is logged: the
    /// foreground time since its From event was last logged on this install. When it
    /// never was, the property is left off rather than sent as zero.
    ///
    /// Every event logged is also a place later events can count from, so it moves
    /// its own stake once its properties are measured.
    public static func log(_ event: Event) {
        Core.shared.log(event)
    }
}
