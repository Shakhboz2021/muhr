//
//  VerifySignatureUseCase.swift
//  Muhr
//
//  Created by Muhammad on 27/01/26.
//

import Foundation

// MARK: - Verify Signature Use Case
/// Imzoni tekshirish uchun UseCase
///
/// Bu UseCase faqat BITTA vazifani bajaradi: imzoni tekshirish.
///
/// ## Clean Architecture:
/// ```
/// ViewModel ──▶ VerifySignatureUseCase ──▶ SigningRepository ──▶ Provider
/// ```
///
/// ## Tekshirish Bosqichlari (RFC 5280, Section 6):
/// 1. Imzo matematik jihatdan to'g'rimi?
/// 2. Sertifikat muddati tugamaganmi?
/// 3. Sertifikat zanjiri ishonchlimi?
/// 4. Sertifikat bekor qilinmaganmi?
///
/// ## Foydalanish:
/// ```swift
/// let useCase = VerifySignatureUseCase(repository: repository)
///
/// let result = try await useCase.execute(
///     signature: signatureData,
///     originalData: document,
///     certificate: signerCert
/// )
///
/// if result.isValid {
///     print("✅ Imzo haqiqiy")
/// } else {
///     print("❌ Imzo noto'g'ri: \(result.errors)")
/// }
/// ```
public final class VerifySignatureUseCase: Sendable {

    // MARK: - Dependencies

    private let signingRepository: SigningRepository

    // MARK: - Initializer

    /// UseCase yaratish
    ///
    /// - Parameter signingRepository: Imzolash repository
    public init(signingRepository: SigningRepository) {
        self.signingRepository = signingRepository
    }

    // MARK: - Execute

    /// Imzoni tekshirish
    ///
    /// - Parameters:
    ///   - signature: Tekshiriladigan imzo (raw bytes)
    ///   - originalData: Original ma'lumot
    ///   - certificate: Imzolovchi sertifikat (optional)
    /// - Returns: Tekshirish natijasi
    /// - Throws: `MuhrError`
    public func execute(
        signature: Data,
        originalData: Data,
        certificate: CertificateInfo? = nil
    ) async throws -> VerificationResult {

        // 1. Validatsiya: Imzo bo'sh emasligini tekshirish
        guard !signature.isEmpty else {
            return VerificationResult.failure(
                errors: [.invalidSignature]
            )
        }

        // 2. Validatsiya: Original ma'lumot bo'sh emasligini tekshirish
        guard !originalData.isEmpty else {
            return VerificationResult.failure(
                errors: [.dataModified]
            )
        }

        // 3. Sertifikat validatsiyasi (agar berilgan bo'lsa)
        var warnings: [String] = []

        if let cert = certificate {
            let certWarnings = validateCertificateForVerification(cert)
            warnings.append(contentsOf: certWarnings)
        }

        // 4. Tekshirish
        let result = try await signingRepository.verify(
            signature: signature,
            originalData: originalData,
            certificate: certificate
        )

        // 5. Natijaga warning'larni qo'shish
        if !warnings.isEmpty {
            return VerificationResult(
                isSignatureValid: result.isSignatureValid,
                isCertificateValid: result.isCertificateValid,
                isCertificateChainValid: result.isCertificateChainValid,
                isCertificateNotRevoked: result.isCertificateNotRevoked,
                signerCertificate: result.signerCertificate,
                signedAt: result.signedAt,
                errors: result.errors,
                warnings: result.warnings + warnings
            )
        }

        return result
    }

    /// Base64 formatdagi imzoni tekshirish
    ///
    /// - Parameters:
    ///   - signatureBase64: Base64 formatda imzo
    ///   - originalData: Original ma'lumot
    ///   - certificate: Imzolovchi sertifikat (optional)
    /// - Returns: Tekshirish natijasi
    /// - Throws: `MuhrError`
    public func execute(
        signatureBase64: String,
        originalData: Data,
        certificate: CertificateInfo? = nil
    ) async throws -> VerificationResult {

        guard let signatureData = Data(base64Encoded: signatureBase64) else {
            return VerificationResult.failure(
                errors: [.invalidSignature]
            )
        }

        return try await execute(
            signature: signatureData,
            originalData: originalData,
            certificate: certificate
        )
    }

