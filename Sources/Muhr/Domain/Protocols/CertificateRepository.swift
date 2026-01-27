//
//  CertificateRepository.swift
//  Muhr
//
//  Created by Muhammad on 27/01/26.
//

import Foundation

// MARK: - Certificate Repository Protocol
/// Sertifikatlar bilan ishlash uchun repository protokoli
///
/// Sertifikatlarni o'rnatish, o'qish, o'chirish va boshqarish
/// operatsiyalari uchun abstraktsiya.
///
/// ## Clean Architecture:
/// ```
/// UseCase ──▶ CertificateRepository (Protocol) ◀── KeychainCertificateRepository
///                                               ◀── FileCertificateRepository
/// ```
///
/// ## Operatsiyalar:
/// - **CRUD**: Create, Read, Update, Delete
/// - **Import**: PKCS#12 (.p12/.pfx) fayldan import
/// - **Export**: Sertifikatni eksport qilish
/// - **Validation**: Sertifikat validligini tekshirish
///
/// ## Foydalanish:
/// ```swift
/// class LoadCertificatesUseCase {
///     private let repository: CertificateRepository
///
///     func execute() async throws -> [CertificateInfo] {
///         return try await repository.getAllCertificates()
///     }
/// }
/// ```
public protocol CertificateRepository: Sendable {

    // MARK: - Read Operations

    /// Barcha sertifikatlarni olish
    ///
    /// Keychain'dagi barcha mavjud sertifikatlarni qaytaradi.
    /// - Returns: Sertifikatlar ro'yxati
    /// - Throws: `MuhrError.keychainReadFailed`
    func getAllCertificates() async throws -> [CertificateInfo]

    /// ID bo'yicha sertifikat olish
    ///
    /// - Parameter id: Sertifikat ID'si (serial number)
    /// - Returns: Sertifikat yoki nil
    /// - Throws: `MuhrError.keychainReadFailed`
    func getCertificate(by id: String) async throws -> CertificateInfo?

    /// Default sertifikatni olish
    ///
    /// Oldin `setDefaultCertificate()` bilan belgilangan sertifikat.
    /// - Returns: Default sertifikat yoki nil
    func getDefaultCertificate() async throws -> CertificateInfo?

    // MARK: - Import Operations

    /// PKCS#12 fayldan sertifikat import qilish
    ///
    /// .p12 yoki .pfx fayl formatidan sertifikat va private key'ni
    /// Keychain'ga import qiladi.
    ///
    /// ## PKCS#12 Format (RFC 7292):
    /// ```
    /// PFX ::= SEQUENCE {
    ///     version    INTEGER,
    ///     authSafe   ContentInfo,
    ///     macData    MacData OPTIONAL
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - data: PKCS#12 format ma'lumot
    ///   - password: Fayl paroli
    /// - Returns: Import qilingan sertifikat
    /// - Throws: `MuhrError.invalidCertificatePassword`, `MuhrError.invalidCertificateFormat`
    func importPKCS12(data: Data, password: String) async throws
        -> CertificateInfo

    /// Fayldan sertifikat import qilish
    ///
    /// - Parameters:
    ///   - fileURL: .p12 yoki .pfx fayl manzili
    ///   - password: Fayl paroli
    /// - Returns: Import qilingan sertifikat
    /// - Throws: `MuhrError.fileNotFound`, `MuhrError.invalidCertificatePassword`
    func importFromFile(at fileURL: URL, password: String) async throws
        -> CertificateInfo

    // MARK: - Delete Operations

    /// Sertifikatni o'chirish
    ///
    /// Keychain'dan sertifikat va unga bog'liq private key'ni o'chiradi.
    ///
    /// - Parameter certificate: O'chiriladigan sertifikat
    /// - Throws: `MuhrError.keychainDeleteFailed`
    func deleteCertificate(_ certificate: CertificateInfo) async throws

    /// ID bo'yicha sertifikatni o'chirish
    ///
    /// - Parameter id: Sertifikat ID'si
    /// - Throws: `MuhrError.certificateNotFound`, `MuhrError.keychainDeleteFailed`
    func deleteCertificate(by id: String) async throws

    /// Barcha sertifikatlarni o'chirish
    ///
    /// ⚠️ Ehtiyot bo'ling! Bu operatsiya qaytarilmas.
    /// - Throws: `MuhrError.keychainDeleteFailed`
    func deleteAllCertificates() async throws

