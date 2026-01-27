//
//  CertificateInfo.swift
//  Muhr
//
//  Created by Muhammad on 27/01/26.
//

import Foundation
import Security

// MARK: - Certificate Info
/// X.509 sertifikat ma'lumotlari
///
/// X.509 standarti ITU-T tomonidan belgilangan va quyidagi RFC'larda tasvirlangan:
/// - **RFC 5280**: Internet X.509 PKI Certificate and CRL Profile
///   https://datatracker.ietf.org/doc/html/rfc5280
/// - **RFC 6818**: Updates to the Internet X.509 PKI Certificate and CRL Profile
///   https://datatracker.ietf.org/doc/html/rfc6818
///
/// ## X.509 Certificate Strukturasi (RFC 5280, Section 4.1):
/// ```
/// Certificate ::= SEQUENCE {
///     tbsCertificate       TBSCertificate,
///     signatureAlgorithm   AlgorithmIdentifier,
///     signatureValue       BIT STRING
/// }
///
/// TBSCertificate ::= SEQUENCE {
///     version         [0]  EXPLICIT Version DEFAULT v1,
///     serialNumber         CertificateSerialNumber,
///     signature            AlgorithmIdentifier,
///     issuer               Name,
///     validity             Validity,
///     subject              Name,
///     subjectPublicKeyInfo SubjectPublicKeyInfo,
///     ...
/// }
/// ```
///
/// ## Foydalanish:
/// ```swift
/// let cert = try CertificateParser.parse(data: certData)
/// print(cert.commonName)        // "Muhammad"
/// print(cert.algorithm)         // .ecdsaP256
/// print(cert.isValid)           // true
/// print(cert.daysUntilExpiry)   // 365
/// ```
public struct CertificateInfo: Identifiable, Sendable {

    // MARK: - Identification

    /// Unique identifier (serial number asosida)
    public let id: String

    /// Sertifikat serial raqami (hex formatda)
    ///
    /// RFC 5280, Section 4.1.2.2:
    /// Serial number MUST be unique for each certificate issued by a given CA.
    /// Misol: "01:23:45:67:89:AB:CD:EF"
    public let serialNumber: String

    // MARK: - Subject (RFC 5280, Section 4.1.2.6)

    /// Common Name (OID: 2.5.4.3)
    ///
    /// RFC 5280 va RFC 4519 da belgilangan.
    /// Misol: "Muhammad Karimov" yoki "DCIB Bank"
    public let commonName: String

    /// Organization (OID: 2.5.4.10)
    ///
    /// RFC 4519, Section 2.19
    /// Misol: "Digital Commercial International Bank"
    public let organization: String?

    /// Organization Unit (OID: 2.5.4.11)
    ///
    /// RFC 4519, Section 2.20
    /// Misol: "IT Department"
    public let organizationUnit: String?

    /// Country (OID: 2.5.4.6)
    ///
    /// RFC 4519, Section 2.2 - ISO 3166 country code
    /// Misol: "UZ"
    public let country: String?

    // MARK: - O'zbekiston Identifikatorlari

    /// PINFL - Jismoniy shaxs identifikatsiya raqami
    ///
    /// O'zbekiston Respublikasi qonunchiligiga muvofiq (14 ta raqam)
    /// Serial Number (OID: 2.5.4.5) maydonida saqlanadi
    /// Misol: "12345678901234"
    public let pinfl: String?

    /// STIR - Soliq to'lovchi identifikatsiya raqami
    ///
    /// O'zbekiston Respublikasi qonunchiligiga muvofiq (9 ta raqam)
    /// Serial Number (OID: 2.5.4.5) maydonida saqlanadi
    /// Misol: "123456789"
    public let stir: String?

    // MARK: - Issuer (RFC 5280, Section 4.1.2.4)

    /// Sertifikat bergan tashkilot nomi (CA)
    ///
    /// RFC 5280: The issuer field identifies the entity that has signed
    /// and issued the certificate.
    /// Misol: "E-IMZO CA"
    public let issuerName: String

    // MARK: - Validity (RFC 5280, Section 4.1.2.5)

    /// Sertifikat boshlanish sanasi (notBefore)
    ///
    /// RFC 5280: The date on which the certificate validity period begins.
    public let validFrom: Date

