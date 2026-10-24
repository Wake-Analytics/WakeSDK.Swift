import Foundation

/// Persistent key/value seam. Everything the SDK writes to disk goes through it.
protocol KeyValueStore: AnyObject, Sendable {
    func string(forKey key: String) -> String?
    func set(_ value: String?, forKey key: String)
    func integer(forKey key: String) -> Int?
    func setInteger(_ value: Int?, forKey key: String)
}

/// Namespaced UserDefaults keys.
enum Keys {
    static let prefix = "app.realwake."
    static let installID = prefix + "installID"
    static let sequence = prefix + "eventSequence"
    static let pendingErasureID = prefix + "pendingErasureInstallID"
    static let session = prefix + "session"
    static let screenTime = prefix + "screenTime"
    static let carried = prefix + "carried"
}

final class UserDefaultsStore: KeyValueStore, @unchecked Sendable {
    private let defaults: UserDefaults

    init(_ defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func string(forKey key: String) -> String? {
        defaults.object(forKey: key) as? String
    }

    func set(_ value: String?, forKey key: String) {
        if let value {
            defaults.set(value, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }

    func integer(forKey key: String) -> Int? {
        defaults.object(forKey: key) as? Int
    }

    func setInteger(_ value: Int?, forKey key: String) {
        if let value {
            defaults.set(value, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }
}
