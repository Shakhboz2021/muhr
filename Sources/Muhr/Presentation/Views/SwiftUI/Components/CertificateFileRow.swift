//
//  CertificateFileRow.swift
//  Muhr
//
//  Created by Muhammad on 29/01/26.
//

import SwiftUI

@available(iOS 14.0, macOS 11.0, *)
public struct CertificateFileRow: View {

    // MARK: - Properties

    let file: CertificateFile
    let isSelected: Bool
    let onTap: () -> Void

    // MARK: - Init

    public init(
        file: CertificateFile,
        isSelected: Bool,
        onTap: @escaping () -> Void
    ) {
        self.file = file
        self.isSelected = isSelected
        self.onTap = onTap
    }

    // MARK: - Body

    public var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Icon
                Image(systemName: "doc.fill")
                    .font(.title2)
                    .foregroundColor(MuhrTheme.Colors.systemBlue)
                    .frame(width: 32)

                // Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(file.name)
                        .font(.body)
                        .foregroundColor(MuhrTheme.Colors.label)
                        .lineLimit(1)

                    Text(file.formattedSize)
                        .font(.caption)
                        .foregroundColor(MuhrTheme.Colors.secondaryLabel)
                }

                Spacer()

                // Checkmark (iOS native style)
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.semibold))
                        .foregroundColor(MuhrTheme.Colors.systemBlue)
                }
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview
#if DEBUG
    @available(iOS 14.0, macOS 11.0, *)
    struct CertificateFileRow_Previews: PreviewProvider {
        static var previews: some View {
            List {
                CertificateFileRow(
                    file: CertificateFile(
                        url: URL(fileURLWithPath: "/test/muhammad.p12")
                    ),
                    isSelected: false,
                    onTap: {}
                )

                CertificateFileRow(
                    file: CertificateFile(
                        url: URL(fileURLWithPath: "/test/company.pfx")
                    ),
                    isSelected: true,
                    onTap: {}
                )
            }
            .listStyle(.insetGrouped)
        }
    }
#endif
