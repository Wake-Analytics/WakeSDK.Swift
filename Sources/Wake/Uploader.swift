import Foundation

extension Wake {
    /// Result of one events flush.
    enum FlushOutcome: Equatable {
        case notConfigured
        case empty
        case sent(Int)
        case retained
        case held
        case dropped(Int)
    }
}

/// Serializes all network work: event flushes and the erasure beacon. One flush
/// at a time.
actor Uploader {
    private let buffer: EventBuffer
    private let http: HTTPClient
    private let store: KeyValueStore
    private let baseURL: URL
    private let sdkVersion: String
    private let batchLimit: Int
    private let backoff = Backoff()

    private var apiKey: String?
    private var installID: String?
    private var holdUntilRestart = false
    private var attempt = 0

    var pendingDelay: TimeInterval { backoff.delay(forAttempt: attempt) }

    init(
        buffer: EventBuffer,
        http: HTTPClient,
        store: KeyValueStore,
        baseURL: URL = Wake.Config.baseURL,
        sdkVersion: String = Wake.sdkVersion,
        batchLimit: Int = 100
    ) {
        self.buffer = buffer
        self.http = http
        self.store = store
        self.baseURL = baseURL
        self.sdkVersion = sdkVersion
        self.batchLimit = batchLimit
    }

    /// Stops event uploads, keeping the api key so the erasure beacon can still send.
    func deactivate() {
        installID = nil
        attempt = 0
    }

    func configure(apiKey: String, installID: String) {
        self.apiKey = apiKey
        self.installID = installID
        self.holdUntilRestart = false
        self.attempt = 0
    }

    // MARK: Events

    @discardableResult
    func flush(now: Date = Date()) async -> Wake.FlushOutcome {
        guard let apiKey, let installID, !holdUntilRestart else {
            return .notConfigured
        }
        let events = buffer.peek(limit: batchLimit)
        guard !events.isEmpty else { return .empty }

        let body: Data
        do {
            body = try Wire.eventsBody(
                installID: installID, sdkVersion: sdkVersion, events: events
            )
        } catch {
            attempt += 1
            return .retained
        }

        do {
            let resp = try await http.send(
                method: "POST", url: url(Wake.Config.Path.events),
                headers: Wire.authHeaders(apiKey: apiKey), body: body
            )
            switch HTTPPolicy.classify(resp.status) {
            case .success:
                buffer.remove(ids: events.map(\.eventID))
                attempt = 0
                Diag.debug("uploaded \(events.count) event(s)")
                return .sent(events.count)
            case .retry:
                attempt += 1
                Diag.debug("ingest returned HTTP \(resp.status) — \(events.count) event(s) retained, retrying in \(Int(pendingDelay))s")
                return .retained
            case .hold:
                holdUntilRestart = true
                Diag.error("ingest rejected the API key (HTTP \(resp.status)) — uploads paused until the next launch")
                return .held
            case .dropPermanent:
                buffer.remove(ids: events.map(\.eventID))
                attempt = 0
                Diag.error("ingest permanently rejected \(events.count) event(s) (HTTP \(resp.status)) — dropped")
                return .dropped(events.count)
            }
        } catch {
            attempt += 1
            Diag.debug("upload failed (\(error.localizedDescription)) — \(events.count) event(s) retained, retrying in \(Int(pendingDelay))s")
            return .retained
        }
    }

    // MARK: Erasure

    func drainErasure() async {
        guard let apiKey, let id = store.string(forKey: Keys.pendingErasureID) else { return }
        do {
            let resp = try await http.send(
                method: "POST", url: url(Wake.Config.Path.erasure),
                headers: Wire.authHeaders(apiKey: apiKey),
                body: try Wire.erasureBody(installID: id)
            )
            if (200..<300).contains(resp.status) {
                store.set(nil, forKey: Keys.pendingErasureID)
            }
        } catch {
            // retried on the next start
        }
    }

    private func url(_ path: String) -> URL {
        baseURL.appendingPathComponent(path)
    }
}
