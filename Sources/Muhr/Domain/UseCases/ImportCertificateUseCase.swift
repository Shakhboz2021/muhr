//
//  ImportCertificateUseCase.swift
//  Muhr
//
//  Created by Muhammad on 27/01/26.
//

import Foundation

// MARK: - Import Certificate Use Case
/// Sertifikat import qilish uchun UseCase
///
/// PKCS#12 (.p12/.pfx) fayldan sertifikat va private key'ni
/// Keychain'ga import qiladi.
///
/// ## PKCS#12 Format (RFC 7292):
/// ```
/// PFX ::= SEQUENCE {
///     version     INTEGER {v3(3)},
///     authSafe    ContentInfo,
///     macData     MacData OPTIONAL
/// }
/// ```
///
/// ## Import Jarayoni:
/// 1. Fayl formatini tekshirish (magic bytes)
/// 2. Parolni tekshirish
/// 3. Sertifikat va private key'ni ajratish
/// 4. Keychain'ga saqlash
/// 5. Natijani qaytarish
///
/// ## Foydalanish:
/// ```swift
/// let useCase = ImportCertificateUseCase(repository: repository)
///
/// // Fayldan import
/// let cert = try await useCase.execute(
///     fileURL: p12FileURL,
///     password: "secret123"
/// )
///
/// // Data'dan import
/// let cert = try await useCase.execute(
///     data: p12Data,
///     password: "secret123"
/// )
/// ```
public final class ImportCertificateUseCase: Sendable {

    // MARK: - Dependencies

    private let certificateRepository: CertificateRepository

    // MARK: - Constants

    /// PKCS#12 magic bytes (ZIP format, chunki PFX ZIP ichida)
    /// Lekin aslida bu sequence tag bo'ladi: 0x30 (SEQUENCE)
    private static let pkcs12MagicByte: UInt8 = 0x30

    /// Minimal fayl hajmi (baytlarda)
    private static let minFileSize = 100

    /// Maksimal fayl hajmi (10 MB)
    private static let maxFileSize = 10 * 1024 * 1024

    // MARK: - Initializer

    /// UseCase yaratish
    ///
    /// - Parameter certificateRepository: Sertifikat repository
    public init(certificateRepository: CertificateRepository) {
        self.certificateRepository = certificateRepository
    }

    // MARK: - Execute from File

    /// Fayldan sertifikat import qilish
    ///
    /// - Parameters:
    ///   - fileURL: .p12 yoki .pfx fayl manzili
    ///   - password: Fayl paroli
    ///   - setAsDefault: Import qilingan sertifikatni default qilish
    /// - Returns: Import qilingan sertifikat
    /// - Throws: `MuhrError`
    public func execute(
        fileURL: URL,
        password: String,
        setAsDefault: Bool = false
    ) async throws -> CertificateInfo {

        // 1. Fayl mavjudligini tekshirish
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw MuhrError.fileNotFound(path: fileURL.path)
        }

        // 2. Fayl kengaytmasini tekshirish
        let fileExtension = fileURL.pathExtension.lowercased()
        guard fileExtension == "p12" || fileExtension == "pfx" else {
            throw MuhrError.unsupportedFileType(fileExtension: fileExtension)
        }

        // 3. Faylni o'qish
        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch {
            throw MuhrError.fileReadError(reason: error.localizedDescription)
        }

