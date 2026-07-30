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

        // MARK: - Init

        public init(isTestMode: Bool = false) {
            self.config = EImzoConfig(isTestMode: isTestMode)
        }

        // MARK: - Lifecycle

        public func initialize() async throws {
            isInitialized = true
        }

        public func shutdown() async {
            isInitialized = false
        }

        // MARK: - View Factory

        /// E-IMZO imzolash view'ini qaytaradi
        ///
        /// - Parameters:
        ///   - deepLink: `eimzo://sign?qc=...` URL (boshqa ilovadan kelganda)
        ///   - onSignComplete: Imzolash tugaganda chaqiriladi — sheet yopilishi kerak
        public func makeView(
            deepLink: String? = nil,
            onSignComplete: @escaping (Result<MuhrSignResult, Error>) -> Void
        ) -> EImzoView {
            EImzoView(
                config: config,
                deepLink: deepLink,
                onSignComplete: { result in
                    switch result {
                    case .success(_, _, let serial, let signature):
                        onSignComplete(
                            .success(
                                MuhrSignResult(
                                    providerType: .eImzo,
                                    signatureHex: signature,
                                    serialNumber: serial
                                )
                            )
                        )
                    case .failure(let message):
                        onSignComplete(
                            .failure(MuhrError.signingFailed(reason: message))
                        )
                    @unknown default:
                        onSignComplete(
                            .failure(MuhrError.signingFailed(reason: "Noma'lum EimzoSDK natijasi"))
                        )
                    }
                }
            )
        }
    }

#endif
