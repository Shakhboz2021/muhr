//
//  VerificationResult.swift
//  Muhr
//
//  Created by Muhammad on 27/01/26.
//

import Foundation

// MARK: - Verification Result
/// Imzo tekshirish natijasi
///
/// `verify()` metodi qaytaradigan natija. Imzo haqiqiyligi,
/// sertifikat holati va xatolar haqida ma'lumot beradi.
///
/// ## Tekshirish Jarayoni (RFC 5280, Section 6):
/// ```
/// 1. Signature mathematically valid?     → isSignatureValid
/// 2. Certificate not expired?            → isCertificateValid
/// 3. Certificate chain trusted?          → isCertificateChainValid
/// 4. Certificate not revoked?            → isCertificateNotRevoked
/// 5. All checks passed?                  → isValid
/// ```
///
/// ## Foydalanish:
/// ```swift
/// let result = try await verifier.verify(
///     signature: signatureData,
///     originalData: document,
///     certificate: cert
/// )
///
/// if result.isValid {
///     print("✅ Imzo haqiqiy")
/// } else {
///     print("❌ Xatolar: \(result.errors)")
/// }
/// ```
public struct VerificationResult: Sendable {

    // MARK: - Core Status

    /// Imzo matematik jihatdan to'g'rimi?
    ///
    /// SecKeyVerifySignature() natijasi.
    /// Bu faqat kriptografik tekshirish - sertifikat holatini tekshirmaydi.
    public let isSignatureValid: Bool

    /// Sertifikat hozir amal qiladimi?
    ///
    /// notBefore <= now <= notAfter (RFC 5280, Section 4.1.2.5)
    public let isCertificateValid: Bool

    /// Sertifikat zanjiri ishonchlimi?
    ///
    /// Root CA gacha bo'lgan zanjir tekshiriladi.
    /// RFC 5280, Section 6: Certification Path Validation
    public let isCertificateChainValid: Bool

    /// Sertifikat bekor qilinmaganmi?
    ///
    /// CRL (Certificate Revocation List) yoki OCSP orqali tekshiriladi.
    /// - RFC 5280: CRL Profile
    /// - RFC 6960: OCSP (Online Certificate Status Protocol)
    public let isCertificateNotRevoked: Bool

    // MARK: - Signer Info

    /// Imzolovchi sertifikat ma'lumotlari
    public let signerCertificate: CertificateInfo?

    /// Imzolangan vaqt (agar mavjud bo'lsa)
    ///
    /// Signed attribute'dan olinadi (RFC 5652, Section 11.3)
    public let signedAt: Date?

    // MARK: - Errors & Warnings

    /// Xatolar ro'yxati
    ///
    /// Bo'sh bo'lsa - xato yo'q
    public let errors: [VerificationError]

    /// Ogohlantirishlar ro'yxati
    ///
    /// Kritik emas, lekin e'tibor berish kerak
    public let warnings: [String]

    // MARK: - Computed Properties

    /// Barcha tekshiruvlar muvaffaqiyatlimi?
    ///
    /// `true` faqat HAMMA tekshiruvlar o'tganda
    public var isValid: Bool {
        return isSignatureValid && isCertificateValid && isCertificateChainValid
            && isCertificateNotRevoked && errors.isEmpty
    }

    /// Qisqa holat tavsifi
    public var statusMessage: String {
        if isValid {
            return "✅ Imzo haqiqiy va ishonchli"
        }

        if !isSignatureValid {
            return "❌ Imzo matematik jihatdan noto'g'ri"
        }

        if !isCertificateValid {
            return "❌ Sertifikat muddati tugagan yoki hali kuchga kirmagan"
        }

        if !isCertificateChainValid {
            return "❌ Sertifikat zanjiri ishonchsiz"
        }

        if !isCertificateNotRevoked {
            return "❌ Sertifikat bekor qilingan"
        }

        return "❌ Tekshirish muvaffaqiyatsiz"
    }

    /// Imzolovchi ismi (agar mavjud)
    public var signerName: String? {
        signerCertificate?.commonName
    }

    /// Xatolar bormi?
    public var hasErrors: Bool {
        !errors.isEmpty
    }

    /// Ogohlantirishlar bormi?
    public var hasWarnings: Bool {
        !warnings.isEmpty
    }

    // MARK: - Initializer

    public init(
        isSignatureValid: Bool,
        isCertificateValid: Bool = true,
        isCertificateChainValid: Bool = true,
        isCertificateNotRevoked: Bool = true,
        signerCertificate: CertificateInfo? = nil,
        signedAt: Date? = nil,
        errors: [VerificationError] = [],
        warnings: [String] = []
    ) {
        self.isSignatureValid = isSignatureValid
        self.isCertificateValid = isCertificateValid
        self.isCertificateChainValid = isCertificateChainValid
        self.isCertificateNotRevoked = isCertificateNotRevoked
        self.signerCertificate = signerCertificate
        self.signedAt = signedAt
        self.errors = errors
        self.warnings = warnings
    }

    // MARK: - Factory Methods

    /// Muvaffaqiyatli natija yaratish
    public static func success(
        signerCertificate: CertificateInfo,
        signedAt: Date? = nil,
        warnings: [String] = []
    ) -> VerificationResult {
        VerificationResult(
            isSignatureValid: true,
            isCertificateValid: true,
            isCertificateChainValid: true,
            isCertificateNotRevoked: true,
            signerCertificate: signerCertificate,
            signedAt: signedAt,
            errors: [],
            warnings: warnings
        )
    }

