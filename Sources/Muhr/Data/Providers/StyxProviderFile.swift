//
//  StyxProvider.swift
//  Muhr
//
//  Created by Muhammad on 27/01/26.
//

import Foundation
import Security

// MARK: - Styx Provider
/// Lokal sertifikat bilan imzolash provider'i
///
/// Styx - bu Keychain'da saqlangan sertifikat va private key
/// yordamida imzolash. Tashqi server yoki tarmoq talab qilmaydi.
///
/// ## Xususiyatlari:
/// - ✅ Offline ishlaydi
/// - ✅ Tez (lokal operatsiya)
/// - ✅ Private key qurilmadan chiqmaydi
/// - ❌ SMS tasdiqlash yo'q
///
/// ## Foydalanish:
/// ```swift
/// let provider = StyxProvider()
/// try await provider.initialize()
///
/// let certs = try await provider.loadCertificates()
/// let signature = try await provider.sign(data: document, with: certs[0])
/// ```
public final class StyxProvider: ProviderProtocol, @unchecked Sendable {

    // MARK: - Properties

    public let type: ProviderType = .styx

    public private(set) var isInitialized: Bool = false

    public private(set) var availableCertificates: [CertificateInfo] = []

    public private(set) var configuration: ProviderConfiguration

    // MARK: - Private Properties
    private let certificateRepository: KeychainCertificateRepository
    private let signingRepository: KeychainSigningRepository

    private var state: ProviderState = .notInitialized
    private weak var delegate: ProviderDelegate?

    private let queue = DispatchQueue(
        label: "com.muhr.styx",
        qos: .userInitiated
    )

    // MARK: - Initializer
    /// Provider yaratish
    ///
    /// - Parameters:
    ///   - configuration: Provider konfiguratsiyasi
    ///   - delegate: Hodisalarni kuzatish uchun delegate
    public init(
        configuration: ProviderConfiguration = .styx,
        delegate: ProviderDelegate? = nil
    ) {
        self.configuration = configuration
        self.delegate = delegate

        // Repository'larni yaratish
        self.certificateRepository = KeychainCertificateRepository()
        self.signingRepository = KeychainSigningRepository(
            certificateRepository: certificateRepository
        )
    }

    // MARK: - Lifecycle
    public func initialize() async throws {

        guard !isInitialized else { return }

        updateState(.initializing)

        do {
            // Sertifikatlarni yuklash
            let certificates =
                try await certificateRepository.getAllCertificates()

            await MainActor.run {
                self.availableCertificates = certificates
                self.isInitialized = true
            }

            updateState(.ready)

            delegate?.providerDidUpdateCertificates(
                self,
                certificates: certificates
            )

            #if DEBUG
                print(
                    "✅ StyxProvider initialized with \(certificates.count) certificate(s)"
                )
            #endif

        } catch {
            let muhrError =
                (error as? MuhrError)
                ?? .unknown(message: error.localizedDescription)
            updateState(.error(muhrError))
            delegate?.providerDidEncounterError(self, error: muhrError)
            throw muhrError
        }
    }

    public func shutdown() async {

        await MainActor.run {
            self.availableCertificates = []
            self.isInitialized = false
        }

        updateState(.shutdown)

        #if DEBUG
            print("🔒 StyxProvider shutdown")
        #endif
    }

    // MARK: - Certificate Operations

    public func loadCertificates() async throws -> [CertificateInfo] {

        guard isInitialized else {
            throw MuhrError.providerNotInitialized
        }

        let certificates = try await certificateRepository.getAllCertificates()

        await MainActor.run {
            self.availableCertificates = certificates
        }

        delegate?.providerDidUpdateCertificates(
            self,
            certificates: certificates
        )

        return certificates
    }

    public func importCertificate(data: Data, password: String) async throws
        -> CertificateInfo
    {

        guard isInitialized else {
            throw MuhrError.providerNotInitialized
        }

        let certificate = try await certificateRepository.importPKCS12(
            data: data,
            password: password
        )

        // Ro'yxatni yangilash
        _ = try await loadCertificates()

        #if DEBUG
            print("✅ Certificate imported: \(certificate.commonName)")
        #endif

        return certificate
    }

    public func deleteCertificate(_ certificate: CertificateInfo) async throws {

        guard isInitialized else {
            throw MuhrError.providerNotInitialized
        }

        try await certificateRepository.deleteCertificate(certificate)

        // Ro'yxatni yangilash
        _ = try await loadCertificates()

        #if DEBUG
            print("🗑️ Certificate deleted: \(certificate.commonName)")
        #endif
    }

    // MARK: - Signing Operations

