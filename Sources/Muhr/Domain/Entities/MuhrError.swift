//
//  MuhrError.swift
//  Muhr
//
//  Created by Muhammad on 27/01/26.
//

import Foundation

// MARK: - Muhr Error
/// Muhr kutubxonasi xatoliklari
///
/// Barcha xatolar LocalizedError protokoliga mos keladi va
/// o'zbekcha xabarlarni qaytaradi.
///
/// ## Xato Kategoriyalari:
/// - **Certificate**: Sertifikat bilan bog'liq xatolar
/// - **Signing**: Imzolash jarayonidagi xatolar
/// - **Verification**: Tekshirish jarayonidagi xatolar
/// - **Keychain**: iOS Keychain bilan bog'liq xatolar
/// - **File**: Fayl operatsiyalari xatolari
/// - **Provider**: Provider (Styx/Metin) xatolari
/// - **Network**: Tarmoq xatolari (Metin/E-IMZO uchun)
///
/// ## Foydalanish:
/// ```swift
/// do {
///     let signature = try await muhr.sign(data: document)
/// } catch let error as MuhrError {
///     print(error.localizedDescription)  // O'zbekcha xabar
///     print(error.errorCode)             // Xato kodi
///     print(error.recoverySuggestion)    // Tavsiya
/// }
/// ```
public enum MuhrError: Error, Sendable {

    // MARK: - Certificate Errors (1xxx)

    /// Sertifikat topilmadi
    /// Keychain'da mos sertifikat yo'q
    case certificateNotFound

    /// Sertifikat muddati tugagan
    /// - Parameter expiryDate: Tugash sanasi
    case certificateExpired(expiryDate: Date)

    /// Sertifikat hali kuchga kirmagan
    /// - Parameter validFrom: Boshlanish sanasi
    case certificateNotYetValid(validFrom: Date)

    /// Sertifikat bekor qilingan
    /// - Parameter reason: Bekor qilish sababi
    case certificateRevoked(reason: RevocationReason)

    /// Sertifikat formati noto'g'ri
    /// DER/PEM parse qilishda xatolik
    case invalidCertificateFormat

    /// Sertifikat paroli noto'g'ri
    /// PKCS#12 (.p12/.pfx) fayl uchun
    case invalidCertificatePassword

    /// Sertifikat zanjiri noto'g'ri
    /// Root CA gacha tekshirishda xatolik
    case invalidCertificateChain

    // MARK: - Key Errors (2xxx)

    /// Maxfiy kalit topilmadi
    /// Sertifikat bor, lekin private key yo'q
    case privateKeyNotFound

    /// Maxfiy kalitga kirish rad etildi
    /// Keychain ACL yoki biometrik xatolik
    case privateKeyAccessDenied

    /// Kalit formati noto'g'ri
    case invalidKeyFormat

    // MARK: - Signing Errors (3xxx)

    /// Imzolash muvaffaqiyatsiz
    /// - Parameter reason: Xato sababi
    case signingFailed(reason: String)

    /// Imzolanadigan ma'lumot bo'sh
    case emptyDataToSign

    /// Algoritm qo'llab-quvvatlanmaydi
    /// - Parameter algorithm: Algoritm nomi
    case unsupportedAlgorithm(algorithm: String)

    // MARK: - Verification Errors (4xxx)

    /// Tekshirish muvaffaqiyatsiz
    /// - Parameter reason: Xato sababi
    case verificationFailed(reason: String)

    /// Imzo formati noto'g'ri
    case invalidSignatureFormat

    /// Ma'lumot o'zgartirilgan
    /// Hash qiymatlari mos kelmadi
    case dataModified

    // MARK: - Keychain Errors (5xxx)

    /// Keychain xatosi
    /// - Parameter status: OSStatus kodi
    case keychainError(status: OSStatus)

    /// Keychain'ga saqlash muvaffaqiyatsiz
    case keychainSaveFailed

    /// Keychain'dan o'qish muvaffaqiyatsiz
    case keychainReadFailed

    /// Keychain'dan o'chirish muvaffaqiyatsiz
    case keychainDeleteFailed

    // MARK: - File Errors (6xxx)

    /// Fayl topilmadi
    /// - Parameter path: Fayl yo'li
    case fileNotFound(path: String)

    /// Fayl o'qishda xato
    /// - Parameter reason: Xato sababi
    case fileReadError(reason: String)

    /// Fayl yozishda xato
    /// - Parameter reason: Xato sababi
    case fileWriteError(reason: String)

    /// Fayl turi qo'llab-quvvatlanmaydi
    /// - Parameter fileExtension: Fayl kengaytmasi
    case unsupportedFileType(fileExtension: String)

    /// Fayl formati noto'g'ri
    /// Magic bytes mos kelmadi
    case invalidFileFormat

    // MARK: - Provider Errors (7xxx)

    /// Provider ishga tushirilmagan
    case providerNotInitialized

