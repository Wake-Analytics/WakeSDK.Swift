import Foundation
#if canImport(Darwin)
import Darwin
#endif

/// Build/runtime facts stamped on every envelope. No device identifiers.
enum Environment {

    /// True for debug builds and TestFlight/sandbox installs.
    static let isSandbox: Bool = {
        #if DEBUG
        return true
        #else
        if Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt" {
            return true
        }
        return false
        #endif
    }()

    static let osVersion: String = {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        return "\(v.majorVersion).\(v.minorVersion).\(v.patchVersion)"
    }()

    static let appVersion: String? = {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    }()

    /// Lowercase OS family. Mac Catalyst reports `ios`.
    static let platform: String = {
        #if os(iOS)
        return "ios"
        #elseif os(macOS)
        return "macos"
        #elseif os(tvOS)
        return "tvos"
        #elseif os(watchOS)
        return "watchos"
        #elseif os(visionOS)
        return "visionos"
        #else
        return "unknown"
        #endif
    }()

    /// Hardware model identifier, e.g. "iPhone16,2" — a model class, not a device id.
    static let device: String? = {
        if let sim = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"], !sim.isEmpty {
            return sim
        }
        var size = 0
        guard sysctlbyname("hw.machine", nil, &size, nil, 0) == 0, size > 0 else { return nil }
        var machine = [UInt8](repeating: 0, count: size)
        guard sysctlbyname("hw.machine", &machine, &size, nil, 0) == 0 else { return nil }
        let id = String(decoding: machine.prefix { $0 != 0 }, as: UTF8.self)
        return id.isEmpty ? nil : id
    }()

    /// BCP-47 language tag, e.g. "en-US".
    static let locale: String? = {
        let id = Locale.current.identifier(.bcp47)
        return id.isEmpty ? nil : id
    }()

    /// ISO 3166-1 alpha-2 region from the user's locale, e.g. "US".
    static let country: String? = {
        Locale.current.region?.identifier
    }()
}