        // 4. Data bilan import qilish
        return try await execute(
            data: data,
            password: password,
            setAsDefault: setAsDefault
        )
    }

    // MARK: - Execute from Data

    /// Data'dan sertifikat import qilish
    ///
    /// - Parameters:
    ///   - data: PKCS#12 format ma'lumot
    ///   - password: Parol
    ///   - setAsDefault: Import qilingan sertifikatni default qilish
    /// - Returns: Import qilingan sertifikat
    /// - Throws: `MuhrError`
    public func execute(
        data: Data,
        password: String,
        setAsDefault: Bool = false
    ) async throws -> CertificateInfo {

        // 1. Ma'lumot hajmini tekshirish
        try validateDataSize(data)

        // 2. Format validatsiyasi
        try validatePKCS12Format(data)

        // 3. Parol validatsiyasi
        try validatePassword(password)

        // 4. Repository orqali import qilish
        let certificate = try await certificateRepository.importPKCS12(
            data: data,
            password: password
        )

        // 5. Default qilish (agar so'ralgan bo'lsa)
        if setAsDefault {
            try await certificateRepository.setDefaultCertificate(certificate)
        }

        return certificate
    }

    // MARK: - Execute from Base64

    /// Base64 string'dan sertifikat import qilish
    ///
    /// Server'dan olingan sertifikat uchun qulay.
    ///
    /// - Parameters:
    ///   - base64String: Base64 formatda PKCS#12 ma'lumot
    ///   - password: Parol
    ///   - setAsDefault: Import qilingan sertifikatni default qilish
    /// - Returns: Import qilingan sertifikat
    /// - Throws: `MuhrError`
    public func execute(
        base64String: String,
        password: String,
        setAsDefault: Bool = false
    ) async throws -> CertificateInfo {

        guard let data = Data(base64Encoded: base64String) else {
            throw MuhrError.invalidCertificateFormat
        }

        return try await execute(
            data: data,
            password: password,
            setAsDefault: setAsDefault
        )
    }

    // MARK: - Private Validation Methods

    /// Ma'lumot hajmini tekshirish
    private func validateDataSize(_ data: Data) throws {

        // Minimum hajm
        guard data.count >= Self.minFileSize else {
            throw MuhrError.invalidCertificateFormat
        }

        // Maximum hajm
        guard data.count <= Self.maxFileSize else {
            throw MuhrError.fileReadError(
                reason:
                    "Fayl hajmi juda katta (max: \(Self.maxFileSize / 1024 / 1024) MB)"
            )
        }
    }

    /// PKCS#12 format tekshirish
    private func validatePKCS12Format(_ data: Data) throws {

        // PKCS#12 ASN.1 SEQUENCE bilan boshlanadi (0x30)
        guard let firstByte = data.first,
            firstByte == Self.pkcs12MagicByte
        else {
            throw MuhrError.invalidCertificateFormat
        }

        // Qo'shimcha ASN.1 struktura tekshiruvi
        // SEQUENCE tag'dan keyin length byte keladi
        guard data.count > 2 else {
            throw MuhrError.invalidCertificateFormat
        }
    }

    /// Parol validatsiyasi
    private func validatePassword(_ password: String) throws {

        // Bo'sh parol ba'zi P12 fayllarda ruxsat etiladi,
        // lekin biz xavfsizlik uchun tekshiramiz
        //
        // Eslatma: Ba'zi test sertifikatlar bo'sh parol bilan keladi,
        // shuning uchun bu faqat warning bo'lishi mumkin

        // Hozircha bo'sh parolga ruxsat beramiz
        // Lekin real productionda bu o'zgartirilishi mumkin
    }
}

// MARK: - Import Options
/// Import opsiyalari
public struct ImportOptions: Sendable {

    /// Import qilingan sertifikatni default qilish
    public var setAsDefault: Bool

    /// Mavjud sertifikatni almashtirish (agar bir xil serial bo'lsa)
    public var replaceExisting: Bool

    /// Import'dan keyin validatsiya qilish
    public var validateAfterImport: Bool

    // MARK: - Initializer

    public init(
        setAsDefault: Bool = false,
        replaceExisting: Bool = false,
        validateAfterImport: Bool = true
    ) {
        self.setAsDefault = setAsDefault
        self.replaceExisting = replaceExisting
        self.validateAfterImport = validateAfterImport
    }

    // MARK: - Presets

    /// Default opsiyalar
    public static var `default`: ImportOptions {
        ImportOptions()
    }

    /// Birinchi sertifikat uchun
    public static var firstCertificate: ImportOptions {
        ImportOptions(setAsDefault: true)
    }

    /// Yangilash uchun
    public static var replacement: ImportOptions {
        ImportOptions(replaceExisting: true)
    }
}
