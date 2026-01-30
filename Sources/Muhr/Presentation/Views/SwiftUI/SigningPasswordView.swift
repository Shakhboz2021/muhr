//
//  SigningPasswordView.swift
//  Muhr
//
//  Created by Muhammad on 30/01/26.
//

import SwiftUI

@available(iOS 14.0, macOS 11.0, *)
public struct SigningPasswordView: View {

    @StateObject private var viewModel: SigningPasswordViewModel
    @Environment(\.presentationMode) var presentationMode

    // MARK: - Callbacks

    private let onSuccess: ((SignatureResult) -> Void)?
    private let onCancel: (() -> Void)?

    // MARK: - Init

    public init(
        dataToSign: Data,
        login: String,
        onSuccess: ((SignatureResult) -> Void)? = nil,
        onCancel: (() -> Void)? = nil
    ) {
        self._viewModel = StateObject(
            wrappedValue: SigningPasswordViewModel(
                dataToSign: dataToSign,
                login: login
            )
        )
        self.onSuccess = onSuccess
        self.onCancel = onCancel
    }

    // MARK: - Body

    public var body: some View {
        ZStack {
            MuhrTheme.Colors.systemGroupedBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Header
                headerSection

                Spacer()

                // Form
                formSection
            }
        }
        .onAppear {
            viewModel.onSuccess = { result in
                onSuccess?(result)
                presentationMode.wrappedValue.dismiss()
            }
            viewModel.onCancel = {
                onCancel?()
                presentationMode.wrappedValue.dismiss()
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 16) {
            // Icon
            Image(systemName: "signature")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(MuhrTheme.Colors.systemBlue)

            // Title
            Text(L10n.signingTitle)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(MuhrTheme.Colors.label)

            // Description
            Text(L10n.signingDescription)
                .font(.subheadline)
                .foregroundColor(MuhrTheme.Colors.secondaryLabel)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }

    // MARK: - Form

    private var formSection: some View {
        VStack(spacing: 16) {
            // Password field
            MuhrSecureField(
                title: L10n.passwordLabel,
                placeholder: L10n.passwordPlaceholder,
                text: $viewModel.password,
                isEnabled: !viewModel.isSigning
            )

            // Error message
            if let error = viewModel.errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(MuhrTheme.Colors.systemRed)

                    Text(error)
                        .font(.caption)
                        .foregroundColor(MuhrTheme.Colors.systemRed)

                    Spacer()
                }
            }

            // Sign button
            MuhrButton(
                title: L10n.signButton,
                isLoading: viewModel.isSigning,
                isEnabled: viewModel.canSign
            ) {
                Task {
                    await viewModel.sign()
                }
            }

            // Cancel button
            Button(action: {
                viewModel.cancel()
            }) {
                Text(L10n.cancel)
                    .font(.body)
                    .foregroundColor(MuhrTheme.Colors.systemBlue)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isSigning)
            .padding(.top, 8)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(MuhrTheme.Colors.systemBackground)
        )
        .padding(16)
    }
}

// MARK: - Preview
#if DEBUG
    @available(iOS 14.0, macOS 11.0, *)
    struct SigningPasswordView_Previews: PreviewProvider {
        static var previews: some View {
            SigningPasswordView(
                dataToSign: "Test".data(using: .utf8)!,
                login: "admin"
            )
        }
    }
#endif
