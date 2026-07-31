//
//  EImzoSignFlowView.swift
//  Muhr
//

#if canImport(EimzoSDK) && os(iOS)

    import EimzoSDK
    import Foundation
    import SwiftUI

    // MARK: - EImzoSignFlowView

    /// Auth → EImzoSDK UI → Upload zanjirini boshqaruvchi ichki view
    ///
    /// App faqat imzolanadigan kontent beradi, qolgan barcha qadamlarni
    /// bu view o'zi boshqaradi:
    /// 1. `auth()` → challenge olish
    /// 2. EImzoSDK UI (deeplink bilan)
    /// 3. `upload()` → PKCS7 ni serverga yuborish
    /// 4. `onComplete` → natijani qaytarish
    struct EImzoSignFlowView: View {

        // MARK: - Properties

        let contentBase64: String
        let fileName: String
        let config: EImzoConfig
        let networkService: EImzoNetworkService?
        let onComplete: (Result<MuhrSignResult, Error>) -> Void

        @State private var phase: Phase = .loading

        // MARK: - Phase

        private enum Phase {
            case loading
            case signing(deepLink: String, documentId: String)
            case uploading
            case failed(Error)
        }

        // MARK: - Body

        var body: some View {
            switch phase {
            case .loading:
                ProgressView()
                    .task { await startAuth() }

            case .signing(let deepLink, let documentId):
                EImzoView(
                    config: config,
                    deepLink: deepLink,
                    onSignComplete: { result in
                        Task { await handleSign(result, documentId: documentId) }
                    }
                )

            case .uploading:
                ProgressView()

            case .failed(let error):
                Color.clear
                    .onAppear { onComplete(.failure(error)) }
            }
        }

        // MARK: - Steps

        private func startAuth() async {
            guard let service = networkService else {
                phase = .failed(
                    MuhrError.providerConfigurationError(
                        reason: "E-IMZO base URL sozlanmagan. Muhr.configure(eimzoBaseURL:) ni chaqiring."
                    )
                )
                return
            }
            do {
                let response = try await service.auth(
                    contentBase64: contentBase64,
                    fileName: fileName
                )
                let request = EImzoRequest(
                    siteId: response.state,
                    documentId: response.documentId,
                    hash: response.challenge
                )
                guard let url = generateEImzoDeepLink(from: request) else {
                    phase = .failed(MuhrError.invalidServerResponse)
                    return
                }
                phase = .signing(deepLink: url.absoluteString, documentId: response.documentId)
            } catch {
                phase = .failed(error)
            }
        }

        private func handleSign(_ result: SignResult, documentId: String) async {
            switch result {
            case .success(_, _, let serialNumber, let signature):
                phase = .uploading
                do {
                    try await networkService?.upload(
                        pkcs7: signature,
                        documentId: documentId,
                        serialNumber: serialNumber
                    )
                    onComplete(
                        .success(
                            MuhrSignResult(
                                providerType: .eImzo,
                                signatureHex: signature,
                                serialNumber: serialNumber
                            )
                        )
                    )
                } catch {
                    onComplete(.failure(error))
                }
            case .failure(let message):
                onComplete(.failure(MuhrError.signingFailed(reason: message)))
            @unknown default:
                onComplete(.failure(MuhrError.signingFailed(reason: "Noma'lum natija")))
            }
        }
    }

#endif
