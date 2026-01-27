//
//  SignatureResult.swift
//  Muhr
//
//  Created by Muhammad on 27/01/26.
//

import Foundation

// MARK: - Signature Result
/// Imzolash natijasi
///
/// `sign()` metodi muvaffaqiyatli bo'lganda qaytariladi.
/// Imzo, vaqt, sertifikat va algoritm ma'lumotlarini o'z ichiga oladi.
///
/// ## Imzo Strukturasi (RFC 6979, ECDSA uchun):
/// ```
/// ECDSA-Sig-Value ::= SEQUENCE {
///     r  INTEGER,
///     s  INTEGER
/// }
/// ```
///
/// ## RSA Imzo (RFC 8017):
/// ```
/// signature = RSASP1(K, M)
/// where K = private key, M = message
/// ```
///
/// ## Foydalanish:
/// ```swift
/// let result = try await signer.sign(data: document)
///
/// // Server'ga yuborish
/// let payload = [
///     "signature": result.signatureBase64,
///     "timestamp": result.timestampISO8601,
///     "algorithm": result.algorithm.rawValue
/// ]
/// ```
public struct SignatureResult: Sendable {

    // MARK: - Core Properties

    /// Imzo (raw bytes)
    ///
    /// ECDSA uchun: DER-encoded (RFC 5753)
    /// RSA uchun: PKCS#1 v1.5 format (RFC 8017)
    public let signature: Data

    /// Imzolangan original ma'lumotning hash'i
    ///
    /// SHA-256/384/512 natijasi (algoritmga bog'liq)
    /// Verification uchun ishlatiladi
    public let dataHash: Data

    /// Imzolash vaqti
    ///
    /// Local device vaqti. Server-side timestamp uchun
    /// TSA (Time Stamping Authority) ishlatish tavsiya etiladi.
    /// RFC 3161: Internet X.509 PKI Time-Stamp Protocol
    public let timestamp: Date

    /// Imzolashda ishlatilgan sertifikat
    public let certificate: CertificateInfo

    /// Ishlatilgan algoritm
    public let algorithm: SignatureAlgorithm

    // MARK: - Computed Properties (Formatlar)

    /// Base64 formatida imzo
    ///
    /// Server'ga yuborish uchun eng qulay format.
    /// RFC 4648: Base64 Encoding
    public var signatureBase64: String {
        signature.base64EncodedString()
    }

    /// URL-safe Base64 formatida imzo
    ///
    /// URL parametr sifatida yuborish uchun.
    /// RFC 4648, Section 5: Base64url
    public var signatureBase64URL: String {
        signature.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    /// Hex (16-lik) formatida imzo
    ///
    /// Debug va logging uchun qulay.
    public var signatureHex: String {
        signature.map { String(format: "%02x", $0) }.joined()
    }

    /// Hex formatida, ikki nuqta bilan ajratilgan
    ///
    /// Misol: "AB:CD:EF:12:34"
    public var signatureHexColonSeparated: String {
        signature.map { String(format: "%02X", $0) }.joined(separator: ":")
    }

    /// Data hash Base64 formatida
    public var dataHashBase64: String {
        dataHash.base64EncodedString()
    }

    /// Data hash Hex formatida
    public var dataHashHex: String {
        dataHash.map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Timestamp Formats

    /// ISO 8601 formatida vaqt
    ///
    /// RFC 3339: Date and Time on the Internet
    /// Misol: "2026-01-27T14:30:00Z"
    public var timestampISO8601: String {
        ISO8601DateFormatter().string(from: timestamp)
    }

    /// Unix timestamp (soniyalarda)
    public var timestampUnix: Int64 {
        Int64(timestamp.timeIntervalSince1970)
    }

    /// Unix timestamp (millisekundlarda)
    public var timestampUnixMillis: Int64 {
        Int64(timestamp.timeIntervalSince1970 * 1000)
    }

    // MARK: - Metadata

    /// Imzo uzunligi (baytlarda)
    public var signatureLength: Int {
        signature.count
    }

    /// Imzolangan ma'lumot hash uzunligi (baytlarda)
    public var hashLength: Int {
        dataHash.count
    }

    /// Imzolovchi haqida qisqa ma'lumot
    public var signerInfo: String {
        certificate.commonName
    }

    // MARK: - Initializer

    public init(
        signature: Data,
        dataHash: Data,
        timestamp: Date = Date(),
        certificate: CertificateInfo,
        algorithm: SignatureAlgorithm
    ) {
        self.signature = signature
        self.dataHash = dataHash
        self.timestamp = timestamp
        self.certificate = certificate
        self.algorithm = algorithm
    }
}

// MARK: - Equatable
extension SignatureResult: Equatable {
    public static func == (lhs: SignatureResult, rhs: SignatureResult) -> Bool {
        return lhs.signature == rhs.signature && lhs.dataHash == rhs.dataHash
            && lhs.timestamp == rhs.timestamp
    }
}

// MARK: - CustomStringConvertible
extension SignatureResult: CustomStringConvertible {
    public var description: String {
        """
        SignatureResult:
          Signer: \(signerInfo)
          Algorithm: \(algorithm.displayName)
          Signature: \(signatureHex.prefix(32))...
          Hash: \(dataHashHex.prefix(16))...
          Timestamp: \(timestampISO8601)
          Size: \(signatureLength) bytes
        """
    }
}

// MARK: - JSON Export
extension SignatureResult {

    /// JSON dictionary sifatida export
    ///
    /// Server'ga yuborish uchun tayyor format
    public var asDictionary: [String: Any] {
        [
            "signature": signatureBase64,
            "data_hash": dataHashBase64,
            "timestamp": timestampISO8601,
            "timestamp_unix": timestampUnix,
            "algorithm": algorithm.rawValue,
            "algorithm_oid": algorithm.oid,
            "signer": [
                "common_name": certificate.commonName,
                "serial_number": certificate.serialNumber,
                "pinfl": certificate.pinfl as Any,
                "stir": certificate.stir as Any,
            ],
        ]
    }

    /// JSON Data sifatida export
    public func asJSONData(prettyPrinted: Bool = false) throws -> Data {
        let options: JSONSerialization.WritingOptions =
            prettyPrinted ? [.prettyPrinted, .sortedKeys] : []
        return try JSONSerialization.data(
            withJSONObject: asDictionary,
            options: options
        )
    }

    /// JSON String sifatida export
    public func asJSONString(prettyPrinted: Bool = false) throws -> String {
        let data = try asJSONData(prettyPrinted: prettyPrinted)
        return String(data: data, encoding: .utf8) ?? "{}"
    }
}
