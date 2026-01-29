//
//  CertificatePickerView.swift
//  Muhr
//
//  Created by Muhammad on 29/01/26.
//

import SwiftUI

// MARK: - Certificate Picker View
@available(iOS 14.0, macOS 11.0, *)
public struct CertificatePickerView: View {

    @StateObject private var viewModel = CertificatePickerViewModel()

    // MARK: - Callbacks

    private let onInstallSuccess: ((CertificateInfo) -> Void)?
    private let onCancel: (() -> Void)?

    // MARK: - Init

    public init(
        onInstallSuccess: ((CertificateInfo) -> Void)? = nil,
        onCancel: (() -> Void)? = nil
    ) {
        self.onInstallSuccess = onInstallSuccess
        self.onCancel = onCancel
    }

    // MARK: - Body

    public var body: some View {
        NavigationView {
            content
                .navigationTitle("Сертификат ўрнатиш")
                #if os(iOS)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Бекор") {
                                viewModel.cancel()
                            }
                        }
                    }
                #else
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Бекор") {
                                viewModel.cancel()
                            }
                        }
                    }
                #endif
        }
        .onAppear {
            viewModel.onInstallSuccess = onInstallSuccess
            viewModel.onCancel = onCancel
            viewModel.loadFiles()
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if viewModel.files.isEmpty {
            emptyState
        } else {
            fileListContent
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.badge.plus")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("Сертификат топилмади")
                .font(.headline)

            Text("Documents папкасига .p12 ёки .pfx файлни қўшинг")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }

    // MARK: - File List Content

    private var fileListContent: some View {
        VStack(spacing: 0) {
            // File list
            List(viewModel.files, selection: $viewModel.selectedFile) { file in
                CertificateFileRow(
                    file: file,
                    isSelected: viewModel.selectedFile?.id == file.id
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    viewModel.selectedFile = file
                }
            }
            .listStyle(.plain)

            Divider()

            // Bottom section
            bottomSection
                .padding()
                #if os(iOS)
                    .background(Color(.systemBackground))
                #else
                    .background(Color(NSColor.windowBackgroundColor))
                #endif
        }
    }

    // MARK: - Bottom Section

    private var bottomSection: some View {
        VStack(spacing: 16) {
            // Password field
            SecureField("Сертификат пароли", text: $viewModel.password)
                #if os(iOS)
                    .textFieldStyle(.roundedBorder)
                #endif
                .disabled(viewModel.isLoading)

            // Error message
            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }

            // Install button
            Button(action: {
                Task {
                    await viewModel.install()
                }
            }) {
                HStack {
                    if viewModel.isLoading {
                        ProgressView()
                            #if os(iOS)
                                .progressViewStyle(
                                    CircularProgressViewStyle(tint: .white)
                                )
                            #endif
                    } else {
                        Text("Ўрнатиш")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.canInstall)
        }
    }
}

// MARK: - Certificate File Row
@available(iOS 14.0, macOS 11.0, *)
struct CertificateFileRow: View {

    let file: CertificateFile
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: "doc.badge.lock.fill")
                .font(.title2)
                .foregroundColor(.blue)

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(file.name)
                    .font(.body)
                    .lineLimit(1)

                Text(file.formattedSize)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Checkmark
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview
#if DEBUG
    @available(iOS 14.0, macOS 11.0, *)
    struct CertificatePickerView_Previews: PreviewProvider {
        static var previews: some View {
            CertificatePickerView()
        }
    }
#endif
