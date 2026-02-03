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
/// ## Xavfsizlik Modeli (Styx):
/// - Certificate password har safar talab qilinadi
/// - 3 marta xato = certificate o'chiriladi
/// - Keychain'da SHA256(password) bilan saqlanadi
///
/// ## Quick Start:
/// ```swift
/// import Muhr
///
/// // 1. Ishga tushirish
/// try await Muhr.initialize()
///
/// // 2. Certificate import (birinchi marta)
/// let cert = try await Muhr.importCertificate(
///     fileURL: p12URL,
///     password: "secret"
/// )
///
/// // 3. Imzolash (har safar password kerak)
/// let result = try await Muhr.sign(
///     data: document,
///     password: "secret"
/// )
///
/// // 4. Tekshirish
/// let verification = try await Muhr.verify(
///     signature: result.signature,
///     originalData: document,
///     certificate: result.certificate
/// )
/// ```
public enum Muhr {

    // MARK: - Version

    public static let version = "1.0.0"
    public static let build = 1

    // MARK: - Provider

    private static var provider: StyxProvider?

    // MARK: - Initialization

    /// Muhr'ni ishga tushirish
    public static func initialize() async throws {
        let styx = StyxProvider()
        try await styx.initialize()
        provider = styx

        #if DEBUG
            print("✅ Muhr initialized")
        #endif
    }

    /// Ishga tushirilganmi?
    public static var isInitialized: Bool {
        provider?.isInitialized ?? false
    }

    /// Muhr'ni to'xtatish
    public static func shutdown() async {
        await provider?.shutdown()
        provider = nil
    }

    // MARK: - Certificate Status

    /// Certificate o'rnatilganmi?
    public static func hasCertificate() -> Bool {
        provider?.hasCertificate() ?? false
    }

    /// Qolgan urinishlar soni
    public static var remainingAttempts: Int {
        provider?.remainingAttempts ?? 0
    }

    // MARK: - File Discovery

    /// Documents directory'dan .p12/.pfx fayllarni topish
    ///
    /// - Returns: Topilgan fayl URL'lari
    ///
    /// ## Misol:
    /// ```swift
    /// let files = Muhr.discoverCertificateFiles()
    /// for file in files {
    ///     print(file.lastPathComponent) // "muhammad.p12"
    /// }
    /// ```
    public static func discoverCertificateFiles() -> [URL] {
        return StyxProvider.discoverCertificateFiles()
    }

    // MARK: - Certificate Import

    /// Certificate import qilish (fayldan)
    ///
    /// - Parameters:
    ///   - fileURL: .p12 yoki .pfx fayl
    ///   - password: Certificate password
    /// - Returns: Import qilingan certificate info
    public static func importCertificate(
        fileURL: URL,
        password: String,
        login: String
    ) async throws -> CertificateInfo {
        guard let provider = provider else {
            throw MuhrError.providerNotInitialized
        }
        let data = try Data(contentsOf: fileURL)
        return try await provider.importCertificate(
            data: data,
            password: password,
            login: login
        )
    }

    /// Certificate import qilish (Data'dan)
    public static func importCertificate(
        data: Data,
        password: String,
        login: String
    ) async throws -> CertificateInfo {
        guard let provider = provider else {
            throw MuhrError.providerNotInitialized
        }
        return try await provider.importCertificate(
            data: data,
            password: password,
            login: login
        )
    }

    // MARK: - Password Verification

    /// Password tekshirish
    ///
    /// Login uchun ishlatiladi.
    /// 3 marta xato bo'lsa certificate o'chiriladi.
    ///
    /// - Parameter password: Certificate password
    /// - Returns: true = to'g'ri
    public static func verifyPassword(_ password: String) async throws -> Bool {
        guard let provider = provider else {
            throw MuhrError.providerNotInitialized
        }
        return try await provider.verifyPassword(password)
    }

    // MARK: - Signing

    /// Ma'lumotni imzolash
    ///
    /// - Parameters:
    ///   - data: Imzolanadigan ma'lumot
    ///   - password: Certificate password
    /// - Returns: Imzo natijasi
    public static func sign(data: Data, password: String, login: String)
        async throws
        -> SignatureResult
    {
        guard let provider = provider else {
            throw MuhrError.providerNotInitialized
        }
        return
            try await provider
            .sign(data: data, password: password, login: login)
    }

    /// String imzolash
    public static func sign(
        string: String,
        encoding: String.Encoding = .utf8,
        password: String,
        login: String
    ) async throws -> SignatureResult {
        guard let data = string.data(using: encoding) else {
            throw MuhrError.signingFailed(reason: "String encoding failed")
        }
        return try await sign(data: data, password: password, login: login)
    }

    /// JSON imzolash
    public static func sign(
        json: [String: Any],
        password: String,
        login: String
    ) async throws -> SignatureResult {
        let data = try JSONSerialization.data(
            withJSONObject: json,
            options: [.sortedKeys]
        )
        return try await sign(data: data, password: password, login: login)
    }

    /// Encodable ob'ekt imzolash
    public static func sign<T: Encodable>(
        object: T,
        password: String,
        login: String
    ) async throws -> SignatureResult {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(object)
        return try await sign(data: data, password: password, login: login)
    }

    /// Fayl imzolash
    public static func sign(
        fileURL: URL,
        password: String,
        login: String
    ) async throws -> SignatureResult {
        let data = try Data(contentsOf: fileURL)
        return try await sign(
            data: data,
            password: password,
            login: login
        )
    }

