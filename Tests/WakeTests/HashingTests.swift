import XCTest
@testable import Wake

final class HashingTests: XCTestCase {

    // NIST SHA-256 vectors — confirm our hex encoding of CryptoKit's digest is correct.
    func testKnownVectors() {
        XCTAssertEqual(
            Hashing.hexDigest(of: ""),
            "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
        )
        XCTAssertEqual(
            Hashing.hexDigest(of: "abc"),
            "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
        )
    }

    func testStableAcrossCalls() {
        XCTAssertEqual(Hashing.hexDigest(of: "wake"), Hashing.hexDigest(of: "wake"))
    }
}
