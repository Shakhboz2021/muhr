//
//  SignDataUseCase.swift
//  Muhr
//
//  Created by Muhammad on 27/01/26.
//

import Foundation

// MARK: - Sign Data Use Case
/// Ma'lumotni imzolash uchun UseCase
///
/// Bu UseCase faqat BITTA vazifani bajaradi: ma'lumotni imzolash.
///
/// ## Clean Architecture:
/// ```
/// ViewModel ──▶ SignDataUseCase ──▶ SigningRepository ──▶ Provider
/// ```
///
/// ## Single Responsibility Principle:
/// - Faqat imzolash logikasi
/// - Validatsiya
/// - Xatolarni qayta ishlash
///
/// ## Foydalanish:
/// ```swift
/// let useCase = SignDataUseCase(repository: repository)
///
/// // Oddiy imzolash
/// let result = try await useCase.execute(data: document)
///
/// // Sertifikat bilan
/// let result = try await useCase.execute(
///     data: document,
///     certificate: selectedCert
/// )
/// ```
public final class SignDataUseCase: Sendable {

    // MARK: - Dependencies

    private let signingRepository: SigningRepository
    private let certificateRepository: CertificateRepository

    // MARK: - Initializer

    /// UseCase yaratish
    ///
    /// - Parameters:
    ///   - signingRepository: Imzolash repository
    ///   - certificateRepository: Sertifikat repository
    public init(
        signingRepository: SigningRepository,
        certificateRepository: CertificateRepository
    ) {
        self.signingRepository = signingRepository
        self.certificateRepository = certificateRepository
    }

    // MARK: - Execute

    /// Ma'lumotni imzolash
    ///
    /// - Parameters:
    ///   - data: Imzolanadigan ma'lumot
    ///   - certificate: Sertifikat (nil bo'lsa default ishlatiladi)
    /// - Returns: Imzolash natijasi
    /// - Throws: `MuhrError`
    public func execute(
        data: Data,
        certificate: CertificateInfo? = nil
    ) async throws -> SignatureResult {

        // 1. Validatsiya: Ma'lumot bo'sh emasligini tekshirish
        guard !data.isEmpty else {
            throw MuhrError.emptyDataToSign
        }

        // 2. Sertifikatni aniqlash
        let signingCertificate = try await resolveCertificate(certificate)

        // 3. Sertifikat validligini tekshirish
        try validateCertificate(signingCertificate)

        // 4. Imzolash
        let result = try await signingRepository.sign(
            data: data,
            with: signingCertificate
        )

        return result
    }

    /// String ma'lumotni imzolash
    ///
    /// - Parameters:
    ///   - string: Imzolanadigan matn
    ///   - encoding: Matn kodlash turi (default: UTF-8)
    ///   - certificate: Sertifikat (nil bo'lsa default ishlatiladi)
    /// - Returns: Imzolash natijasi
    /// - Throws: `MuhrError`
    public func execute(
        string: String,
        encoding: String.Encoding = .utf8,
        certificate: CertificateInfo? = nil
    ) async throws -> SignatureResult {

        guard let data = string.data(using: encoding) else {
            throw MuhrError.signingFailed(
                reason: "String to Data conversion failed"
            )
        }

        return try await execute(data: data, certificate: certificate)
    }

    /// JSON ma'lumotni imzolash
    ///
    /// - Parameters:
    ///   - json: Imzolanadigan JSON dictionary
    ///   - certificate: Sertifikat (nil bo'lsa default ishlatiladi)
    /// - Returns: Imzolash natijasi
    /// - Throws: `MuhrError`
    public func execute(
        json: [String: Any],
        certificate: CertificateInfo? = nil
    ) async throws -> SignatureResult {

        let data = try JSONSerialization.data(
            withJSONObject: json,
            options: [.sortedKeys]  // Deterministik natija uchun
        )

        return try await execute(data: data, certificate: certificate)
    }

    /// Encodable ob'ektni imzolash
    ///
    /// - Parameters:
    ///   - object: Imzolanadigan Encodable ob'ekt
    ///   - certificate: Sertifikat (nil bo'lsa default ishlatiladi)
    /// - Returns: Imzolash natijasi
    /// - Throws: `MuhrError`
    public func execute<T: Encodable>(
        object: T,
        certificate: CertificateInfo? = nil
    ) async throws -> SignatureResult {

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]  // Deterministik natija uchun

        let data = try encoder.encode(object)

        return try await execute(data: data, certificate: certificate)
    }

    // MARK: - Private Methods

    /// Sertifikatni aniqlash
    private func resolveCertificate(_ certificate: CertificateInfo?)
        async throws -> CertificateInfo
    {

        // Agar sertifikat berilgan bo'lsa, uni qaytarish
        if let cert = certificate {
            return cert
        }

        // Default sertifikatni olishga harakat
        if let defaultCert =
            try await certificateRepository.getDefaultCertificate()
        {
            return defaultCert
        }

        // Birinchi valid sertifikatni olish
        let validCerts = try await certificateRepository.getValidCertificates()

        guard let firstCert = validCerts.first else {
            throw MuhrError.certificateNotFound
        }

        return firstCert
    }

    /// Sertifikat validligini tekshirish
    private func validateCertificate(_ certificate: CertificateInfo) throws {

        // Muddati tugaganmi?
        if certificate.isExpired {
            throw MuhrError.certificateExpired(expiryDate: certificate.validTo)
        }

        // Hali kuchga kirmaganmi?
        if certificate.isNotYetValid {
            throw MuhrError.certificateNotYetValid(
                validFrom: certificate.validFrom
            )
        }

        // Private key bormi?
        if !certificate.canSign {
            throw MuhrError.privateKeyNotFound
        }
    }
}

// MARK: - Convenience Extensions
extension SignDataUseCase {

    /// Bank operatsiyasini imzolash
    ///
    /// Bank operatsiyalari uchun maxsus format.
    ///
    /// - Parameters:
    ///   - operationId: Operatsiya ID'si
    ///   - amount: Summa
    ///   - currency: Valyuta kodi (UZS, USD, etc.)
    ///   - description: Tavsif
    ///   - certificate: Sertifikat
    /// - Returns: Imzolash natijasi
    public func signBankOperation(
        operationId: String,
        amount: Decimal,
        currency: String,
        description: String,
        certificate: CertificateInfo? = nil
    ) async throws -> SignatureResult {

        let payload: [String: Any] = [
            "operation_id": operationId,
            "amount": "\(amount)",
            "currency": currency,
            "description": description,
            "timestamp": ISO8601DateFormatter().string(from: Date()),
        ]

        return try await execute(json: payload, certificate: certificate)
    }
}