    /// Hex formatdagi imzoni tekshirish
    ///
    /// - Parameters:
    ///   - signatureHex: Hex formatda imzo
    ///   - originalData: Original ma'lumot
    ///   - certificate: Imzolovchi sertifikat (optional)
    /// - Returns: Tekshirish natijasi
    /// - Throws: `MuhrError`
    public func execute(
        signatureHex: String,
        originalData: Data,
        certificate: CertificateInfo? = nil
    ) async throws -> VerificationResult {

        guard let signatureData = Data(hexString: signatureHex) else {
            return VerificationResult.failure(
                errors: [.invalidSignature]
            )
        }

        return try await execute(
            signature: signatureData,
            originalData: originalData,
            certificate: certificate
        )
    }

    /// String ma'lumot bilan tekshirish
    ///
    /// - Parameters:
    ///   - signature: Imzo (raw bytes)
    ///   - originalString: Original matn
    ///   - encoding: Matn kodlash turi (default: UTF-8)
    ///   - certificate: Imzolovchi sertifikat (optional)
    /// - Returns: Tekshirish natijasi
    /// - Throws: `MuhrError`
    public func execute(
        signature: Data,
        originalString: String,
        encoding: String.Encoding = .utf8,
        certificate: CertificateInfo? = nil
    ) async throws -> VerificationResult {

        guard let originalData = originalString.data(using: encoding) else {
            return VerificationResult.failure(
                errors: [.dataModified]
            )
        }

        return try await execute(
            signature: signature,
            originalData: originalData,
            certificate: certificate
        )
    }

    /// SignatureResult bilan tekshirish
    ///
    /// Avval imzolangan natijani tekshirish uchun qulay metod.
    ///
    /// - Parameters:
    ///   - signatureResult: Oldingi imzolash natijasi
    ///   - originalData: Original ma'lumot
    /// - Returns: Tekshirish natijasi
    /// - Throws: `MuhrError`
    public func execute(
        signatureResult: SignatureResult,
        originalData: Data
    ) async throws -> VerificationResult {

        return try await execute(
            signature: signatureResult.signature,
            originalData: originalData,
            certificate: signatureResult.certificate
        )
    }

    // MARK: - Private Methods

    /// Sertifikatni tekshirish va warning'lar qaytarish
    private func validateCertificateForVerification(
        _ certificate: CertificateInfo
    ) -> [String] {

        var warnings: [String] = []

        // Muddati tugagan bo'lsa (lekin imzo hali ham tekshiriladi)
        if certificate.isExpired {
            warnings.append(
                "⚠️ Sertifikat muddati tugagan: \(certificate.validTo.formatted()). "
                    + "Imzo imzolangan vaqtda haqiqiy bo'lgan bo'lishi mumkin."
            )
        }

        // Muddati tugashiga oz qolgan bo'lsa
        if certificate.daysUntilExpiry > 0 && certificate.daysUntilExpiry <= 30
        {
            warnings.append(
                "⚠️ Sertifikat muddati \(certificate.daysUntilExpiry) kundan keyin tugaydi."
            )
        }

        return warnings
    }
}

// MARK: - Data Extension for Hex
extension Data {

    /// Hex string'dan Data yaratish
    init?(hexString: String) {
        // "AB:CD:EF" yoki "ABCDEF" formatini qo'llab-quvvatlash
        let hex =
            hexString
            .replacingOccurrences(of: ":", with: "")
            .replacingOccurrences(of: " ", with: "")

        guard hex.count % 2 == 0 else { return nil }

        var data = Data()
        var index = hex.startIndex

        while index < hex.endIndex {
            let nextIndex = hex.index(index, offsetBy: 2)
            let byteString = String(hex[index..<nextIndex])

            guard let byte = UInt8(byteString, radix: 16) else {
                return nil
            }

            data.append(byte)
            index = nextIndex
        }

        self = data
    }
}
