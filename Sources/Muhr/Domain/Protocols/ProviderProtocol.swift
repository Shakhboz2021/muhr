//
//  ProviderProtocol.swift
//  Muhr
//
//  Created by Muhammad on 27/01/26.
//

import Foundation

// MARK: - Provider Type
/// Qo'llab-quvvatlanadigan provider turlari
public enum ProviderType: String, CaseIterable, Codable, Sendable {

    /// Styx - Lokal sertifikat bilan imzolash
    ///
    /// Keychain'da saqlangan sertifikat va private key ishlatiladi.
    /// Hech qanday tashqi xizmat talab qilinmaydi.
    case styx = "styx"

    /// Metin - O'zbekiston ERI/ЭЦП
    ///
    /// MetinSDK orqali imzolash. SMS tasdiqlash talab qilinadi.
    /// Tashqi server bilan bog'lanish kerak.
    case metin = "metin"

    /// E-IMZO - Davlat xizmatlari
    ///
    /// Davlat xizmatlari uchun raqamli imzo.
    /// Kelajakda qo'shiladi.
    case eImzo = "eImzo"

    /// Foydalanuvchiga ko'rsatiladigan nom
    public var displayName: String {
        switch self {
        case .styx:
            return "Lokal sertifikat"
        case .metin:
            return "Metin ERI"
        case .eImzo:
            return "E-IMZO"
        }
    }

    /// Provider tavsifi
    public var description: String {
        switch self {
        case .styx:
            return "Qurilmaga o'rnatilgan sertifikat orqali imzolash"
        case .metin:
            return "O'zbekiston elektron raqamli imzo tizimi (SMS tasdiqlash)"
        case .eImzo:
            return "Davlat xizmatlari uchun raqamli imzo"
        }
    }

    /// Tashqi tarmoq talab qiladimi?
    public var requiresNetwork: Bool {
        switch self {
        case .styx:
            return false
        case .metin, .eImzo:
            return true
        }
    }

    /// UI talab qiladimi? (SMS dialog, PIN kiritish va h.k.)
    public var requiresUI: Bool {
        switch self {
        case .styx:
            return false  // Faqat biometric/PIN so'ralishi mumkin
        case .metin:
            return true  // SMS tasdiqlash UI kerak
        case .eImzo:
            return true
        }
    }
}

// MARK: - Provider Protocol
/// Imzolash provider protokoli
///
/// Har bir provider (Styx, Metin, E-IMZO) shu protokolni implement qiladi.
///
/// ## Clean Architecture:
/// ```
/// Domain Layer:
///   UseCase ──▶ ProviderProtocol (abstraction)
///
/// Data Layer:
///   StyxProvider ──────────────┐
///   MetinProvider ─────────────┼──▶ implements ProviderProtocol
///   eImzoProvider ─────────────┘
/// ```
///
/// ## Provider Lifecycle:
/// ```
/// 1. initialize()     - Providerni ishga tushirish
/// 2. loadCertificates() - Sertifikatlarni yuklash
/// 3. sign()/verify()  - Operatsiyalar
/// 4. shutdown()       - Providerni to'xtatish
/// ```
///
/// ## Foydalanish:
/// ```swift
/// let provider: ProviderProtocol = StyxProvider()
/// try await provider.initialize()
///
/// let certificates = try await provider.loadCertificates()
/// let signature = try await provider.sign(data: document, with: certificates[0])
/// ```
public protocol ProviderProtocol: AnyObject, Sendable {

    // MARK: - Properties

    /// Provider turi
    var type: ProviderType { get }

    /// Provider tayyor holatdami?
    var isInitialized: Bool { get }

    /// Mavjud sertifikatlar
    var availableCertificates: [CertificateInfo] { get }

    // MARK: - Lifecycle

    /// Providerni ishga tushirish
    ///
    /// Kerakli resurslarni yuklash, SDK'ni boshlash va h.k.
    /// - Throws: `MuhrError.providerConfigurationError`
    func initialize() async throws

