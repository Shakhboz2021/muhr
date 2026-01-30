//
//  MuhrTheme.swift
//  Muhr
//
//  Created by Muhammad on 29/01/26.
//

import SwiftUI

// MARK: - Muhr Theme (Cupertino Style)
@available(iOS 14.0, macOS 11.0, *)
public enum MuhrTheme {

    // MARK: - Colors (Semantic iOS Colors)
    public enum Colors {
        // Labels
        public static let label = Color(.label)
        public static let secondaryLabel = Color(.secondaryLabel)
        public static let tertiaryLabel = Color(.tertiaryLabel)

        // Backgrounds
        public static let systemBackground = Color(.systemBackground)
        public static let secondarySystemBackground = Color(
            .secondarySystemBackground
        )
        public static let tertiarySystemBackground = Color(
            .tertiarySystemBackground
        )
        public static let systemGroupedBackground = Color(
            .systemGroupedBackground
        )
        public static let secondarySystemGroupedBackground = Color(
            .secondarySystemGroupedBackground
        )

        // Fills
        public static let systemFill = Color(.systemFill)
        public static let secondarySystemFill = Color(.secondarySystemFill)
        public static let tertiarySystemFill = Color(.tertiarySystemFill)

        // Separators
        public static let separator = Color(.separator)
        public static let opaqueSeparator = Color(.opaqueSeparator)

        // System Colors
        public static let systemBlue = Color(.systemBlue)
        public static let systemGreen = Color(.systemGreen)
        public static let systemRed = Color(.systemRed)
        public static let systemOrange = Color(.systemOrange)
        public static let systemGray = Color(.systemGray)
        public static let systemGray2 = Color(.systemGray2)
        public static let systemGray3 = Color(.systemGray3)
        public static let systemGray4 = Color(.systemGray4)
        public static let systemGray5 = Color(.systemGray5)
        public static let systemGray6 = Color(.systemGray6)
    }
}
