//
//  SigningRepository.swift
//  Muhr
//
//  Created by Muhammad on 27/01/26.
//

import Foundation

// MARK: - Signing Repository Protocol
/// Imzolash operatsiyalari uchun repository protokoli
///
/// Bu protokol Domain layer'da joylashgan va Data layer
/// tomonidan implement qilinadi.
///
/// ## Clean Architecture:
/// ```
/// UseCase ──▶ SigningRepository (Protocol) ◀── KeychainSigningRepository
///                                          ◀── StyxSigningRepository
///                                          ◀── MetinSigningRepository
/// ```
///
/// ## SOLID Principles:
/// - **D**ependency Inversion: Domain abstraksiyaga bog'liq, konkret implementatsiyaga emas
/// - **I**nterface Segregation: Faqat imzolash operatsiyalari
/// - **O**pen/Closed: Yangi provider qo'shish oson (yangi implementation)
///
/// ## Foydalanish:
/// ```swift
/// class SignDataUseCase {
///     private let repository: SigningRepository
///
///     init(repository: SigningRepository) {
///         self.repository = repository
///     }
///
///     func execute(data: Data) async throws -> SignatureResult {
///         return try await repository.sign(data: data)
///     }
/// }
/// ```
public protocol SigningRepository: Sendable {

    // MARK: - Signing Operations

    /// Ma'lumotni imzolash
    ///
    /// - Parameters:
    ///   - data: Imzolanadigan ma'lumot
    ///   - certificate: Imzolash uchun sertifikat (nil bo'lsa, default ishlatiladi)
    /// - Returns: Imzolash natijasi
    /// - Throws: `MuhrError` xatolik yuz berganda
    func sign(data: Data, with certificate: CertificateInfo?) async throws
        -> SignatureResult

    /// Faylni imzolash
    ///
    /// - Parameters:
    ///   - fileURL: Fayl manzili
    ///   - certificate: Imzolash uchun sertifikat (nil bo'lsa, default ishlatiladi)
    /// - Returns: Imzolash natijasi
    /// - Throws: `MuhrError` xatolik yuz berganda
    func signFile(at fileURL: URL, with certificate: CertificateInfo?)
        async throws -> SignatureResult

    // MARK: - Verification Operations

    /// Imzoni tekshirish
    ///
    /// - Parameters:
    ///   - signature: Tekshiriladigan imzo
    ///   - originalData: Original ma'lumot
    ///   - certificate: Tekshirish uchun sertifikat (nil bo'lsa, imzodan olinadi)
    /// - Returns: Tekshirish natijasi
    /// - Throws: `MuhrError` xatolik yuz berganda
    func verify(
        signature: Data,
        originalData: Data,
        certificate: CertificateInfo?
    ) async throws -> VerificationResult

    // MARK: - Hash Operations

    /// Ma'lumotni hash qilish
    ///
    /// - Parameters:
    ///   - data: Hash qilinadigan ma'lumot
    ///   - algorithm: Hash algoritmi
    /// - Returns: Hash qiymat
    func hash(data: Data, using algorithm: HashAlgorithm) -> Data
}

// MARK: - Default Implementations
extension SigningRepository {

    /// Default sertifikat bilan imzolash
    public func sign(data: Data) async throws -> SignatureResult {
        try await sign(data: data, with: nil)
    }

    /// Default sertifikat bilan fayl imzolash
    public func signFile(at fileURL: URL) async throws -> SignatureResult {
        try await signFile(at: fileURL, with: nil)
    }

    /// Default - imzodan sertifikat olish
    public func verify(signature: Data, originalData: Data) async throws
        -> VerificationResult
    {
        try await verify(
            signature: signature,
            originalData: originalData,
            certificate: nil
        )
    }

    /// Default SHA-256 hash
    public func hash(data: Data) -> Data {
        hash(data: data, using: .sha256)
    }
}