    /// Providerni to'xtatish
    ///
    /// Resurslarni tozalash, ulanishlarni yopish.
    func shutdown() async

    // MARK: - Authentication (Provider-specific)

    /// Provider uchun autentifikatsiya talab qiladimi?
    var requiresAuthentication: Bool { get }

    /// Autentifikatsiya bilan imzolash
    ///
    /// - Parameters:
    ///   - data: Imzolanadigan ma'lumot
    ///   - certificate: Sertifikat
    ///   - credential: Provider-specific credential (Styx: password, Metin: SMS code)
    /// - Returns: Imzolash natijasi
    func sign(
        data: Data,
        with certificate: CertificateInfo,
        credential: String
    ) async throws -> SignatureResult

    /// Password tekshirish (login uchun)
    ///
    /// - Parameter key: login+password kombinatsiyasi yoki faqat password
    /// - Returns: true = to'g'ri
    func verifyPassword(_ key: String) async throws -> Bool

    // MARK: - Certificate Operations

    /// Sertifikatlarni yuklash
    ///
    /// Provider'ga tegishli barcha sertifikatlarni qaytaradi.
    /// - Returns: Sertifikatlar ro'yxati
    /// - Throws: `MuhrError`
    func loadCertificates() async throws -> [CertificateInfo]

    /// Sertifikat import qilish
    ///
    /// - Parameters:
    ///   - data: PKCS#12 data
    ///   - password: Parol
    /// - Returns: Import qilingan sertifikat
    /// - Throws: `MuhrError.invalidCertificatePassword`
    func importCertificate(data: Data, password: String, login: String) async throws
        -> CertificateInfo

    /// Sertifikatni o'chirish
    ///
    /// - Parameter certificate: O'chiriladigan sertifikat
    /// - Throws: `MuhrError`
    func deleteCertificate(_ certificate: CertificateInfo) async throws

    // MARK: - Signing Operations

    /// Ma'lumotni imzolash
    ///
    /// - Parameters:
    ///   - data: Imzolanadigan ma'lumot
    ///   - certificate: Imzolash uchun sertifikat
    /// - Returns: Imzolash natijasi
    /// - Throws: `MuhrError.signingFailed`
    func sign(data: Data, with certificate: CertificateInfo) async throws
        -> SignatureResult

    /// Imzoni tekshirish
    ///
    /// - Parameters:
    ///   - signature: Imzo
    ///   - originalData: Original ma'lumot
    ///   - certificate: Sertifikat (optional)
    /// - Returns: Tekshirish natijasi
    /// - Throws: `MuhrError.verificationFailed`
    func verify(
        signature: Data,
        originalData: Data,
        certificate: CertificateInfo?
    ) async throws -> VerificationResult

    // MARK: - Provider-Specific

    /// Provider konfiguratsiyasi
    ///
    /// Har bir provider o'ziga xos sozlamalarni qaytaradi.
    var configuration: ProviderConfiguration { get }

    /// Konfiguratsiyani yangilash
    ///
    /// - Parameter configuration: Yangi konfiguratsiya
    func updateConfiguration(_ configuration: ProviderConfiguration)
        async throws
}

extension ProviderProtocol {
    /// Default: autentifikatsiya talab qilmaydi
    public var requiresAuthentication: Bool { false }

    /// Default: credential'siz imzolash
    public func sign(
        data: Data,
        with certificate: CertificateInfo,
        credential: String
    ) async throws -> SignatureResult {
        // Default - credential'ni ignore qilish
        return try await sign(data: data, with: certificate)
    }

    /// Default: har doim true
    public func verifyPassword(_ key: String) async throws -> Bool {
        return true
    }
}

// MARK: - Provider Configuration
/// Provider konfiguratsiyasi
///
/// Har bir provider o'ziga xos sozlamalarga ega.
public struct ProviderConfiguration: Sendable {

