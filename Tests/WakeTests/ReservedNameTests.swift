import XCTest
@testable import Wake

/// What the SDK still reserves. Events are designed in Wake, which refuses a name
/// whose id is already taken, and the write behind the event form refuses a
/// `$`-prefixed one. The automatic events the SDK emits itself are the only names
/// left that are the SDK's own.
final class ReservedNameTests: XCTestCase {

    func testAutomaticEventsAreRecognizedByPrefix() {
        XCTAssertTrue(AutoEvent.isAutomatic("$first_launch"))
        XCTAssertTrue(AutoEvent.isAutomatic("$session_start"))
        XCTAssertFalse(AutoEvent.isAutomatic("used_search"))
    }

    func testPurchaseIsAnOrdinaryName() {
        XCTAssertFalse(
            AutoEvent.isAutomatic("purchase"),
            "purchases are a property now, so an event may be called this"
        )
    }
}
