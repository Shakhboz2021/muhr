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

    @State private var showCertificatePicker = false
    @State private var hasCertificate = false
    @State private var isCheckingCertificate = true

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
        Group {
            if isCheckingCertificate {
                loadingView
            } else if hasCertificate {
                signingContent
            } else {
                noCertificateView
            }
        }
        .onAppear {
            setupCallbacks()
            checkCertificate()
        }
        .sheet(isPresented: $showCertificatePicker) {
            CertificatePickerView(
                login: viewModel.login,
                onInstallSuccess: { cert in
                    showCertificatePicker = false
                    hasCertificate = true
                },
                onCancel: {
                    showCertificatePicker = false
                }
            )
        }
    }

    // MARK: - Loading

    private var loadingView: some View {
        ZStack {
            MuhrTheme.Colors.systemGroupedBackground
                .ignoresSafeArea()

            ProgressView()
        }
    }

    // MARK: - No Certificate View

    private var noCertificateView: some View {
        ZStack {
            MuhrTheme.Colors.systemGroupedBackground
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                // Icon
                Image(systemName: "doc.badge.plus")
                    .font(.system(size: 56))
                    .foregroundColor(MuhrTheme.Colors.tertiaryLabel)

                // Title
                Text(L10n.certificateNotFound)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(MuhrTheme.Colors.label)

                // Description
                Text(L10n.certificateRequiredForSigning)
                    .font(.subheadline)
                    .foregroundColor(MuhrTheme.Colors.secondaryLabel)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Spacer()

                // Buttons
                VStack(spacing: 12) {
                    MuhrButton(
                        title: L10n.installCertificateButton,
                        isLoading: false,
                        isEnabled: true
                    ) {
                        showCertificatePicker = true
                    }

                    Button(action: {
                        onCancel?()
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Text(L10n.cancel)
                            .font(.body)
                            .foregroundColor(MuhrTheme.Colors.systemBlue)
                    }
                    .buttonStyle(.plain)
                }
                .padding(24)
            }
        }
    }

    // MARK: - Signing Content

    private var signingContent: some View {
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
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "signature")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(MuhrTheme.Colors.systemBlue)

            Text(L10n.signingTitle)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(MuhrTheme.Colors.label)

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
            MuhrSecureField(
                title: L10n.passwordLabel,
                placeholder: L10n.passwordPlaceholder,
                text: $viewModel.password,
                isEnabled: !viewModel.isSigning
            )

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

            MuhrButton(
                title: L10n.signButton,
                isLoading: viewModel.isSigning,
                isEnabled: viewModel.canSign
            ) {
                Task {
                    await viewModel.sign()
                }
            }

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

    // MARK: - Setup

    private func setupCallbacks() {
        viewModel.onSuccess = { result in
            onSuccess?(result)
            presentationMode.wrappedValue.dismiss()
        }
        viewModel.onCancel = {
            onCancel?()
            presentationMode.wrappedValue.dismiss()
        }
    }

    // MARK: - Check Certificate

    private func checkCertificate() {
        Task {
            let provider = StyxProvider()
            try? await provider.initialize()

            await MainActor.run {
                hasCertificate = provider.hasCertificate()
                isCheckingCertificate = false
            }
        }
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
