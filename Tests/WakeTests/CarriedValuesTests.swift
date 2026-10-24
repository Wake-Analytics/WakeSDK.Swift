import XCTest
@testable import Wake

/// Values one event passes for the rest of its feature: stored when it's logged,
/// attached to the events that take them.
final class CarriedValuesTests: XCTestCase {

    private let t0 = Date(timeIntervalSince1970: 1000)

    private func startedCore(store: InMemoryStore = InMemoryStore(), sink: CollectingSink) -> Wake.Core {
        let core = Wake.Core(store: store, clock: ManualClock(date: t0), sink: sink, carried: CarriedValues(store: store))
        core.start(apiKey: "k")
        return core
    }

    private func open(source: String?, version: String? = nil) -> Wake.Event {
        var params: [String: Wake.ParamValue] = [:]
        if let source { params["source"] = .string(source) }
        if let version { params["version"] = .string(version) }
        return ._event("paywall.open", params: params, carries: ["source", "version"])
    }

    private func purchase(_ params: [String: Wake.ParamValue] = [:]) -> Wake.Event {
        ._event("paywall.purchase", params: params, carriedFrom: "paywall.open")
    }

    func testALaterEventTakesWhatTheStoringEventPassed() {
        let sink = CollectingSink()
        let core = startedCore(sink: sink)

        core.log(open(source: "settings", version: "b"))
        core.log(purchase())

        XCTAssertEqual(sink.received.last?.params["source"], .string("settings"))
        XCTAssertEqual(sink.received.last?.params["version"], .string("b"))
    }

    func testTheLatestStoringEventWins() {
        let sink = CollectingSink()
        let core = startedCore(sink: sink)

        core.log(open(source: "settings", version: "b"))
        core.log(open(source: "onboarding"))
        core.log(purchase())

        XCTAssertEqual(sink.received.last?.params["source"], .string("onboarding"))
        XCTAssertNil(sink.received.last?.params["version"], "left out on the latest open → not carried from an earlier one")
    }

    func testAnEventsOwnValueWins() {
        let sink = CollectingSink()
        let core = startedCore(sink: sink)

        core.log(open(source: "settings"))
        core.log(purchase(["source": .string("override")]))

        XCTAssertEqual(sink.received.last?.params["source"], .string("override"))
    }

    func testOnlyTheDeclaredKeysAreCarried() {
        let sink = CollectingSink()
        let core = startedCore(sink: sink)

        core.log(._event("paywall.open", params: ["source": .string("settings"), "local": .int(1)], carries: ["source"]))
        core.log(purchase())

        XCTAssertNil(sink.received.last?.params["local"])
    }

    func testNothingStoredMeansNothingAttached() {
        let sink = CollectingSink()
        let core = startedCore(sink: sink)

        core.log(purchase())

        XCTAssertEqual(sink.received.last?.params, [:])
    }

    func testValuesSurviveARelaunch() {
        let store = InMemoryStore()
        startedCore(store: store, sink: CollectingSink()).log(open(source: "settings"))

        let sink = CollectingSink()
        startedCore(store: store, sink: sink).log(purchase())

        XCTAssertEqual(sink.received.last?.params["source"], .string("settings"))
    }

    func testNothingIsStoredBeforeStart() {
        let store = InMemoryStore()
        let sink = CollectingSink()
        let core = Wake.Core(store: store, clock: ManualClock(date: t0), sink: sink, carried: CarriedValues(store: store))

        core.log(open(source: "settings"))
        core.start(apiKey: "k")
        core.log(purchase())

        XCTAssertNil(sink.received.last?.params["source"], "no consent → nothing kept")
    }

    func testDeleteDataErasesThem() {
        let store = InMemoryStore()
        let sink = CollectingSink()
        let core = startedCore(store: store, sink: sink)
        core.log(open(source: "settings"))

        core.deleteData()
        core.start(apiKey: "k")
        core.log(purchase())

        XCTAssertNil(sink.received.last?.params["source"])
    }
}