    /// Provider qo'llab-quvvatlanmaydi
    /// - Parameter providerName: Provider nomi
    case providerNotSupported(providerName: String)

    /// Provider konfiguratsiya xatosi
    /// - Parameter reason: Xato sababi
    case providerConfigurationError(reason: String)

    // MARK: - Authentication Errors (8xxx)

    /// PIN kod talab qilinadi
    case pinRequired

    /// PIN kod noto'g'ri
    case invalidPin

    /// PIN kod bloklangan
    /// Ko'p marta noto'g'ri kiritilgan
    case pinBlocked

    /// Biometrik autentifikatsiya muvaffaqiyatsiz
    case biometricAuthFailed

    /// Foydalanuvchi bekor qildi
    case userCancelled

    // MARK: - Network Errors (9xxx)

    /// Tarmoq xatosi
    /// - Parameter reason: Xato sababi
    case networkError(reason: String)

    /// Server javob bermadi
    case serverNotResponding

    /// Server javobi noto'g'ri
    case invalidServerResponse

    /// So'rov vaqti tugadi
    case timeout

    /// Internet ulanishi yo'q
    case noInternetConnection

    // MARK: - General Errors (0xxx)

    /// Noma'lum xato
    /// - Parameter message: Xato xabari
    case unknown(message: String)

    /// Operatsiya qo'llab-quvvatlanmaydi
    case operationNotSupported

    case maxAttemptsExceeded
}

// MARK: - LocalizedError
extension MuhrError: LocalizedError {

    public var errorDescription: String? {
        switch self {
        // Certificate
        case .certificateNotFound:
            return "Sertifikat topilmadi"
        case .certificateExpired(let date):
            return "Sertifikat muddati tugagan: \(Self.formatDate(date))"
        case .certificateNotYetValid(let date):
            return
                "Sertifikat hali kuchga kirmagan. Boshlanish: \(Self.formatDate(date))"
        case .certificateRevoked(let reason):
            return "Sertifikat bekor qilingan: \(reason.description)"
        case .invalidCertificateFormat:
            return "Sertifikat formati noto'g'ri"
        case .invalidCertificatePassword:
            return "Sertifikat paroli noto'g'ri"
        case .invalidCertificateChain:
            return "Sertifikat zanjiri tekshiruvdan o'tmadi"

        // Key
        case .privateKeyNotFound:
            return "Maxfiy kalit topilmadi"
        case .privateKeyAccessDenied:
            return "Maxfiy kalitga kirish rad etildi"
        case .invalidKeyFormat:
            return "Kalit formati noto'g'ri"

        // Signing
        case .signingFailed(let reason):
            return "Imzolash muvaffaqiyatsiz: \(reason)"
        case .emptyDataToSign:
            return "Imzolanadigan ma'lumot bo'sh"
        case .unsupportedAlgorithm(let algo):
            return "'\(algo)' algoritmi qo'llab-quvvatlanmaydi"

        // Verification
        case .verificationFailed(let reason):
            return "Tekshirish muvaffaqiyatsiz: \(reason)"
        case .invalidSignatureFormat:
            return "Imzo formati noto'g'ri"
        case .dataModified:
            return "Ma'lumot o'zgartirilgan"

        // Keychain
        case .keychainError(let status):
            return "Keychain xatosi: \(status)"
        case .keychainSaveFailed:
            return "Keychain'ga saqlash muvaffaqiyatsiz"
        case .keychainReadFailed:
            return "Keychain'dan o'qish muvaffaqiyatsiz"
        case .keychainDeleteFailed:
            return "Keychain'dan o'chirish muvaffaqiyatsiz"

        // File
        case .fileNotFound(let path):
            return "Fayl topilmadi: \(path)"
        case .fileReadError(let reason):
            return "Faylni o'qishda xato: \(reason)"
        case .fileWriteError(let reason):
            return "Faylni yozishda xato: \(reason)"
        case .unsupportedFileType(let ext):
            return "'\(ext)' fayl turi qo'llab-quvvatlanmaydi"
        case .invalidFileFormat:
            return "Fayl formati noto'g'ri"

        // Provider
        case .providerNotInitialized:
            return "Provider ishga tushirilmagan"
        case .providerNotSupported(let name):
            return "'\(name)' provider qo'llab-quvvatlanmaydi"
        case .providerConfigurationError(let reason):
            return "Provider konfiguratsiya xatosi: \(reason)"

        // Authentication
        case .pinRequired:
            return "PIN kod kiritish talab qilinadi"
        case .invalidPin:
            return "PIN kod noto'g'ri"
        case .pinBlocked:
            return "PIN kod bloklangan. Administrator bilan bog'laning"
        case .biometricAuthFailed:
            return "Biometrik autentifikatsiya muvaffaqiyatsiz"
        case .userCancelled:
            return "Amal bekor qilindi"

        // Network
        case .networkError(let reason):
            return "Tarmoq xatosi: \(reason)"
        case .serverNotResponding:
            return "Server javob bermayapti"
        case .invalidServerResponse:
            return "Server javobi noto'g'ri"
        case .timeout:
            return "So'rov vaqti tugadi"
        case .noInternetConnection:
            return "Internet ulanishi yo'q"

        // General
        case .unknown(let message):
            return "Noma'lum xato: \(message)"
        case .operationNotSupported:
            return "Bu operatsiya qo'llab-quvvatlanmaydi"
        case .maxAttemptsExceeded:
            return
                "Maksimal urinishlar soni oshdi. Certificate qayta o'rnatilishi kerak."
        }
    }

