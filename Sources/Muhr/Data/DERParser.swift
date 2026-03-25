//
//  DERParser.swift
//  Muhr
//
//  Created by Muhammad on 25/03/26.
//

import Foundation

// MARK: - DER Parser
/// ASN.1 DER formatidagi ma'lumotni parse qilish
///
/// X.509 sertifikatdan issuer va serial number olish uchun ishlatiladi.
/// RFC 5280: Internet X.509 PKI Certificate
struct DERParser {

    private let data: Data
    private var offset: Int = 0

    init(data: Data) {
        self.data = data
    }

    // MARK: - Certificate Parsing

    /// X.509 sertifikatdan issuer va serial number olish
    ///
    /// Certificate ::= SEQUENCE {
    ///     tbsCertificate       TBSCertificate,
    ///     signatureAlgorithm   AlgorithmIdentifier,
    ///     signatureValue       BIT STRING
    /// }
    ///
    /// TBSCertificate ::= SEQUENCE {
    ///     version         [0] EXPLICIT INTEGER DEFAULT v1,
    ///     serialNumber    CertificateSerialNumber,
    ///     signature       AlgorithmIdentifier,
    ///     issuer          Name,
    ///     ...
    /// }
    mutating func extractIssuerAndSerial() throws -> (issuerDER: Data, serialNumberDER: Data) {
        // Certificate SEQUENCE
        _ = try readTag()
        _ = try readLength()

        // TBSCertificate SEQUENCE
        _ = try readTag()
        _ = try readLength()

        // version [0] EXPLICIT (optional)
        if offset < data.count && data[offset] == 0xA0 {
            _ = try readTag()
            let vLen = try readLength()
            offset += vLen
        }

        // serialNumber INTEGER — to'liq TLV sifatida olish
        let serialStart = offset
        _ = try readTag()
        let serialLen = try readLength()
        offset += serialLen
        let serialNumberDER = Data(data[serialStart..<offset])

        // signature AlgorithmIdentifier — skip
        _ = try skipTLV()

        // issuer Name — to'liq TLV sifatida olish
        let issuerStart = offset
        _ = try skipTLV()
        let issuerDER = Data(data[issuerStart..<offset])

        return (issuerDER, serialNumberDER)
    }

    // MARK: - Low-Level Parsing

    private mutating func readTag() throws -> UInt8 {
        guard offset < data.count else {
            throw MuhrError.invalidCertificateFormat
        }
        let tag = data[offset]
        offset += 1
        return tag
    }

    private mutating func readLength() throws -> Int {
        guard offset < data.count else {
            throw MuhrError.invalidCertificateFormat
        }

        let first = data[offset]
        offset += 1

        if first < 0x80 {
            return Int(first)
        }

        let numBytes = Int(first & 0x7F)
        guard offset + numBytes <= data.count else {
            throw MuhrError.invalidCertificateFormat
        }

        var length = 0
        for _ in 0..<numBytes {
            length = (length << 8) | Int(data[offset])
            offset += 1
        }

        return length
    }

    @discardableResult
    private mutating func skipTLV() throws -> Int {
        _ = try readTag()
        let length = try readLength()
        guard offset + length <= data.count else {
            throw MuhrError.invalidCertificateFormat
        }
        offset += length
        return length
    }
}
