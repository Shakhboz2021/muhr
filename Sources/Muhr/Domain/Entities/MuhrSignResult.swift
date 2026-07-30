//
//  MuhrSignResult.swift
//  Muhr
//

import Foundation

// MARK: - MuhrSignResult

/// Barcha provider'lar uchun unified imzolash natijasi
///
/// Server JSON'dan kelgan `keyType` asosida qaysi provider ishlatilgandan
/// qat'iy nazar, bir xil turdagi natija qaytariladi.
///
/// ## Foydalanish:
/// ```swift
/// switch ProviderType(keyType: json.keyType) {
/// case .styx:
///     Muhr.signingView(data: data, login: login, onSuccess: { result in
///         let muhrResult = result.asMuhrResult(providerType: .styx)
///     })
/// case .eImzo:
///     Muhr.eimzo.makeView(deepLink: deepLink, onSignComplete: { result in
///         // natija allaqachon MuhrSignResult
///     })
/// default: break
/// }
/// ```
public struct MuhrSignResult: Sendable {

    /// Imzolashni amalga oshirgan provider
    public let providerType: ProviderType

    /// Imzo hex formatida (128 char = EimzoSDK, boshqalar uchun uzunroq)
    public let signatureHex: String

    /// Sertifikat seriya raqami
    public let serialNumber: String?

    /// To'liq sertifikat ma'lumoti (Styx/Metin uchun bor, EimzoSDK uchun nil)
    public let certificate: CertificateInfo?

    /// Imzolash vaqti
    public let timestamp: Date

    public init(
        providerType: ProviderType,
        signatureHex: String,
        serialNumber: String? = nil,
        certificate: CertificateInfo? = nil,
        timestamp: Date = Date()
    ) {
        self.providerType = providerType
        self.signatureHex = signatureHex
        self.serialNumber = serialNumber
        self.certificate = certificate
        self.timestamp = timestamp
    }
}

// MARK: - SignatureResult → MuhrSignResult

extension SignatureResult {

    /// `SignatureResult`'ni unified `MuhrSignResult`'ga aylantirish
    public func asMuhrResult(providerType: ProviderType) -> MuhrSignResult {
        MuhrSignResult(
            providerType: providerType,
            signatureHex: signatureHex,
            serialNumber: certificate.serialNumber,
            certificate: certificate,
            timestamp: timestamp
        )
    }
}
