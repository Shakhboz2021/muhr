//
//  StyxProvider.swift
//  Muhr
//
//  Created by Muhammad on 27/01/26.
//

import CryptoKit
import Foundation
import Security

// MARK: - Styx Provider
/// Lokal .p12 sertifikat bilan imzolash provider'i
///
/// Styx - Keychain'da shifrlangan .p12 fayl saqlanadi.
/// Har safar certificate password talab qilinadi.
///
/// ## Xavfsizlik Modeli:
/// - kSecAttrService = "com.muhr.styx"
/// - kSecAttrAccount = SHA256(password)
/// - kSecValueData = .p12 raw bytes
/// - 3 marta xato = Keychain tozalanadi
///
public final class StyxProvider: ProviderProtocol, @unchecked Sendable {

    // MARK: - Constants

    private var serviceName: String {
        let bundleID = Bundle.main.bundleIdentifier ?? "uz.muhr"
        return bundleID + ".styx"
    }
    private let maxFailedAttempts = 3

    // MARK: - Properties

    public let type: ProviderType = .styx
    public private(set) var isInitialized: Bool = false
    public private(set) var availableCertificates: [CertificateInfo] = []
    public private(set) var configuration: ProviderConfiguration
    public var requiresAuthentication: Bool { true }

    // MARK: - Private Properties

    private var failedAttempts: Int = 0
    private weak var delegate: ProviderDelegate?

    private let queue = DispatchQueue(
        label: "com.muhr.styx",
        qos: .userInitiated
    )

    // MARK: - Initializer

    public init(
        configuration: ProviderConfiguration = .styx,
        delegate: ProviderDelegate? = nil
    ) {
        self.configuration = configuration
        self.delegate = delegate
    }

    // MARK: - Lifecycle

    public func initialize() async throws {
        guard !isInitialized else { return }

        await MainActor.run {
            self.isInitialized = true
        }

        #if DEBUG
            print("✅ StyxProvider initialized")
        #endif
    }

    // MARK: - File Discovery
    /// Documents directory'dan .p12/.pfx fayllarni topish
    public static func discoverCertificateFiles() -> [URL] {

        guard
            let documentsURL = FileManager.default.urls(
                for: .documentDirectory,
                in: .userDomainMask
            ).first
        else {
            return []
        }

        do {
            let files = try FileManager.default.contentsOfDirectory(
                at: documentsURL,
                includingPropertiesForKeys: nil
            )

            return files.filter { url in
                let ext = url.pathExtension.lowercased()
                return ext == "p12" || ext == "pfx"
            }
        } catch {
            #if DEBUG
                print("❌ Failed to list documents: \(error)")
            #endif
            return []
        }
    }

    public func shutdown() async {
        await MainActor.run {
            self.availableCertificates = []
            self.isInitialized = false
            self.failedAttempts = 0
        }
    }

    // MARK: - Certificate Import

    /// .p12 faylni import qilish va Keychain'ga saqlash
    ///
    /// - Parameters:
    ///   - data: .p12 fayl content
    ///   - password: Certificate password
    /// - Returns: Import qilingan certificate info
    public func importCertificate(data: Data, password: String, login: String) async throws
        -> CertificateInfo
    {

        // 1. Avval .p12 ni ochib ko'ramiz (password to'g'riligini tekshirish)
        let identity = try openPKCS12(data: data, password: password)

        // 2. Certificate info olish
        let certInfo = try parseCertificateInfo(from: identity)

        // 3. Keychain'ga saqlash
        try saveToKeychain(
            p12Data: data,
            certificatePassword: password,
            login: login
        )

        // 4. Available certificates yangilash
        await MainActor.run {
            self.availableCertificates = [certInfo]
        }

        #if DEBUG
            print("✅ Certificate imported: \(certInfo.commonName)")
        #endif

        return certInfo
    }

    // MARK: - Certificate Check

