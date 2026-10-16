import XCTest
@testable import Wake

/// Where a subject came from: the `original_download_ts` that rides `$first_launch`
/// when StoreKit can say when the app was first bought, and the sanitizing that
/// keeps a placeholder date from being reported as a decades-old origin.
final class AppOriginTests: XCTestCase {

    private let t0 = Date(timeIntervalSince1970: 1000)

    // MARK: original_download_ts origin

    private func makeSessionCore(
        store: InMemoryStore,
        sink: EventSink,
        appOrigin: AppOriginSource?
    ) -> Wake.Core {
        let clock = ManualClock(date: t0)
        let sessions = SessionManager(clock: clock, store: store, uuid: { UUID().uuidString })
        return Wake.Core(
            store: store, clock: clock, sink: sink,
            sessions: sessions, appOrigin: appOrigin, uuid: CountingUUID().next
        )
    }

    func testFirstLaunchCarriesOriginWhenKnown() {
        let origin = Date(timeIntervalSince1970: 500)
        let firstLaunch = expectation(description: "first_launch recorded")
        let sink = ClosureSink { if $0.name == "$first_launch" { firstLaunch.fulfill() } }

        let core = makeSessionCore(store: InMemoryStore(), sink: sink, appOrigin: StubAppOrigin(date: origin))
        core.start(apiKey: "k")

        wait(for: [firstLaunch], timeout: 2)
        let fl = sink.received.first { $0.name == "$first_launch" }
        let iso = ISO8601DateFormatter().string(from: origin)
        XCTAssertEqual(fl?.params["original_download_ts"], .string(iso))
    }

    func testFirstLaunchOmitsOriginWhenUnknown() {
        let firstLaunch = expectation(description: "first_launch recorded")
        let sink = ClosureSink { if $0.name == "$first_launch" { firstLaunch.fulfill() } }

        let core = makeSessionCore(store: InMemoryStore(), sink: sink, appOrigin: StubAppOrigin(date: nil))
        core.start(apiKey: "k")

        wait(for: [firstLaunch], timeout: 2)
        let fl = sink.received.first { $0.name == "$first_launch" }
        XCTAssertNil(fl?.params["original_download_ts"], "unknown origin is absent, never zero")
    }

#if canImport(StoreKit)
    // SystemAppOrigin sanitizes StoreKit's originalPurchaseDate: the Simulator /
    // StoreKit-testing epoch placeholder (1970) is a non-date and must map to unknown,
    // not ship as a decades-old origin. A genuine date passes through untouched.
    func testSystemOriginRejectsPreAppStorePlaceholders() {
        XCTAssertNil(SystemAppOrigin.sanitize(Date(timeIntervalSince1970: 0)), "epoch is a placeholder")
        XCTAssertNil(SystemAppOrigin.sanitize(Date(timeIntervalSince1970: 500)), "1970 is a placeholder")
        XCTAssertNil(SystemAppOrigin.sanitize(nil), "missing stays missing")
        XCTAssertNil(
            SystemAppOrigin.sanitize(SystemAppOrigin.appStoreEpoch.addingTimeInterval(-86_400)),
            "the day before the App Store opened is not a real download"
        )
    }

    func testSystemOriginKeepsRealDates() {
        let real = Date(timeIntervalSince1970: 1_700_000_000) // 2023
        XCTAssertEqual(SystemAppOrigin.sanitize(real), real)
        XCTAssertEqual(
            SystemAppOrigin.sanitize(SystemAppOrigin.appStoreEpoch), SystemAppOrigin.appStoreEpoch,
            "the boundary itself is a valid date"
        )
    }
#endif

    func testOriginOnlyOnFreshInstall() {
        // A relaunch (existing install id) records no first_launch, origin or not.
        let store = InMemoryStore()
        makeSessionCore(store: store, sink: CollectingSink(),
                        appOrigin: StubAppOrigin(date: t0)).start(apiKey: "k")

        let sink2 = CollectingSink()
        makeSessionCore(store: store, sink: sink2,
                        appOrigin: StubAppOrigin(date: t0)).start(apiKey: "k")

        XCTAssertFalse(sink2.received.contains { $0.name == "$first_launch" })
    }
}
