//
//  L10n.swift
//  Muhr
//
//  Created by Muhammad on 30/01/26.
//

import SwiftUI

@available(iOS 14.0, macOS 11.0, *)
public enum L10n {

    // MARK: - Bundle
    private static let bundle: Bundle = .module

    // MARK: - Private Helper
    private static func localized(_ key: String) -> String {
        NSLocalizedString(key, bundle: bundle, comment: "")
    }

    // MARK: - General

    /// "Sertifikat" / "Certificate" / "Сертификат"
    public static var certificateTitle: String {
        localized("certificate.title")
    }

    /// "Bekor" / "Cancel" / "Отмена"
    public static var cancel: String {
        localized("cancel")
    }

    // MARK: - Empty State

    /// "Sertifikat topilmadi" / "Certificate not found" / "Сертификат не найден"
    public static var certificateNotFound: String {
        localized("certificate.notFound")
    }

    /// "Documents papkasiga\n.p12 yoki .pfx faylni qo'shing"
    public static var certificateInstruction: String {
        localized("certificate.instruction")
    }

    // MARK: - Certificate Selection

    /// "Sertifikatni tanlang" / "Select Certificate" / "Выберите сертификат"
    public static var selectCertificateTitle: String {
        localized("certificate.selectTitle")
    }

    // MARK: - Password

    /// "PAROL" / "PASSWORD" / "ПАРОЛЬ"
    public static var passwordLabel: String {
        localized("password.label")
    }

    /// "Parolni kiriting" / "Enter password" / "Введите пароль"
    public static var passwordPlaceholder: String {
        localized("password.placeholder")
    }

    // MARK: - Actions

    /// "O'rnatish" / "Install" / "Установить"
    public static var installButton: String {
        localized("install.button")
    }

    /// "O'chirish" / "Delete" / "Удалить"
    public static var deleteButton: String {
        localized("delete.button")
    }

    /// "Bekor" / "Cancel" / "Отмена"
    public static var cancelActionButton: String {
        localized("cancelAction.button")
    }

    // MARK: - Errors

    /// "Parol noto'g'ri" / "Invalid password" / "Неверный пароль"
    public static var errorInvalidPassword: String {
        localized("error.invalidPassword")
    }

    /// "Sertifikat formati noto'g'ri" / "Invalid certificate format" / "Неверный формат сертификата"
    public static var errorInvalidFormat: String {
        localized("error.invalidFormat")
    }

    /// "Fayl topilmadi" / "File not found" / "Файл не найден"
    public static var errorFileNotFound: String {
        localized("error.fileNotFound")
    }

    /// "Ruxsat berilmagan" / "Permission denied" / "Доступ запрещен"
    public static var errorPermissionDenied: String {
        localized("error.permissionDenied")
    }

    // MARK: - Success Messages

    /// "Sertifikat muvaffaqiyatli o'rnatildi" / "Certificate installed successfully" / "Сертификат успешно установлен"
    public static var successInstalled: String {
        localized("success.installed")
    }

    // MARK: - Alerts

    /// "Muvaffaqiyatli" / "Success" / "Успешно"
    public static var alertSuccessTitle: String {
        localized("alert.success.title")
    }

    /// "Xatolik" / "Error" / "Ошибка"
    public static var alertErrorTitle: String {
        localized("alert.error.title")
    }

    /// "OK"
    public static var alertOK: String {
        localized("alert.ok")
    }

    /// "%@ sertifikati o'rnatildi" / "Certificate %@ installed" / "Сертификат %@ установлен"
    public static func certificateInstalledMessage(_ name: String) -> String {
        String(format: localized("certificate.installed.message"), name)
    }

    // MARK: - Signing

    /// "Imzolash" / "Sign" / "Подписать"
    public static var signingTitle: String {
        localized("signing.title")
    }

    /// "Hujjatni imzolash uchun sertifikat parolini kiriting"
    public static var signingDescription: String {
        localized("signing.description")
    }

    /// "Imzolash" / "Sign" / "Подписать"
    public static var signButton: String {
        localized("sign.button")
    }

    /// "Urinishlar tugadi. Sertifikat o'chirildi."
    public static var errorMaxAttemptsExceeded: String {
        localized("error.maxAttemptsExceeded")
    }

    /// "Imzolash uchun sertifikat o'rnatish kerak"
    public static var certificateRequiredForSigning: String {
        localized("certificate.requiredForSigning")
    }

    /// "Sertifikat o'rnatish"
    public static var installCertificateButton: String {
        localized("certificate.install.button")
    }
}
