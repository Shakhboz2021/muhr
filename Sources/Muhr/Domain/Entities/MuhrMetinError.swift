//
//  MuhrMetinError.swift
//  Muhr
//
//  Created by Muhammad on 20/08/26.
//

import Foundation

// MARK: - Muhr Metin Error
/// MetinSDK xatoliklarining strukturaviy nusxasi (1:1 mirror)
///
/// `MetinSDK.MetinException` iOS-only binary framework ichida bo'lgani uchun
/// uni to'g'ridan-to'g'ri `MuhrError` ichida ishlatib bo'lmaydi (aks holda
/// butun core binary'ga bog'lanib qoladi). Shu sabab uning barcha case'lari
/// shu yerda aynan takrorlangan.
///
/// MetinSDK xatolari `MetinProvider` da bir marta shu turga o'giriladi va
/// `MuhrError.metin(_)` orqali App ga uzatiladi. Natijada App **string
/// tekshirishsiz**, to'g'ridan-to'g'ri case bo'yicha pattern-match qila oladi:
///
/// ```swift
/// if case .failure(.metin(.certificateRevoked(let reason))) = result {
///     // sertifikat bekor qilingan
/// }
/// if case .failure(.metin(.pinCodeMismatch(_, let triesCount))) = result {
///     // qolgan urinishlar: triesCount
/// }
/// ```
public enum MuhrMetinError: Error, Equatable, Sendable {

    /// Noto'g'ri argument uzatildi
    case invalidArgument(String)

    /// Sertifikat noto'g'ri (format/parse xatosi)
    case invalidCertificate(String)

    /// Sertifikat muddati tugagan
    case certificateExpired(message: String, notBefore: String, notAfter: String)

    /// Sertifikat bekor qilingan
    case certificateRevoked(String)

    /// PIN kod noto'g'ri
    /// - Parameter triesCount: Qolgan urinishlar soni (0 = bloklangan)
    case pinCodeMismatch(message: String, triesCount: Int)

    /// INN yoki PINFL mos kelmadi
    case innOrPinflMismatch(String)

    /// Bu sertifikat allaqachon imzo qo'ygan
    case alreadyExistSigner(String)

    /// CMS validatsiyasi muvaffaqiyatsiz
    case cmsValidation(String)

    /// Qurilma limiti oshdi
    case deviceLimit(String)

    /// Token noto'g'ri
    case invalidToken(String)

    /// HTTP xato
    case metinHttp(String)

    /// So'rov vaqti tugadi
    case metinTimeout(String)

    /// Server xatosi
    case metinServer(String)

    /// Foydalanuvchi topilmadi
    case metinUserNotFound(String)

    /// Foydalanuvchi allaqachon mavjud
    case metinUserExist(String)

    /// Foydalanuvchi tasdiqlanmagan
    case metinUserValidate(String)

    /// Telefon raqami noto'g'ri
    case wrongPhoneNumber(String)

    /// Ma'lumotlar bazasi (SQLite) xatosi
    case metinSqlite(String)

    /// MetinSDK ishga tushirilmagan
    case notInitialized(String)

    /// Noma'lum Metin xatosi (SDK'ga yangi case qo'shilgan bo'lsa)
    case unknown(String)
}

// MARK: - LocalizedError
extension MuhrMetinError: LocalizedError {

    public var errorDescription: String? {
        switch self {
        case .invalidArgument(let reason):
            return "Noto'g'ri argument: \(reason)"
        case .invalidCertificate(let reason):
            return "Sertifikat noto'g'ri: \(reason)"
        case .certificateExpired(let message, _, let notAfter):
            return "Sertifikat muddati tugagan (\(notAfter)): \(message)"
        case .certificateRevoked(let reason):
            return "Sertifikat bekor qilingan: \(reason)"
        case .pinCodeMismatch(_, let triesCount):
            return triesCount > 0
                ? "PIN kod noto'g'ri. Qolgan urinishlar: \(triesCount)"
                : "PIN kod bloklangan"
        case .innOrPinflMismatch(let reason):
            return "INN/PINFL mos kelmadi: \(reason)"
        case .alreadyExistSigner(let reason):
            return "Bu sertifikat allaqachon imzo qo'ygan: \(reason)"
        case .cmsValidation(let reason):
            return "CMS validatsiyasi muvaffaqiyatsiz: \(reason)"
        case .deviceLimit(let reason):
            return "Qurilma limiti oshdi: \(reason)"
        case .invalidToken(let reason):
            return "Token noto'g'ri: \(reason)"
        case .metinHttp(let reason):
            return "HTTP xato: \(reason)"
        case .metinTimeout(let reason):
            return "So'rov vaqti tugadi: \(reason)"
        case .metinServer(let reason):
            return "Server xatosi: \(reason)"
        case .metinUserNotFound(let reason):
            return "Foydalanuvchi topilmadi: \(reason)"
        case .metinUserExist(let reason):
            return "Foydalanuvchi allaqachon mavjud: \(reason)"
        case .metinUserValidate(let reason):
            return "Foydalanuvchi tasdiqlanmagan: \(reason)"
        case .wrongPhoneNumber(let reason):
            return "Telefon raqami noto'g'ri: \(reason)"
        case .metinSqlite(let reason):
            return "Ma'lumotlar bazasi xatosi: \(reason)"
        case .notInitialized(let reason):
            return "MetinSDK ishga tushirilmagan: \(reason)"
        case .unknown(let reason):
            return "Noma'lum Metin xatosi: \(reason)"
        }
    }
}

// MARK: - Error Code
extension MuhrMetinError {

    /// Xato kodi (logging va `MuhrError` bilan solishtirish uchun) — 71xx
    public var errorCode: Int {
        switch self {
        case .invalidArgument: return 7101
        case .invalidCertificate: return 7102
        case .certificateExpired: return 7103
        case .certificateRevoked: return 7104
        case .pinCodeMismatch: return 7105
        case .innOrPinflMismatch: return 7106
        case .alreadyExistSigner: return 7107
        case .cmsValidation: return 7108
        case .deviceLimit: return 7109
        case .invalidToken: return 7110
        case .metinHttp: return 7111
        case .metinTimeout: return 7112
        case .metinServer: return 7113
        case .metinUserNotFound: return 7114
        case .metinUserExist: return 7115
        case .metinUserValidate: return 7116
        case .wrongPhoneNumber: return 7117
        case .metinSqlite: return 7118
        case .notInitialized: return 7119
        case .unknown: return 7120
        }
    }
}
