import Foundation

protocol AppLifecycleObserver: AnyObject, Sendable {
    var onForeground: (() -> Void)? { get set }
    var onBackground: (() -> Void)? { get set }
    func start()
    func stop()
}

#if canImport(UIKit)
import UIKit
private let foregroundNotification = UIApplication.didBecomeActiveNotification
private let backgroundNotification = UIApplication.didEnterBackgroundNotification
#elseif canImport(AppKit)
import AppKit
private let foregroundNotification = NSApplication.didBecomeActiveNotification
private let backgroundNotification = NSApplication.didResignActiveNotification
#endif

final class SystemLifecycleObserver: AppLifecycleObserver, @unchecked Sendable {
    var onForeground: (() -> Void)?
    var onBackground: (() -> Void)?
    private var tokens: [NSObjectProtocol] = []

    func start() {
        #if canImport(UIKit) || canImport(AppKit)
        guard tokens.isEmpty else { return }
        let center = NotificationCenter.default
        tokens.append(center.addObserver(forName: foregroundNotification, object: nil, queue: .main) { [weak self] _ in
            self?.onForeground?()
        })
        tokens.append(center.addObserver(forName: backgroundNotification, object: nil, queue: .main) { [weak self] _ in
            self?.onBackground?()
        })
        #endif
    }

    func stop() {
        tokens.forEach { NotificationCenter.default.removeObserver($0) }
        tokens = []
    }
}
