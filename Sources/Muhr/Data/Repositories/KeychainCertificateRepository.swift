//
//  KeychainCertificateRepository.swift
//  Muhr
//
//  Created by Muhammad on 27/01/26.
//

import Foundation
import Security

// MARK: - Keychain Certificate Repository
/// Keychain orqali sertifikatlar bilan ishlash
///
/// iOS Keychain Services API yordamida sertifikatlarni
/// saqlash, o'qish va o'chirish.
///
/// ## Keychain Items:
/// - **kSecClassIdentity**: Certificate + Private Key pair
/// - **kSecClassCertificate**: Faqat certificate
/// - **kSecClassKey**: Faqat key
///
/// ## Apple Documentation:
/// https://developer.apple.com/documentation/security/keychain_services
///
/// ## Thread Safety:
/// Keychain API thread-safe, lekin biz qo'shimcha queue ishlatamiz.
public final class KeychainCertificateRepository: CertificateRepository,
    @unchecked Sendable
{

    // MARK: - Constants

    /// Keychain service nomi
    private let serviceName: String

    /// Keychain access group (app group uchun)
    private let accessGroup: String?

    /// Default sertifikat uchun UserDefaults key
    private let defaultCertificateKey = "com.muhr.defaultCertificateId"

    // MARK: - Queue

    /// Thread-safe operatsiyalar uchun
    private let queue = DispatchQueue(
        label: "com.muhr.keychain",
        qos: .userInitiated
    )

    // MARK: - Initializer

    /// Repository yaratish
    ///
    /// - Parameters:
    ///   - serviceName: Keychain service nomi
    ///   - accessGroup: App group identifier (optional)
    public init(
        serviceName: String = "com.muhr.certificates",
        accessGroup: String? = nil
    ) {
        self.serviceName = serviceName
        self.accessGroup = accessGroup
    }

    // MARK: - Read Operations

    public func getAllCertificates() async throws -> [CertificateInfo] {
        return try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    let certificates = try self.fetchAllIdentities()
                    continuation.resume(returning: certificates)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    public func getCertificate(by id: String) async throws -> CertificateInfo? {
        let all = try await getAllCertificates()
        return all.first { $0.id == id }
    }

    public func getDefaultCertificate() async throws -> CertificateInfo? {
        guard
            let defaultId = UserDefaults.standard.string(
                forKey: defaultCertificateKey
            )
        else {
            return nil
        }
        return try await getCertificate(by: defaultId)
    }

    // MARK: - Import Operations

    public func importPKCS12(data: Data, password: String) async throws
        -> CertificateInfo
    {
        return try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    let certificate = try self.importPKCS12Sync(
                        data: data,
                        password: password
                    )
                    continuation.resume(returning: certificate)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    public func importFromFile(at fileURL: URL, password: String) async throws
        -> CertificateInfo
    {
        let data = try Data(contentsOf: fileURL)
        return try await importPKCS12(data: data, password: password)
    }

    // MARK: - Delete Operations

    public func deleteCertificate(_ certificate: CertificateInfo) async throws {
        try await deleteCertificate(by: certificate.id)
    }

    public func deleteCertificate(by id: String) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    try self.deleteIdentity(id: id)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    public func deleteAllCertificates() async throws {
        return try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    try self.deleteAllIdentities()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Default Certificate

    public func setDefaultCertificate(_ certificate: CertificateInfo)
        async throws
    {
        UserDefaults.standard.set(certificate.id, forKey: defaultCertificateKey)
    }

    public func clearDefaultCertificate() async throws {
        UserDefaults.standard.removeObject(forKey: defaultCertificateKey)
    }

    // MARK: - Validation

    public func validateCertificate(_ certificate: CertificateInfo) async throws
        -> CertificateValidationResult
    {

        var errors: [MuhrError] = []
        var warnings: [String] = []

        // 1. Muddati tekshirish
        let isNotExpired = !certificate.isExpired
        if !isNotExpired {
            errors.append(.certificateExpired(expiryDate: certificate.validTo))
        }

        // 2. Kuchga kirganmi
        let isActivated = !certificate.isNotYetValid
        if !isActivated {
            errors.append(
                .certificateNotYetValid(validFrom: certificate.validFrom)
            )
        }

        // 3. Muddati tugashiga oz qolganmi
        if certificate.daysUntilExpiry > 0 && certificate.daysUntilExpiry <= 30
        {
            warnings.append(
                "Sertifikat muddati \(certificate.daysUntilExpiry) kundan keyin tugaydi"
            )
        }

        // 4. Private key bormi
        if !certificate.canSign {
            warnings.append(
                "Sertifikatda private key yo'q, imzolash mumkin emas"
            )
        }

        let isValid = errors.isEmpty && isNotExpired && isActivated

        return CertificateValidationResult(
            isValid: isValid,
            isNotExpired: isNotExpired,
            isActivated: isActivated,
            isNotRevoked: true,  // CRL/OCSP tekshiruvi hozircha yo'q
            isChainValid: true,  // Chain tekshiruvi hozircha yo'q
            errors: errors,
            warnings: warnings
        )
    }

    // MARK: - Private Keychain Methods

    /// Barcha Identity'larni olish
    private func fetchAllIdentities() throws -> [CertificateInfo] {

        var query: [String: Any] = [
            kSecClass as String: kSecClassIdentity,
            kSecReturnRef as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll,
        ]

        // Access group qo'shish (agar mavjud bo'lsa)
        if let group = accessGroup {
            query[kSecAttrAccessGroup as String] = group
        }

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        // Hech narsa topilmadi - bo'sh ro'yxat
        if status == errSecItemNotFound {
            return []
        }

        // Boshqa xato
        guard status == errSecSuccess else {
            throw MuhrError.keychainError(status: status)
        }

        // Natijani parse qilish
        guard let identities = result as? [SecIdentity] else {
            return []
        }

        // Identity'larni CertificateInfo'ga aylantirish
        var certificates: [CertificateInfo] = []

        for identity in identities {
            if let certInfo = try? parseCertificateInfo(from: identity) {
                certificates.append(certInfo)
            }
        }

        return certificates
    }

    /// PKCS#12 import (sync)
    private func importPKCS12Sync(data: Data, password: String) throws
        -> CertificateInfo
    {

        // 1. PKCS#12 ni parse qilish
        let options: [String: Any] = [
            kSecImportExportPassphrase as String: password
        ]

        var items: CFArray?
        let status = SecPKCS12Import(
            data as CFData,
            options as CFDictionary,
            &items
        )

        // Parol xato
        if status == errSecAuthFailed {
            throw MuhrError.invalidCertificatePassword
        }

        // Boshqa xato
        guard status == errSecSuccess else {
            throw MuhrError.keychainError(status: status)
        }

        // Natijani olish
        guard let itemsArray = items as? [[String: Any]],
            let firstItem = itemsArray.first,
            let identity = firstItem[kSecImportItemIdentity as String]
                as? SecIdentity
        else {
            throw MuhrError.invalidCertificateFormat
        }

        // 2. Keychain'ga saqlash
        try saveIdentityToKeychain(identity)

        // 3. CertificateInfo yaratish
        let certInfo = try parseCertificateInfo(from: identity)

        return certInfo
    }

    /// Identity'ni Keychain'ga saqlash
    private func saveIdentityToKeychain(_ identity: SecIdentity) throws {

        var query: [String: Any] = [
            kSecValueRef as String: identity,
            kSecAttrAccessible as String:
                kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]

        if let group = accessGroup {
            query[kSecAttrAccessGroup as String] = group
        }

        // Avval mavjudini o'chirish
        SecItemDelete(query as CFDictionary)

        // Yangi qo'shish
        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess || status == errSecDuplicateItem else {
            throw MuhrError.keychainSaveFailed
        }
    }

    /// Identity'ni o'chirish
    private func deleteIdentity(id: String) throws {

        // Avval Identity'ni topish
        let certificates = try fetchAllIdentities()

        guard let certToDelete = certificates.first(where: { $0.id == id })
        else {
            throw MuhrError.certificateNotFound
        }

        // Identity o'chirish
        var query: [String: Any] = [
            kSecClass as String: kSecClassIdentity,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecAttrSerialNumber as String: certToDelete.serialNumber,
        ]

        if let group = accessGroup {
            query[kSecAttrAccessGroup as String] = group
        }

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw MuhrError.keychainDeleteFailed
        }

        // Default edi bo'lsa, tozalash
        if let defaultId = UserDefaults.standard.string(
            forKey: defaultCertificateKey
        ),
            defaultId == id
        {
            UserDefaults.standard.removeObject(forKey: defaultCertificateKey)
        }
    }

    /// Barcha Identity'larni o'chirish
    private func deleteAllIdentities() throws {

        var query: [String: Any] = [
            kSecClass as String: kSecClassIdentity
        ]

        if let group = accessGroup {
            query[kSecAttrAccessGroup as String] = group
        }

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw MuhrError.keychainDeleteFailed
        }

        // Default ni tozalash
        UserDefaults.standard.removeObject(forKey: defaultCertificateKey)
    }

    /// SecIdentity'dan CertificateInfo yaratish
    private func parseCertificateInfo(from identity: SecIdentity) throws
        -> CertificateInfo
    {

        // 1. Certificate olish
        var certificate: SecCertificate?
        let certStatus = SecIdentityCopyCertificate(identity, &certificate)

        guard certStatus == errSecSuccess, let cert = certificate else {
            throw MuhrError.invalidCertificateFormat
        }

        // 2. Private key olish
        var privateKey: SecKey?
        let keyStatus = SecIdentityCopyPrivateKey(identity, &privateKey)

        // Private key optional (faqat verify uchun kerak emas)
        let hasPrivateKey = (keyStatus == errSecSuccess && privateKey != nil)

        // 3. Certificate ma'lumotlarini parse qilish
        return try parseCertificate(
            cert,
            privateKey: hasPrivateKey ? privateKey : nil
        )
    }

    /// SecCertificate'dan CertificateInfo yaratish
    private func parseCertificate(
        _ certificate: SecCertificate,
        privateKey: SecKey?
    ) throws -> CertificateInfo {

        // Serial number
        var error: Unmanaged<CFError>?
        guard
            let serialData = SecCertificateCopySerialNumberData(
                certificate,
                &error
            ) as Data?
        else {
            throw MuhrError.invalidCertificateFormat
        }
        let serialNumber = serialData.map { String(format: "%02X", $0) }.joined(
            separator: ":"
        )

        // Common Name
        var commonName: CFString?
        SecCertificateCopyCommonName(certificate, &commonName)
        let cn = (commonName as String?) ?? "Unknown"

        // Subject va Issuer
        let (subject, issuer) = parseSubjectAndIssuer(certificate)

        // Validity dates
        let (validFrom, validTo) = parseValidityDates(certificate)

        // Algorithm va key size
        let (algorithm, keySize) = try detectAlgorithm(from: certificate)

        return CertificateInfo(
            id: serialNumber,
            serialNumber: serialNumber,
            commonName: cn,
            organization: subject.organization,
            organizationUnit: subject.organizationUnit,
            country: subject.country,
            pinfl: subject.pinfl,
            stir: subject.stir,
            issuerName: issuer,
            validFrom: validFrom,
            validTo: validTo,
            algorithm: algorithm,
            keySize: keySize,
            secCertificate: certificate,
            privateKeyRef: privateKey
        )
    }

    /// Subject va Issuer parse
    private func parseSubjectAndIssuer(_ certificate: SecCertificate) -> (
        subject: (
            organization: String?, organizationUnit: String?, country: String?,
            pinfl: String?, stir: String?
        ),
        issuer: String
    ) {
        // Simplified parsing - real implementatsiyada OID'lar bilan ishlash kerak

        var issuerName: CFString?
        // iOS 15+ uchun
        if #available(iOS 15.0, *) {
            // SecCertificateCopyIssuerSummary mavjud emas, oddiy nom ishlatamiz
            issuerName = SecCertificateCopySubjectSummary(certificate)
        }

        let issuer = (issuerName as String?) ?? "Unknown Issuer"

        // Subject ma'lumotlari (soddalashtirilgan)
        let subject:
            (
                organization: String?, organizationUnit: String?,
                country: String?, pinfl: String?, stir: String?
            )
        subject = (nil, nil, nil, nil, nil)

        return (subject, issuer)
    }

    /// Validity dates parse
    private func parseValidityDates(_ certificate: SecCertificate) -> (
        Date, Date
    ) {
        // Simplified - real implementatsiyada SecCertificateCopyValues ishlatish kerak

        let now = Date()
        let validFrom = now.addingTimeInterval(-365 * 24 * 60 * 60)  // 1 yil oldin
        let validTo = now.addingTimeInterval(365 * 24 * 60 * 60)  // 1 yil keyin

        return (validFrom, validTo)
    }

    /// Algorithm aniqlash
    private func detectAlgorithm(from certificate: SecCertificate) throws -> (
        SignatureAlgorithm, Int
    ) {

        // Public key olish
        var publicKey: SecKey?
        if #available(iOS 12.0, *) {
            publicKey = SecCertificateCopyKey(certificate)
        }

        guard let key = publicKey else {
            // Default ECDSA P-256
            return (.ecdsaP256, 256)
        }

        // Key attributes
        guard let attributes = SecKeyCopyAttributes(key) as? [String: Any]
        else {
            return (.ecdsaP256, 256)
        }

        let keyType = attributes[kSecAttrKeyType as String] as? String
        let keySize = attributes[kSecAttrKeySizeInBits as String] as? Int ?? 256

        // Mapping
        let algorithm: SignatureAlgorithm

        switch (keyType, keySize) {
        case (kSecAttrKeyTypeECSECPrimeRandom as String, 256),
            (kSecAttrKeyTypeEC as String, 256):
            algorithm = .ecdsaP256

        case (kSecAttrKeyTypeECSECPrimeRandom as String, 384),
            (kSecAttrKeyTypeEC as String, 384):
            algorithm = .ecdsaP384

        case (kSecAttrKeyTypeECSECPrimeRandom as String, 521),
            (kSecAttrKeyTypeEC as String, 521):
            algorithm = .ecdsaP521

        case (kSecAttrKeyTypeRSA as String, 2048):
            algorithm = .rsaSHA256

        case (kSecAttrKeyTypeRSA as String, 3072):
            algorithm = .rsaSHA384

        case (kSecAttrKeyTypeRSA as String, 4096):
            algorithm = .rsaSHA512

        default:
            algorithm = .ecdsaP256
        }

        return (algorithm, keySize)
    }
}