    public func sign(data: Data, with certificate: CertificateInfo) async throws
        -> SignatureResult
    {

        guard isInitialized else {
            throw MuhrError.providerNotInitialized
        }

        // Sertifikat validatsiyasi
        guard certificate.isValid else {
            if certificate.isExpired {
                throw MuhrError.certificateExpired(
                    expiryDate: certificate.validTo
                )
            } else {
                throw MuhrError.certificateNotYetValid(
                    validFrom: certificate.validFrom
                )
            }
        }

        // Private key tekshirish
        guard certificate.canSign else {
            throw MuhrError.privateKeyNotFound
        }

        // Imzolash
        let result = try await signingRepository.sign(
            data: data,
            with: certificate
        )

        #if DEBUG
            print("✅ Data signed: \(result.signature.count) bytes")
        #endif

        return result
    }

    public func verify(
        signature: Data,
        originalData: Data,
        certificate: CertificateInfo?
    ) async throws -> VerificationResult {

        guard isInitialized else {
            throw MuhrError.providerNotInitialized
        }

        let result = try await signingRepository.verify(
            signature: signature,
            originalData: originalData,
            certificate: certificate
        )

        #if DEBUG
            print(
                "🔍 Verification result: \(result.isValid ? "✅ Valid" : "❌ Invalid")"
            )
        #endif

        return result
    }

    // MARK: - Configuration

    public func updateConfiguration(_ configuration: ProviderConfiguration)
        async throws
    {

        guard configuration.type == .styx else {
            throw MuhrError.providerConfigurationError(
                reason:
                    "Configuration type mismatch: expected styx, got \(configuration.type)"
            )
        }

        self.configuration = configuration

        #if DEBUG
            print("⚙️ StyxProvider configuration updated")
        #endif
    }

    // MARK: - Delegate

    /// Delegate o'rnatish
    public func setDelegate(_ delegate: ProviderDelegate?) {
        self.delegate = delegate
    }

    // MARK: - Private Methods

    private func updateState(_ newState: ProviderState) {
        self.state = newState
        delegate?.providerDidChangeState(self, state: newState)
    }
}

// MARK: - Convenience Extensions
extension StyxProvider {

    /// String imzolash
    public func sign(
        string: String,
        encoding: String.Encoding = .utf8,
        with certificate: CertificateInfo
    ) async throws -> SignatureResult {

        guard let data = string.data(using: encoding) else {
            throw MuhrError.signingFailed(
                reason: "String to Data conversion failed"
            )
        }

        return try await sign(data: data, with: certificate)
    }

    /// JSON imzolash
    public func sign(
        json: [String: Any],
        with certificate: CertificateInfo
    ) async throws -> SignatureResult {

        let data = try JSONSerialization.data(
            withJSONObject: json,
            options: [.sortedKeys]
        )

        return try await sign(data: data, with: certificate)
    }

    /// Fayl imzolash
    public func signFile(
        at url: URL,
        with certificate: CertificateInfo
    ) async throws -> SignatureResult {

        let data = try Data(contentsOf: url)
        return try await sign(data: data, with: certificate)
    }

    /// Default sertifikat bilan imzolash
    public func signWithDefaultCertificate(data: Data) async throws
        -> SignatureResult
    {

        guard
            let defaultCert =
                try await certificateRepository.getDefaultCertificate()
        else {
            // Default yo'q, birinchi valid sertifikatni ishlatish
            let validCerts = availableCertificates.filter {
                $0.isValid && $0.canSign
            }

            guard let firstCert = validCerts.first else {
                throw MuhrError.certificateNotFound
            }

            return try await sign(data: data, with: firstCert)
        }

        return try await sign(data: data, with: defaultCert)
    }

    /// Sertifikatni default qilish
    public func setDefaultCertificate(_ certificate: CertificateInfo)
        async throws
    {
        try await certificateRepository.setDefaultCertificate(certificate)
    }

    /// Default sertifikatni olish
    public func getDefaultCertificate() async throws -> CertificateInfo? {
        return try await certificateRepository.getDefaultCertificate()
    }
}

// MARK: - Certificate Validation
extension StyxProvider {

    /// Sertifikat validatsiyasi
    public func validateCertificate(_ certificate: CertificateInfo) async throws
        -> CertificateValidationResult
    {
        return try await certificateRepository.validateCertificate(certificate)
    }

    /// Imzolash uchun tayyor sertifikatlar
    public func getSigningCertificates() -> [CertificateInfo] {
        return availableCertificates.filter { $0.isValid && $0.canSign }
    }

    /// Muddati tugayotgan sertifikatlar
    public func getExpiringSoonCertificates(days: Int = 30) -> [CertificateInfo]
    {
        return availableCertificates.filter {
            $0.isValid && $0.daysUntilExpiry <= days
        }
    }
}
