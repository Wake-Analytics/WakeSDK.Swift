import XCTest
@testable import Wake

final class ConfigTests: XCTestCase {

    func testDefaultWhenNoOverride() {
        let url = Wake.Config.resolveBaseURL(environment: nil, infoPlist: nil)
        XCTAssertEqual(url, Wake.Config.defaultBaseURL)
    }

    func testDefaultHostIsPinned() {
        // Baked into every consumer binary and unchangeable for builds already
        // shipped — changing it should be deliberate, not incidental.
        XCTAssertEqual(Wake.Config.defaultBaseURL.absoluteString, "https://ingest.realwake.app")
    }

    func testEnvironmentWins() {
        let url = Wake.Config.resolveBaseURL(
            environment: "http://localhost:8787",
            infoPlist: "https://plist.example"
        )
        XCTAssertEqual(url.absoluteString, "http://localhost:8787")
    }

    func testInfoPlistUsedWhenNoEnvironment() {
        let url = Wake.Config.resolveBaseURL(
            environment: nil,
            infoPlist: "https://staging.example.com"
        )
        XCTAssertEqual(url.absoluteString, "https://staging.example.com")
    }

    func testEmptyOrWhitespaceIgnored() {
        let url = Wake.Config.resolveBaseURL(environment: "   ", infoPlist: "")
        XCTAssertEqual(url, Wake.Config.defaultBaseURL)
    }

    func testSchemelessOverrideIgnored() {
        // A bare host with no scheme would build a relative URL — reject it and
        // fall through rather than ship a broken endpoint.
        let url = Wake.Config.resolveBaseURL(environment: "localhost:8787", infoPlist: nil)
        XCTAssertEqual(url, Wake.Config.defaultBaseURL)
    }

    func testEnvironmentTrimmedBeforeUse() {
        let url = Wake.Config.resolveBaseURL(environment: "  http://localhost:8787\n", infoPlist: nil)
        XCTAssertEqual(url.absoluteString, "http://localhost:8787")
    }
}