    /// Sertifikat tugash sanasi (notAfter)
    ///
    /// RFC 5280: The date on which the certificate validity period ends.
    public let validTo: Date

    // MARK: - Algorithm (RFC 5280, Section 4.1.1.2)

    /// Imzo algoritmi
    ///
    /// RFC 5280, Section 4.1.1.2: This field contains the algorithm
    /// identifier for the algorithm used by the CA to sign the certificate.
    ///
    /// Algoritmlar quyidagi RFC'larda belgilangan:
    /// - **RFC 5758**: ECDSA for X.509 (P-256, P-384, P-521)
    /// - **RFC 8017**: PKCS #1 RSA
    /// - **RFC 8410**: Ed25519/Ed448
    public let algorithm: SignatureAlgorithm

    /// Kalit uzunligi (bitlarda)
    ///
    /// SubjectPublicKeyInfo (RFC 5280, Section 4.1.2.7) dan olinadi.
    /// Misol: 256, 384, 2048
    public let keySize: Int

    // MARK: - Internal References

    /// Security framework certificate reference
    /// Apple's Security.framework SecCertificate type
    internal let secCertificate: SecCertificate

    /// Private key reference (Keychain'dan)
    ///
    /// PKCS#8 (RFC 5958) formatida saqlangan private key
    internal let privateKeyRef: SecKey?

    // MARK: - Computed Properties

    /// Sertifikat hozir amal qiladimi?
    ///
    /// RFC 5280, Section 4.1.2.5:
    /// "The certificate validity period is the time interval during which
    /// the CA warrants that it will maintain information about the status
    /// of the certificate."
    public var isValid: Bool {
        let now = Date()
        return now >= validFrom && now <= validTo
    }

    /// Muddati tugashiga qancha kun qoldi
    public var daysUntilExpiry: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents(
            [.day],
            from: Date(),
            to: validTo
        )
        return components.day ?? 0
    }

    /// Sertifikat muddati tugaganmi?
    public var isExpired: Bool {
        return Date() > validTo
    }

    /// Sertifikat hali kuchga kirmaganmi?
    public var isNotYetValid: Bool {
        return Date() < validFrom
    }

    /// Private key mavjudmi? (imzolash uchun kerak)
    ///
    /// Imzolash uchun private key bo'lishi shart.
    /// Agar faqat certificate bo'lsa, faqat verify qilish mumkin.
    public var canSign: Bool {
        return privateKeyRef != nil
    }

    // MARK: - Initializer

    public init(
        id: String,
        serialNumber: String,
        commonName: String,
        organization: String?,
        organizationUnit: String?,
        country: String?,
        pinfl: String?,
        stir: String?,
        issuerName: String,
        validFrom: Date,
        validTo: Date,
        algorithm: SignatureAlgorithm,
        keySize: Int,
        secCertificate: SecCertificate,
        privateKeyRef: SecKey?
    ) {
        self.id = id
        self.serialNumber = serialNumber
        self.commonName = commonName
        self.organization = organization
        self.organizationUnit = organizationUnit
        self.country = country
        self.pinfl = pinfl
        self.stir = stir
        self.issuerName = issuerName
        self.validFrom = validFrom
        self.validTo = validTo
        self.algorithm = algorithm
        self.keySize = keySize
        self.secCertificate = secCertificate
        self.privateKeyRef = privateKeyRef
    }
}

// MARK: - Equatable
extension CertificateInfo: Equatable {
    public static func == (lhs: CertificateInfo, rhs: CertificateInfo) -> Bool {
        return lhs.id == rhs.id && lhs.serialNumber == rhs.serialNumber
    }
}

// MARK: - Hashable
extension CertificateInfo: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(serialNumber)
    }
}

// MARK: - CustomStringConvertible
extension CertificateInfo: CustomStringConvertible {
    public var description: String {
        """
        Certificate: \(commonName)
        Serial: \(serialNumber)
        Algorithm: \(algorithm.displayName)
        Valid: \(validFrom.formatted()) - \(validTo.formatted())
        Status: \(isValid ? "✅ Valid" : "❌ Invalid")
        """
    }
}
