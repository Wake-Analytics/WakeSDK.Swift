import Foundation
@testable import Wake

/// In-memory store so tests can inspect exactly what the SDK persisted.
final class InMemoryStore: KeyValueStore, @unchecked Sendable {
    private(set) var strings: [String: String] = [:]
    private(set) var ints: [String: Int] = [:]

    var isEmpty: Bool { strings.isEmpty && ints.isEmpty }

    func string(forKey key: String) -> String? { strings[key] }
    func set(_ value: String?, forKey key: String) {
        if let value { strings[key] = value } else { strings[key] = nil }
    }
    func integer(forKey key: String) -> Int? { ints[key] }
    func setInteger(_ value: Int?, forKey key: String) {
        if let value { ints[key] = value } else { ints[key] = nil }
    }
}

/// Fixed clock for deterministic `client_ts`.
final class MutableClock: Clock, @unchecked Sendable {
    var date: Date
    init(_ date: Date) { self.date = date }
    func now() -> Date { date }
}

struct ManualClock: Clock {
    var date: Date
    func now() -> Date { date }
}

/// Deterministic, sequential UUIDs: "id-1", "id-2", …
final class CountingUUID {
    private var n = 0
    func next() -> String {
        n += 1
        return "id-\(n)"
    }
}

final class CollectingSink: EventSink {
    private(set) var received: [Wake.Envelope] = []
    func receive(_ envelope: Wake.Envelope) { received.append(envelope) }
}

/// Sink that also fires a callback per envelope — for awaiting the async
/// `$first_launch` origin path with an XCTestExpectation.
final class ClosureSink: EventSink, @unchecked Sendable {
    private let lock = NSLock()
    private var _received: [Wake.Envelope] = []
    private let onReceive: @Sendable (Wake.Envelope) -> Void

    init(onReceive: @escaping @Sendable (Wake.Envelope) -> Void) {
        self.onReceive = onReceive
    }

    var received: [Wake.Envelope] {
        lock.lock(); defer { lock.unlock() }
        return _received
    }

    func receive(_ envelope: Wake.Envelope) {
        lock.lock(); _received.append(envelope); lock.unlock()
        onReceive(envelope)
    }
}

/// Returns a fixed origin date (or nil) for the `$first_launch` origin path.
struct StubAppOrigin: AppOriginSource {
    let date: Date?
    func originalDownloadDate() async -> Date? { date }
}

/// In-memory event buffer for uploader tests.
final class InMemoryEventBuffer: EventBuffer, @unchecked Sendable {
    private let lock = NSLock()
    private var events: [BufferedEvent] = []

    func append(_ event: BufferedEvent) {
        lock.lock(); defer { lock.unlock() }
        events.append(event)
    }
    func peek(limit: Int) -> [BufferedEvent] {
        lock.lock(); defer { lock.unlock() }
        return Array(events.prefix(limit))
    }
    func removeAll() {
        lock.lock(); defer { lock.unlock() }
        events = []
    }

    func remove(ids: [String]) {
        lock.lock(); defer { lock.unlock() }
        let drop = Set(ids)
        events.removeAll { drop.contains($0.eventID) }
    }
    var count: Int {
        lock.lock(); defer { lock.unlock() }
        return events.count
    }
}

/// Scripted HTTP client: routes responses by URL path and records every request.
final class MockHTTPClient: HTTPClient, @unchecked Sendable {
    struct Sent { let method: String; let url: URL; let body: Data? }

    private let lock = NSLock()
    private var _requests: [Sent] = []
    private let responder: @Sendable (URL) -> Result<HTTPResponse, Error>

    init(responder: @escaping @Sendable (URL) -> Result<HTTPResponse, Error>) {
        self.responder = responder
    }

    /// Convenience: a fixed status + body for every request.
    convenience init(status: Int, body: Data = Data()) {
        self.init(responder: { _ in .success(HTTPResponse(status: status, body: body)) })
    }

    var requests: [Sent] {
        lock.lock(); defer { lock.unlock() }
        return _requests
    }

    func requests(matching path: String) -> [Sent] {
        requests.filter { $0.url.path.contains(path) }
    }

    func send(method: String, url: URL, headers: [String: String], body: Data?) async throws -> HTTPResponse {
        lock.withLock { _requests.append(Sent(method: method, url: url, body: body)) }
        switch responder(url) {
        case .success(let r): return r
        case .failure(let e): throw e
        }
    }
}

struct MockNetworkError: Error {}

func makeEnvelope(
    id: String,
    name: String = "opened_paywall",
    seq: Int = 1,
    params: [String: Wake.ParamValue] = [:]
) -> Wake.Envelope {
    Wake.Envelope(
        eventID: id, name: name, params: params,
        clientTS: Date(timeIntervalSince1970: 0), eventSequence: seq,
        sdkVersion: "0.1.0"
    )
}

func makeBufferedEvent(id: String, name: String = "opened_paywall", seq: Int = 1) -> BufferedEvent {
    BufferedEvent(makeEnvelope(id: id, name: name, seq: seq))
}

/// Records lifecycle calls from Core without doing any transport.
final class SpyLifecycle: TransportLifecycle, @unchecked Sendable {
    private(set) var started: [(apiKey: String, installID: String)] = []
    private(set) var erasures: [String] = []

    private(set) var flushes = 0

    func start(apiKey: String, installID: String) {
        started.append((apiKey, installID))
    }
    func requestErasure(installID: String) {
        erasures.append(installID)
    }
    func flush() {
        flushes += 1
    }
}

/// Drives foreground/background transitions manually in tests.
final class ManualLifecycleObserver: AppLifecycleObserver, @unchecked Sendable {
    var onForeground: (() -> Void)?
    var onBackground: (() -> Void)?
    func start() {}
    func stop() {}
    func fireForeground() { onForeground?() }
    func fireBackground() { onBackground?() }
}

/// The vocabulary version a test build reports. Any integer will do — the SDK
/// carries the number and holds no opinion about it.
