//
//  Muhr.swift
//  Muhr
//
//  Created by Muhammad on 27/01/26.
//

import Foundation
import SwiftUI
import UIKit

// MARK: - Muhr

/// Muhr - O'zbekistonda raqamli imzo kutubxonasi
public enum Muhr {

    // MARK: - Version

    public static let version = "1.0.0"
    public static let build = 1

    // MARK: - Providers

    /// Lokal .p12 sertifikat bilan imzolash (Styx)
    public static let styx = StyxProvider()
}

// MARK: - UI Components

extension Muhr {

    /// UIKit: Certificate picker controller
    public static func makeCertificatePickerViewController()
        -> CertificatePickerViewController
    {
        CertificatePickerViewController()
    }

    /// SwiftUI: Certificate picker view
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
    public static func signingView(
        data: Data,
        login: String,
        onSuccess: ((SignatureResult) -> Void)? = nil,
        onCancel: (() -> Void)? = nil
    ) -> SigningPasswordView {
        SigningPasswordView(
            dataToSign: data,
            login: login,
            onSuccess: onSuccess,
            onCancel: onCancel
        )
    }

    /// SwiftUI: Container parolni so'rash va tekshirish uchun view
    public static func containerPasswordView(
        login: String,
        onSuccess: ((String) -> Void)? = nil,
        onCancel: (() -> Void)? = nil
    ) -> ContainerPasswordView {
        ContainerPasswordView(
            login: login,
            onSuccess: onSuccess,
            onCancel: onCancel
        )
    }
}

// MARK: - E-IMZO

#if canImport(EimzoSDK)
    extension Muhr {

        /// E-IMZO davlat imzolash tizimi (EimzoSDK)
        ///
        /// ```swift
        /// .sheet(isPresented: $show) {
        ///     Muhr.eimzo.makeView(deepLink: link) { result in
        ///         show = false
        ///     }
        /// }
        /// ```
        public static let eimzo = EImzoProvider()
    }
#endif
