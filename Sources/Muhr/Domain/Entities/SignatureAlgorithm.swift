//
//  SignatureAlgorithm.swift
//  Muhr
//
//  Created by Muhammad on 27/01/26.
//

import Foundation
import Security

// MARK: - Signature Algorithm
/// Raqamli imzo algoritmlari
///
/// Certificate'dan avtomatik aniqlanadi. Qo'lda tanlash shart emas.
///
/// ## Qo'llab-quvvatlanadigan algoritmlar:
///
/// ### ECDSA (Elliptic Curve Digital Signature Algorithm)
/// - **RFC 6979**: Deterministic ECDSA
///   https://datatracker.ietf.org/doc/html/rfc6979
/// - **RFC 5758**: ECDSA for X.509 Certificates
///   https://datatracker.ietf.org/doc/html/rfc5758
/// - **FIPS 186-4**: Digital Signature Standard (DSS)
///   https://nvlpubs.nist.gov/nistpubs/FIPS/NIST.FIPS.186-4.pdf
///
/// ### RSA (Rivest-Shamir-Adleman)
/// - **RFC 8017**: PKCS #1 RSA Cryptography Specifications v2.2
///   https://datatracker.ietf.org/doc/html/rfc8017
/// - **RFC 3447**: PKCS #1 RSA Cryptography Specifications v2.1
///   https://datatracker.ietf.org/doc/html/rfc3447
///
/// ## OID (Object Identifier) Ma'lumotnomasi:
/// ```
/// ECDSA-P256:  1.2.840.10045.4.3.2 (ecdsa-with-SHA256)
/// ECDSA-P384:  1.2.840.10045.4.3.3 (ecdsa-with-SHA384)
/// ECDSA-P521:  1.2.840.10045.4.3.4 (ecdsa-with-SHA512)
/// RSA-SHA256:  1.2.840.113549.1.1.11 (sha256WithRSAEncryption)
/// RSA-SHA384:  1.2.840.113549.1.1.12 (sha384WithRSAEncryption)
/// RSA-SHA512:  1.2.840.113549.1.1.13 (sha512WithRSAEncryption)
/// ```
public enum SignatureAlgorithm: String, Codable, Sendable, CaseIterable {

    // MARK: - ECDSA (Elliptic Curve)

    /// ECDSA with P-256 curve (secp256r1 / prime256v1)
    ///
    /// - **OID**: 1.2.840.10045.4.3.2
    /// - **Key size**: 256 bit
    /// - **Security level**: 128 bit (NIST recommendation)
    /// - **RFC 5758**: Section 3.2
    /// - **Curve**: NIST P-256 (RFC 5480)
    ///
    /// Eng keng tarqalgan algoritm. Ko'pchilik certificate'lar shuni ishlatadi.
    case ecdsaP256 = "ECDSA-P256"

    /// ECDSA with P-384 curve (secp384r1)
    ///
    /// - **OID**: 1.2.840.10045.4.3.3
    /// - **Key size**: 384 bit
    /// - **Security level**: 192 bit
    /// - **RFC 5758**: Section 3.2
    /// - **Curve**: NIST P-384 (RFC 5480)
    ///
    /// Yuqori xavfsizlik talab qilinadigan holatlar uchun.
    case ecdsaP384 = "ECDSA-P384"

    /// ECDSA with P-521 curve (secp521r1)
    ///
    /// - **OID**: 1.2.840.10045.4.3.4
    /// - **Key size**: 521 bit
    /// - **Security level**: 256 bit
    /// - **RFC 5758**: Section 3.2
    /// - **Curve**: NIST P-521 (RFC 5480)
    ///
    /// Maksimal xavfsizlik. Kamdan-kam ishlatiladi.
    case ecdsaP521 = "ECDSA-P521"

    // MARK: - RSA

