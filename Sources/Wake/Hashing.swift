import Foundation
import CryptoKit

enum Hashing {

    static func hexDigest(of string: String) -> String {
        let digest = SHA256.hash(data: Data(string.utf8))
        let hex: [UInt8] = Array("0123456789abcdef".utf8)
        var out = [UInt8]()
        out.reserveCapacity(SHA256Digest.byteCount * 2)
        for byte in digest {
            out.append(hex[Int(byte >> 4)])
            out.append(hex[Int(byte & 0x0f)])
        }
        return String(decoding: out, as: UTF8.self)
    }

    /// A deterministic, UUID-shaped (v5) id derived from `input` via SHA-256.
    static func deterministicUUID(_ input: String) -> String {
        let digest = SHA256.hash(data: Data(input.utf8))
        var bytes = Array(digest.prefix(16))
        bytes[6] = (bytes[6] & 0x0f) | 0x50 // version 5
        bytes[8] = (bytes[8] & 0x3f) | 0x80 // RFC 4122 variant

        let hex: [UInt8] = Array("0123456789abcdef".utf8)
        var out = [UInt8]()
        out.reserveCapacity(36)
        for (i, byte) in bytes.enumerated() {
            if i == 4 || i == 6 || i == 8 || i == 10 { out.append(UInt8(ascii: "-")) }
            out.append(hex[Int(byte >> 4)])
            out.append(hex[Int(byte & 0x0f)])
        }
        return String(decoding: out, as: UTF8.self)
    }
}
