//
//  Muhr.swift
//  Muhr
//
//  Created by Muhammad on 27/01/26.
//

import Foundation

// MARK: - Muhr
/// Muhr - O'zbekistonda raqamli imzo kutubxonasi
///
/// Bu facade class kutubxonaning barcha funksiyalariga
/// oddiy va qulay kirish imkonini beradi.
///
/// ## Asosiy Imkoniyatlar:
/// - 🔐 Ma'lumotlarni imzolash
/// - ✅ Imzolarni tekshirish
/// - 📜 Sertifikatlarni boshqarish
/// - 📦 PKCS#12 import
///
/// ## Quick Start:
/// ```swift
/// import Muhr
///
/// // 1. Muhr'ni ishga tushirish
/// try await Muhr.initialize()
///
/// // 2. Sertifikat import qilish
/// let cert = try await Muhr.importCertificate(
///     fileURL: p12URL,
///     password: "secret"
/// )
///
/// // 3. Ma'lumotni imzolash
/// let result = try await Muhr.sign(data: document)
/// print(result.signatureBase64)
///
/// // 4. Imzoni tekshirish
/// let verification = try await Muhr.verify(
///     signature: result.signature,
///     originalData: document
/// )
/// print(verification.isValid) // true
/// ```
public enum Muhr {

    // MARK: - Version

    /// Kutubxona versiyasi
    public static let version = "1.0.0"

    /// Build raqami
    public static let build = 1

    // MARK: - Shared Instance
    /// Shared manager instance
    private static var _shared: MuhrManager?

    /// Shared manager (lazy initialization)
    private static var shared: MuhrManager {
        get throws {
            guard let manager = _shared else {
                throw MuhrError.providerNotInitialized
            }
            return manager
        }
    }

    // MARK: - Initialization

    /// Muhr'ni ishga tushirish
    ///
    /// Bu metod boshqa metodlardan oldin chaqirilishi shart.
    ///
    /// - Parameter providerType: Provider turi (default: .styx)
    /// - Throws: `MuhrError.providerConfigurationError`
    ///
    /// ## Misol:
    /// ```swift
    /// // AppDelegate yoki App init'da
    /// try await Muhr.initialize()
    /// ```
    public static func initialize(provider providerType: ProviderType = .styx)
        async throws
    {
        let manager = MuhrManager()
        try await manager.initialize(provider: providerType)
        _shared = manager
    }

    /// Muhr ishga tushirilganmi?
    public static var isInitialized: Bool {
        _shared?.isInitialized ?? false
    }

    /// Muhr'ni to'xtatish
    public static func shutdown() async {
        await _shared?.shutdown()
        _shared = nil
    }

    // MARK: - Certificates

    /// Barcha sertifikatlarni olish
    ///
    /// - Returns: Sertifikatlar ro'yxati
    /// - Throws: `MuhrError`
    ///
    /// ## Misol:
    /// ```swift
    /// let certs = try await Muhr.getCertificates()
    /// for cert in certs {
    ///     print(cert.commonName)
    /// }
    /// ```
    public static func getCertificates() async throws -> [CertificateInfo] {
        return try await shared.getCertificates()
    }

    /// Faqat valid sertifikatlarni olish
    public static func getValidCertificates() async throws -> [CertificateInfo]
    {
        return try await shared.getValidCertificates()
    }

    /// Imzolash mumkin bo'lgan sertifikatlarni olish
    public static func getSigningCertificates() async throws
        -> [CertificateInfo]
    {
        return try await shared.getSigningCertificates()
    }

    /// Sertifikat import qilish (fayldan)
    ///
    /// - Parameters:
    ///   - fileURL: .p12 yoki .pfx fayl manzili
    ///   - password: Fayl paroli
    ///   - setAsDefault: Default sertifikat qilish
    /// - Returns: Import qilingan sertifikat
    /// - Throws: `MuhrError`
    ///
    /// ## Misol:
    /// ```swift
    /// let cert = try await Muhr.importCertificate(
    ///     fileURL: url,
    ///     password: "123456"
    /// )
    /// ```
    public static func importCertificate(
        fileURL: URL,
        password: String,
        setAsDefault: Bool = true
    ) async throws -> CertificateInfo {
        return try await shared.importCertificate(
            fileURL: fileURL,
            password: password,
            setAsDefault: setAsDefault
        )
    }

    /// Sertifikat import qilish (Data'dan)
    public static func importCertificate(
        data: Data,
        password: String,
        setAsDefault: Bool = true
    ) async throws -> CertificateInfo {
        return try await shared.importCertificate(
            data: data,
            password: password,
            setAsDefault: setAsDefault
        )
    }

