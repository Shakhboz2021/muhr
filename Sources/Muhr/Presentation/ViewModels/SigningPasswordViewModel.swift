//
//  SigningPasswordViewModel.swift
//  Muhr
//
//  Created by Muhammad on 30/01/26.
//

import Combine
import Foundation

// MARK: - Signing State
@available(iOS 14.0, macOS 11.0, *)
public enum SigningState: Equatable {
    case idle
    case signing
    case success
    case error(String)
}

// MARK: - ViewModel
@available(iOS 14.0, macOS 11.0, *)
@MainActor
public final class SigningPasswordViewModel: ObservableObject {

    // MARK: - Published

    @Published public var password: String = ""
    @Published public private(set) var state: SigningState = .idle

    // MARK: - Private

    private let dataToSign: Data
    let login: String
    private var signatureResult: SignatureResult?

    // MARK: - Computed

    public var canSign: Bool {
        !password.isEmpty && state != .signing
    }

    public var isSigning: Bool {
        state == .signing
    }

    public var errorMessage: String? {
        if case .error(let msg) = state {
            return msg
        }
        return nil
    }

    // MARK: - Callbacks

    public var onSuccess: ((SignatureResult) -> Void)?
    public var onCancel: (() -> Void)?

    // MARK: - Init

    public init(dataToSign: Data, login: String) {
        self.dataToSign = dataToSign
        self.login = login
    }

    // MARK: - Methods

    public func sign() async {
        guard canSign else { return }

        state = .signing

        do {
            let result = try await Muhr.styx.sign(
                data: dataToSign,
                password: password,
                login: login
            )

            signatureResult = result
            state = .success
            onSuccess?(result)

        } catch MuhrError.invalidCertificatePassword {
            state = .error(L10n.errorInvalidPassword)
        } catch MuhrError.certificateNotFound {
            state = .error(L10n.certificateNotFound)
        } catch MuhrError.maxAttemptsExceeded {
            state = .error(L10n.errorMaxAttemptsExceeded)
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    public func cancel() {
        onCancel?()
    }
}
