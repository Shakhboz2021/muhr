//
//  ContainerPasswordView.swift
//  Muhr
//
//  Created by Muhammad on 25/03/26.
//

import SwiftUI

/// Container parolni so'rash va tekshirish uchun view
///
/// Faqat parolni verify qiladi va muvaffaqiyatli bo'lganda parolni qaytaradi.
/// Sign qilish chaqiruvchi tomonida amalga oshiriladi.
///
/// ## Foydalanish:
/// ```swift
/// .sheet(isPresented: $showContainer) {
///     Muhr.containerPasswordView(
///         login: login,
///         onSuccess: { password in
///             // password bilan signCMS chaqirish
///         },
///         onCancel: {
///             showContainer = false
///         }
///     )
/// }
/// ```
@available(iOS 14.0, macOS 11.0, *)
public struct ContainerPasswordView: View {

    @Environment(\.presentationMode) var presentationMode

    @State private var password: String = ""
    @State private var isVerifying: Bool = false
    @State private var errorMessage: String?
    @State private var showCertificatePicker = false
    @State private var hasCertificate = false
    @State private var isCheckingCertificate = true

    private let login: String
    private let onSuccess: ((String) -> Void)?
    private let onCancel: (() -> Void)?

    // MARK: - Init

    public init(
        login: String,
        onSuccess: ((String) -> Void)? = nil,
        onCancel: (() -> Void)? = nil
    ) {
        self.login = login
        self.onSuccess = onSuccess
        self.onCancel = onCancel
    }

    // MARK: - Body

    public var body: some View {
        Group {
            if isCheckingCertificate {
                loadingView
            } else if hasCertificate {
                passwordContent
            } else {
                noCertificateView
            }
        }
        .onAppear {
            checkCertificate()
        }
        .sheet(isPresented: $showCertificatePicker) {
            CertificatePickerView(
                login: login,
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

                Image(systemName: "doc.badge.plus")
                    .font(.system(size: 56))
                    .foregroundColor(MuhrTheme.Colors.tertiaryLabel)

                Text(L10n.certificateNotFound)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(MuhrTheme.Colors.label)

                Text(L10n.certificateRequiredForSigning)
                    .font(.subheadline)
                    .foregroundColor(MuhrTheme.Colors.secondaryLabel)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Spacer()

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

    // MARK: - Password Content

    private var passwordContent: some View {
        ZStack {
            MuhrTheme.Colors.systemGroupedBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Header
                VStack(spacing: 16) {
                    Image(systemName: "lock.shield")
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

                Spacer()

                // Form
                VStack(spacing: 16) {
                    MuhrSecureField(
                        title: L10n.passwordLabel,
                        placeholder: L10n.passwordPlaceholder,
                        text: $password,
                        isEnabled: !isVerifying
                    )

                    if let error = errorMessage {
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
                        isLoading: isVerifying,
                        isEnabled: !password.isEmpty && !isVerifying
                    ) {
                        Task {
                            await verifyPassword()
                        }
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
                    .disabled(isVerifying)
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
    }

    // MARK: - Verify Password

    private func verifyPassword() async {
        isVerifying = true
        errorMessage = nil

        do {
            let provider = StyxProvider()
            try await provider.initialize()

            let isValid = try await provider.verifyPassword(
                login + password
            )

            if isValid {
                onSuccess?(password)
                presentationMode.wrappedValue.dismiss()
            } else {
                errorMessage = L10n.errorInvalidPassword
            }
        } catch MuhrError.maxAttemptsExceeded {
            errorMessage = L10n.errorMaxAttemptsExceeded
        } catch {
            errorMessage = error.localizedDescription
        }

        isVerifying = false
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
