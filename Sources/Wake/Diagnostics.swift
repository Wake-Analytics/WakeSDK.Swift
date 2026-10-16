import Foundation
import os

extension Wake {

    /// How much the SDK reports about what it's doing. Off by default; set it before
    /// `start` to trace an integration. Output goes to the unified log (and Xcode's
    /// console) under the `app.realwake` subsystem.
    public enum LogLevel: Int, Sendable, Comparable {
        /// Silence, including integration mistakes. Rarely what you want.
        case off
        /// The default. Integration problems only — a rejected API key, a batch the
        /// server refused. Silent for a correct integration.
        case error
        /// Everything above plus lifecycle and upload activity.
        case debug

        public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    public static var logLevel: LogLevel {
        get { Diag.level }
        set { Diag.level = newValue }
    }
}

enum Diag {
    private static let state = OSAllocatedUnfairLock(initialState: Wake.LogLevel.error)
    private static let logger = Logger(subsystem: "app.realwake", category: "sdk")

    static var level: Wake.LogLevel {
        get { state.withLock { $0 } }
        set { state.withLock { $0 = newValue } }
    }

    static func error(_ message: @autoclosure () -> String) {
        guard level >= .error else { return }
        let text = message()
        logger.error("[Wake] \(text, privacy: .public)")
    }

    static func debug(_ message: @autoclosure () -> String) {
        guard level >= .debug else { return }
        let text = message()
        logger.notice("[Wake] \(text, privacy: .public)")
    }
}
