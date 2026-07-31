//
//  EImzoProvider.swift
//  Muhr
//

// EimzoSDK faqat iOS 16+ da mavjud
#if canImport(EimzoSDK) && os(iOS)

    import EimzoSDK
    import Foundation
    import SwiftUI

    // MARK: - EImzoProvider

    /// E-IMZO davlat imzolash tizimi uchun provider
    ///
    /// EimzoSDK'ni Muhr namespace'iga birlashtiradi.
    /// Styx/Metin'dan farqli — imzolash to'liq SDK UI ichida bo'ladi.
    ///
    /// ## Foydalanish:
    /// ```swift
    /// .sheet(isPresented: $showEimzo) {
    ///     Muhr.eimzo.makeView(deepLink: incomingLink) { result in
    ///         switch result {
    ///         case .success(let muhrResult):
    ///             print(muhrResult.signatureHex)
    ///         case .failure(let error):
    ///             print(error.localizedDescription)
    ///         }
    ///         showEimzo = false
    ///     }
    /// }
    /// ```
    public final class EImzoProvider: @unchecked Sendable {

        // MARK: - Properties

        public let type: ProviderType = .eImzo
        public private(set) var isInitialized: Bool = false

        private let config: EImzoConfig
        private var networkService: EImzoNetworkService?

        // MARK: - Init

        public init(baseURL: URL? = nil, isTestMode: Bool = false) {
            self.config = EImzoConfig(isTestMode: isTestMode)
            if let baseURL {
                self.networkService = EImzoNetworkService(baseURL: baseURL)
            }
        }

        // MARK: - Lifecycle

        public func initialize() async throws {
            isInitialized = true
        }

        public func shutdown() async {
            isInitialized = false
        }

        // MARK: - Mobile Auth Network

        /// 1-qadam: E-IMZO mobil autentifikatsiya sessiyasini boshlash
        ///
        /// - Parameters:
        ///   - contentBase64: Imzolanadigan kontent (Base64 encoded)
        ///   - fileName: Fayl nomi
        ///   - lang: Til kodi ("uz", "ru", "en")
        /// - Returns: `documentId` va `challenge` o'z ichiga olgan javob
        public func auth(contentBase64: String, fileName: String = "document", lang: String = "uz") async throws -> EImzoAuthResponse {
            guard let service = networkService else {
                throw MuhrError.providerConfigurationError(
                    reason: "E-IMZO base URL konfiguratsiya qilinmagan. Muhr.configure(eimzoBaseURL:) ni chaqiring."
                )
            }
            return try await service.auth(contentBase64: contentBase64, fileName: fileName, lang: lang)
        }

        /// 2-qadam: E-IMZO ilovasidan imzo kutish (polling)
        ///
        /// `status.isCompleted == true` bo'lguncha polling qiling.
        ///
        /// - Parameter documentId: `auth()` dan kelgan document ID
        public func status(documentId: String) async throws -> EImzoStatusResponse {
            guard let service = networkService else {
                throw MuhrError.providerConfigurationError(
                    reason: "E-IMZO base URL konfiguratsiya qilinmagan. Muhr.configure(eimzoBaseURL:) ni chaqiring."
                )
            }
            return try await service.status(documentId: documentId)
        }

        /// 3-qadam: PKCS7 imzoni serverga yuklash
        ///
        /// - Parameters:
        ///   - pkcs7: Base64 formatidagi PKCS7 imzo
        ///   - documentId: `auth()` dan kelgan document ID
        ///   - serialNumber: Sertifikat seriya raqami
        public func upload(pkcs7: String, documentId: String, serialNumber: String) async throws {
            guard let service = networkService else {
                throw MuhrError.providerConfigurationError(
                    reason: "E-IMZO base URL konfiguratsiya qilinmagan. Muhr.configure(eimzoBaseURL:) ni chaqiring."
                )
            }
            try await service.upload(pkcs7: pkcs7, documentId: documentId, serialNumber: serialNumber)
        }

        // MARK: - View Factory (To'liq flow)

        /// String imzolash — auth → SDK UI → upload zanjirini avtomatik boshqaradi
        ///
        /// App faqat imzolanadigan matnni beradi, qolgan barcha qadamlarni Muhr o'zi handle qiladi.
        ///
        /// ## Foydalanish:
        /// ```swift
        /// .sheet(isPresented: $show) {
        ///     Muhr.eimzo.makeSignView(string: "Shartnoma matni") { result in
        ///         show = false
        ///         // result: MuhrSignResult yoki Error
        ///     }
        /// }
        /// ```
        public func sign(
            string: String,
            fileName: String = "document.txt",
            onComplete: @escaping (Result<MuhrSignResult, Error>) -> Void
        ) -> some View {
            EImzoSignFlowView(
                contentBase64: Data(string.utf8).base64EncodedString(),
                fileName: fileName,
                config: config,
                networkService: networkService,
                onComplete: onComplete
            )
        }

        /// Binary data imzolash — auth → SDK UI → upload zanjirini avtomatik boshqaradi
        ///
        /// PDF, rasm yoki boshqa binary kontent allaqachon xotirada bo'lsa ishlatiladi.
        ///
        /// ## Foydalanish:
        /// ```swift
        /// .sheet(isPresented: $show) {
        ///     Muhr.eimzo.makeSignView(data: pdfData, fileName: "contract.pdf") { result in
        ///         show = false
        ///     }
        /// }
        /// ```
        public func sign(
            data: Data,
            fileName: String = "document",
            onComplete: @escaping (Result<MuhrSignResult, Error>) -> Void
        ) -> some View {
            EImzoSignFlowView(
                contentBase64: data.base64EncodedString(),
                fileName: fileName,
                config: config,
                networkService: networkService,
                onComplete: onComplete
            )
        }

        /// Fayl imzolash — auth → SDK UI → upload zanjirini avtomatik boshqaradi
        ///
        /// App faqat fayl URL'ini beradi, qolgan barcha qadamlarni Muhr o'zi handle qiladi.
        ///
        /// ## Foydalanish:
        /// ```swift
        /// .sheet(isPresented: $show) {
        ///     Muhr.eimzo.makeSignView(fileURL: pdfURL) { result in
        ///         show = false
        ///     }
        /// }
        /// ```
        public func sign(
            fileURL: URL,
            onComplete: @escaping (Result<MuhrSignResult, Error>) -> Void
        ) -> some View {
            let (contentBase64, fileName) = Self.readFile(at: fileURL, onComplete: onComplete)
            return EImzoSignFlowView(
                contentBase64: contentBase64,
                fileName: fileName,
                config: config,
                networkService: networkService,
                onComplete: onComplete
            )
        }

        /// Encodable struct imzolash — JSON ga o'girib auth → SDK UI → upload
        ///
        /// Server ga yuboriluvchi request body'ni bevosita imzolash uchun qulay.
        ///
        /// ## Foydalanish:
        /// ```swift
        /// struct Contract: Encodable {
        ///     let id: Int
        ///     let amount: Double
        /// }
        ///
        /// .sheet(isPresented: $show) {
        ///     Muhr.eimzo.makeSignView(encodable: Contract(id: 1, amount: 500_000)) { result in
        ///         show = false
        ///     }
        /// }
        /// ```
        public func sign<T: Encodable>(
            encodable value: T,
            encoder: JSONEncoder = JSONEncoder(),
            fileName: String = "document.json",
            onComplete: @escaping (Result<MuhrSignResult, Error>) -> Void
        ) -> some View {
            let contentBase64: String
            do {
                let data = try encoder.encode(value)
                contentBase64 = data.base64EncodedString()
            } catch {
                contentBase64 = ""
                onComplete(.failure(MuhrError.fileReadError(reason: error.localizedDescription)))
            }
            return EImzoSignFlowView(
                contentBase64: contentBase64,
                fileName: fileName,
                config: config,
                networkService: networkService,
                onComplete: onComplete
            )
        }

        private static func readFile(
            at url: URL,
            onComplete: @escaping (Result<MuhrSignResult, Error>) -> Void
        ) -> (contentBase64: String, fileName: String) {
            do {
                let data = try Data(contentsOf: url)
                return (data.base64EncodedString(), url.lastPathComponent)
            } catch {
                onComplete(.failure(MuhrError.fileReadError(reason: error.localizedDescription)))
                return ("", url.lastPathComponent)
            }
        }

        // MARK: - View Factory (Tashqi deeplink)

        /// Tashqi deeplink bilan E-IMZO view'ini qaytaradi (manual flow uchun)
        ///
        /// - Parameters:
        ///   - deepLink: `eimzo://sign?qc=...` URL (boshqa ilovadan kelganda)
        ///   - onSignComplete: Imzolash tugaganda chaqiriladi — sheet yopilishi kerak
        public func sign(
            deepLink: String? = nil,
            onComplete: @escaping (Result<MuhrSignResult, Error>) -> Void
        ) -> EImzoView {
            EImzoView(
                config: config,
                deepLink: deepLink,
                onSignComplete: { result in
                    switch result {
                    case .success(_, _, let serial, let signature):
                        onComplete(
                            .success(
                                MuhrSignResult(
                                    providerType: .eImzo,
                                    signatureHex: signature,
                                    serialNumber: serial
                                )
                            )
                        )
                    case .failure(let message):
                        onComplete(
                            .failure(MuhrError.signingFailed(reason: message))
                        )
                    @unknown default:
                        onComplete(
                            .failure(MuhrError.signingFailed(reason: "Noma'lum EimzoSDK natijasi"))
                        )
                    }
                }
            )
        }
    }

#endif
