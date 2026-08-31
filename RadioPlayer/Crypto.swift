import Foundation
import CommonCrypto

enum Crypto {
    /// Тот же хэш, что в Android-приложении: PBKDF2-HMAC-SHA1, 10000 итераций, 512 бит, hex.
    static func pbkdf2Hex(token: String) -> String {
        let salt = "$2y$10$aldj8u34yrufdg8f3nfs$"
        guard let key = pbkdf2SHA1(password: token, salt: Data(salt.utf8), iterations: 10000, keyLength: 64) else {
            return ""
        }
        return key.map { String(format: "%02x", $0) }.joined()
    }

    private static func pbkdf2SHA1(password: String, salt: Data, iterations: UInt32, keyLength: Int) -> Data? {
        var derivedKey = Data(count: keyLength)
        let result = derivedKey.withUnsafeMutableBytes { derivedBytes -> Int32 in
            guard let derivedAddress = derivedBytes.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                return Int32(kCCParamError)
            }
            return password.withCString { passwordChars in
                salt.withUnsafeBytes { saltBytes -> Int32 in
                    guard let saltAddress = saltBytes.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                        return Int32(kCCParamError)
                    }
                    return CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        passwordChars, password.utf8.count,
                        saltAddress, salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA1),
                        iterations,
                        derivedAddress, keyLength
                    )
                }
            }
        }
        return result == kCCSuccess ? derivedKey : nil
    }
}
