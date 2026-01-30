//
//  MuhrSecureField.swift
//  Muhr
//
//  Created by Muhammad on 29/01/26.
//

import SwiftUI

@available(iOS 14.0, macOS 11.0, *)
public struct MuhrSecureField: View {

    // MARK: - Properties

    let title: String
    let placeholder: String
    @Binding var text: String
    var isEnabled: Bool = true

    @State private var isSecure: Bool = true

    // MARK: - Init

    public init(
        title: String,
        placeholder: String = "",
        text: Binding<String>,
        isEnabled: Bool = true
    ) {
        self.title = title
        self.placeholder = placeholder
        self._text = text
        self.isEnabled = isEnabled
    }

    // MARK: - Body

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Title (iOS Settings style)
            if !title.isEmpty {
                Text(title)
                    .font(.footnote)
                    .foregroundColor(MuhrTheme.Colors.secondaryLabel)
                    .textCase(.uppercase)
                    .padding(.horizontal, 16)
            }

            // Input row (iOS native style)
            HStack {
                Group {
                    if isSecure {
                        SecureField(placeholder, text: $text)
                    } else {
                        TextField(placeholder, text: $text)
                    }
                }
                .disabled(!isEnabled)
                #if os(iOS)
                    .textContentType(.password)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                #endif

                Button(action: { isSecure.toggle() }) {
                    Image(systemName: isSecure ? "eye.slash" : "eye")
                        .foregroundColor(MuhrTheme.Colors.tertiaryLabel)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .background(MuhrTheme.Colors.secondarySystemGroupedBackground)
            .cornerRadius(10)
        }
    }
}

// MARK: - Preview
#if DEBUG
    @available(iOS 14.0, macOS 11.0, *)
    struct MuhrSecureField_Previews: PreviewProvider {
        static var previews: some View {
            ZStack {
                MuhrTheme.Colors.systemGroupedBackground
                    .ignoresSafeArea()

                VStack(spacing: 20) {
                    MuhrSecureField(
                        title: "Пароль",
                        placeholder: "Паролни киритинг",
                        text: .constant("")
                    )

                    MuhrSecureField(
                        title: "",
                        placeholder: "Паролни киритинг",
                        text: .constant("secret123")
                    )
                }
                .padding()
            }
        }
    }
#endif
