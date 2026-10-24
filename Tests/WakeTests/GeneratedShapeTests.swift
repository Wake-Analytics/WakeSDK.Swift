import XCTest
@testable import Wake

// The shape the generated file declares: events nested under their feature, reached
// as an implicit member chain from `Wake.log(.`.
extension Wake.Event {
    fileprivate static var paywall: PaywallEvents { PaywallEvents() }

    fileprivate struct PaywallEvents {
        var opened: Wake.Event {
            ._event("paywall.opened")
        }

        func subscribed(plan: String?) -> Wake.Event {
            var params: [String: Wake.ParamValue] = [:]
            if let plan { params["plan"] = .string(plan) }
            return ._event("paywall.subscribed", params: params, screenTimeSince: ["since_paywall_opened": "paywall.opened"])
        }
    }
}

final class GeneratedShapeTests: XCTestCase {

    func testFeatureNestedEventsReadAsAChain() {
        let clock = MutableClock(Date(timeIntervalSince1970: 1000))
        let store = InMemoryStore()
        let sink = CollectingSink()
        let core = Wake.Core(store: store, clock: clock, sink: sink, screenTime: ScreenTime(clock: clock, store: store))
        core.start(apiKey: "k")

        core.log(.paywall.opened)
        clock.date = clock.date.addingTimeInterval(12)
        core.log(.paywall.subscribed(plan: "annual"))

        XCTAssertEqual(sink.received.map(\.name), ["paywall.opened", "paywall.subscribed"])
        XCTAssertEqual(sink.received.last?.params["plan"], .string("annual"))
        XCTAssertEqual(sink.received.last?.params["since_paywall_opened"], .double(12))
    }
}