    /// Muvaffaqiyatsiz natija yaratish
    public static func failure(
        errors: [VerificationError],
        signerCertificate: CertificateInfo? = nil
    ) -> VerificationResult {
        VerificationResult(
            isSignatureValid: false,
            isCertificateValid: false,
            isCertificateChainValid: false,
            isCertificateNotRevoked: false,
            signerCertificate: signerCertificate,
            signedAt: nil,
            errors: errors,
            warnings: []
        )
    }
}

// MARK: - Verification Error
/// Tekshirish xatoliklari
///
/// RFC 5280, Section 6.1.3 da keltirilgan validation xatolari
public enum VerificationError: Error, Sendable, Equatable {

    /// Imzo matematik jihatdan noto'g'ri
    case invalidSignature

    /// Sertifikat muddati tugagan
    case certificateExpired(Date)

    /// Sertifikat hali kuchga kirmagan
    case certificateNotYetValid(Date)

    /// Sertifikat bekor qilingan
    case certificateRevoked(reason: RevocationReason)

    /// Sertifikat zanjiri buzilgan
    case invalidCertificateChain(String)

    /// Ishonchli CA topilmadi
    case untrustedRoot

    /// Sertifikat topilmadi
    case certificateNotFound

    /// Algoritm qo'llab-quvvatlanmaydi
    case unsupportedAlgorithm(String)

    /// Ma'lumot o'zgartirilgan (hash mos kelmadi)
    case dataModified

    /// Noma'lum xato
    case unknown(String)

    /// Xato tavsifi
    public var localizedDescription: String {
        switch self {
        case .invalidSignature:
            return "Imzo matematik jihatdan noto'g'ri"
        case .certificateExpired(let date):
            return "Sertifikat muddati tugagan: \(Self.formatDate(date))"
        case .certificateNotYetValid(let date):
            return "Sertifikat hali kuchga kirmagan: \(Self.formatDate(date))"
        case .certificateRevoked(let reason):
            return "Sertifikat bekor qilingan: \(reason.description)"
        case .invalidCertificateChain(let details):
            return "Sertifikat zanjiri noto'g'ri: \(details)"
        case .untrustedRoot:
            return "Ishonchli CA topilmadi"
        case .certificateNotFound:
            return "Sertifikat topilmadi"
        case .unsupportedAlgorithm(let algo):
            return "Algoritm qo'llab-quvvatlanmaydi: \(algo)"
        case .dataModified:
            return "Ma'lumot o'zgartirilgan"
        case .unknown(let msg):
            return "Noma'lum xato: \(msg)"
        }
    }

    private static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "uz_UZ")
        return formatter.string(from: date)
    }
}

// MARK: - Revocation Reason
/// Sertifikat bekor qilish sabablari
///
/// RFC 5280, Section 5.3.1: CRL Entry Extensions - reasonCode
/// OID: 2.5.29.21
public enum RevocationReason: Int, Sendable {
    /// Noma'lum sabab
    case unspecified = 0

    /// Kalit buzilgan (compromised)
    case keyCompromise = 1

    /// CA buzilgan
    case caCompromise = 2

    /// Bog'liqlik o'zgargan (ish joyi, ism va h.k.)
    case affiliationChanged = 3

    /// Yangi sertifikat bilan almashtirilgan
    case superseded = 4

    /// Faoliyat to'xtatilgan
    case cessationOfOperation = 5

    /// Vaqtinchalik to'xtatilgan
    case certificateHold = 6

    /// CRL'dan olib tashlash (faqat delta CRL uchun)
    case removeFromCRL = 8

    /// Imtiyoz bekor qilingan
    case privilegeWithdrawn = 9

    /// AA buzilgan
    case aaCompromise = 10

    /// Tavsif
    public var description: String {
        switch self {
        case .unspecified: return "Noma'lum sabab"
        case .keyCompromise: return "Kalit buzilgan"
        case .caCompromise: return "CA buzilgan"
        case .affiliationChanged: return "Ma'lumotlar o'zgargan"
        case .superseded: return "Yangi sertifikat bilan almashtirilgan"
        case .cessationOfOperation: return "Faoliyat to'xtatilgan"
        case .certificateHold: return "Vaqtinchalik to'xtatilgan"
        case .removeFromCRL: return "CRL'dan olib tashlangan"
        case .privilegeWithdrawn: return "Imtiyoz bekor qilingan"
        case .aaCompromise: return "AA buzilgan"
        }
    }
}

// MARK: - CustomStringConvertible
extension VerificationResult: CustomStringConvertible {
    public var description: String {
        """
        VerificationResult:
          Status: \(isValid ? "✅ VALID" : "❌ INVALID")
          Signature: \(isSignatureValid ? "✓" : "✗")
          Certificate: \(isCertificateValid ? "✓" : "✗")
          Chain: \(isCertificateChainValid ? "✓" : "✗")
          Not Revoked: \(isCertificateNotRevoked ? "✓" : "✗")
          Signer: \(signerName ?? "Unknown")
          Errors: \(errors.count)
          Warnings: \(warnings.count)
        """
    }
}
