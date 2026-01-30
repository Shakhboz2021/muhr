//
//  MuhrButton.swift
//  Muhr
//
//  Created by Muhammad on 29/01/26.
//

import SwiftUI

@available(iOS 14.0, macOS 11.0, *)
public struct MuhrButton: View {

    // MARK: - Properties

    let title: String
    let isLoading: Bool
    let isEnabled: Bool
    let action: () -> Void

    // MARK: - Init

    public init(
        title: String,
        isLoading: Bool = false,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.isLoading = isLoading
        self.isEnabled = isEnabled
        self.action = action
    }

    // MARK: - Body

    public var body: some View {
        Button(action: {
            if isEnabled && !isLoading {
                action()
            }
        }) {
            HStack {
                Spacer()

                if isLoading {
                    ProgressView()
                        .progressViewStyle(
                            CircularProgressViewStyle(tint: .white)
                        )
                } else {
                    Text(title)
                        .fontWeight(.semibold)
                }

                Spacer()
            }
            .padding(.vertical, 14)
            .background(
                isEnabled && !isLoading
                    ? MuhrTheme.Colors.systemBlue
                    : MuhrTheme.Colors.systemGray4
            )
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled || isLoading)
    }
}

// MARK: - Secondary Button
@available(iOS 14.0, macOS 11.0, *)
public struct MuhrSecondaryButton: View {

    let title: String
    let action: () -> Void

    public init(title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(title)
                .fontWeight(.regular)
                .foregroundColor(MuhrTheme.Colors.systemBlue)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Destructive Button
@available(iOS 14.0, macOS 11.0, *)
public struct MuhrDestructiveButton: View {

    let title: String
    let action: () -> Void

    public init(title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack {
                Spacer()
                Text(title)
                    .fontWeight(.semibold)
                Spacer()
            }
            .padding(.vertical, 14)
            .background(MuhrTheme.Colors.systemRed)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview
#if DEBUG
    @available(iOS 14.0, macOS 11.0, *)
    struct MuhrButton_Previews: PreviewProvider {
        static var previews: some View {
            VStack(spacing: 16) {
                MuhrButton(title: L10n.installButton) {}
                MuhrButton(title: L10n.installButton, isLoading: true) {}
                MuhrButton(title: L10n.installButton, isEnabled: false) {}
                MuhrSecondaryButton(title: L10n.cancel) {}
                MuhrDestructiveButton(title: L10n.deleteButton) {}
            }
            .padding()
        }
    }
#endif
