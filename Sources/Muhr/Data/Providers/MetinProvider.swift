//
//  MetinProvider.swift
//  Muhr
//
//  Created by Muhammad on 01/04/26.
//

// MetinSDK faqat iOS da mavjud (xcframework — iOS only binary)
#if canImport(MetinSDK)

    import CommonCrypto
    import Foundation
    import MetinSDK

    // MARK: - Metin Provider
    /// O'zbekiston ERI/ЭЦП tizimi orqali imzolash provider'i
    ///
    /// MetinSDK yordamida server tomonida sertifikat saqlash va
    /// PIN kod orqali imzolashni ta'minlaydi.
    ///
    /// ## Arxitektura:
    /// ```
    /// MuhrMetin (alohida modul)
    ///   └── MetinProvider → ProviderProtocol (Muhr core)
    ///         └── MetinSDK (binary framework, iOS only)
    /// ```
    ///
    /// ## Foydalanish tartibi:
    /// ```swift
    /// let provider = MetinProvider(
    ///     configuration: .init(
    ///         type: .metin,
    ///         additionalParameters: ["base_url": "https://api.metin.uz"]
    ///     )
    /// )
    /// try await provider.initialize()
    ///
    /// // addCertificate → sign
    /// ```
    ///
    /// ## Xavfsizlik modeli:
    /// - Sertifikat va private key MetinSDK server tomonida saqlanadi
    /// - Har bir imzolash PIN kod talab qiladi
    /// - PIN bloklanishi server tomonida boshqariladi
    public final class MetinProvider: ProviderProtocol, @unchecked Sendable {

        // MARK: - Properties

        public let type: ProviderType = .metin
        public private(set) var isInitialized: Bool = false
        public private(set) var availableCertificates: [CertificateInfo] = []
        public private(set) var configuration: ProviderConfiguration
        public var requiresAuthentication: Bool { true }

        // MARK: - Private Properties

        private let sdk = MetinManager.shared
        private weak var delegate: ProviderDelegate?

        private let queue = DispatchQueue(
            label: "com.muhr.metin",
            qos: .userInitiated
        )

        // MARK: - Initializer

        public init(
            configuration: ProviderConfiguration = .metin,
            delegate: ProviderDelegate? = nil
        ) {
            self.configuration = configuration
            self.delegate = delegate
        }

        // MARK: - Lifecycle

        public func initialize() async throws {
            guard !isInitialized else { return }

            let baseUrl = configuration.additionalParameters["base_url"] ?? ""
            guard !baseUrl.isEmpty else {
                throw MuhrError.providerConfigurationError(
                    reason:
                        "MetinProvider uchun 'base_url' konfiguratsiyada ko'rsatilishi shart"
                )
            }

            sdk.initialize(baseUrl: baseUrl)

            await MainActor.run {
                self.isInitialized = true
            }

            #if DEBUG
                print("✅ MetinProvider initialized: \(sdk.getVersion())")
            #endif
        }

        public func shutdown() async {
            await MainActor.run {
                self.availableCertificates = []
                self.isInitialized = false
            }
        }

        // MARK: - Certificate Operations

        public func loadCertificates() async throws -> [CertificateInfo] {
            guard isInitialized else { throw MuhrError.providerNotInitialized }
            // Metin da sertifikatlar sign paytida lazim bo'ladi,
            // alohida yuklab saqlash kerak emas
            return availableCertificates
        }

        /// Metin da "import" to'g'ridan-to'g'ri ishlamaydi.
        /// Sertifikat qo'shish uchun `addCertificate` metodidan foydalaning.
        public func importCertificate(
            data: Data,
            password pinCode: String,
            login: String
        ) async throws -> CertificateInfo {
            throw MuhrError.operationNotSupported
        }

        public func deleteCertificate(_ certificate: CertificateInfo)
            async throws
        {
            guard isInitialized else { throw MuhrError.providerNotInitialized }

            if let pinfl = certificate.pinfl {
                sdk.deleteCertificate(pinfl: pinfl, inn: nil)
            } else if let stir = certificate.stir {
                sdk.deleteCertificate(pinfl: nil, inn: stir)
            } else {
                sdk.deleteCertificate(serialNumber: certificate.serialNumber)
            }
        }

        public func deleteCertificate(pinfl: String?, inn: String?, headers: [String: String] = [:]) async {
            sdk.deleteCertificate(pinfl: pinfl, inn: inn, headers: headers)
        }

        // MARK: - Signing

        /// PIN kod va sertifikat bilan imzolash
        ///
        /// - Parameters:
        ///   - data: Imzolanadigan ma'lumot (ichida Base64 ga aylantiriladi)
        ///   - certificate: Sertifikat (`serialNumber` ishlatiladi)
        ///   - credential: PIN kod
        public func sign(
            data: Data,
            with certificate: CertificateInfo,
            credential pinCode: String
        ) async throws -> SignatureResult {
            guard isInitialized else { throw MuhrError.providerNotInitialized }

            let message = data.base64EncodedString()

            return try await withCheckedThrowingContinuation { continuation in
                sdk.sign(
                    pinCode: pinCode,
                    message: message,
                    serialNumber: certificate.serialNumber
                ) { result in
                    switch result {
                    case .success(let signatureBase64):
                        guard
                            let signatureData = Data(
                                base64Encoded: signatureBase64
                            )
                        else {
                            continuation.resume(
                                throwing: MuhrError.signingFailed(
                                    reason: "Imzo Base64 decode muvaffaqiyatsiz"
                                )
                            )
                            return
                        }
                        let dataHash = self.sha256(data)
                        let signResult = SignatureResult(
                            signature: signatureData,
                            dataHash: dataHash,
                            timestamp: Date(),
                            certificate: certificate,
                            algorithm: certificate.algorithm
                        )
                        continuation.resume(returning: signResult)

                    case .failure(let error):
                        continuation.resume(throwing: error.toMuhrError())
                    }
                }
            }
        }

        /// Delegate orqali PIN so'rab imzolash
        public func sign(
            data: Data,
            with certificate: CertificateInfo
        ) async throws -> SignatureResult {
            let pinCode = try await requestPin()
            return try await sign(
                data: data,
                with: certificate,
                credential: pinCode
            )
        }

        // MARK: - CMS Signing

        /// Mavjud CMS ga Metin imzosini qo'shish (serialNumber bilan)
        ///
        /// - Parameters:
        ///   - cms: Mavjud CMS string (bo'sh string = yangi CMS)
        ///   - pinCode: PIN kod
        ///   - serialNumber: Sertifikat serial raqami
        public func signCMS(
            cms: String,
            pinCode: String,
            serialNumber: String,
            headers: [String: String] = [:]
        ) async throws -> String {
            guard isInitialized else { throw MuhrError.providerNotInitialized }

            return try await withCheckedThrowingContinuation { continuation in
                sdk.signCMS(
                    pinCode: pinCode,
                    cms: cms,
                    serialNumber: serialNumber,
                    headers: headers
                ) { result in
                    switch result {
                    case .success(let signedCMS):
                        continuation.resume(returning: signedCMS)
                    case .failure(let error):
                        continuation.resume(throwing: error.toMuhrError())
                    }
                }
            }
        }

        /// Mavjud CMS ga Metin imzosini qo'shish (CertificateInfo bilan)
        ///
        /// - Parameters:
        ///   - cms: Mavjud CMS string (bo'sh string = yangi CMS)
        ///   - pinCode: PIN kod
        ///   - certificate: Sertifikat
        public func signCMS(
            cms: String,
            pinCode: String,
            certificate: CertificateInfo,
            headers: [String: String] = [:]
        ) async throws -> String {
            guard isInitialized else { throw MuhrError.providerNotInitialized }

            return try await withCheckedThrowingContinuation { continuation in
                sdk.signCMS(
                    pinCode: pinCode,
                    cms: cms,
                    serialNumber: certificate.serialNumber,
                    headers: headers
                ) { result in
                    switch result {
                    case .success(let signedCMS):
                        continuation.resume(returning: signedCMS)
                    case .failure(let error):
                        continuation.resume(throwing: error.toMuhrError())
                    }
                }
            }
        }

        // MARK: - Verification

        public func verify(
            signature: Data,
            originalData: Data,
            certificate: CertificateInfo?
        ) async throws -> VerificationResult {
            guard isInitialized else { throw MuhrError.providerNotInitialized }
            let cmsBase64 = signature.base64EncodedString()
            return try await verifyCMS(cmsBase64)
        }

        /// CMS string ni Metin server orqali tekshirish
        public func verifyCMS(_ cms: String, headers: [String: String] = [:]) async throws -> VerificationResult
        {
            guard isInitialized else { throw MuhrError.providerNotInitialized }

            return try await withCheckedThrowingContinuation { continuation in
                sdk.verify(cms: cms, headers: headers) { result in
                    switch result {
                    case .success(let metinResult):
                        let verResult = VerificationResult(
                            isSignatureValid: metinResult.isVerified,
                            isCertificateValid: true,
                            isCertificateChainValid: true,
                            isCertificateNotRevoked: !metinResult.isRevoked,
                            signerCertificate: nil,
                            signedAt: Date(),
                            errors: metinResult.isRevoked
                                ? [.certificateRevoked(reason: .unspecified)]
                                : [],
                            warnings: []
                        )
                        continuation.resume(returning: verResult)

                    case .failure(let error):
                        continuation.resume(throwing: error.toMuhrError())
                    }
                }
            }
        }

        // MARK: - PIN

        public func verifyPassword(_ key: String) async throws -> Bool {
            // Metin da PIN tekshirish server tomonida (sign orqali)
            return true
        }

        // MARK: - Configuration

        public func updateConfiguration(_ configuration: ProviderConfiguration)
            async throws
        {
            self.configuration = configuration
        }

        public func setDelegate(_ delegate: ProviderDelegate?) {
            self.delegate = delegate
        }

        // MARK: - Info

        public func getVersion() -> String {
            sdk.getVersion()
        }

        // MARK: - Registration Flow

        /// Sertifikat qo'shish (userId bilan)
        public func addCertificate(
            userId: String,
            emailAddress: String,
            commonName: String,
            organizationUnitName: String,
            organizationName: String,
            streetAddress: String,
            localityName: String,
            stateOrProvinceName: String,
            countryName: Country,
            pinfl: String? = nil,
            inn: String? = nil,
            pinCode: String,
            surName: String = "",
            headers: [String: String] = [:]
        ) async throws -> MetinAddCertificateResult {
            guard isInitialized else { throw MuhrError.providerNotInitialized }

            return try await withCheckedThrowingContinuation { continuation in
                sdk.addCertificate(
                    userId: userId,
                    emailAddress: emailAddress,
                    commonName: commonName,
                    organizationUnitName: organizationUnitName,
                    organizationName: organizationName,
                    streetAddress: streetAddress,
                    localityName: localityName,
                    stateOrProvinceName: stateOrProvinceName,
                    countryName: countryName,
                    pinfl: pinfl,
                    inn: inn,
                    pinCode: pinCode,
                    surName: surName,
                    headers: headers
                ) { result in
                    switch result {
                    case .success(let r): continuation.resume(returning: r)
                    case .failure(let error):
                        continuation.resume(throwing: error.toMuhrError())
                    }
                }
            }
        }

        /// Sertifikat qo'shish (userId + dboUserId bilan)
        public func addCertificate(
            userId: String,
            dboUserId: String,
            emailAddress: String,
            commonName: String,
            organizationUnitName: String,
            organizationName: String,
            streetAddress: String,
            localityName: String,
            stateOrProvinceName: String,
            countryName: Country,
            pinfl: String? = nil,
            inn: String? = nil,
            pinCode: String,
            surName: String = "",
            headers: [String: String] = [:]
        ) async throws -> MetinAddCertificateResult {
            guard isInitialized else { throw MuhrError.providerNotInitialized }

            return try await withCheckedThrowingContinuation { continuation in
                sdk.addCertificate(
                    userId: userId,
                    dboUserId: dboUserId,
                    emailAddress: emailAddress,
                    commonName: commonName,
                    organizationUnitName: organizationUnitName,
                    organizationName: organizationName,
                    streetAddress: streetAddress,
                    localityName: localityName,
                    stateOrProvinceName: stateOrProvinceName,
                    countryName: countryName,
                    pinfl: pinfl,
                    inn: inn,
                    pinCode: pinCode,
                    surName: surName,
                    headers: headers
                ) { result in
                    switch result {
                    case .success(let r): continuation.resume(returning: r)
                    case .failure(let error):
                        continuation.resume(throwing: error.toMuhrError())
                    }
                }
            }
        }

        // MARK: - Get Certificate

        /// Sertifikatni serialNumber bilan olish
        public func getCertificate(serialNumber: String) async throws -> MetinCertificate {
            guard isInitialized else { throw MuhrError.providerNotInitialized }

            return try await withCheckedThrowingContinuation { continuation in
                sdk.getCertificate(serialNumber: serialNumber) { result in
                    switch result {
                    case .success(let cert): continuation.resume(returning: cert)
                    case .failure(let error): continuation.resume(throwing: error.toMuhrError())
                    }
                }
            }
        }

        /// Sertifikatni pinfl/inn bilan olish
        public func getCertificate(pinfl: String?, inn: String?) async throws -> MetinCertificate {
            guard isInitialized else { throw MuhrError.providerNotInitialized }

            return try await withCheckedThrowingContinuation { continuation in
                sdk.getCertificate(pinfl: pinfl, inn: inn) { result in
                    switch result {
                    case .success(let cert): continuation.resume(returning: cert)
                    case .failure(let error): continuation.resume(throwing: error.toMuhrError())
                    }
                }
            }
        }

        /// Sertifikatni dboUserId bilan olish
        public func getCertificate(dboUserId: String) async throws -> MetinCertificate {
            guard isInitialized else { throw MuhrError.providerNotInitialized }

            return try await withCheckedThrowingContinuation { continuation in
                sdk.getCertificate(dboUserId: dboUserId) { result in
                    switch result {
                    case .success(let cert): continuation.resume(returning: cert)
                    case .failure(let error): continuation.resume(throwing: error.toMuhrError())
                    }
                }
            }
        }

        // MARK: - Delete Certificate

        /// Sertifikatni serialNumber bilan o'chirish
        public func deleteCertificate(serialNumber: String, headers: [String: String] = [:]) async {
            sdk.deleteCertificate(serialNumber: serialNumber, headers: headers)
        }

        /// Sertifikatni dboUserId bilan o'chirish
        public func deleteCertificate(dboUserId: String, headers: [String: String] = [:]) async {
            sdk.deleteCertificate(dboUserId: dboUserId, headers: headers)
        }

        /// Barcha sertifikatlarni tozalash
        public func clearCertificates(headers: [String: String] = [:]) async {
            sdk.clearCertificates(headers: headers)
        }

        // MARK: - Sign (batch)

        /// Bir nechta xabarni serialNumber bilan imzolash
        public func sign(
            pinCode: String,
            messages: [String],
            serialNumber: String,
            headers: [String: String] = [:]
        ) async throws -> [String] {
            guard isInitialized else { throw MuhrError.providerNotInitialized }

            return try await withCheckedThrowingContinuation { continuation in
                sdk.sign(pinCode: pinCode, messages: messages, serialNumber: serialNumber, headers: headers) { result in
                    switch result {
                    case .success(let signatures): continuation.resume(returning: signatures)
                    case .failure(let error): continuation.resume(throwing: error.toMuhrError())
                    }
                }
            }
        }

        /// Bitta xabarni pinfl/inn bilan imzolash
        public func sign(
            pinCode: String,
            message: String,
            pinfl: String?,
            inn: String?,
            headers: [String: String] = [:]
        ) async throws -> String {
            guard isInitialized else { throw MuhrError.providerNotInitialized }

            return try await withCheckedThrowingContinuation { continuation in
                sdk.sign(pinCode: pinCode, message: message, pinfl: pinfl, inn: inn, headers: headers) { result in
                    switch result {
                    case .success(let signature): continuation.resume(returning: signature)
                    case .failure(let error): continuation.resume(throwing: error.toMuhrError())
                    }
                }
            }
        }

        /// Bir nechta xabarni pinfl/inn bilan imzolash
        public func sign(
            pinCode: String,
            messages: [String],
            pinfl: String?,
            inn: String?,
            headers: [String: String] = [:]
        ) async throws -> [String] {
            guard isInitialized else { throw MuhrError.providerNotInitialized }

            return try await withCheckedThrowingContinuation { continuation in
                sdk.sign(pinCode: pinCode, messages: messages, pinfl: pinfl, inn: inn, headers: headers) { result in
                    switch result {
                    case .success(let signatures): continuation.resume(returning: signatures)
                    case .failure(let error): continuation.resume(throwing: error.toMuhrError())
                    }
                }
            }
        }

        // MARK: - Sign CMS (pinfl/inn)

        /// CMS ni pinfl/inn bilan imzolash
        public func signCMS(
            cms: String,
            pinCode: String,
            pinfl: String?,
            inn: String?,
            headers: [String: String] = [:]
        ) async throws -> String {
            guard isInitialized else { throw MuhrError.providerNotInitialized }

            return try await withCheckedThrowingContinuation { continuation in
                sdk.signCMS(pinCode: pinCode, cms: cms, pinfl: pinfl, inn: inn, headers: headers) { result in
                    switch result {
                    case .success(let signedCMS): continuation.resume(returning: signedCMS)
                    case .failure(let error): continuation.resume(throwing: error.toMuhrError())
                    }
                }
            }
        }

        // MARK: - Change PIN

        /// PIN o'zgartirish
        public func changePin(
            currentPin: String,
            newPin: String,
            serialNumber: String,
            headers: [String: String] = [:]
        ) async throws {
            guard isInitialized else { throw MuhrError.providerNotInitialized }

            try await withCheckedThrowingContinuation {
                (continuation: CheckedContinuation<Void, Error>) in
                sdk.changePin(
                    currentPin: currentPin,
                    newPin: newPin,
                    serialNumber: serialNumber,
                    headers: headers
                ) { result in
                    switch result {
                    case .success: continuation.resume()
                    case .failure(let error):
                        continuation.resume(throwing: error.toMuhrError())
                    }
                }
            }
        }

        // MARK: - Private Helpers

        private func requestPin() async throws -> String {
            return try await withCheckedThrowingContinuation { continuation in
                delegate?.providerRequiresPin(self) { pin in
                    if let pin {
                        continuation.resume(returning: pin)
                    } else {
                        continuation.resume(throwing: MuhrError.userCancelled)
                    }
                }
            }
        }

        private func sha256(_ data: Data) -> Data {
            var digest = [UInt8](
                repeating: 0,
                count: Int(CC_SHA256_DIGEST_LENGTH)
            )
            data.withUnsafeBytes {
                _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &digest)
            }
            return Data(digest)
        }
    }

    // MARK: - MetinSDK Error → MuhrError

    extension MetinSignError {
        fileprivate func toMuhrError() -> MuhrError {
            switch self {
            case .pinCodeMismatch:
                return .invalidPin
            case .certificateExpired(_, _, let notAfter):
                let expiry =
                    ISO8601DateFormatter().date(from: notAfter) ?? Date()
                return .certificateExpired(expiryDate: expiry)
            case .certificateRevoked:
                return .certificateRevoked(reason: .unspecified)
            case .invalidCertificate:
                return .invalidCertificateFormat
            case .signingFailed(let reason):
                return .signingFailed(reason: reason)
            case .innOrPinflMismatch(let reason):
                return .providerConfigurationError(
                    reason: "INN/PINFL mos kelmadi: \(reason)"
                )
            }
        }
    }

    extension MetinSignCmsError {
        fileprivate func toMuhrError() -> MuhrError {
            switch self {
            case .pinCodeMismatch:
                return .invalidPin
            case .certificateExpired(_, _, let notAfter):
                let expiry =
                    ISO8601DateFormatter().date(from: notAfter) ?? Date()
                return .certificateExpired(expiryDate: expiry)
            case .certificateRevoked:
                return .certificateRevoked(reason: .unspecified)
            case .invalidCertificate:
                return .invalidCertificateFormat
            case .signingFailed(let reason):
                return .signingFailed(reason: reason)
            case .alreadyExistSigner(let reason):
                return .signingFailed(
                    reason: "Bu sertifikat allaqachon imzo qo'ygan: \(reason)"
                )
            case .invalidCms:
                return .invalidSignatureFormat
            case .innOrPinflMismatch(let reason):
                return .providerConfigurationError(
                    reason: "INN/PINFL mos kelmadi: \(reason)"
                )
            }
        }
    }

    extension MetinCmsVerifyError {
        fileprivate func toMuhrError() -> MuhrError {
            switch self {
            case .serverResponse:
                return .invalidServerResponse
            case .httpError(let reason):
                return .networkError(reason: "HTTP xato: \(reason)")
            case .networkError(let reason):
                return .networkError(reason: reason)
            }
        }
    }

    extension MetinAddCertificateError {
        fileprivate func toMuhrError() -> MuhrError {
            switch self {
            case .invalidArgument(let reason):
                return .providerConfigurationError(reason: reason)
            case .serverResponse(_):
                return .invalidServerResponse
            case .httpError(let reason):
                return .networkError(reason: "HTTP xato: \(reason)")
            case .userNotValidate(let reason):
                return .providerConfigurationError(
                    reason: "Foydalanuvchi tasdiqlanmagan: \(reason)"
                )
            case .networkError(let reason):
                return .networkError(reason: reason)
            case .csrError(_):
                return .invalidCertificateFormat
            case .deviceLimit(let reason):
                return .providerConfigurationError(
                    reason: "Qurilma limiti: \(reason)"
                )
            }
        }
    }

    extension MetinGetCertificateError {
        fileprivate func toMuhrError() -> MuhrError {
            switch self {
            case .certificateExpired(_, _, let notAfter):
                let expiry =
                    ISO8601DateFormatter().date(from: notAfter) ?? Date()
                return .certificateExpired(expiryDate: expiry)
            case .certificateNotFound(_):
                return .certificateNotFound
            case .certificateRevoked(_):
                return .certificateRevoked(reason: .unspecified)
            case .httpError(let reason):
                return .networkError(reason: "HTTP xato: \(reason)")
            case .networkError(let reason):
                return .networkError(reason: reason)
            }
        }
    }

    extension MetinChangePinError {
        fileprivate func toMuhrError() -> MuhrError {
            switch self {
            case .invalidArgument(let reason):
                return .providerConfigurationError(reason: reason)
            case .pinCodeMismatch:
                return .invalidPin
            case .certificateRevoked:
                return .certificateRevoked(reason: .unspecified)
            }
        }
    }

#endif  // canImport(MetinSDK)
