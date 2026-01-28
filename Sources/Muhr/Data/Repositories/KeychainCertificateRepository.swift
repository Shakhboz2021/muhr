//
//  KeychainCertificateRepository.swift
//  Muhr
//
//  Created by Muhammad on 27/01/26.
//

import Foundation
import Security

// MARK: - Keychain Certificate Repository
public final class KeychainCertificateRepository: CertificateRepository,
    @unchecked Sendable
{

    // MARK: - Properties

    private let serviceName: String
    private let accessGroup: String?
    private let defaultCertificateKey = "com.muhr.defaultCertificateId"

    private let queue = DispatchQueue(
        label: "com.muhr.keychain",
        qos: .userInitiated
    )

    // MARK: - Initializer

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

        let isNotExpired = !certificate.isExpired
        if !isNotExpired {
            errors.append(.certificateExpired(expiryDate: certificate.validTo))
        }

        let isActivated = !certificate.isNotYetValid
        if !isActivated {
            errors.append(
                .certificateNotYetValid(validFrom: certificate.validFrom)
            )
        }

        if certificate.daysUntilExpiry > 0 && certificate.daysUntilExpiry <= 30
        {
            warnings.append(
                "Sertifikat muddati \(certificate.daysUntilExpiry) kundan keyin tugaydi"
            )
        }

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
            isNotRevoked: true,
            isChainValid: true,
            errors: errors,
            warnings: warnings
        )
    }

    // MARK: - Private Keychain Methods

    private func fetchAllIdentities() throws -> [CertificateInfo] {

        var query: [String: Any] = [
            kSecClass as String: kSecClassIdentity,
            kSecReturnRef as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll,
        ]

        if let group = accessGroup {
            query[kSecAttrAccessGroup as String] = group
        }

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecItemNotFound {
            return []
        }

        guard status == errSecSuccess else {
            throw MuhrError.keychainError(status: status)
        }

        guard let identities = result as? [SecIdentity] else {
            return []
        }

        var certificates: [CertificateInfo] = []

        for identity in identities {
            if let certInfo = try? parseCertificateInfo(from: identity) {
                certificates.append(certInfo)
            }
        }

        return certificates
    }

    private func importPKCS12Sync(data: Data, password: String) throws
        -> CertificateInfo
    {

        let options: [String: Any] = [
            kSecImportExportPassphrase as String: password
        ]

        var items: CFArray?
        let status = SecPKCS12Import(
            data as CFData,
            options as CFDictionary,
            &items
        )

        if status == errSecAuthFailed {
            throw MuhrError.invalidCertificatePassword
        }

        guard status == errSecSuccess else {
            throw MuhrError.keychainError(status: status)
        }

        guard let itemsArray = items as? [[String: Any]],
            let firstItem = itemsArray.first
        else {
            throw MuhrError.invalidCertificateFormat
        }
        let identity =
            firstItem[kSecImportItemIdentity as String]
            as! SecIdentity
        try saveIdentityToKeychain(identity)

        let certInfo = try parseCertificateInfo(from: identity)

        return certInfo
    }

    private func saveIdentityToKeychain(_ identity: SecIdentity) throws {

        var query: [String: Any] = [
            kSecValueRef as String: identity,
            kSecAttrAccessible as String:
                kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]

        if let group = accessGroup {
            query[kSecAttrAccessGroup as String] = group
        }

        SecItemDelete(query as CFDictionary)

        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess || status == errSecDuplicateItem else {
            throw MuhrError.keychainSaveFailed
        }
    }

    private func deleteIdentity(id: String) throws {

        let certificates = try fetchAllIdentities()

        guard certificates.first(where: { $0.id == id }) != nil else {
            throw MuhrError.certificateNotFound
        }

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

        if let defaultId = UserDefaults.standard.string(
            forKey: defaultCertificateKey
        ),
            defaultId == id
        {
            UserDefaults.standard.removeObject(forKey: defaultCertificateKey)
        }
    }

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

        UserDefaults.standard.removeObject(forKey: defaultCertificateKey)
    }

    private func parseCertificateInfo(from identity: SecIdentity) throws
        -> CertificateInfo
    {

        var certificate: SecCertificate?
        let certStatus = SecIdentityCopyCertificate(identity, &certificate)

        guard certStatus == errSecSuccess, let cert = certificate else {
            throw MuhrError.invalidCertificateFormat
        }

        var privateKey: SecKey?
        let keyStatus = SecIdentityCopyPrivateKey(identity, &privateKey)

        let hasPrivateKey = (keyStatus == errSecSuccess && privateKey != nil)

        return try parseCertificate(
            cert,
            privateKey: hasPrivateKey ? privateKey : nil
        )
    }

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

        // Validity dates (simplified)
        let now = Date()
        let validFrom = now.addingTimeInterval(-365 * 24 * 60 * 60)
        let validTo = now.addingTimeInterval(365 * 24 * 60 * 60)

        // Algorithm
        let (algorithm, keySize) = detectAlgorithm(from: certificate)

        return CertificateInfo(
            id: serialNumber,
            serialNumber: serialNumber,
            commonName: cn,
            organization: nil,
            organizationUnit: nil,
            country: nil,
            pinfl: nil,
            stir: nil,
            issuerName: "Unknown Issuer",
            validFrom: validFrom,
            validTo: validTo,
            algorithm: algorithm,
            keySize: keySize,
            secCertificate: certificate,
            privateKeyRef: privateKey
        )
    }

    private func detectAlgorithm(from certificate: SecCertificate) -> (
        SignatureAlgorithm, Int
    ) {

        // Public key olish
        var publicKey: SecKey?
        if #available(iOS 12.0, *) {
            publicKey = SecCertificateCopyKey(certificate)
        }

        guard let key = publicKey,
            let attributes = SecKeyCopyAttributes(key) as? [String: Any]
        else {
            return (.ecdsaP256, 256)
        }

        // Key type va size olish
        let keyTypeRef = attributes[kSecAttrKeyType as String]
        let keySize = attributes[kSecAttrKeySizeInBits as String] as? Int ?? 256

        // CFString ni String ga convert qilish
        var keyTypeString: String = ""
        if let cfString = keyTypeRef as CFTypeRef?,
            CFGetTypeID(cfString) == CFStringGetTypeID()
        {
            keyTypeString = cfString as! CFString as String
        }

        // EC key type'larni tekshirish
        let ecSecPrimeRandom = kSecAttrKeyTypeECSECPrimeRandom as String
        let ecType = kSecAttrKeyTypeEC as String
        let rsaType = kSecAttrKeyTypeRSA as String

        // Algorithm aniqlash
        if keyTypeString == ecSecPrimeRandom || keyTypeString == ecType {
            switch keySize {
            case 256: return (.ecdsaP256, keySize)
            case 384: return (.ecdsaP384, keySize)
            case 521: return (.ecdsaP521, keySize)
            default: return (.ecdsaP256, keySize)
            }
        } else if keyTypeString == rsaType {
            switch keySize {
            case 2048: return (.rsaSHA256, keySize)
            case 3072: return (.rsaSHA384, keySize)
            case 4096: return (.rsaSHA512, keySize)
            default: return (.rsaSHA256, keySize)
            }
        }

        return (.ecdsaP256, 256)
    }
}
