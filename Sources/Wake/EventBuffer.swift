import Foundation

/// The wire-ready subset of an envelope.
struct BufferedEvent: Codable, Sendable, Equatable {
    let eventID: String
    let name: String
    let params: [String: Wake.ParamValue]
    let clientTS: Date
    let eventSequence: Int
    let sessionID: String?
    let isSandbox: Bool
    let osVersion: String?
    let appVersion: String?
    let platform: String?
    let device: String?
    let locale: String?
    let country: String?
    /// Optional, so events persisted by an older build still decode.
    let configID: String?

    init(_ e: Wake.Envelope) {
        eventID = e.eventID
        name = e.name
        params = e.params
        clientTS = e.clientTS
        eventSequence = e.eventSequence
        sessionID = e.sessionID
        isSandbox = e.isSandbox
        osVersion = e.osVersion
        appVersion = e.appVersion
        platform = e.platform
        device = e.device
        locale = e.locale
        country = e.country
        configID = e.configID
    }
}

/// Durable event queue. Events are removed only on a confirmed server ack.
protocol EventBuffer: AnyObject, Sendable {
    func append(_ event: BufferedEvent)
    func peek(limit: Int) -> [BufferedEvent]
    func remove(ids: [String])
    func removeAll()
    var count: Int { get }
}

final class FileEventBuffer: EventBuffer, @unchecked Sendable {
    private let url: URL
    private let lock = NSLock()

    init(fileURL: URL) {
        self.url = fileURL
        try? FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
    }

    static func makeDefault() -> FileEventBuffer {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return FileEventBuffer(fileURL: base.appendingPathComponent("app.realwake/events.json"))
    }

    func append(_ event: BufferedEvent) {
        lock.lock(); defer { lock.unlock() }
        var events = load()
        events.append(event)
        save(events)
    }

    func peek(limit: Int) -> [BufferedEvent] {
        lock.lock(); defer { lock.unlock() }
        return Array(load().prefix(limit))
    }

    func remove(ids: [String]) {
        lock.lock(); defer { lock.unlock() }
        let drop = Set(ids)
        save(load().filter { !drop.contains($0.eventID) })
    }

    func removeAll() {
        lock.lock(); defer { lock.unlock() }
        save([])
    }

    var count: Int {
        lock.lock(); defer { lock.unlock() }
        return load().count
    }

    // MARK: Storage (lock held)

    private func load() -> [BufferedEvent] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([BufferedEvent].self, from: data)) ?? []
    }

    private func save(_ events: [BufferedEvent]) {
        guard let data = try? JSONEncoder().encode(events) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