    /// Sertifikatni o'chirish
    public static func deleteCertificate(_ certificate: CertificateInfo)
        async throws
    {
        try await shared.deleteCertificate(certificate)
    }

    /// Default sertifikatni olish
    public static func getDefaultCertificate() async throws -> CertificateInfo?
    {
        return try await shared.getDefaultCertificate()
    }

    /// Default sertifikatni belgilash
    public static func setDefaultCertificate(_ certificate: CertificateInfo)
        async throws
    {
        try await shared.setDefaultCertificate(certificate)
    }

    // MARK: - Signing

    /// Ma'lumotni imzolash
    ///
    /// - Parameters:
    ///   - data: Imzolanadigan ma'lumot
    ///   - certificate: Sertifikat (nil bo'lsa default ishlatiladi)
    /// - Returns: Imzolash natijasi
    /// - Throws: `MuhrError`
    ///
    /// ## Misol:
    /// ```swift
    /// let document = "Hello, World!".data(using: .utf8)!
    /// let result = try await Muhr.sign(data: document)
    /// print(result.signatureBase64)
    /// ```
    public static func sign(
        data: Data,
        certificate: CertificateInfo? = nil
    ) async throws -> SignatureResult {
        return try await shared.sign(data: data, certificate: certificate)
    }

    /// String imzolash
    ///
    /// ## Misol:
    /// ```swift
    /// let result = try await Muhr.sign(string: "Hello, World!")
    /// ```
    public static func sign(
        string: String,
        encoding: String.Encoding = .utf8,
        certificate: CertificateInfo? = nil
    ) async throws -> SignatureResult {
        guard let data = string.data(using: encoding) else {
            throw MuhrError.signingFailed(reason: "String encoding failed")
        }
        return try await sign(data: data, certificate: certificate)
    }

    /// JSON imzolash
    ///
    /// ## Misol:
    /// ```swift
    /// let payload = ["action": "transfer", "amount": "1000"]
    /// let result = try await Muhr.sign(json: payload)
    /// ```
    public static func sign(
        json: [String: Any],
        certificate: CertificateInfo? = nil
    ) async throws -> SignatureResult {
        let data = try JSONSerialization.data(
            withJSONObject: json,
            options: [.sortedKeys]
        )
        return try await sign(data: data, certificate: certificate)
    }

    /// Encodable ob'ekt imzolash
    ///
    /// ## Misol:
    /// ```swift
    /// struct Payment: Encodable {
    ///     let id: String
    ///     let amount: Decimal
    /// }
    /// let payment = Payment(id: "123", amount: 1000)
    /// let result = try await Muhr.sign(object: payment)
    /// ```
    public static func sign<T: Encodable>(
        object: T,
        certificate: CertificateInfo? = nil
    ) async throws -> SignatureResult {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(object)
        return try await sign(data: data, certificate: certificate)
    }

    /// Fayl imzolash
    ///
    /// ## Misol:
    /// ```swift
    /// let result = try await Muhr.sign(fileURL: documentURL)
    /// ```
    public static func sign(
        fileURL: URL,
        certificate: CertificateInfo? = nil
    ) async throws -> SignatureResult {
        let data = try Data(contentsOf: fileURL)
        return try await sign(data: data, certificate: certificate)
    }

    // MARK: - Verification

    /// Imzoni tekshirish
    ///
    /// - Parameters:
    ///   - signature: Imzo (raw bytes)
    ///   - originalData: Original ma'lumot
    ///   - certificate: Sertifikat (optional)
    /// - Returns: Tekshirish natijasi
    /// - Throws: `MuhrError`
    ///
    /// ## Misol:
    /// ```swift
    /// let result = try await Muhr.verify(
    ///     signature: signatureData,
    ///     originalData: document
    /// )
    /// if result.isValid {
    ///     print("✅ Imzo haqiqiy")
    /// }
    /// ```
    public static func verify(
        signature: Data,
        originalData: Data,
        certificate: CertificateInfo? = nil
    ) async throws -> VerificationResult {
        return try await shared.verify(
            signature: signature,
            originalData: originalData,
            certificate: certificate
        )
    }

    /// Base64 imzoni tekshirish
    public static func verify(
        signatureBase64: String,
        originalData: Data,
        certificate: CertificateInfo? = nil
    ) async throws -> VerificationResult {
        guard let signatureData = Data(base64Encoded: signatureBase64) else {
            return VerificationResult.failure(errors: [.invalidSignature])
        }
        return try await verify(
            signature: signatureData,
            originalData: originalData,
            certificate: certificate
        )
    }

    /// SignatureResult bilan tekshirish
    public static func verify(
        signatureResult: SignatureResult,
        originalData: Data
    ) async throws -> VerificationResult {
        return try await verify(
            signature: signatureResult.signature,
            originalData: originalData,
            certificate: signatureResult.certificate
        )
    }
}

