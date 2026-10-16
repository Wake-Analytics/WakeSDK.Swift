import Foundation

extension Wake {
    enum Config {
        static let defaultBaseURL = URL(string: "https://ingest.realwake.app")!

        /// Env var or Info.plist key that overrides the ingest host.
        static let overrideKey = "WAKE_INGEST_URL"

        static var baseURL: URL {
            resolveBaseURL(
                environment: ProcessInfo.processInfo.environment[overrideKey],
                infoPlist: Bundle.main.object(forInfoDictionaryKey: overrideKey) as? String
            )
        }

        static func resolveBaseURL(environment: String?, infoPlist: String?) -> URL {
            for candidate in [environment, infoPlist] {
                guard let raw = candidate?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !raw.isEmpty,
                      let url = URL(string: raw),
                      let scheme = url.scheme?.lowercased(),
                      scheme == "http" || scheme == "https",
                      url.host != nil
                else { continue }
                return url
            }
            return defaultBaseURL
        }

        enum Path {
            static let events = "v1/events"
            static let erasure = "v1/erasure"
        }
    }
}
