//
//  StyxProvider.swift
//  Muhr
//
//  Created by Muhammad on 27/01/26.
//

import CommonCrypto
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
    public func importCertificate(data: Data, password: String, login: String)
        async throws
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
    public func sign(data: Data, password: String, login: String? = "")
        async throws
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
    private func saveToKeychain(
        p12Data: Data,
        certificatePassword: String,
        login: String
    ) throws {

        let hashedKey = hashKey(key: login + certificatePassword)

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

        guard let itemsArray = items as? [[String: Any]],
            let firstItem = itemsArray.first,
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

        let certDER = SecCertificateCopyData(cert) as Data
        var parser = DERParser(data: certDER)

        // DERParser orqali to'liq parse qilish
        let fields: CertificateFields
        if let parsed = try? parser.extractCertificateFields() {
            fields = parsed
        } else {
            // Fallback: Security framework dan faqat CN olish
            var commonNameRef: CFString?
            SecCertificateCopyCommonName(cert, &commonNameRef)
            let cn = (commonNameRef as String?) ?? "Unknown"

            var errRef: Unmanaged<CFError>?
            let serialData =
                SecCertificateCopySerialNumberData(cert, &errRef) as Data?
                ?? Data()
            let serial = serialData.map { String(format: "%02X", $0) }.joined(
                separator: ":"
            )

            let now = Date()
            fields = CertificateFields(
                serialNumber: serial,
                commonName: cn,
                organization: nil,
                organizationUnit: nil,
                country: nil,
                pinfl: nil,
                stir: nil,
                issuerName: "Unknown",
                notBefore: now.addingTimeInterval(-365 * 24 * 60 * 60),
                notAfter: now.addingTimeInterval(365 * 24 * 60 * 60)
            )
        }

        // Algorithm
        let (algorithm, keySize) = detectAlgorithm(from: cert)

        return CertificateInfo(
            id: fields.serialNumber,
            serialNumber: fields.serialNumber,
            commonName: fields.commonName,
            organization: fields.organization,
            organizationUnit: fields.organizationUnit,
            country: fields.country,
            pinfl: fields.pinfl,
            stir: fields.stir,
            issuerName: fields.issuerName,
            validFrom: fields.notBefore,
            validTo: fields.notAfter,
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
            CFGetTypeID(cfString) == CFStringGetTypeID(),
            let str = cfString as? String
        {
            keyTypeString = str
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

    // MARK: - CMS/PKCS#7 Signing

    // CMS OID konstantalari
    private static let oidSHA1 = "1.3.14.3.2.26"
    private static let oidRSAEncryption = "1.2.840.113549.1.1.1"
    private static let oidPKCS7Data = "1.2.840.113549.1.7.1"
    private static let oidPKCS7SignedData = "1.2.840.113549.1.7.2"
    private static let oidContentType = "1.2.840.113549.1.9.3"
    private static let oidMessageDigest = "1.2.840.113549.1.9.4"
    private static let oidSigningTime = "1.2.840.113549.1.9.5"
    private static let oidCMSAlgorithmProtection = "1.2.840.113549.1.9.52"

    /// PKCS#7/CMS formatida to'liq signed message yaratish
    ///
    /// Android ishlagan formatga mos:
    /// - Digest: SHA-1
    /// - Signature algorithm: rsaEncryption (1.2.840.113549.1.1.1)
    /// - SignedAttrs: contentType, signingTime, messageDigest, CMSAlgorithmProtection
    ///
    /// - Parameters:
    ///   - data: Imzolanadigan ma'lumot
    ///   - password: Certificate password
    ///   - login: Foydalanuvchi login
    /// - Returns: CMS/PKCS#7 signed message (DER format, Base64 ga tayyor)
    public func signCMS(data: Data, password: String, login: String? = "")
        async throws -> Data
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

        // 4. Certificate olish
        var certificate: SecCertificate?
        let certStatus = SecIdentityCopyCertificate(identity, &certificate)
        guard certStatus == errSecSuccess, let cert = certificate else {
            throw MuhrError.invalidCertificateFormat
        }

        // 5. Certificate DER data olish
        let certDER = SecCertificateCopyData(cert) as Data

        // 6. Content SHA-1 hash hisoblash (Android kabi)
        let contentDigest = computeSHA1(data)

        // 7. SignedAttrs yaratish (Android formatiga mos: 4 ta attribute)
        let signedAttrs = buildSignedAttrs(contentDigest: contentDigest)

        // 8. SignedAttrs ni SET OF sifatida DER encode (imzolash uchun)
        // RFC 5652: imzo signedAttrs ning DER-encoded SET OF ustida yaratiladi
        let signedAttrsDER = DERBuilder.set(signedAttrs)

        // 9. Imzoni signedAttrs ustida yaratish
        // Android: rsaSignatureMessagePKCS1v15SHA1 ishlatiladi
        let signature = try signDataSHA1(signedAttrsDER, privateKey: key)

        // 10. CMS/PKCS#7 SignedData strukturasini yaratish
        let cmsData = try buildCMSSignedData(
            content: data,
            signature: signature,
            certificateDER: certDER,
            signedAttrs: signedAttrs
        )

        // 11. Reset failed attempts
        failedAttempts = 0

        #if DEBUG
            print("✅ CMS signed message created: \(cmsData.count) bytes")
        #endif

        return cmsData
    }

    /// SHA-1 hash hisoblash (Android kabi)
    private func computeSHA1(_ data: Data) -> Data {
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA1($0.baseAddress, CC_LONG(data.count), &digest)
        }
        return Data(digest)
    }

    /// SHA-1 bilan RSA PKCS#1 v1.5 imzolash
    private func signDataSHA1(_ data: Data, privateKey: SecKey) throws -> Data {
        let algorithm: SecKeyAlgorithm = .rsaSignatureMessagePKCS1v15SHA1

        guard SecKeyIsAlgorithmSupported(privateKey, .sign, algorithm) else {
            throw MuhrError.unsupportedAlgorithm(
                algorithm: "rsaSignatureMessagePKCS1v15SHA1"
            )
        }

        var error: Unmanaged<CFError>?
        guard
            let signature = SecKeyCreateSignature(
                privateKey,
                algorithm,
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

    // MARK: - Private: CMS/PKCS#7 Builder

    /// RFC 5652 SignedData strukturasini DER formatida yaratish
    ///
    /// Android ishlagan formatga mos:
    /// - digestAlgorithm: SHA-1
    /// - signatureAlgorithm: rsaEncryption
    /// - signedAttrs: 4 ta attribute
    private func buildCMSSignedData(
        content: Data,
        signature: Data,
        certificateDER: Data,
        signedAttrs: [Data]
    ) throws -> Data {

        // DigestAlgorithmIdentifier: SHA-1
        let digestAlgId = DERBuilder.sequence([
            DERBuilder.oid(Self.oidSHA1),
            DERBuilder.null(),
        ])

        // EncapsulatedContentInfo
        let eContent = DERBuilder.sequence([
            DERBuilder.oid(Self.oidPKCS7Data),  // id-data
            DERBuilder.explicit(
                tag: 0,
                content: DERBuilder.octetString(content)
            ),
        ])

        // SignerInfo
        let signerInfo = try buildSignerInfo(
            certificateDER: certificateDER,
            signature: signature,
            signedAttrs: signedAttrs
        )

        // SignedData
        let signedData = DERBuilder.sequence([
            DERBuilder.integer(1),  // version
            DERBuilder.set([digestAlgId]),  // digestAlgorithms
            eContent,  // encapContentInfo
            DERBuilder.implicit(tag: 0, content: certificateDER),  // certificates [0]
            DERBuilder.set([signerInfo]),  // signerInfos
        ])

        // ContentInfo wrapper
        return DERBuilder.sequence([
            DERBuilder.oid(Self.oidPKCS7SignedData),  // id-signedData
            DERBuilder.explicit(tag: 0, content: signedData),
        ])
    }

    /// SignedAttributes yaratish (Android formatiga mos — 4 ta attribute)
    ///
    /// 1. content-type (1.2.840.113549.1.9.3) = id-data
    /// 2. signing-time (1.2.840.113549.1.9.5) = UTCTime
    /// 3. message-digest (1.2.840.113549.1.9.4) = SHA-1(content)
    /// 4. CMSAlgorithmProtection (1.2.840.113549.1.9.52) = sha1 + rsaEncryption
    private func buildSignedAttrs(contentDigest: Data) -> [Data] {
        // 1. content-type attribute
        let contentTypeAttr = DERBuilder.sequence([
            DERBuilder.oid(Self.oidContentType),
            DERBuilder.set([
                DERBuilder.oid(Self.oidPKCS7Data)  // id-data
            ]),
        ])

        // 2. signing-time attribute
        let signingTimeAttr = DERBuilder.sequence([
            DERBuilder.oid(Self.oidSigningTime),
            DERBuilder.set([
                DERBuilder.utcTime(Date())
            ]),
        ])

        // 3. message-digest attribute (SHA-1 digest — 20 bytes)
        let messageDigestAttr = DERBuilder.sequence([
            DERBuilder.oid(Self.oidMessageDigest),
            DERBuilder.set([
                DERBuilder.octetString(contentDigest)
            ]),
        ])

        // 4. CMSAlgorithmProtection attribute (RFC 6211)
        // SEQUENCE {
        //   SEQUENCE { OID sha1, NULL }          -- digestAlgorithm
        //   [1] SEQUENCE { OID rsaEncryption, NULL }  -- signatureAlgorithm
        // }
        let cmsAlgProtectionValue = DERBuilder.sequence([
            DERBuilder.sequence([
                DERBuilder.oid(Self.oidSHA1),
                DERBuilder.null(),
            ]),
            DERBuilder.implicit(
                tag: 1,
                content:
                    DERBuilder.sequence([
                        DERBuilder.oid(Self.oidRSAEncryption),
                        DERBuilder.null(),
                    ])
            ),
        ])

        let cmsAlgProtectionAttr = DERBuilder.sequence([
            DERBuilder.oid(Self.oidCMSAlgorithmProtection),
            DERBuilder.set([cmsAlgProtectionValue]),
        ])

        return [
            contentTypeAttr, signingTimeAttr, messageDigestAttr,
            cmsAlgProtectionAttr,
        ]
    }

    /// SignerInfo strukturasini yaratish (RFC 5652 Section 5.3)
    ///
    /// Android formatiga mos:
    /// - digestAlgorithm: SHA-1
    /// - signatureAlgorithm: rsaEncryption (NOT sha256WithRSAEncryption)
    private func buildSignerInfo(
        certificateDER: Data,
        signature: Data,
        signedAttrs: [Data]
    ) throws -> Data {
        // Certificate'dan issuer va serial number olish
        var parser = DERParser(data: certificateDER)
        let (issuerDER, serialNumberDER) = try parser.extractIssuerAndSerial()

        // IssuerAndSerialNumber
        let signerIdentifier = DERBuilder.sequence([
            DERBuilder.raw(issuerDER),
            DERBuilder.raw(serialNumberDER),
        ])

        // DigestAlgorithmIdentifier: SHA-1
        let digestAlgId = DERBuilder.sequence([
            DERBuilder.oid(Self.oidSHA1),
            DERBuilder.null(),
        ])

        // SignedAttributes — [0] IMPLICIT tag bilan
        let signedAttrsContent = signedAttrs.reduce(Data()) { $0 + $1 }
        let signedAttrsImplicit = DERBuilder.implicit(
            tag: 0,
            content: signedAttrsContent
        )

        // SignatureAlgorithmIdentifier: rsaEncryption (Android kabi)
        let sigAlgId = DERBuilder.sequence([
            DERBuilder.oid(Self.oidRSAEncryption),
            DERBuilder.null(),
        ])

        return DERBuilder.sequence([
            DERBuilder.integer(1),  // version
            signerIdentifier,  // sid
            digestAlgId,  // digestAlgorithm: SHA-1
            signedAttrsImplicit,  // signedAttrs [0]
            sigAlgId,  // signatureAlgorithm: rsaEncryption
            DERBuilder.octetString(signature),  // signature
        ])
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
