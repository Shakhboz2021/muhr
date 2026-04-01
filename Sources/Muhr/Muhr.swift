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
/// ## Foydalanish:
/// ```swift
/// // Styx (lokal .p12 sertifikat):
/// try await Muhr.styx.initialize()
/// let result = try await Muhr.styx.sign(data: doc, password: "secret", login: userLogin)
///
/// // Metin (server-side ERI) — MuhrMetin modulidan:
/// import MuhrMetin
/// try await Muhr.metin.initialize(baseUrl: "https://api.metin.uz")
/// let result = try await Muhr.metin.sign(data: doc, serialNumber: "...", pinCode: "123456")
/// ```
public enum Muhr {

    // MARK: - Version

    public static let version = "1.0.0"
    public static let build = 1

    // MARK: - Providers

    /// Lokal .p12 sertifikat bilan imzolash (Styx)
    public static let styx = StyxProvider()
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
        ///         login: userLogin,
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

        /// SwiftUI: Imzolash uchun parol so'rash view
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

        /// SwiftUI: Container parolni so'rash va tekshirish uchun view
        ///
        /// Faqat parolni verify qiladi va muvaffaqiyatli bo'lganda parolni qaytaradi.
        ///
        /// ```swift
        /// .sheet(isPresented: $showContainer) {
        ///     Muhr.containerPasswordView(
        ///         login: login,
        ///         onSuccess: { password in
        ///             // password ni Muhr.styx.signCMS(...) ga uzatish
        ///         },
        ///         onCancel: { }
        ///     )
        /// }
        /// ```
        public static func containerPasswordView(
            login: String,
            onSuccess: ((String) -> Void)? = nil,
            onCancel: (() -> Void)? = nil
        ) -> ContainerPasswordView {
            return ContainerPasswordView(
                login: login,
                onSuccess: onSuccess,
                onCancel: onCancel
            )
        }
    }
#endif
