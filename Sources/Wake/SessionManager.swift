import Foundation

extension Wake {
    /// An automatic event to emit, with the session id it must carry.
    struct AutoEmit: Equatable {
        let name: String
        let params: [String: ParamValue]
        let sessionID: String
    }
}

/// Tracks the current session and returns the automatic events its transitions
/// produce; `Core` records them. `$session_end` reports foreground time only.
final class SessionManager: @unchecked Sendable {
    private let clock: Clock
    private let store: KeyValueStore
    private let uuid: () -> String
    private let timeout: TimeInterval
    private let lock = NSLock()

    init(clock: Clock, store: KeyValueStore, uuid: @escaping () -> String, timeout: TimeInterval = 600) {
        self.clock = clock
        self.store = store
        self.uuid = uuid
        self.timeout = timeout
    }

    var currentSessionID: String? {
        lock.lock(); defer { lock.unlock() }
        return load()?.id
    }

    /// The current session's foreground time — what banked, plus the segment in
    /// flight. Backs screen time since `$session_start`; nil when no session is
    /// open. Read, never written, so it can't disturb what `$session_end` reports.
    func foregroundSeconds(now: Date) -> TimeInterval? {
        lock.lock(); defer { lock.unlock() }
        guard let session = load() else { return nil }
        guard let fg = session.lastForegroundTS else { return session.accumulated }
        return session.accumulated + max(0, now.timeIntervalSince(fg))
    }

    /// Resumes the session when the gap since backgrounding is within the timeout,
    /// otherwise closes it and begins a new one.
    func activated(now: Date) -> [Wake.AutoEmit] {
        lock.lock(); defer { lock.unlock() }

        guard var session = load() else {
            return [begin(now: now)]
        }

        let reference = session.lastBackgroundTS ?? session.lastForegroundTS ?? session.startTS
        if now.timeIntervalSince(reference) > timeout {
            let end = endEmit(session)
            return [end, begin(now: now)]
        } else {
            session.lastForegroundTS = now
            session.lastBackgroundTS = nil
            save(session)
            return []
        }
    }

    /// Accrues the finished foreground interval; the session stays open until a
    /// later `activated` finds it timed out.
    func backgrounded(now: Date) {
        lock.lock(); defer { lock.unlock() }
        guard var session = load() else { return }
        if let fg = session.lastForegroundTS {
            session.accumulated += now.timeIntervalSince(fg)
            session.lastForegroundTS = nil
        }
        session.lastBackgroundTS = now
        save(session)
    }

    func reset() {
        lock.lock(); defer { lock.unlock() }
        store.set(nil, forKey: Keys.session)
    }

    // MARK: Helpers (lock held)

    private func begin(now: Date) -> Wake.AutoEmit {
        let id = uuid()
        save(PersistedSession(id: id, startTS: now, accumulated: 0, lastForegroundTS: now, lastBackgroundTS: nil))
        return Wake.AutoEmit(name: AutoEvent.sessionStart, params: [:], sessionID: id)
    }

    private func endEmit(_ session: PersistedSession) -> Wake.AutoEmit {
        let seconds = Int(session.accumulated.rounded())
        return Wake.AutoEmit(
            name: AutoEvent.sessionEnd,
            params: ["duration_seconds": .int(seconds)],
            sessionID: session.id
        )
    }

    private func load() -> PersistedSession? {
        guard let raw = store.string(forKey: Keys.session),
              let data = raw.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(PersistedSession.self, from: data)
    }

    private func save(_ session: PersistedSession) {
        guard let data = try? JSONEncoder().encode(session),
              let raw = String(data: data, encoding: .utf8) else { return }
        store.set(raw, forKey: Keys.session)
    }
}

private struct PersistedSession: Codable {
    var id: String
    var startTS: Date
    var accumulated: TimeInterval
    var lastForegroundTS: Date?
    var lastBackgroundTS: Date?
}