    /// Certificate o'rnatilganmi tekshirish
    public func hasCertificate() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnData as String: false,
        ]

        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    // MARK: - Signing

    /// Password bilan imzolash
    ///
    /// - Parameters:
    ///   - data: Imzolanadigan ma'lumot
    ///   - password: Certificate password
    /// - Returns: Imzo natijasi
    public func sign(data: Data, password: String, login: String? = "") async throws
        -> SignatureResult
    {

        // 1. Keychain'dan .p12 olish
        let p12Data = try getFromKeychain(key: (login ?? "") + password)

        // 2. .p12 ni ochish
        let identity = try openPKCS12(data: p12Data, password: password)

        // 3. Private key olish
        var privateKey: SecKey?
        let keyStatus = SecIdentityCopyPrivateKey(identity, &privateKey)

        guard keyStatus == errSecSuccess, let key = privateKey else {
            throw MuhrError.privateKeyNotFound
        }

        // 4. Certificate info olish
        let certInfo = try parseCertificateInfo(from: identity)

        // 5. Imzolash
        let signature = try signData(
            data,
            privateKey: key,
            algorithm: certInfo.algorithm
        )

        // 6. Hash
        let dataHash = SHA256.hash(data: data)

        // 7. Success - reset failed attempts
        failedAttempts = 0

        #if DEBUG
            print("✅ Data signed successfully")
        #endif

        return SignatureResult(
            signature: signature,
            dataHash: Data(dataHash),
            timestamp: Date(),
            certificate: certInfo,
            algorithm: certInfo.algorithm
        )
    }

    /// Protocol method - delegate orqali password so'raydi
    public func sign(data: Data, with certificate: CertificateInfo) async throws
        -> SignatureResult
    {
        let password = try await requestPassword()
        return try await sign(data: data, password: password)
    }

    /// Protocol method - credential bilan
    public func sign(
        data: Data,
        with certificate: CertificateInfo,
        credential password: String
    ) async throws -> SignatureResult {
        return try await sign(data: data, password: password)
    }

    // MARK: - Password Verification

    /// Password tekshirish
    ///
    /// - Parameter password: Tekshiriladigan password
    /// - Returns: true = to'g'ri, false = xato
    public func verifyPassword(_ key: String) async throws -> Bool {
        do {
            let _ = try getFromKeychain(key: key)
            failedAttempts = 0
            return true
        } catch MuhrError.invalidCertificatePassword {
            failedAttempts += 1

            if failedAttempts >= maxFailedAttempts {
                try await clearAll()
                throw MuhrError.maxAttemptsExceeded
            }

            return false
        }
    }

    /// Qolgan urinishlar soni
    public var remainingAttempts: Int {
        return maxFailedAttempts - failedAttempts
    }

    public func verify(
        signature: Data,
        originalData: Data,
        certificate: CertificateInfo?
    ) async throws -> VerificationResult {

        guard let cert = certificate else {
            return VerificationResult.failure(errors: [.certificateNotFound])
        }

        let secCert = cert.secCertificate

        // Public key olish (password kerak emas)
        guard let publicKey = SecCertificateCopyKey(secCert) else {
            return VerificationResult.failure(errors: [.invalidSignature])
        }

        let isValid = verifySignature(
            signature,
            data: originalData,
            publicKey: publicKey,
            algorithm: cert.algorithm
        )

        if isValid {
            return VerificationResult.success(
                signerCertificate: cert,
                signedAt: Date()
            )
        } else {
            return VerificationResult.failure(
                errors: [.invalidSignature],
                signerCertificate: cert
            )
        }
    }

    // MARK: - Delete

    /// Barcha certificate'larni o'chirish
    public func clearAll() async throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
        ]

        SecItemDelete(query as CFDictionary)

        await MainActor.run {
            self.availableCertificates = []
            self.failedAttempts = 0
        }

        #if DEBUG
            print("🗑️ All certificates cleared")
        #endif
    }

    // MARK: - Protocol Methods (Unused in Styx)

    public func loadCertificates() async throws -> [CertificateInfo] {
        return availableCertificates
    }

    public func deleteCertificate(_ certificate: CertificateInfo) async throws {
        try await clearAll()
    }

    public func updateConfiguration(_ configuration: ProviderConfiguration)
        async throws
    {
        self.configuration = configuration
    }

    public func setDelegate(_ delegate: ProviderDelegate?) {
        self.delegate = delegate
    }

    // MARK: - Private: Keychain Operations

    /// .p12 ni Keychain'ga saqlash
    private func saveToKeychain(p12Data: Data, certificatePassword: String, login: String) throws {

        let hashedKey = hashKey(key: login+certificatePassword)

        // Avval eskisini o'chirish (agar bor bo'lsa)
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        // Yangi saqlash
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: hashedKey,
            kSecValueData as String: p12Data,
            kSecAttrAccessible as String:
                kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]

        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw MuhrError.keychainSaveFailed
        }
    }

    /// Keychain'dan .p12 olish (password bilan)
    private func getFromKeychain(key: String) throws -> Data {

        let hashedKey = hashKey(key: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: hashedKey,
            kSecReturnData as String: true,
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecItemNotFound {
            // Certificate bor-yo'qligini tekshirish
            if hasCertificate() {
                throw MuhrError.invalidCertificatePassword
            } else {
                throw MuhrError.certificateNotFound
            }
        }

        guard status == errSecSuccess, let data = result as? Data else {
            throw MuhrError.keychainError(status: status)
        }

        return data
    }

    /// Password hash qilish
    private func hashKey(key: String) -> String {
        let data = Data(key.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Private: PKCS12 Operations

    /// .p12 faylni ochish
    private func openPKCS12(data: Data, password: String) throws -> SecIdentity
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

        guard status == errSecSuccess, items != nil else {
            throw MuhrError.invalidCertificateFormat
        }

        let itemsArray = items as! [[String: Any]]

        guard let firstItem = itemsArray.first,
            firstItem[kSecImportItemIdentity as String] != nil
        else {
            throw MuhrError.invalidCertificateFormat
        }

        let identity =
            firstItem[kSecImportItemIdentity as String] as! SecIdentity

        return identity
    }

    // MARK: - Private: Signing

    private func signData(
        _ data: Data,
        privateKey: SecKey,
        algorithm: SignatureAlgorithm
    ) throws -> Data {

        let secAlgorithm = algorithm.secKeyAlgorithm

        guard SecKeyIsAlgorithmSupported(privateKey, .sign, secAlgorithm) else {
            throw MuhrError.unsupportedAlgorithm(algorithm: algorithm.rawValue)
        }

        var error: Unmanaged<CFError>?
        guard
            let signature = SecKeyCreateSignature(
                privateKey,
                secAlgorithm,
                data as CFData,
                &error
            ) as Data?
        else {
            let msg =
                error?.takeRetainedValue().localizedDescription ?? "Unknown"
            throw MuhrError.signingFailed(reason: msg)
        }

        return signature
    }

    private func verifySignature(
        _ signature: Data,
        data: Data,
        publicKey: SecKey,
        algorithm: SignatureAlgorithm
    ) -> Bool {

        let secAlgorithm = algorithm.secKeyAlgorithm

        guard SecKeyIsAlgorithmSupported(publicKey, .verify, secAlgorithm)
        else {
            return false
        }

        var error: Unmanaged<CFError>?
        return SecKeyVerifySignature(
            publicKey,
            secAlgorithm,
            data as CFData,
            signature as CFData,
            &error
        )
    }

    // MARK: - Private: Certificate Parsing

    private func parseCertificateInfo(from identity: SecIdentity) throws
        -> CertificateInfo
    {

        var certificate: SecCertificate?
        let status = SecIdentityCopyCertificate(identity, &certificate)

        guard status == errSecSuccess, let cert = certificate else {
            throw MuhrError.invalidCertificateFormat
        }

        // Serial number
        var error: Unmanaged<CFError>?
        guard
            let serialData = SecCertificateCopySerialNumberData(cert, &error)
                as Data?
        else {
            throw MuhrError.invalidCertificateFormat
        }
        let serialNumber = serialData.map { String(format: "%02X", $0) }.joined(
            separator: ":"
        )

        // Common name
        var commonName: CFString?
        SecCertificateCopyCommonName(cert, &commonName)
        let cn = (commonName as String?) ?? "Unknown"

        // Dates (simplified - real implementation should parse from certificate)
        let now = Date()
        let validFrom = now.addingTimeInterval(-365 * 24 * 60 * 60)
        let validTo = now.addingTimeInterval(365 * 24 * 60 * 60)

        // Algorithm
        let (algorithm, keySize) = detectAlgorithm(from: cert)

        return CertificateInfo(
            id: serialNumber,
            serialNumber: serialNumber,
            commonName: cn,
            organization: nil,
            organizationUnit: nil,
            country: nil,
            pinfl: nil,
            stir: nil,
            issuerName: "Unknown",
            validFrom: validFrom,
            validTo: validTo,
            algorithm: algorithm,
            keySize: keySize,
            secCertificate: cert,
            privateKeyRef: nil
        )
    }

    private func detectAlgorithm(from certificate: SecCertificate) -> (
        SignatureAlgorithm, Int
    ) {

        guard let publicKey = SecCertificateCopyKey(certificate),
            let attributes = SecKeyCopyAttributes(publicKey) as? [String: Any]
        else {
            return (.ecdsaP256, 256)
        }

        let keySize = attributes[kSecAttrKeySizeInBits as String] as? Int ?? 256
        let keyTypeRef = attributes[kSecAttrKeyType as String]

        var keyTypeString = ""
        if let cfString = keyTypeRef as CFTypeRef?,
            CFGetTypeID(cfString) == CFStringGetTypeID()
        {
            keyTypeString = cfString as! CFString as String
        }

        let ecType = kSecAttrKeyTypeECSECPrimeRandom as String
        let rsaType = kSecAttrKeyTypeRSA as String

        if keyTypeString == ecType
            || keyTypeString == (kSecAttrKeyTypeEC as String)
        {
            switch keySize {
            case 384: return (.ecdsaP384, keySize)
            case 521: return (.ecdsaP521, keySize)
            default: return (.ecdsaP256, keySize)
            }
        } else if keyTypeString == rsaType {
            switch keySize {
            case 3072: return (.rsaSHA384, keySize)
            case 4096: return (.rsaSHA512, keySize)
            default: return (.rsaSHA256, keySize)
            }
        }

        return (.ecdsaP256, 256)
    }

    // MARK: - Private: Delegate

    private func requestPassword() async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            delegate?.providerRequiresPin(self) { password in
                if let pwd = password {
                    continuation.resume(returning: pwd)
                } else {
                    continuation.resume(throwing: MuhrError.userCancelled)
                }
            }
        }
    }
}