    // MARK: - Verification

    /// Imzoni tekshirish
    ///
    /// - Parameters:
    ///   - signature: Imzo (raw bytes)
    ///   - originalData: Original ma'lumot
    ///   - certificate: Sertifikat
    /// - Returns: Tekshirish natijasi
    public static func verify(
        signature: Data,
        originalData: Data,
        certificate: CertificateInfo
    ) async throws -> VerificationResult {
        guard let provider = provider else {
            throw MuhrError.providerNotInitialized
        }
        return try await provider.verify(
            signature: signature,
            originalData: originalData,
            certificate: certificate
        )
    }

    /// Base64 imzoni tekshirish
    public static func verify(
        signatureBase64: String,
        originalData: Data,
        certificate: CertificateInfo
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

    // MARK: - Clear

    /// Barcha certificate'larni o'chirish
    public static func clearAll() async throws {
        guard let provider = provider else {
            throw MuhrError.providerNotInitialized
        }
        try await provider.clearAll()
    }
}

// MARK: - UI Components

#if os(iOS)
    import UIKit

    @available(iOS 13.0, *)
    extension Muhr {

        /// UIKit: Certificate picker controller
        ///
        /// ## Misol:
        /// ```swift
        /// let picker = Muhr.makeCertificatePickerViewController()
        /// picker.onInstallSuccess = { cert in
        ///     print("Installed: \(cert.commonName)")
        ///     self.dismiss(animated: true)
        /// }
        /// picker.onCancel = {
        ///     self.dismiss(animated: true)
        /// }
        /// let nav = UINavigationController(rootViewController: picker)
        /// present(nav, animated: true)
        /// ```
        public static func makeCertificatePickerViewController()
            -> CertificatePickerViewController
        {
            return CertificatePickerViewController()
        }
    }
#endif

#if canImport(SwiftUI)
    import SwiftUI

    @available(iOS 14.0, macOS 11.0, *)
    extension Muhr {

        /// SwiftUI: Certificate picker view
        ///
        /// ## Misol:
        /// ```swift
        /// .sheet(isPresented: $showPicker) {
        ///     Muhr.certificatePickerView(
        ///         onInstallSuccess: { cert in
        ///             print("Installed: \(cert.commonName)")
        ///             showPicker = false
        ///         },
        ///         onCancel: {
        ///             showPicker = false
        ///         }
        ///     )
        /// }
        /// ```
        public static func certificatePickerView(
            login: String,
            onInstallSuccess: ((CertificateInfo) -> Void)? = nil,
            onCancel: (() -> Void)? = nil
        ) -> CertificatePickerView {
            CertificatePickerView(
                login: login,
                onInstallSuccess: onInstallSuccess,
                onCancel: onCancel
            )
        }
    }
#endif

// MARK: - Signing with UI

#if canImport(SwiftUI)
    import SwiftUI

    @available(iOS 14.0, macOS 11.0, *)
    extension Muhr {

        /// SwiftUI: Sign data with password UI
        ///
        /// ## Misol:
        /// ```swift
        /// .sheet(isPresented: $showSigning) {
        ///     Muhr.signingView(
        ///         data: paymentData,
        ///         login: userLogin,
        ///         onSuccess: { result in
        ///             print(result.signatureBase64)
        ///             showSigning = false
        ///         },
        ///         onCancel: {
        ///             showSigning = false
        ///         }
        ///     )
        /// }
        /// ```
        public static func signingView(
            data: Data,
            login: String,
            onSuccess: ((SignatureResult) -> Void)? = nil,
            onCancel: (() -> Void)? = nil
        ) -> SigningPasswordView {
            return SigningPasswordView(
                dataToSign: data,
                login: login,
                onSuccess: onSuccess,
                onCancel: onCancel
            )
        }

        /// SwiftUI: Sign string with password UI
        public static func signingView(
            string: String,
            encoding: String.Encoding = .utf8,
            login: String,
            onSuccess: ((SignatureResult) -> Void)? = nil,
            onCancel: (() -> Void)? = nil
        ) -> SigningPasswordView? {
            guard let data = string.data(using: encoding) else {
                return nil
            }
            return signingView(
                data: data,
                login: login,
                onSuccess: onSuccess,
                onCancel: onCancel
            )
        }

        /// SwiftUI: Sign JSON with password UI
        public static func signingView(
            json: [String: Any],
            login: String,
            onSuccess: ((SignatureResult) -> Void)? = nil,
            onCancel: (() -> Void)? = nil
        ) -> SigningPasswordView? {
            guard
                let data = try? JSONSerialization.data(
                    withJSONObject: json,
                    options: [.sortedKeys]
                )
            else {
                return nil
            }
            return signingView(
                data: data,
                login: login,
                onSuccess: onSuccess,
                onCancel: onCancel
            )
        }

        /// SwiftUI: Sign Encodable object with password UI
        public static func signingView<T: Encodable>(
            object: T,
            login: String,
            onSuccess: ((SignatureResult) -> Void)? = nil,
            onCancel: (() -> Void)? = nil
        ) -> SigningPasswordView? {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            guard let data = try? encoder.encode(object) else {
                return nil
            }
            return signingView(
                data: data,
                login: login,
                onSuccess: onSuccess,
                onCancel: onCancel
            )
        }
    }
#endif
