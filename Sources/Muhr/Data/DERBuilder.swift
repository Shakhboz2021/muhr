//
//  DERBuilder.swift
//  Muhr
//
//  Created by Muhammad on 25/03/26.
//

import Foundation

// MARK: - DER Builder
/// ASN.1 DER (Distinguished Encoding Rules) formatida ma'lumot yaratish
///
/// CMS/PKCS#7 SignedData strukturasini yaratish uchun ishlatiladi.
/// RFC 5652: Cryptographic Message Syntax (CMS)
enum DERBuilder {

    // MARK: - ASN.1 Tags

    private static let tagInteger: UInt8 = 0x02
    private static let tagOctetString: UInt8 = 0x04
    private static let tagNull: UInt8 = 0x05
    private static let tagOID: UInt8 = 0x06
    private static let tagSequence: UInt8 = 0x30
    private static let tagSet: UInt8 = 0x31

    // MARK: - Primitive Types

    /// NULL value
    static func null() -> Data {
        return Data([tagNull, 0x00])
    }

    /// INTEGER (kichik qiymatlar uchun)
    static func integer(_ value: Int) -> Data {
        if value == 0 {
            return Data([tagInteger, 0x01, 0x00])
        }

        var bytes: [UInt8] = []
        var v = value
        while v > 0 {
            bytes.insert(UInt8(v & 0xFF), at: 0)
            v >>= 8
        }

        // Agar birinchi bayt >= 0x80 bo'lsa, 0x00 prefix qo'shish
        if let first = bytes.first, first >= 0x80 {
            bytes.insert(0x00, at: 0)
        }

        var result = Data([tagInteger])
        result.append(contentsOf: encodeLength(bytes.count))
        result.append(contentsOf: bytes)
        return result
    }

    /// INTEGER (raw bytes — sertifikat serial number uchun)
    static func integerRaw(_ bytes: Data) -> Data {
        var result = Data([tagInteger])
        var content = Data(bytes)
        if let first = content.first, first >= 0x80 {
            content.insert(0x00, at: 0)
        }
        result.append(contentsOf: encodeLength(content.count))
        result.append(content)
        return result
    }

    /// OCTET STRING
    static func octetString(_ data: Data) -> Data {
        var result = Data([tagOctetString])
        result.append(contentsOf: encodeLength(data.count))
        result.append(data)
        return result
    }

    /// OID (Object Identifier)
    static func oid(_ oidString: String) -> Data {
        let components = oidString.split(separator: ".").compactMap { Int($0) }
        guard components.count >= 2 else { return Data() }

        var encoded: [UInt8] = []

        // Birinchi ikki komponent: 40 * first + second
        encoded.append(UInt8(40 * components[0] + components[1]))

        // Qolgan komponentlar base-128 formatida
        for i in 2..<components.count {
            encoded.append(contentsOf: encodeBase128(components[i]))
        }

        var result = Data([tagOID])
        result.append(contentsOf: encodeLength(encoded.count))
        result.append(contentsOf: encoded)
        return result
    }

    // MARK: - Constructed Types

    /// SEQUENCE
    static func sequence(_ elements: [Data]) -> Data {
        let content = elements.reduce(Data()) { $0 + $1 }
        var result = Data([tagSequence])
        result.append(contentsOf: encodeLength(content.count))
        result.append(content)
        return result
    }

    /// SET
    static func set(_ elements: [Data]) -> Data {
        let content = elements.reduce(Data()) { $0 + $1 }
        var result = Data([tagSet])
        result.append(contentsOf: encodeLength(content.count))
        result.append(content)
        return result
    }

    // MARK: - Context-Specific Tags

    /// EXPLICIT context-specific tag [tag]
    static func explicit(tag: UInt8, content: Data) -> Data {
        let tagByte: UInt8 = 0xA0 | tag
        var result = Data([tagByte])
        result.append(contentsOf: encodeLength(content.count))
        result.append(content)
        return result
    }

    /// IMPLICIT context-specific tag [tag]
    static func implicit(tag: UInt8, content: Data) -> Data {
        let tagByte: UInt8 = 0xA0 | tag
        var result = Data([tagByte])
        result.append(contentsOf: encodeLength(content.count))
        result.append(content)
        return result
    }

    /// BIT STRING
    static func bitString(_ data: Data) -> Data {
        var result = Data([0x03]) // BIT STRING tag
        // BIT STRING: birinchi bayt = unused bits (0)
        result.append(contentsOf: encodeLength(data.count + 1))
        result.append(0x00) // unused bits
        result.append(data)
        return result
    }

    /// UTCTime (ASN.1 format: YYMMDDHHMMSSZ)
    static func utcTime(_ date: Date) -> Data {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyMMddHHmmss"
        formatter.timeZone = TimeZone(identifier: "UTC")
        let dateString = formatter.string(from: date) + "Z"
        let bytes = Array(dateString.utf8)
        var result = Data([0x17]) // UTCTime tag
        result.append(contentsOf: encodeLength(bytes.count))
        result.append(contentsOf: bytes)
        return result
    }

    /// Raw data (allaqachon DER formatida bo'lgan ma'lumot)
    static func raw(_ data: Data) -> Data {
        return data
    }

    // MARK: - Length Encoding

    /// DER length encoding
    /// Short form: 0-127 → 1 bayt
    /// Long form: 128+ → 0x80 | baytlar soni, keyin baytlar
    static func encodeLength(_ length: Int) -> [UInt8] {
        if length < 0x80 {
            return [UInt8(length)]
        }

        var bytes: [UInt8] = []
        var len = length
        while len > 0 {
            bytes.insert(UInt8(len & 0xFF), at: 0)
            len >>= 8
        }

        return [0x80 | UInt8(bytes.count)] + bytes
    }

    // MARK: - Base-128 Encoding

    /// OID komponentini base-128 formatida kodlash
    private static func encodeBase128(_ value: Int) -> [UInt8] {
        if value < 0x80 {
            return [UInt8(value)]
        }

        var bytes: [UInt8] = []
        var v = value

        bytes.insert(UInt8(v & 0x7F), at: 0)
        v >>= 7

        while v > 0 {
            bytes.insert(UInt8((v & 0x7F) | 0x80), at: 0)
            v >>= 7
        }

        return bytes
    }
}
