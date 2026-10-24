import Foundation

/// How long the app has actually been in front, for the life of the install, and
/// where on that total each event was last logged.
///
/// One accumulator, and a mark is a number on it. Logging an event stores the total
/// as it stands under the event's name; screen time since it is one subtraction.
/// There is one mark per event the app has logged, and nothing runs on a timer.
///
/// Foreground time only, which is the whole reason this exists: it cannot be
/// recovered from event timestamps afterwards, because nothing in the event stream
/// says when the app stopped being looked at.
///
/// Advances on the same transitions `SessionManager` advances on, off the same
/// `Clock`, so a session's duration and a screen-time-since value can never
/// disagree about what a second is.
final class ScreenTime: @unchecked Sendable {

    private let clock: Clock
    private let store: KeyValueStore
    private let lock = NSLock()

    init(clock: Clock, store: KeyValueStore) {
        self.clock = clock
        self.store = store
    }

    /// The app came to the front: start counting.
    func resumed(now: Date) {
        lock.lock(); defer { lock.unlock() }
        var state = load()
        // Already counting — a second resume without a background in between would
        // otherwise discard the segment in flight.
        guard state.lastForegroundTS == nil else { return }
        state.lastForegroundTS = now
        save(state)
    }

    /// The app went away: bank the segment that just ended. This is also the only
    /// point the total is written, so a hard kill loses the time since the last
    /// backgrounding — undercounting, which is the safe direction.
    func backgrounded(now: Date) {
        lock.lock(); defer { lock.unlock() }
        var state = load()
        guard let since = state.lastForegroundTS else { return }
        state.total += max(0, now.timeIntervalSince(since))
        state.lastForegroundTS = nil
        save(state)
    }

    /// Foreground seconds so far: what has been banked, plus the segment in flight.
    func total(now: Date) -> TimeInterval {
        lock.lock(); defer { lock.unlock() }
        return total(load(), now: now)
    }

    /// Put the event's mark here, or move it here if it already exists. The last
    /// occurrence wins: screen time since an event always counts from the latest
    /// time it was logged.
    func mark(_ id: String, now: Date) {
        lock.lock(); defer { lock.unlock() }
        var state = load()
        state.marks[id] = total(state, now: now)
        save(state)
    }

    /// Foreground seconds since that event was marked, or nil when it never was.
    /// Absence is a fact about this subject, never a zero.
    func since(_ id: String, now: Date) -> TimeInterval? {
        lock.lock(); defer { lock.unlock() }
        let state = load()
        guard let mark = state.marks[id] else { return nil }
        return max(0, total(state, now: now) - mark)
    }

    /// Erasure. The total and every mark are facts about a person's use of the app,
    /// so they go when the subject does.
    func reset() {
        lock.lock(); defer { lock.unlock() }
        store.set(nil, forKey: Keys.screenTime)
    }

    // MARK: Helpers (lock held)

    private func total(_ state: PersistedScreenTime, now: Date) -> TimeInterval {
        guard let since = state.lastForegroundTS else { return state.total }
        return state.total + max(0, now.timeIntervalSince(since))
    }

    private func load() -> PersistedScreenTime {
        guard let raw = store.string(forKey: Keys.screenTime),
              let data = raw.data(using: .utf8),
              let state = try? JSONDecoder().decode(PersistedScreenTime.self, from: data)
        else { return PersistedScreenTime() }
        return state
    }

    private func save(_ state: PersistedScreenTime) {
        guard let data = try? JSONEncoder().encode(state),
              let raw = String(data: data, encoding: .utf8) else { return }
        store.set(raw, forKey: Keys.screenTime)
    }
}

private struct PersistedScreenTime: Codable {
    var total: TimeInterval = 0
    var lastForegroundTS: Date?
    var marks: [String: TimeInterval] = [:]
}