// MARK: - Muhr Manager (Internal)
/// Ichki manager class
internal final class MuhrManager: @unchecked Sendable {

    // MARK: - Properties

    private(set) var isInitialized = false
    private var provider: ProviderProtocol?

    // UseCases
    private var signDataUseCase: SignDataUseCase?
    private var verifySignatureUseCase: VerifySignatureUseCase?
    private var importCertificateUseCase: ImportCertificateUseCase?
    private var getCertificatesUseCase: GetCertificatesUseCase?

    // MARK: - Initialization

    func initialize(provider providerType: ProviderType) async throws {

        // Provider yaratish
        let newProvider: ProviderProtocol

        switch providerType {
        case .styx:
            newProvider = StyxProvider()
        case .metin, .eimzo:
            throw MuhrError.providerNotSupported(
                providerName: providerType.displayName
            )
        }

        // Provider'ni ishga tushirish
        try await newProvider.initialize()

        // Repository'lar
        let certRepo = KeychainCertificateRepository()
        let signRepo = KeychainSigningRepository(
            certificateRepository: certRepo
        )

        // UseCase'lar
        signDataUseCase = SignDataUseCase(
            signingRepository: signRepo,
            certificateRepository: certRepo
        )
        verifySignatureUseCase = VerifySignatureUseCase(
            signingRepository: signRepo
        )
        importCertificateUseCase = ImportCertificateUseCase(
            certificateRepository: certRepo
        )
        getCertificatesUseCase = GetCertificatesUseCase(
            certificateRepository: certRepo
        )

        self.provider = newProvider
        self.isInitialized = true

        #if DEBUG
            print("✅ Muhr initialized with \(providerType.displayName)")
        #endif
    }

    func shutdown() async {
        await provider?.shutdown()
        provider = nil
        isInitialized = false

        #if DEBUG
            print("🔒 Muhr shutdown")
        #endif
    }

    // MARK: - Certificates

    func getCertificates() async throws -> [CertificateInfo] {
        guard let useCase = getCertificatesUseCase else {
            throw MuhrError.providerNotInitialized
        }
        return try await useCase.execute()
    }

    func getValidCertificates() async throws -> [CertificateInfo] {
        guard let useCase = getCertificatesUseCase else {
            throw MuhrError.providerNotInitialized
        }
        return try await useCase.execute(filter: .validOnly)
    }

    func getSigningCertificates() async throws -> [CertificateInfo] {
        guard let useCase = getCertificatesUseCase else {
            throw MuhrError.providerNotInitialized
        }
        return try await useCase.execute(filter: .canSign)
    }

    func importCertificate(
        fileURL: URL,
        password: String,
        setAsDefault: Bool
    ) async throws -> CertificateInfo {
        guard let useCase = importCertificateUseCase else {
            throw MuhrError.providerNotInitialized
        }
        return try await useCase.execute(
            fileURL: fileURL,
            password: password,
            setAsDefault: setAsDefault
        )
    }

    func importCertificate(
        data: Data,
        password: String,
        setAsDefault: Bool
    ) async throws -> CertificateInfo {
        guard let useCase = importCertificateUseCase else {
            throw MuhrError.providerNotInitialized
        }
        return try await useCase.execute(
            data: data,
            password: password,
            setAsDefault: setAsDefault
        )
    }

    func deleteCertificate(_ certificate: CertificateInfo) async throws {
        guard let provider = provider as? StyxProvider else {
            throw MuhrError.providerNotInitialized
        }
        try await provider.deleteCertificate(certificate)
    }

    func getDefaultCertificate() async throws -> CertificateInfo? {
        guard let provider = provider as? StyxProvider else {
            throw MuhrError.providerNotInitialized
        }
        return try await provider.getDefaultCertificate()
    }

    func setDefaultCertificate(_ certificate: CertificateInfo) async throws {
        guard let provider = provider as? StyxProvider else {
            throw MuhrError.providerNotInitialized
        }
        try await provider.setDefaultCertificate(certificate)
    }

    // MARK: - Signing

    func sign(data: Data, certificate: CertificateInfo?) async throws
        -> SignatureResult
    {
        guard let useCase = signDataUseCase else {
            throw MuhrError.providerNotInitialized
        }
        return try await useCase.execute(data: data, certificate: certificate)
    }

    // MARK: - Verification

    func verify(
        signature: Data,
        originalData: Data,
        certificate: CertificateInfo?
    ) async throws -> VerificationResult {
        guard let useCase = verifySignatureUseCase else {
            throw MuhrError.providerNotInitialized
        }
        return try await useCase.execute(
            signature: signature,
            originalData: originalData,
            certificate: certificate
        )
    }
}