    public var failureReason: String? {
        switch self {
        case .certificateExpired:
            return "Sertifikat amal qilish muddati o'tgan"
        case .certificateRevoked:
            return "Sertifikat sertifikatsiya markazi tomonidan bekor qilingan"
        case .privateKeyAccessDenied:
            return "Keychain'dan maxfiy kalitni o'qish uchun ruxsat yo'q"
        case .invalidPin:
            return "Kiritilgan PIN kod mos kelmadi"
        case .pinBlocked:
            return "Ko'p marta noto'g'ri PIN kiritilgan"
        case .dataModified:
            return "Imzolangan ma'lumot keyinchalik o'zgartirilgan"
        default:
            return nil
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .certificateNotFound:
            return "Sertifikat o'rnating yoki mavjud sertifikatni tanlang"
        case .certificateExpired:
            return "Yangi sertifikat oling va o'rnating"
        case .certificateRevoked:
            return "Sertifikatsiya markazi bilan bog'laning"
        case .invalidCertificatePassword:
            return "Parolni tekshirib, qaytadan urinib ko'ring"
        case .privateKeyAccessDenied:
            return "Ilovaga Keychain'ga kirish huquqi bering"
        case .pinRequired, .invalidPin:
            return "To'g'ri PIN kodni kiriting"
        case .pinBlocked:
            return
                "PIN kodni qayta tiklash uchun administrator bilan bog'laning"
        case .biometricAuthFailed:
            return "Qaytadan urinib ko'ring yoki PIN kod kiriting"
        case .networkError, .serverNotResponding, .timeout:
            return "Internet ulanishini tekshiring va qaytadan urinib ko'ring"
        case .noInternetConnection:
            return "Internet ulanishini yoqing"
        default:
            return nil
        }
    }
}

// MARK: - Error Code
extension MuhrError {

    /// Xato kodi (logging va debugging uchun)
    public var errorCode: Int {
        switch self {
        // Certificate: 1xxx
        case .certificateNotFound: return 1001
        case .certificateExpired: return 1002
        case .certificateNotYetValid: return 1003
        case .certificateRevoked: return 1004
        case .invalidCertificateFormat: return 1005
        case .invalidCertificatePassword: return 1006
        case .invalidCertificateChain: return 1007

        // Key: 2xxx
        case .privateKeyNotFound: return 2001
        case .privateKeyAccessDenied: return 2002
        case .invalidKeyFormat: return 2003

        // Signing: 3xxx
        case .signingFailed: return 3001
        case .emptyDataToSign: return 3002
        case .unsupportedAlgorithm: return 3003

        // Verification: 4xxx
        case .verificationFailed: return 4001
        case .invalidSignatureFormat: return 4002
        case .dataModified: return 4003

        // Keychain: 5xxx
        case .keychainError: return 5001
        case .keychainSaveFailed: return 5002
        case .keychainReadFailed: return 5003
        case .keychainDeleteFailed: return 5004

        // File: 6xxx
        case .fileNotFound: return 6001
        case .fileReadError: return 6002
        case .fileWriteError: return 6003
        case .unsupportedFileType: return 6004
        case .invalidFileFormat: return 6005

        // Provider: 7xxx
        case .providerNotInitialized: return 7001
        case .providerNotSupported: return 7002
        case .providerConfigurationError: return 7003

        // Authentication: 8xxx
        case .pinRequired: return 8001
        case .invalidPin: return 8002
        case .pinBlocked: return 8003
        case .biometricAuthFailed: return 8004
        case .userCancelled: return 8005

        // Network: 9xxx
        case .networkError: return 9001
        case .serverNotResponding: return 9002
        case .invalidServerResponse: return 9003
        case .timeout: return 9004
        case .noInternetConnection: return 9005

        // General: 0xxx
        case .unknown: return 9999
        case .operationNotSupported: return 9998
        case .maxAttemptsExceeded:
            return 9997
        }
    }
}

// MARK: - Equatable
extension MuhrError: Equatable {
    public static func == (lhs: MuhrError, rhs: MuhrError) -> Bool {
        return lhs.errorCode == rhs.errorCode
    }
}

// MARK: - Helper
extension MuhrError {
    /// Sana formatlash
    private static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "uz_UZ")
        return formatter.string(from: date)
    }
}
