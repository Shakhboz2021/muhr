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
/// X.509 sertifikatdan issuer, serial number va validity dates olish uchun ishlatiladi.
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

    /// X.509 sertifikatdan to'liq ma'lumotlarni olish
    ///
    /// TBSCertificate strukturasidan quyidagilarni parse qiladi:
    /// - serialNumber
    /// - issuer (Name)
    /// - validity (notBefore, notAfter)
    /// - subject (Name) — CN, O, OU, C, SERIALNUMBER
    mutating func extractCertificateFields() throws -> CertificateFields {
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

        // serialNumber INTEGER
        let serialStart = offset
        _ = try readTag()
        let serialLen = try readLength()
        offset += serialLen
        let serialNumberDER = Data(data[serialStart..<offset])
        let serialNumber = serialNumberDER.dropFirst(2)  // tag + length skip
            .map { String(format: "%02X", $0) }.joined(separator: ":")

        // signature AlgorithmIdentifier — skip
        _ = try skipTLV()

        // issuer Name
        let issuerStart = offset
        _ = try skipTLV()
        let issuerDER = Data(data[issuerStart..<offset])
        let issuerFields = parseNameFields(issuerDER)
        let issuerName = issuerFields["CN"] ?? issuerFields["O"] ?? "Unknown"

        // validity SEQUENCE { notBefore, notAfter }
        _ = try readTag()  // SEQUENCE tag
        _ = try readLength()

        let notBefore = try readTimeValue()
        let notAfter = try readTimeValue()

        // subject Name
        let subjectStart = offset
        _ = try skipTLV()
        let subjectDER = Data(data[subjectStart..<offset])
        let subjectFields = parseNameFields(subjectDER)

        let commonName = subjectFields["CN"] ?? "Unknown"
        let organization = subjectFields["O"]
        let organizationUnit = subjectFields["OU"]
        let country = subjectFields["C"]

        // PINFL va STIR serialNumber OID (2.5.4.5) dan olinadi
        let serialAttr = subjectFields["SERIALNUMBER"] ?? subjectFields["SN"] ?? subjectFields["2.5.4.5"]
        let (pinfl, stir) = extractPinflStir(from: serialAttr)

        return CertificateFields(
            serialNumber: serialNumber,
            commonName: commonName,
            organization: organization,
            organizationUnit: organizationUnit,
            country: country,
            pinfl: pinfl,
            stir: stir,
            issuerName: issuerName,
            notBefore: notBefore,
            notAfter: notAfter
        )
    }

    // MARK: - Name Parsing

    /// ASN.1 Name strukturasini parse qilish
    ///
    /// Name ::= SEQUENCE OF RelativeDistinguishedName
    /// RelativeDistinguishedName ::= SET OF AttributeTypeAndValue
    /// AttributeTypeAndValue ::= SEQUENCE { type OID, value ANY }
    private func parseNameFields(_ nameData: Data) -> [String: String] {
        var result: [String: String] = [:]
        var pos = 0

        // Name = SEQUENCE
        guard pos < nameData.count, nameData[pos] == 0x30 else { return result }
        pos += 1
        guard pos < nameData.count else { return result }
        let (nameLen, nameLenBytes) = readLengthAt(nameData, offset: pos)
        pos += nameLenBytes

        let nameEnd = pos + nameLen

        while pos < nameEnd && pos < nameData.count {
            // SET
            guard nameData[pos] == 0x31 else { break }
            pos += 1
            let (setLen, setLenBytes) = readLengthAt(nameData, offset: pos)
            pos += setLenBytes
            let setEnd = pos + setLen

            while pos < setEnd && pos < nameData.count {
                // SEQUENCE (AttributeTypeAndValue)
                guard nameData[pos] == 0x30 else { break }
                pos += 1
                let (seqLen, seqLenBytes) = readLengthAt(nameData, offset: pos)
                pos += seqLenBytes
                let seqEnd = pos + seqLen

                // OID
                guard pos < seqEnd, nameData[pos] == 0x06 else {
                    pos = seqEnd
                    continue
                }
                pos += 1
                let (oidLen, oidLenBytes) = readLengthAt(nameData, offset: pos)
                pos += oidLenBytes
                guard pos + oidLen <= nameData.count else { break }
                let oidData = Data(nameData[pos..<pos + oidLen])
                let oidString = decodeOID(oidData)
                pos += oidLen

                // Value (UTF8String, PrintableString, IA5String, BMPString, TeletexString)
                guard pos < seqEnd && pos < nameData.count else { break }
                let valueTag = nameData[pos]
                pos += 1
                let (valueLen, valueLenBytes) = readLengthAt(nameData, offset: pos)
                pos += valueLenBytes
                guard pos + valueLen <= nameData.count else { break }
                let valueData = Data(nameData[pos..<pos + valueLen])
                pos += valueLen

                let value: String
                if valueTag == 0x1E {  // BMPString (UTF-16 BE)
                    value = String(bytes: valueData, encoding: .utf16BigEndian) ?? ""
                } else {
                    value = String(bytes: valueData, encoding: .utf8)
                        ?? String(bytes: valueData, encoding: .isoLatin1)
                        ?? ""
                }

                let attrName = oidToAttributeName(oidString)
                result[attrName] = value
            }
            pos = setEnd
        }

        return result
    }

    /// OID ni attribute nomi ga aylantirish
    private func oidToAttributeName(_ oid: String) -> String {
        switch oid {
        case "2.5.4.3": return "CN"
        case "2.5.4.10": return "O"
        case "2.5.4.11": return "OU"
        case "2.5.4.6": return "C"
        case "2.5.4.5": return "SERIALNUMBER"
        case "2.5.4.7": return "L"
        case "2.5.4.8": return "ST"
        case "1.2.840.113549.1.9.1": return "EMAIL"
        default: return oid
        }
    }

    /// PINFL va STIR ni serialNumber attributedan ajratish
    ///
    /// O'zbekiston standartida:
    /// - PINFL: 14 ta raqam
    /// - STIR: 9 ta raqam
    private func extractPinflStir(from serialAttr: String?) -> (pinfl: String?, stir: String?) {
        guard let value = serialAttr else { return (nil, nil) }

        // Format: "INN:123456789" yoki "PINFL:12345678901234" yoki faqat raqamlar
        let cleanValue = value
            .replacingOccurrences(of: "INN:", with: "")
            .replacingOccurrences(of: "PINFL:", with: "")
            .replacingOccurrences(of: "UID:", with: "")
            .trimmingCharacters(in: .whitespaces)

        let digits = cleanValue.filter { $0.isNumber }

        if digits.count == 14 {
            return (pinfl: digits, stir: nil)
        } else if digits.count == 9 {
            return (pinfl: nil, stir: digits)
        }

        return (nil, nil)
    }

    // MARK: - Time Parsing

    /// UTCTime yoki GeneralizedTime qiymatini Date ga parse qilish
    ///
    /// UTCTime:        YYMMDDHHMMSSZ  (tag: 0x17)
    /// GeneralizedTime: YYYYMMDDHHMMSSZ (tag: 0x18)
    private mutating func readTimeValue() throws -> Date {
        guard offset < data.count else {
            throw MuhrError.invalidCertificateFormat
        }

        let tag = data[offset]
        offset += 1
        let length = try readLength()

        guard offset + length <= data.count else {
            throw MuhrError.invalidCertificateFormat
        }

        let timeData = Data(data[offset..<offset + length])
        offset += length

        guard let timeString = String(bytes: timeData, encoding: .ascii) else {
            throw MuhrError.invalidCertificateFormat
        }

        if tag == 0x17 {
            // UTCTime: YYMMDDHHMMSSZ
            return parseUTCTime(timeString) ?? Date()
        } else if tag == 0x18 {
            // GeneralizedTime: YYYYMMDDHHMMSSZ
            return parseGeneralizedTime(timeString) ?? Date()
        }

        throw MuhrError.invalidCertificateFormat
    }

    /// UTCTime parse qilish: YYMMDDHHMMSSZ
    private func parseUTCTime(_ s: String) -> Date? {
        // YY >= 50 → 19YY, YY < 50 → 20YY (RFC 5280 Section 4.1.2.5.1)
        guard s.count >= 12 else { return nil }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")

        // "Z" qo'shimchasi bilan yoki "±HHMM" bilan kelishi mumkin
        let withoutZ = s.hasSuffix("Z") ? String(s.dropLast()) : s

        if withoutZ.count == 12 {
            formatter.dateFormat = "yyMMddHHmmss"
            if let date = formatter.date(from: withoutZ) {
                return adjustUTCTime(date)
            }
        } else if withoutZ.count == 10 {
            formatter.dateFormat = "yyMMddHHmm"
            if let date = formatter.date(from: withoutZ) {
                return adjustUTCTime(date)
            }
        }

        return nil
    }

    /// UTCTime uchun yil tuzatish (RFC 5280: YY >= 50 → 1950-1999, YY < 50 → 2000-2049)
    private func adjustUTCTime(_ date: Date) -> Date {
        // DateFormatter bu tuzatishni avtomatik qiladi (yil 2000-2068 yoki 1969-1999 bo'ladi)
        return date
    }

    /// GeneralizedTime parse qilish: YYYYMMDDHHMMSSZ
    private func parseGeneralizedTime(_ s: String) -> Date? {
        guard s.count >= 14 else { return nil }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")

        let withoutZ = s.hasSuffix("Z") ? String(s.dropLast()) : s

        if withoutZ.count == 14 {
            formatter.dateFormat = "yyyyMMddHHmmss"
            return formatter.date(from: withoutZ)
        } else if withoutZ.count >= 14 {
            // Fractional seconds ni ignore qilish
            let truncated = String(withoutZ.prefix(14))
            formatter.dateFormat = "yyyyMMddHHmmss"
            return formatter.date(from: truncated)
        }

        return nil
    }

    // MARK: - OID Decoding

    /// ASN.1 OID ni string formatga decode qilish
    private func decodeOID(_ data: Data) -> String {
        guard !data.isEmpty else { return "" }

        var result = ""
        var firstByte = true
        var currentValue: UInt64 = 0

        for (index, byte) in data.enumerated() {
            if firstByte {
                // Birinchi octet: first = value / 40, second = value % 40
                result = "\(Int(byte) / 40).\(Int(byte) % 40)"
                firstByte = false
            } else {
                // Base-128 encoding
                currentValue = (currentValue << 7) | UInt64(byte & 0x7F)

                if byte & 0x80 == 0 {
                    result += ".\(currentValue)"
                    currentValue = 0
                }
            }

            _ = index  // suppress warning
        }

        return result
    }

    // MARK: - Low-Level Parsing (mutating)

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

    // MARK: - Low-Level Parsing (non-mutating, for name parsing)

    private func readLengthAt(_ data: Data, offset: Int) -> (length: Int, bytesConsumed: Int) {
        guard offset < data.count else { return (0, 0) }

        let first = data[offset]

        if first < 0x80 {
            return (Int(first), 1)
        }

        let numBytes = Int(first & 0x7F)
        guard offset + 1 + numBytes <= data.count else { return (0, 1) }

        var length = 0
        for i in 0..<numBytes {
            length = (length << 8) | Int(data[offset + 1 + i])
        }

        return (length, 1 + numBytes)
    }
}

// MARK: - Certificate Fields

/// DERParser tomonidan parse qilingan sertifikat maydonlari
struct CertificateFields {
    let serialNumber: String
    let commonName: String
    let organization: String?
    let organizationUnit: String?
    let country: String?
    let pinfl: String?
    let stir: String?
    let issuerName: String
    let notBefore: Date
    let notAfter: Date
}
