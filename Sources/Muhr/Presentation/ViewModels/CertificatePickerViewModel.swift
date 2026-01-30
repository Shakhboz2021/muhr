//
//  CertificatePickerViewModel.swift
//  Muhr
//
//  Created by Muhammad on 29/01/26.
//

import Combine
import Foundation

// MARK: - Certificate File Model
public struct CertificateFile: Identifiable, Hashable {
    public let id: String
    public let url: URL
    public let name: String
    public let size: Int64
    public let modifiedDate: Date

    public init(url: URL) {
        self.id = url.absoluteString
        self.url = url
        self.name = url.lastPathComponent

        let attributes = try? FileManager.default.attributesOfItem(
            atPath: url.path
        )
        self.size = attributes?[.size] as? Int64 ?? 0
        self.modifiedDate = attributes?[.modificationDate] as? Date ?? Date()
    }

    /// Fayl hajmi (formatted)
    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}

// MARK: - Install State
public enum CertificateInstallState: Equatable {
    case idle
    case loading
    case success(CertificateInfo)
    case error(String)
}

// MARK: - ViewModel
@MainActor
public final class CertificatePickerViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published public private(set) var files: [CertificateFile] = []
    @Published public var selectedFile: CertificateFile?
    @Published public var password: String = ""
    @Published public private(set) var state: CertificateInstallState = .idle

    // MARK: - Computed Properties

    public var canInstall: Bool {
        selectedFile != nil && !password.isEmpty && state != .loading
    }

    public var isLoading: Bool {
        state == .loading
    }

    public var errorMessage: String? {
        if case .error(let message) = state {
            return message
        }
        return nil
    }

    public var installedCertificate: CertificateInfo? {
        if case .success(let cert) = state {
            return cert
        }
        return nil
    }

    // MARK: - Callbacks

    public var onInstallSuccess: ((CertificateInfo) -> Void)?
    public var onCancel: (() -> Void)?

    // MARK: - Init

    public init() {}

    // MARK: - Public Methods

    /// Documents directory'dan .p12/.pfx fayllarni yuklash
    public func loadFiles() {
        files = discoverCertificateFiles()

        // Agar bitta fayl bo'lsa, avtomatik tanlash
        if files.count == 1 {
            selectedFile = files.first
        }
    }

    /// Tanlangan faylni install qilish
    public func install(login: String) async {
        guard let file = selectedFile else { return }
        guard !password.isEmpty else { return }

        state = .loading

        do {
            let cert = try await Muhr.importCertificate(
                fileURL: file.url,
                password: password,
                login: login
            )

            state = .success(cert)
            onInstallSuccess?(cert)

        } catch MuhrError.invalidCertificatePassword {
            state = .error(L10n.errorInvalidPassword)
        } catch MuhrError.invalidCertificateFormat {
            state = .error(L10n.errorInvalidFormat)
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    /// Holatni tozalash
    public func reset() {
        selectedFile = nil
        password = ""
        state = .idle
    }

    /// Bekor qilish
    public func cancel() {
        onCancel?()
    }

    // MARK: - Private Methods

    private func discoverCertificateFiles() -> [CertificateFile] {
        guard
            let documentsURL = FileManager.default.urls(
                for: .documentDirectory,
                in: .userDomainMask
            ).first
        else {
            return []
        }

        do {
            let files = try FileManager.default.contentsOfDirectory(
                at: documentsURL,
                includingPropertiesForKeys: [
                    .fileSizeKey, .contentModificationDateKey,
                ]
            )

            return
                files
                .filter { url in
                    let ext = url.pathExtension.lowercased()
                    return ext == "p12" || ext == "pfx"
                }
                .map { CertificateFile(url: $0) }
                .sorted { $0.name < $1.name }

        } catch {
            #if DEBUG
                print("❌ Failed to list documents: \(error)")
            #endif
            return []
        }
    }
}