    // MARK: - Default Certificate

    /// Default sertifikatni belgilash
    ///
    /// Imzolashda certificate ko'rsatilmasa, shu ishlatiladi.
    /// - Parameter certificate: Default sertifikat
    func setDefaultCertificate(_ certificate: CertificateInfo) async throws

    /// Default sertifikatni tozalash
    func clearDefaultCertificate() async throws

    // MARK: - Validation

    /// Sertifikat validligini tekshirish
    ///
    /// - Muddati tugamaganmi
    /// - Hali kuchga kirganmi
    /// - Bekor qilinmaganmi (agar OCSP/CRL mavjud bo'lsa)
    ///
    /// - Parameter certificate: Tekshiriladigan sertifikat
    /// - Returns: Tekshirish natijasi
    func validateCertificate(_ certificate: CertificateInfo) async throws
        -> CertificateValidationResult

    // MARK: - Search

    /// Sertifikatlarni qidirish
    ///
    /// - Parameter query: Qidiruv so'rovi (CN, Organization, PINFL, STIR)
    /// - Returns: Mos sertifikatlar
    func searchCertificates(query: String) async throws -> [CertificateInfo]

    /// Amal qilayotgan sertifikatlarni olish
    ///
    /// Faqat hozir valid bo'lgan sertifikatlar.
    /// - Returns: Valid sertifikatlar
    func getValidCertificates() async throws -> [CertificateInfo]
}

// MARK: - Certificate Validation Result
/// Sertifikat validatsiya natijasi
public struct CertificateValidationResult: Sendable {

    /// Sertifikat validmi?
    public let isValid: Bool

    /// Muddati tugamaganmi?
    public let isNotExpired: Bool

    /// Kuchga kirganmi?
    public let isActivated: Bool

    /// Bekor qilinmaganmi?
    public let isNotRevoked: Bool

    /// Zanjir to'g'rimi?
    public let isChainValid: Bool

    /// Xatolar
    public let errors: [MuhrError]

    /// Ogohlantirishlar (masalan: 30 kundan kam qolgan)
    public let warnings: [String]

    // MARK: - Initializer
    public init(
        isValid: Bool,
        isNotExpired: Bool,
        isActivated: Bool,
        isNotRevoked: Bool,
        isChainValid: Bool,
        errors: [MuhrError] = [],
        warnings: [String] = []
    ) {
        self.isValid = isValid
        self.isNotExpired = isNotExpired
        self.isActivated = isActivated
        self.isNotRevoked = isNotRevoked
        self.isChainValid = isChainValid
        self.errors = errors
        self.warnings = warnings
    }

    // MARK: - Factory Methods

    /// Muvaffaqiyatli natija
    public static func valid(warnings: [String] = [])
        -> CertificateValidationResult
    {
        CertificateValidationResult(
            isValid: true,
            isNotExpired: true,
            isActivated: true,
            isNotRevoked: true,
            isChainValid: true,
            errors: [],
            warnings: warnings
        )
    }

    /// Muvaffaqiyatsiz natija
    public static func invalid(errors: [MuhrError])
        -> CertificateValidationResult
    {
        CertificateValidationResult(
            isValid: false,
            isNotExpired: false,
            isActivated: false,
            isNotRevoked: false,
            isChainValid: false,
            errors: errors,
            warnings: []
        )
    }
}

// MARK: - Default Implementations
extension CertificateRepository {

    /// Qidiruv - default empty implementation
    public func searchCertificates(query: String) async throws
        -> [CertificateInfo]
    {
        let all = try await getAllCertificates()
        let lowercasedQuery = query.lowercased()

        return all.filter { cert in
            cert.commonName.lowercased().contains(lowercasedQuery)
                || cert.organization?.lowercased().contains(lowercasedQuery)
                    == true
                || cert.pinfl?.contains(query) == true
                || cert.stir?.contains(query) == true
                || cert.serialNumber.lowercased().contains(lowercasedQuery)
        }
    }

    /// Valid sertifikatlar - default implementation
    public func getValidCertificates() async throws -> [CertificateInfo] {
        let all = try await getAllCertificates()
        return all.filter { $0.isValid }
    }
}
