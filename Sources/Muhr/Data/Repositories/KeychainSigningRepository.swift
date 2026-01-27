//
//  KeychainSigningRepository.swift
//  Muhr
//
//  Created by Muhammad on 27/01/26.
//

import CryptoKit
import Foundation
import Security

// MARK: - Keychain Signing Repository
/// Keychain orqali imzolash operatsiyalari
///
/// iOS Security framework va CryptoKit yordamida
/// ma'lumotlarni imzolash va tekshirish.
///
/// ## Imzolash Jarayoni:
/// ```
/// 1. Data → Hash (SHA-256/384/512)
/// 2. Hash → Sign with Private Key
/// 3. Return Signature
/// ```
///
/// ## Apple Security APIs:
/// - **SecKeyCreateSignature**: Imzolash
/// - **SecKeyVerifySignature**: Tekshirish
///
/// ## Thread Safety:
/// Barcha operatsiyalar thread-safe.
public final class KeychainSigningRepository: SigningRepository,
    @unchecked Sendable
{

    // MARK: - Dependencies
    private let certificateRepository: CertificateRepository

    // MARK: - Queue
    private let queue = DispatchQueue(
        label: "com.muhr.signing",
        qos: .userInitiated
    )

    // MARK: - Initializer

    /// Repository yaratish
    ///
    /// - Parameter certificateRepository: Sertifikat repository
    public init(certificateRepository: CertificateRepository) {
        self.certificateRepository = certificateRepository
    }

    // MARK: - Signing Operations

    public func sign(data: Data, with certificate: CertificateInfo?)
        async throws -> SignatureResult
    {

        // 1. Sertifikatni aniqlash
        let cert = try await resolveCertificate(certificate)

        // 2. Private key borligini tekshirish
        guard let privateKey = cert.privateKeyRef else {
            throw MuhrError.privateKeyNotFound
        }

        // 3. Imzolash (sync, chunki CPU-bound)
        return try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    let result = try self.signSync(
                        data: data,
                        privateKey: privateKey,
                        certificate: cert
                    )
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    public func signFile(at fileURL: URL, with certificate: CertificateInfo?)
        async throws -> SignatureResult
    {

        // 1. Fayl mavjudligini tekshirish
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw MuhrError.fileNotFound(path: fileURL.path)
        }

        // 2. Faylni o'qish
        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch {
            throw MuhrError.fileReadError(reason: error.localizedDescription)
        }

        // 3. Imzolash
        return try await sign(data: data, with: certificate)
    }

    // MARK: - Verification Operations

    public func verify(
        signature: Data,
        originalData: Data,
        certificate: CertificateInfo?
    ) async throws -> VerificationResult {

        // Sertifikat talab qilinadi
        guard let cert = certificate else {
            return VerificationResult.failure(
                errors: [.certificateNotFound]
            )
        }

        // Public key olish
        var publicKey: SecKey?
        if #available(iOS 12.0, *) {
            publicKey = SecCertificateCopyKey(cert.secCertificate)
        }

        guard let pubKey = publicKey else {
            return VerificationResult.failure(
                errors: [.invalidSignature]
            )
        }

        // Tekshirish
        return await withCheckedContinuation { continuation in
            queue.async {
                let result = self.verifySync(
                    signature: signature,
                    originalData: originalData,
                    publicKey: pubKey,
                    certificate: cert
                )
                continuation.resume(returning: result)
            }
        }
    }

    // MARK: - Hash Operations

    public func hash(data: Data, using algorithm: HashAlgorithm) -> Data {
        switch algorithm {
        case .sha256:
            Data(SHA256.hash(data: data))
        case .sha384:
            Data(SHA384.hash(data: data))
        case .sha512:
            Data(SHA512.hash(data: data))
        }
    }

    // MARK: - Private Methods

    /// Sertifikatni aniqlash
    private func resolveCertificate(_ certificate: CertificateInfo?)
        async throws -> CertificateInfo
    {

        if let cert = certificate {
            return cert
        }

        // Default sertifikatni olish
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

    /// Sync imzolash
    private func signSync(
        data: Data,
        privateKey: SecKey,
        certificate: CertificateInfo
    ) throws -> SignatureResult {

        let algorithm = certificate.algorithm
        let secAlgorithm = algorithm.secKeyAlgorithm

        // Algoritmni qo'llab-quvvatlashini tekshirish
        guard SecKeyIsAlgorithmSupported(privateKey, .sign, secAlgorithm) else {
            throw MuhrError.unsupportedAlgorithm(algorithm: algorithm.rawValue)
        }

        // Imzolash
        var error: Unmanaged<CFError>?
        guard
            let signatureData = SecKeyCreateSignature(
                privateKey,
                secAlgorithm,
                data as CFData,
                &error
            ) as Data?
        else {
            let errorMessage =
                error?.takeRetainedValue().localizedDescription
                ?? "Unknown error"
            throw MuhrError.signingFailed(reason: errorMessage)
        }

        // Hash hisoblash
        let dataHash = hash(data: data, using: algorithm.hashAlgorithm)

        // Natija
        return SignatureResult(
            signature: signatureData,
            dataHash: dataHash,
            timestamp: Date(),
            certificate: certificate,
            algorithm: algorithm
        )
    }

    /// Sync tekshirish
    private func verifySync(
        signature: Data,
        originalData: Data,
        publicKey: SecKey,
        certificate: CertificateInfo
    ) -> VerificationResult {

        let algorithm = certificate.algorithm
        let secAlgorithm = algorithm.secKeyAlgorithm

        // Algoritmni qo'llab-quvvatlashini tekshirish
        guard SecKeyIsAlgorithmSupported(publicKey, .verify, secAlgorithm)
        else {
            return VerificationResult.failure(
                errors: [.unsupportedAlgorithm(algorithm.rawValue)]
            )
        }

        // Tekshirish
        var error: Unmanaged<CFError>?
        let isValid = SecKeyVerifySignature(
            publicKey,
            secAlgorithm,
            originalData as CFData,
            signature as CFData,
            &error
        )

        // Natija
        if isValid {
            // Sertifikat validatsiyasi
            var warnings: [String] = []

            if certificate.isExpired {
                warnings.append(
                    "Sertifikat muddati tugagan, lekin imzo matematik jihatdan to'g'ri"
                )
            } else if certificate.daysUntilExpiry <= 30 {
                warnings.append(
                    "Sertifikat muddati \(certificate.daysUntilExpiry) kundan keyin tugaydi"
                )
            }

            return VerificationResult(
                isSignatureValid: true,
                isCertificateValid: certificate.isValid,
                isCertificateChainValid: true,
                isCertificateNotRevoked: true,
                signerCertificate: certificate,
                signedAt: Date(),
                errors: [],
                warnings: warnings
            )
        } else {
            return VerificationResult.failure(
                errors: [.invalidSignature],
                signerCertificate: certificate
            )
        }
    }
}

// MARK: - Convenience Extensions
extension KeychainSigningRepository {

    /// String imzolash
    public func sign(
        string: String,
        encoding: String.Encoding = .utf8,
        with certificate: CertificateInfo? = nil
    ) async throws -> SignatureResult {

        guard let data = string.data(using: encoding) else {
            throw MuhrError.signingFailed(
                reason: "String to Data conversion failed"
            )
        }

        return try await sign(data: data, with: certificate)
    }

    /// JSON imzolash
    public func sign(
        json: [String: Any],
        with certificate: CertificateInfo? = nil
    ) async throws -> SignatureResult {

        let data = try JSONSerialization.data(
            withJSONObject: json,
            options: [.sortedKeys]
        )

        return try await sign(data: data, with: certificate)
    }

    /// Encodable imzolash
    public func sign<T: Encodable>(
        object: T,
        with certificate: CertificateInfo? = nil
    ) async throws -> SignatureResult {

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]

        let data = try encoder.encode(object)

        return try await sign(data: data, with: certificate)
    }
}
