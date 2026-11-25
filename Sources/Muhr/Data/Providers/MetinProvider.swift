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

            // PIN urinishlar limiti (ixtiyoriy) — konfiguratsiyada bo'lsa uzatiladi
            let maxTryLimitPin = configuration
                .additionalParameters["max_try_limit_pin"]
                .flatMap { Int($0) }

            // Bearer token (ixtiyoriy) — mobile_log so'rovlari uchun
            let bearerToken = configuration.additionalParameters["bearer_token"]

            // PIN siyosati (ixtiyoriy) — uzunlik va murakkablik talabi
            let pinLength = configuration
                .additionalParameters["pin_length"]
                .flatMap { Int($0) }
            let pinComplexity =
                configuration.additionalParameters["pin_complexity"]
                .map { $0 == "true" || $0 == "1" } ?? false

            sdk.initialize(
                baseUrl: baseUrl,
                maxTryLimitPin: maxTryLimitPin,
                bearerToken: bearerToken,
                pinLength: pinLength,
                pinComplexity: pinComplexity
            )

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
                try await deleteCertificate(pinfl: pinfl, inn: nil)
            } else if let stir = certificate.stir {
                try await deleteCertificate(pinfl: nil, inn: stir)
            } else {
                try await deleteCertificate(
                    serialNumber: certificate.serialNumber
                )
            }
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
            serialNumber: String
        ) async throws -> String {
            guard isInitialized else { throw MuhrError.providerNotInitialized }

            return try await withCheckedThrowingContinuation { continuation in
                sdk.signCMS(
                    pinCode: pinCode,
                    cms: cms,
                    serialNumber: serialNumber
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
            certificate: CertificateInfo
        ) async throws -> String {
            guard isInitialized else { throw MuhrError.providerNotInitialized }

            return try await withCheckedThrowingContinuation { continuation in
                sdk.signCMS(
                    pinCode: pinCode,
                    cms: cms,
                    serialNumber: certificate.serialNumber
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
        public func verifyCMS(_ cms: String) async throws -> VerificationResult
        {
            guard isInitialized else { throw MuhrError.providerNotInitialized }

            return try await withCheckedThrowingContinuation { continuation in
                sdk.verify(cms: cms) { result in
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

        /// PIN kodni SDK siyosati bo'yicha tekshirish (`pinLength`, `pinComplexity`)
        ///
        /// - Returns: Buzilish turi yoki `nil` (PIN yaroqli)
        public func validatePin(_ pinCode: String) -> MetinPinViolation? {
            sdk.validatePin(pinCode)
        }

        /// `mobile_log` uchun Bearer token'ni yangilash (masalan, token refresh dan keyin)
        public func updateBearerToken(_ bearerToken: String?) {
            sdk.updateBearerToken(bearerToken)
        }

        // MARK: - User (O'zMSt)

        /// Foydalanuvchini KMS dan olish
        ///
        /// - Parameters:
        ///   - pinfl: Foydalanuvchi PINFL (14 raqam)
        ///   - inn: Kompaniya INN (9 yoki 14 raqam)
        ///   - dboUserId: DBO foydalanuvchi ID (musbat butun son)
        ///   - passport: Pasport (`AA1234567` yoki `PASUZ-AA1234567`)
        public func getUser(
            pinfl: String?,
            inn: String?,
            dboUserId: String?,
            passport: String = "",
            headers: [String: String] = [:]
        ) async throws -> MetinUser {
            guard isInitialized else { throw MuhrError.providerNotInitialized }

            return try await perform { completion in
                sdk.getUser(
                    userPINFL: pinfl,
                    companyINN: inn,
                    dboUserId: dboUserId,
                    passport: passport,
                    headers: headers,
                    completion: completion
                )
            }
        }

        /// Foydalanuvchini KMS da ro'yxatdan o'tkazish
        ///
        /// Maydon qoidalari SDK tomonidan so'rovdan oldin tekshiriladi
        /// (`phoneNumber` — `998XXXXXXXXX`, matn maydonlari — 64 belgigacha,
        /// `streetAddress` / `emailAddress` — 128 belgigacha).
        public func addUser(
            emailAddress: String,
            commonName: String,
            organizationUnitName: String,
            organizationName: String,
            streetAddress: String,
            localityName: String,
            stateOrProvinceName: String,
            countryName: Country,
            pinfl: String?,
            inn: String?,
            phoneNumber: String,
            dboUserId: String? = nil,
            position: String = "",
            passport: String = "",
            headers: [String: String] = [:]
        ) async throws -> MetinAddUserResult {
            guard isInitialized else { throw MuhrError.providerNotInitialized }

            return try await perform { completion in
                sdk.addUser(
                    emailAddress: emailAddress,
                    commonName: commonName,
                    organizationUnitName: organizationUnitName,
                    organizationName: organizationName,
                    streetAddress: streetAddress,
                    localityName: localityName,
                    stateOrProvinceName: stateOrProvinceName,
                    countryName: countryName,
                    userPINFL: pinfl,
                    companyINN: inn,
                    phoneNumber: phoneNumber,
                    dboUserId: dboUserId,
                    position: position,
                    passport: passport,
                    headers: headers,
                    completion: completion
                )
            }
        }

        // MARK: - Registration Flow

        /// Sertifikat qo'shish
        ///
        /// O'zMSt (v3.6.x) da `pinfl`, `inn`, `dboUserId`, `passport`, `position`
        /// majburiy — SDK ularni so'rovdan oldin tekshiradi.
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
            dboUserId: String? = nil,
            passport: String = "",
            position: String = "",
            headers: [String: String] = [:]
        ) async throws -> MetinAddCertificateResult {
            guard isInitialized else { throw MuhrError.providerNotInitialized }

            return try await perform { completion in
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
                    userPINFL: pinfl,
                    companyINN: inn,
                    pinCode: pinCode,
                    surName: surName,
                    dboUserId: dboUserId,
                    pasport: passport,  // SDK'dagi label: `pasport`
                    position: position,
                    headers: headers,
                    completion: completion
                )
            }
        }

        // MARK: - Get Certificate

        /// Sertifikatni serialNumber bilan olish
        public func getCertificate(
            serialNumber: String,
            headers: [String: String] = [:]
        ) async throws -> MetinCertificate {
            guard isInitialized else { throw MuhrError.providerNotInitialized }

            return try await perform { completion in
                sdk.getCertificate(
                    serialNumber: serialNumber,
                    headers: headers,
                    completion: completion
                )
            }
        }

        /// Sertifikatni 4 maydon (pinfl + inn + dboUserId + passport) bilan olish
        public func getCertificate(
            pinfl: String?,
            inn: String?,
            dboUserId: String? = nil,
            passport: String = "",
            headers: [String: String] = [:]
        ) async throws -> MetinCertificate {
            guard isInitialized else { throw MuhrError.providerNotInitialized }

            return try await perform { completion in
                sdk.getCertificate(
                    userPINFL: pinfl,
                    companyINN: inn,
                    dboUserId: dboUserId,
                    passport: passport,
                    headers: headers,
                    completion: completion
                )
            }
        }

        // MARK: - Delete Certificate

        /// Sertifikatni serialNumber bilan o'chirish (serverda revoke + lokal)
        public func deleteCertificate(
            serialNumber: String,
            headers: [String: String] = [:]
        ) async throws {
            let _: any MetinResult = try await perform { completion in
                sdk.deleteCertificate(
                    serialNumber: serialNumber,
                    headers: headers,
                    completion: completion
                )
            }
        }

        /// Sertifikatni pinfl/inn bilan o'chirish (serverda revoke + lokal)
        public func deleteCertificate(
            pinfl: String?,
            inn: String?,
            headers: [String: String] = [:]
        ) async throws {
            let _: any MetinResult = try await perform { completion in
                sdk.deleteCertificate(
                    userPINFL: pinfl,
                    companyINN: inn,
                    headers: headers,
                    completion: completion
                )
            }
        }

        /// Sertifikatni dboUserId bilan o'chirish (serverda revoke + lokal)
        public func deleteCertificate(
            dboUserId: String,
            headers: [String: String] = [:]
        ) async throws {
            let _: any MetinResult = try await perform { completion in
                sdk.deleteCertificate(
                    dboUserId: dboUserId,
                    headers: headers,
                    completion: completion
                )
            }
        }

        /// Barcha sertifikatlarni tozalash (serverda revoke + lokal)
        public func clearCertificates(headers: [String: String] = [:])
            async throws
        {
            let _: any MetinResult = try await perform { completion in
                sdk.clearCertificates(headers: headers, completion: completion)
            }
        }

        // MARK: - Sign (batch / 4 maydon)

        /// Bir nechta xabarni serialNumber bilan imzolash
        public func sign(
            pinCode: String,
            messages: [String],
            serialNumber: String,
            headers: [String: String] = [:]
        ) async throws -> [String] {
            guard isInitialized else { throw MuhrError.providerNotInitialized }

            return try await perform { completion in
                sdk.sign(
                    pinCode: pinCode,
                    messages: messages,
                    serialNumber: serialNumber,
                    headers: headers,
                    result: completion
                )
            }
        }

        /// Bitta xabarni 4 maydon (pinfl + inn + dboUserId + passport) bilan imzolash
        public func sign(
            pinCode: String,
            message: String,
            pinfl: String?,
            inn: String?,
            dboUserId: String? = nil,
            passport: String = "",
            headers: [String: String] = [:]
        ) async throws -> String {
            guard isInitialized else { throw MuhrError.providerNotInitialized }

            return try await perform { completion in
                sdk.sign(
                    pinCode: pinCode,
                    message: message,
                    userPINFL: pinfl,
                    companyINN: inn,
                    dboUserId: dboUserId,
                    passport: passport,
                    headers: headers,
                    result: completion
                )
            }
        }

        /// Bir nechta xabarni 4 maydon (pinfl + inn + dboUserId + passport) bilan imzolash
        public func sign(
            pinCode: String,
            messages: [String],
            pinfl: String?,
            inn: String?,
            dboUserId: String? = nil,
            passport: String = "",
            headers: [String: String] = [:]
        ) async throws -> [String] {
            guard isInitialized else { throw MuhrError.providerNotInitialized }

            return try await perform { completion in
                sdk.sign(
                    pinCode: pinCode,
                    messages: messages,
                    userPINFL: pinfl,
                    companyINN: inn,
                    dboUserId: dboUserId,
                    passport: passport,
                    headers: headers,
                    result: completion
                )
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

            return try await perform { completion in
                sdk.signCMS(
                    pinCode: pinCode,
                    cms: cms,
                    userPINFL: pinfl,
                    companyINN: inn,
                    headers: headers,
                    result: completion
                )
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

            let _: Bool = try await perform { completion in
                sdk.changePin(
                    currentPin: currentPin,
                    newPin: newPin,
                    serialNumber: serialNumber,
                    headers: headers,
                    completion: completion
                )
            }
        }

        // MARK: - Private Helpers

        /// MetinSDK callback API'sini async/await ga o'giradi va
        /// `MetinException` ni `MuhrError` ga map qiladi.
        private func perform<T>(
            _ body: (@escaping (Result<T, MetinException>) -> Void) -> Void
        ) async throws -> T {
            try await withCheckedThrowingContinuation { continuation in
                body { result in
                    continuation.resume(
                        with: result.mapError { $0.toMuhrError() }
                    )
                }
            }
        }

        private func requestPin() async throws -> String {
            guard let delegate else {
                throw MuhrError.pinRequired
            }
            return try await withCheckedThrowingContinuation { continuation in
                delegate.providerRequiresPin(self) { pin in
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

    // MetinSDK 3.6.4 da barcha xatolar bitta `MetinException` enum'iga
    // birlashtirilgan (MetinSignError, MetinSignCmsError, ... — hammasi
    // shunga typealias). Shu sabab yagona mapping yetarli.
    //
    // MetinException case'lari `MuhrMetinError` ga **1:1** o'giriladi va
    // `MuhrError.metin(_)` orqali uzatiladi. Bu yerda hech qanday ma'lumot
    // yo'qolmaydi — App string tekshirmasdan, aynan o'sha case'lar bo'yicha
    // pattern-match qila oladi.
    extension MetinException {
        fileprivate func toMuhrError() -> MuhrError {
            .metin(
                toMuhrMetinError(),
                requiresNewCertificate: requiresNewCertificate
            )
        }

        private func toMuhrMetinError() -> MuhrMetinError {
            switch self {
            case .invalidArgument(let reason):
                return .invalidArgument(reason)
            case .invalidCertificate(let reason):
                return .invalidCertificate(reason)
            case .certificateExpired(let message, let notBefore, let notAfter):
                return .certificateExpired(
                    message: message,
                    notBefore: notBefore,
                    notAfter: notAfter
                )
            case .certificateRevoked(let reason):
                return .certificateRevoked(reason)
            case .pinCodeMismatch(let message, let triesCount):
                return .pinCodeMismatch(message: message, triesCount: triesCount)
            case .innOrPinflMismatch(let reason):
                return .innOrPinflMismatch(reason)
            case .alreadyExistSigner(let reason):
                return .alreadyExistSigner(reason)
            case .cmsValidation(let reason):
                return .cmsValidation(reason)
            case .deviceLimit(let reason):
                return .deviceLimit(reason)
            case .invalidToken(let reason):
                return .invalidToken(reason)
            case .metinHttp(let reason):
                return .metinHttp(reason)
            case .metinTimeout(let reason):
                return .metinTimeout(reason)
            case .metinServer(let reason):
                return .metinServer(reason)
            case .metinUserNotFound(let reason):
                return .metinUserNotFound(reason)
            case .metinUserExist(let reason):
                return .metinUserExist(reason)
            case .metinUserValidate(let reason):
                return .metinUserValidate(reason)
            case .wrongPhoneNumber(let reason):
                return .wrongPhoneNumber(reason)
            case .metinSqlite(let reason):
                return .metinSqlite(reason)
            case .notInitialized(let reason):
                return .notInitialized(reason)
            @unknown default:
                return .unknown(self.message)
            }
        }
    }

#endif  // canImport(MetinSDK)