    /// Provider turi
    public let type: ProviderType

    /// Timeout (sekundlarda)
    public var timeout: TimeInterval

    /// Auto-retry soni
    public var retryCount: Int

    /// Debug mode
    public var isDebugEnabled: Bool

    /// Qo'shimcha parametrlar
    public var additionalParameters: [String: String]

    // MARK: - Initializer

    public init(
        type: ProviderType,
        timeout: TimeInterval = 30,
        retryCount: Int = 3,
        isDebugEnabled: Bool = false,
        additionalParameters: [String: String] = [:]
    ) {
        self.type = type
        self.timeout = timeout
        self.retryCount = retryCount
        self.isDebugEnabled = isDebugEnabled
        self.additionalParameters = additionalParameters
    }

    // MARK: - Factory Methods

    /// Styx uchun default konfiguratsiya
    public static var styx: ProviderConfiguration {
        ProviderConfiguration(
            type: .styx,
            timeout: 10,
            retryCount: 1,
            isDebugEnabled: false
        )
    }

    /// Metin uchun default konfiguratsiya
    public static var metin: ProviderConfiguration {
        ProviderConfiguration(
            type: .metin,
            timeout: 60,  // SMS kutish uchun ko'proq vaqt
            retryCount: 3,
            isDebugEnabled: false,
            additionalParameters: [
                "sms_timeout": "120",
                "api_version": "v1",
            ]
        )
    }
}

// MARK: - Provider State
/// Provider holati
public enum ProviderState: Sendable {
    /// Ishga tushirilmagan
    case notInitialized

    /// Ishga tushirilmoqda
    case initializing

    /// Tayyor
    case ready

    /// Xato
    case error(MuhrError)

    /// To'xtatilgan
    case shutdown
}

// MARK: - Provider Delegate
/// Provider hodisalarini kuzatish uchun delegate
///
/// UI bilan integratsiya uchun ishlatiladi (masalan: SMS dialog ko'rsatish).
public protocol ProviderDelegate: AnyObject, Sendable {

    /// Provider holati o'zgarganda
    func providerDidChangeState(
        _ provider: ProviderProtocol,
        state: ProviderState
    )

    /// Sertifikatlar yangilanganda
    func providerDidUpdateCertificates(
        _ provider: ProviderProtocol,
        certificates: [CertificateInfo]
    )

    /// PIN/Parol so'ralganda
    ///
    /// - Parameter completion: PIN kiritilganda chaqiriladi
    func providerRequiresPin(
        _ provider: ProviderProtocol,
        completion: @escaping (String?) -> Void
    )

    /// SMS kod so'ralganda (Metin uchun)
    ///
    /// - Parameters:
    ///   - phoneNumber: SMS yuborilgan raqam
    ///   - completion: Kod kiritilganda chaqiriladi
    func providerRequiresSMSCode(
        _ provider: ProviderProtocol,
        phoneNumber: String,
        completion: @escaping (String?) -> Void
    )

    /// Xato yuz berganda
    func providerDidEncounterError(
        _ provider: ProviderProtocol,
        error: MuhrError
    )
}

// MARK: - Default Delegate Implementation
extension ProviderDelegate {

    public func providerDidChangeState(
        _ provider: ProviderProtocol,
        state: ProviderState
    ) {}
    public func providerDidUpdateCertificates(
        _ provider: ProviderProtocol,
        certificates: [CertificateInfo]
    ) {}
    public func providerRequiresPin(
        _ provider: ProviderProtocol,
        completion: @escaping (String?) -> Void
    ) {
        completion(nil)
    }
    public func providerRequiresSMSCode(
        _ provider: ProviderProtocol,
        phoneNumber: String,
        completion: @escaping (String?) -> Void
    ) {
        completion(nil)
    }
    public func providerDidEncounterError(
        _ provider: ProviderProtocol,
        error: MuhrError
    ) {}
}
