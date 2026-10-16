/// Reserved names for SDK-emitted automatic events.
enum AutoEvent {
    static let prefix = "$"
    static let firstLaunch = "$first_launch"
    static let sessionStart = "$session_start"
    static let sessionEnd = "$session_end"

    static let originalDownloadTS = "original_download_ts"

    static func isAutomatic(_ name: String) -> Bool { name.hasPrefix(prefix) }
}
