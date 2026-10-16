import Foundation

protocol AppOriginSource: Sendable {
    func originalDownloadDate() async -> Date?
}

#if canImport(StoreKit)
import StoreKit

struct SystemAppOrigin: AppOriginSource {
    
    /// AppStore launch date
    static let appStoreEpoch = Date(timeIntervalSince1970: 1_215_648_000)

    static func sanitize(_ date: Date?) -> Date? {
        guard let date, date >= appStoreEpoch else { return nil }
        return date
    }

    func originalDownloadDate() async -> Date? {
        do {
            let result = try await AppTransaction.shared
            guard case .verified(let appTransaction) = result else { return nil }
            return Self.sanitize(appTransaction.originalPurchaseDate)
        } catch {
            return nil
        }
    }
}
#else
struct SystemAppOrigin: AppOriginSource {
    func originalDownloadDate() async -> Date? { nil }
}
#endif
