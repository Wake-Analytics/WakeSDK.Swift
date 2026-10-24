import Foundation

/// The values an event passed for the rest of its feature: a paywall's source when it
/// opened, attached to the purchase or dismissal that follows.
///
/// One set per storing event, replaced each time it's logged, so later events take
/// what the latest one passed. Kept on disk like screen-time marks, so a purchase
/// after a relaunch still knows where the paywall was opened from.
final class CarriedValues: @unchecked Sendable {

    private let store: KeyValueStore
    private let lock = NSLock()

    init(store: KeyValueStore) {
        self.store = store
    }

    /// What `event` passed for `keys` this time. A key it left out is gone, not kept
    /// from an earlier occurrence: the latest one speaks for the feature.
    func store(_ params: [String: Wake.ParamValue], keys: [String], for event: String) {
        lock.lock(); defer { lock.unlock() }
        var all = load()
        all[event] = params.filter { keys.contains($0.key) }
        save(all)
    }

    /// What `event` last passed, or nothing when it never was logged.
    func values(from event: String) -> [String: Wake.ParamValue] {
        lock.lock(); defer { lock.unlock() }
        return load()[event] ?? [:]
    }

    /// Erasure: they describe what someone did in the app.
    func reset() {
        lock.lock(); defer { lock.unlock() }
        store.set(nil, forKey: Keys.carried)
    }

    // MARK: Helpers (lock held)

    private func load() -> [String: [String: Wake.ParamValue]] {
        guard let raw = store.string(forKey: Keys.carried),
              let all = try? JSONDecoder().decode([String: [String: Wake.ParamValue]].self, from: Data(raw.utf8))
        else { return [:] }
        return all
    }

    private func save(_ all: [String: [String: Wake.ParamValue]]) {
        guard let data = try? JSONEncoder().encode(all) else { return }
        store.set(String(decoding: data, as: UTF8.self), forKey: Keys.carried)
    }
}
