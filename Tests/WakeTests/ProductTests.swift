import XCTest
@testable import Wake

/// The purchase-product property: what a product contributes to an event's
/// payload, what a caller may not restate, and the deterministic id a transaction
/// gives the event.
final class ProductTests: XCTestCase {

    private let t0 = Date(timeIntervalSince1970: 1000)

    // MARK: ProductFacts → params

    private func facts(
        period: String? = "annual",
        isTrial: Bool? = false,
        type: String = "auto_renewable",
        transactionID: String? = "2000000123"
    ) -> ProductFacts {
        ProductFacts(
            productID: "pro_annual",
            displayName: "Pro Annual",
            price: 34.99,
            currencyCode: "USD",
            period: period,
            productType: type,
            isTrial: isTrial,
            transactionID: transactionID
        )
    }

    func testParamsCarryEveryField() {
        XCTAssertEqual(facts().params(), [
            "product_id": .string("pro_annual"),
            "product_name": .string("Pro Annual"),
            "price": .double(34.99),
            "currency": .string("USD"),
            "period": .string("annual"),
            "product_type": .string("auto_renewable"),
            "is_trial": .bool(false),
            "transaction_id": .string("2000000123"),
        ])
    }

    func testWithoutATransactionNothingSaysItWasAPurchase() {
        // A product shown or chosen carries the same product fields as one bought.
        // Only the transaction id tells them apart.
        let params = facts(isTrial: nil, transactionID: nil).params()

        XCTAssertNil(params["transaction_id"])
        XCTAssertEqual(params["product_id"], .string("pro_annual"))
    }

    func testOneTimePurchaseOmitsPeriodAndTrial() {
        // A one-time purchase has no period, and without a transaction nothing can
        // say an introductory offer applied. Both are absent, not empty.
        let params = facts(period: nil, isTrial: nil, type: "non_consumable").params()

        XCTAssertNil(params["period"])
        XCTAssertNil(params["is_trial"])
        XCTAssertEqual(params["product_type"], .string("non_consumable"))
    }

    func testTheMilestonesOwnPropertiesRideAlongside() {
        let params = facts().params(custom: [
            "paywall_source": .string("onboarding"),
            "days_since_install": .int(3),
        ])

        XCTAssertEqual(params["paywall_source"], .string("onboarding"))
        XCTAssertEqual(params["days_since_install"], .int(3))
        XCTAssertEqual(params["product_id"], .string("pro_annual"), "the product's fields still ride")
    }

    func testEveryProductIDIsReserved() {
        let custom = Dictionary(
            uniqueKeysWithValues: Wake.productParamIDs.map { ($0, Wake.ParamValue.string("injected")) }
        )
        let params = facts().params(custom: custom)

        XCTAssertFalse(
            params.values.contains(.string("injected")),
            "productParamIDs is the full product vocabulary — none of it is writable"
        )
    }

    func testReservedIDsAreDroppedEvenWhenTheProductHasNoValue() {
        let params = facts(period: nil, isTrial: nil).params(custom: [
            "period": .string("annual"),
            "is_trial": .bool(true),
        ])

        XCTAssertNil(params["period"])
        XCTAssertNil(params["is_trial"])
    }

    func testEmptyParamIDIsDropped() {
        let params = facts().params(custom: ["": .string("nameless"), "kept": .int(1)])

        XCTAssertNil(params[""])
        XCTAssertEqual(params["kept"], .int(1))
    }

    // MARK: Core.record with a transaction

    private func startedCore(store: InMemoryStore = InMemoryStore(), sink: EventSink) -> Wake.Core {
        let core = Wake.Core(
            store: store, clock: ManualClock(date: t0), sink: sink, uuid: CountingUUID().next
        )
        core.start(apiKey: "k")
        return core
    }

    private func transaction(_ id: String, isSandbox: Bool = false) -> TransactionIdentity {
        TransactionIdentity(id: id, isSandbox: isSandbox)
    }

    func testTheMilestoneKeepsItsOwnName() {
        let sink = CollectingSink()
        let core = startedCore(sink: sink)

        core.record(name: "subscribed", params: [:], transaction: transaction("99"))

        XCTAssertEqual(sink.received.last?.name, "subscribed", "no name is reserved for purchases")
    }

    func testSandboxComesFromTheTransaction() {
        // The build is DEBUG (Environment.isSandbox == true), but a production
        // transaction must ride as non-sandbox regardless.
        let sink = CollectingSink()
        let core = startedCore(sink: sink)

        core.record(name: "subscribed", params: [:], transaction: transaction("1", isSandbox: false))

        XCTAssertEqual(sink.received.last?.isSandbox, false)
    }

    func testSameTransactionYieldsSameEventID() {
        let sink = CollectingSink()
        let core = startedCore(sink: sink)

        core.record(name: "subscribed", params: [:], transaction: transaction("2000000123"))
        core.record(name: "subscribed", params: [:], transaction: transaction("2000000123"))

        let ids = sink.received.map(\.eventID)
        XCTAssertEqual(ids.count, 2)
        XCTAssertEqual(ids[0], ids[1], "the same purchase dedupes to one instance across routes")
    }

    func testTheSameTransactionOnTwoMilestonesIsTwoEvents() {
        // One purchase can be the moment two different events happened. They
        // are two instances, so the event name is part of the id.
        let sink = CollectingSink()
        let core = startedCore(sink: sink)

        core.record(name: "subscribed", params: [:], transaction: transaction("7"))
        core.record(name: "upgraded", params: [:], transaction: transaction("7"))

        XCTAssertNotEqual(sink.received[0].eventID, sink.received[1].eventID)
    }

    func testDifferentTransactionsYieldDifferentEventIDs() {
        let sink = CollectingSink()
        let core = startedCore(sink: sink)

        core.record(name: "subscribed", params: [:], transaction: transaction("1"))
        core.record(name: "subscribed", params: [:], transaction: transaction("2"))

        XCTAssertNotEqual(sink.received[0].eventID, sink.received[1].eventID)
    }

    func testTransactionEventIDIsUUIDShaped() {
        let sink = CollectingSink()
        let core = startedCore(sink: sink)

        core.record(name: "subscribed", params: [:], transaction: transaction("abc"))

        let id = sink.received.last?.eventID
        XCTAssertNotNil(id.flatMap(UUID.init(uuidString:)), "event_id is a valid UUID string")
    }

    func testWithoutATransactionEachCallIsItsOwnEvent() {
        let sink = CollectingSink()
        let core = startedCore(sink: sink)

        core.record(name: "subscribed", params: [:])
        core.record(name: "subscribed", params: [:])

        XCTAssertNotEqual(sink.received[0].eventID, sink.received[1].eventID)
    }

    func testPurchaseBeforeStartNoOps() {
        let sink = CollectingSink()
        let core = Wake.Core(store: InMemoryStore(), clock: ManualClock(date: t0), sink: sink)

        core.record(name: "subscribed", params: [:], transaction: transaction("1"))

        XCTAssertTrue(sink.received.isEmpty, "no consent → nothing recorded")
    }
}
