//
//  MetinProviderExtensions.swift
//  Muhr
//
//  Created by Muhammad on 01/04/26.
//

// MetinSDK faqat iOS da mavjud
#if canImport(MetinSDK)

import Foundation

// MARK: - Muhr.metin

/// `Muhr.metin` — MetinProvider'ga qulay kirish nuqtasi
///
/// ## Foydalanish:
/// ```swift
/// import Muhr
///
/// // AppDelegate yoki app launch da:
/// try await Muhr.metin.initialize(baseUrl: "https://api.metin.uz")
///
/// // Sertifikat qo'shish:
/// let certResult = try await Muhr.metin.addCertificate(userId: userId, pinCode: "123456", ...)
///
/// // Imzolash:
/// let result = try await Muhr.metin.sign(data: doc, serialNumber: certResult.serialNumber, pinCode: "123456")
/// ```
extension Muhr {
    public static let metin = MetinProvider()
}

// MARK: - MetinProvider: initialize(baseUrl:)

extension MetinProvider {

    /// MetinProvider'ni server URL bilan ishga tushirish
    ///
    /// - Parameters:
    ///   - baseUrl: MetinSDK server manzili (masalan: "https://api.metin.uz")
    ///   - delegate: Hodisalarni kuzatish uchun delegate (ixtiyoriy)
    public func initialize(
        baseUrl: String,
        delegate: ProviderDelegate? = nil
    ) async throws {
        setDelegate(delegate)
        var config = configuration
        config.additionalParameters["base_url"] = baseUrl
        try await updateConfiguration(config)
        try await initialize()
    }

    // MARK: - Signing (serialNumber + pinCode convenience)

    /// Ma'lumotni imzolash
    ///
    /// - Parameters:
    ///   - data: Imzolanadigan ma'lumot
    ///   - serialNumber: Sertifikat seriya raqami
    ///   - pinCode: PIN kod
    public func sign(
        data: Data,
        serialNumber: String,
        pinCode: String
    ) async throws -> SignatureResult {
        let cert = CertificateInfo.metin(serialNumber: serialNumber)
        return try await sign(data: data, with: cert, credential: pinCode)
    }

    /// String imzolash
    public func sign(
        string: String,
        encoding: String.Encoding = .utf8,
        serialNumber: String,
        pinCode: String
    ) async throws -> SignatureResult {
        guard let data = string.data(using: encoding) else {
            throw MuhrError.signingFailed(reason: "String encoding failed")
        }
        return try await sign(data: data, serialNumber: serialNumber, pinCode: pinCode)
    }

    /// JSON imzolash
    public func sign(
        json: [String: Any],
        serialNumber: String,
        pinCode: String
    ) async throws -> SignatureResult {
        let data = try JSONSerialization.data(withJSONObject: json, options: [.sortedKeys])
        return try await sign(data: data, serialNumber: serialNumber, pinCode: pinCode)
    }

    /// Encodable ob'ekt imzolash
    public func sign<T: Encodable>(
        object: T,
        serialNumber: String,
        pinCode: String
    ) async throws -> SignatureResult {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(object)
        return try await sign(data: data, serialNumber: serialNumber, pinCode: pinCode)
    }

    // MARK: - CMS Signing (serialNumber + pinCode convenience)

    /// CMS/PKCS#7 formatida imzolash (yoki mavjud CMS ga imzo qo'shish)
    ///
    /// - Parameters:
    ///   - data: Imzolanadigan ma'lumot
    ///   - serialNumber: Sertifikat seriya raqami
    ///   - pinCode: PIN kod
    ///   - existingCMS: Mavjud CMS (ko'p imzo uchun, bo'sh = yangi CMS)
    /// - Returns: CMS string (Base64 encoded)
    public func signCMS(
        data: Data,
        serialNumber: String,
        pinCode: String,
        existingCMS: String = ""
    ) async throws -> String {
        let cert = CertificateInfo.metin(serialNumber: serialNumber)
        return try await signCMS(cms: existingCMS, pinCode: pinCode, certificate: cert)
    }

    /// String ni CMS formatida imzolash
    public func signCMS(
        string: String,
        encoding: String.Encoding = .utf8,
        serialNumber: String,
        pinCode: String,
        existingCMS: String = ""
    ) async throws -> String {
        guard let data = string.data(using: encoding) else {
            throw MuhrError.signingFailed(reason: "String encoding failed")
        }
        return try await signCMS(
            data: data,
            serialNumber: serialNumber,
            pinCode: pinCode,
            existingCMS: existingCMS
        )
    }
}

// MARK: - CertificateInfo factory (Metin uchun)

extension CertificateInfo {
    /// Metin provider uchun minimal CertificateInfo (faqat serialNumber kerak)
    static func metin(serialNumber: String) -> CertificateInfo {
        CertificateInfo(
            id: serialNumber,
            serialNumber: serialNumber,
            commonName: "",
            organization: nil,
            organizationUnit: nil,
            country: nil,
            pinfl: nil,
            stir: nil,
            issuerName: "Metin",
            validFrom: Date(),
            validTo: Date.distantFuture,
            algorithm: .rsaSHA256,
            keySize: 2048,
            secCertificate: placeholderSecCertificate(),
            privateKeyRef: nil
        )
    }

    /// Metin'da SecCertificate ishlatilmaydi — placeholder
    private static func placeholderSecCertificate() -> SecCertificate {
        let der = Data([0x30, 0x03, 0x02, 0x01, 0x00])
        return SecCertificateCreateWithData(nil, der as CFData)!
    }
}

#endif // canImport(MetinSDK)
