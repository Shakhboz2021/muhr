//
//  CertificatePickerView.swift
//  Muhr
//
//  Created by Muhammad on 29/01/26.
//

import SwiftUI

@available(iOS 14.0, macOS 11.0, *)
public struct CertificatePickerView: View {

    @StateObject private var viewModel = CertificatePickerViewModel()
    @Environment(\.presentationMode) var presentationMode

    @State private var isPasswordVisible = false
    @Binding private var login: String

    // MARK: - Callbacks

    private let onInstallSuccess: ((CertificateInfo) -> Void)?
    private let onCancel: (() -> Void)?

    // MARK: - Init

    public init(
        login: Binding<String>,
        onInstallSuccess: ((CertificateInfo) -> Void)? = nil,
        onCancel: (() -> Void)? = nil
    ) {
        self._login = login
        self.onInstallSuccess = onInstallSuccess
        self.onCancel = onCancel
    }

    // MARK: - Body

    public var body: some View {
        NavigationView {
            content
                .navigationTitle(L10n.certificateTitle)
                #if os(iOS)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(L10n.cancel) {
                                handleCancel()
                            }
                        }
                    }
                #else
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(L10n.cancel) {
                                handleCancel()
                            }
                        }
                    }
                #endif
        }
        .onAppear {
            viewModel.onInstallSuccess = { cert in
                onInstallSuccess?(cert)
            }
            viewModel.onCancel = {
                handleCancel()
            }
            viewModel.loadFiles()
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if viewModel.files.isEmpty {
            emptyState
        } else {
            mainContent
        }
    }

    // MARK: - Empty State (Full Screen)

    private var emptyState: some View {
        ZStack {
            MuhrTheme.Colors.systemGroupedBackground
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "doc.badge.plus")
                    .font(.system(size: 56))
                    .foregroundColor(MuhrTheme.Colors.tertiaryLabel)

                Text(L10n.certificateNotFound)
                    .font(.headline)
                    .foregroundColor(MuhrTheme.Colors.label)

                Text(L10n.certificateInstruction)
                    .font(.subheadline)
                    .foregroundColor(MuhrTheme.Colors.secondaryLabel)
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - Main Content (List + Fixed Bottom)

    private var mainContent: some View {
        ZStack {
            MuhrTheme.Colors.systemGroupedBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Scrollable list
                Spacer()
                List {
                    Section(header: Text(L10n.selectCertificateTitle)) {
                        ForEach(viewModel.files) { file in
                            CertificateFileRow(
                                file: file,
                                isSelected: viewModel.selectedFile?.id
                                    == file.id,
                                onTap: {
                                    viewModel.selectedFile = file
                                }
                            )
                        }
                    }
                }
                #if os(iOS)
                    .listStyle(InsetGroupedListStyle())
                #elseif os(macOS)
                    .listStyle(SidebarListStyle())
                #endif

                // Fixed bottom section
                bottomSection
            }
        }
    }

    // MARK: - Bottom Section (Fixed)

    private var bottomSection: some View {
        VStack(spacing: 16) {
            // Password field
            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.passwordLabel)
                    .font(.caption)
                    .foregroundColor(MuhrTheme.Colors.secondaryLabel)

                HStack {
                    if isPasswordVisible {
                        TextField(
                            L10n.passwordPlaceholder,
                            text: $viewModel.password,
                            onCommit: {
                                install(login: $login)
                            }
                        )
                        #if os(iOS)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                        #endif
                    } else {
                        SecureField(
                            L10n.passwordPlaceholder,
                            text: $viewModel.password,
                            onCommit: {
                                install(login: $login)
                            }
                        )
                    }

                    Button(action: { isPasswordVisible.toggle() }) {
                        Image(
                            systemName: isPasswordVisible ? "eye.slash" : "eye"
                        )
                        .foregroundColor(MuhrTheme.Colors.tertiaryLabel)
                    }
                    .buttonStyle(.plain)
                }
                .padding(12)
                .background(MuhrTheme.Colors.secondarySystemGroupedBackground)
                .cornerRadius(10)
                .disabled(viewModel.isLoading)

                // Error message
                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(MuhrTheme.Colors.systemRed)
                }
            }

            // Install button
            MuhrButton(
                title: L10n.installButton,
                isLoading: viewModel.isLoading,
                isEnabled: viewModel.canInstall
            ) {
                install(login: $login)
            }
        }
        .padding(16)
        .background(
            MuhrTheme.Colors.systemGroupedBackground
                .shadow(
                    color: Color.black.opacity(0.05),
                    radius: 8,
                    x: 0,
                    y: -4
                )
        )
    }

    // MARK: - Actions

    private func install(login: Binding<String>) {
        guard viewModel.canInstall else { return }
        Task {
            await viewModel.install(login: login.wrappedValue)
        }
    }

    private func handleCancel() {
        onCancel?()
        presentationMode.wrappedValue.dismiss()
    }
}