    /// RSA with SHA-256
    ///
    /// - **OID**: 1.2.840.113549.1.1.11
    /// - **Key size**: 2048 bit (minimum recommended)
    /// - **Security level**: ~112 bit
    /// - **RFC 8017**: PKCS #1 v2.2
    /// - **Padding**: PKCS#1 v1.5
    ///
    /// Legacy tizimlar bilan moslik uchun.
    case rsaSHA256 = "RSA-SHA256"

    /// RSA with SHA-384
    ///
    /// - **OID**: 1.2.840.113549.1.1.12
    /// - **Key size**: 3072 bit (recommended)
    /// - **Security level**: ~128 bit
    /// - **RFC 8017**: PKCS #1 v2.2
    case rsaSHA384 = "RSA-SHA384"

    /// RSA with SHA-512
    ///
    /// - **OID**: 1.2.840.113549.1.1.13
    /// - **Key size**: 4096 bit
    /// - **Security level**: ~140 bit
    /// - **RFC 8017**: PKCS #1 v2.2
    case rsaSHA512 = "RSA-SHA512"

    // MARK: - Display Properties

    /// Foydalanuvchiga ko'rsatiladigan nom
    public var displayName: String {
        switch self {
        case .ecdsaP256: return "ECDSA P-256"
        case .ecdsaP384: return "ECDSA P-384"
        case .ecdsaP521: return "ECDSA P-521"
        case .rsaSHA256: return "RSA 2048-bit"
        case .rsaSHA384: return "RSA 3072-bit"
        case .rsaSHA512: return "RSA 4096-bit"
        }
    }

    /// Qisqa tavsif
    public var shortDescription: String {
        switch self {
        case .ecdsaP256: return "EC 256"
        case .ecdsaP384: return "EC 384"
        case .ecdsaP521: return "EC 521"
        case .rsaSHA256: return "RSA 2K"
        case .rsaSHA384: return "RSA 3K"
        case .rsaSHA512: return "RSA 4K"
        }
    }

    // MARK: - Technical Properties

    /// Kalit uzunligi (bitlarda)
    public var keySize: Int {
        switch self {
        case .ecdsaP256: return 256
        case .ecdsaP384: return 384
        case .ecdsaP521: return 521
        case .rsaSHA256: return 2048
        case .rsaSHA384: return 3072
        case .rsaSHA512: return 4096
        }
    }

    /// Hash algoritmi
    public var hashAlgorithm: HashAlgorithm {
        switch self {
        case .ecdsaP256, .rsaSHA256:
            return .sha256
        case .ecdsaP384, .rsaSHA384:
            return .sha384
        case .ecdsaP521, .rsaSHA512:
            return .sha512
        }
    }

    /// Xavfsizlik darajasi
    public var securityLevel: SecurityLevel {
        switch self {
        case .ecdsaP256, .rsaSHA256:
            return .standard  // 128-bit
        case .ecdsaP384, .rsaSHA384:
            return .high  // 192-bit
        case .ecdsaP521, .rsaSHA512:
            return .maximum  // 256-bit
        }
    }

    /// Elliptic curve mi yoki RSA?
    public var isEllipticCurve: Bool {
        switch self {
        case .ecdsaP256, .ecdsaP384, .ecdsaP521:
            return true
        case .rsaSHA256, .rsaSHA384, .rsaSHA512:
            return false
        }
    }

    /// OID (Object Identifier) - RFC 5758, RFC 8017
    public var oid: String {
        switch self {
        case .ecdsaP256: return "1.2.840.10045.4.3.2"
        case .ecdsaP384: return "1.2.840.10045.4.3.3"
        case .ecdsaP521: return "1.2.840.10045.4.3.4"
        case .rsaSHA256: return "1.2.840.113549.1.1.11"
        case .rsaSHA384: return "1.2.840.113549.1.1.12"
        case .rsaSHA512: return "1.2.840.113549.1.1.13"
        }
    }

    // MARK: - Security Framework Mapping

    /// Apple Security framework algoritmi
    ///
    /// SecKeyCreateSignature() va SecKeyVerifySignature() uchun ishlatiladi.
    /// Apple Developer Documentation:
    /// https://developer.apple.com/documentation/security/seckeyalgorithm
    public var secKeyAlgorithm: SecKeyAlgorithm {
        switch self {
        case .ecdsaP256:
            return .ecdsaSignatureMessageX962SHA256
        case .ecdsaP384:
            return .ecdsaSignatureMessageX962SHA384
        case .ecdsaP521:
            return .ecdsaSignatureMessageX962SHA512
        case .rsaSHA256:
            return .rsaSignatureMessagePKCS1v15SHA256
        case .rsaSHA384:
            return .rsaSignatureMessagePKCS1v15SHA384
        case .rsaSHA512:
            return .rsaSignatureMessagePKCS1v15SHA512
        }
    }

    /// Digest uchun SecKeyAlgorithm (pre-hashed data uchun)
    public var secKeyAlgorithmDigest: SecKeyAlgorithm {
        switch self {
        case .ecdsaP256:
            return .ecdsaSignatureDigestX962SHA256
        case .ecdsaP384:
            return .ecdsaSignatureDigestX962SHA384
        case .ecdsaP521:
            return .ecdsaSignatureDigestX962SHA512
        case .rsaSHA256:
            return .rsaSignatureDigestPKCS1v15SHA256
        case .rsaSHA384:
            return .rsaSignatureDigestPKCS1v15SHA384
        case .rsaSHA512:
            return .rsaSignatureDigestPKCS1v15SHA512
        }
    }
}

// MARK: - Hash Algorithm
/// Hash algoritmlari
///
/// - **RFC 6234**: SHA-2 (SHA-256, SHA-384, SHA-512)
///   https://datatracker.ietf.org/doc/html/rfc6234
/// - **FIPS 180-4**: Secure Hash Standard
///   https://nvlpubs.nist.gov/nistpubs/FIPS/NIST.FIPS.180-4.pdf
public enum HashAlgorithm: String, Codable, Sendable {

    /// SHA-256 (256 bit output)
    /// - **OID**: 2.16.840.1.101.3.4.2.1
    /// - **RFC 6234**: Section 1
    case sha256 = "SHA-256"

    /// SHA-384 (384 bit output)
    /// - **OID**: 2.16.840.1.101.3.4.2.2
    /// - **RFC 6234**: Section 1
    case sha384 = "SHA-384"

    /// SHA-512 (512 bit output)
    /// - **OID**: 2.16.840.1.101.3.4.2.3
    /// - **RFC 6234**: Section 1
    case sha512 = "SHA-512"

    /// Digest uzunligi (baytlarda)
    public var digestLength: Int {
        switch self {
        case .sha256: return 32
        case .sha384: return 48
        case .sha512: return 64
        }
    }

    /// OID
    public var oid: String {
        switch self {
        case .sha256: return "2.16.840.1.101.3.4.2.1"
        case .sha384: return "2.16.840.1.101.3.4.2.2"
        case .sha512: return "2.16.840.1.101.3.4.2.3"
        }
    }
}

// MARK: - Security Level
/// Xavfsizlik darajasi
///
/// NIST SP 800-57 Part 1 Rev. 5 ga muvofiq:
/// https://csrc.nist.gov/publications/detail/sp/800-57-part-1/rev-5/final
public enum SecurityLevel: String, Codable, Sendable {

    /// Standart xavfsizlik (128-bit)
    /// NIST: 2030 yilgacha tavsiya etiladi
    case standard = "standard"

    /// Yuqori xavfsizlik (192-bit)
    /// NIST: 2030+ uchun tavsiya
    case high = "high"

    /// Maksimal xavfsizlik (256-bit)
    /// NIST: Uzoq muddatli himoya
    case maximum = "maximum"

    public var displayName: String {
        switch self {
        case .standard: return "Standart (128-bit)"
        case .high: return "Yuqori (192-bit)"
        case .maximum: return "Maksimal (256-bit)"
        }
    }

    /// Xavfsizlik bit darajasi
    public var bitStrength: Int {
        switch self {
        case .standard: return 128
        case .high: return 192
        case .maximum: return 256
        }
    }
}
