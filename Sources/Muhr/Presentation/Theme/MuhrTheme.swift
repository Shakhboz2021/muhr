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

    // MARK: - Colors (Semantic System Colors)
    public enum Colors {

        // MARK: - Labels
        public static let label: Color = {
            #if os(iOS)
                Color(UIColor.label)
            #elseif os(macOS)
                Color(NSColor.labelColor)
            #endif
        }()

        public static let secondaryLabel: Color = {
            #if os(iOS)
                Color(UIColor.secondaryLabel)
            #elseif os(macOS)
                Color(NSColor.secondaryLabelColor)
            #endif
        }()

        public static let tertiaryLabel: Color = {
            #if os(iOS)
                Color(UIColor.tertiaryLabel)
            #elseif os(macOS)
                Color(NSColor.tertiaryLabelColor)
            #endif
        }()

        // MARK: - Backgrounds
        public static let systemBackground: Color = {
            #if os(iOS)
                Color(UIColor.systemBackground)
            #elseif os(macOS)
                Color(NSColor.windowBackgroundColor)
            #endif
        }()

        public static let secondarySystemBackground: Color = {
            #if os(iOS)
                Color(UIColor.secondarySystemBackground)
            #elseif os(macOS)
                Color(NSColor.controlBackgroundColor)
            #endif
        }()

        public static let tertiarySystemBackground: Color = {
            #if os(iOS)
                Color(UIColor.tertiarySystemBackground)
            #elseif os(macOS)
                Color(NSColor.textBackgroundColor)
            #endif
        }()

        public static let systemGroupedBackground: Color = {
            #if os(iOS)
                Color(UIColor.systemGroupedBackground)
            #elseif os(macOS)
                Color(NSColor.windowBackgroundColor)
            #endif
        }()

        public static let secondarySystemGroupedBackground: Color = {
            #if os(iOS)
                Color(UIColor.secondarySystemGroupedBackground)
            #elseif os(macOS)
                Color(NSColor.controlBackgroundColor)
            #endif
        }()

        // MARK: - Fills
        public static let systemFill: Color = {
            #if os(iOS)
                Color(UIColor.systemFill)
            #elseif os(macOS)
                Color(NSColor.quaternaryLabelColor)
            #endif
        }()

        public static let secondarySystemFill: Color = {
            #if os(iOS)
                Color(UIColor.secondarySystemFill)
            #elseif os(macOS)
                Color(NSColor.tertiaryLabelColor)
            #endif
        }()

        public static let tertiarySystemFill: Color = {
            #if os(iOS)
                Color(UIColor.tertiarySystemFill)
            #elseif os(macOS)
                Color(NSColor.secondaryLabelColor)
            #endif
        }()

        // MARK: - Separators
        public static let separator: Color = {
            #if os(iOS)
                Color(UIColor.separator)
            #elseif os(macOS)
                Color(NSColor.separatorColor)
            #endif
        }()

        public static let opaqueSeparator: Color = {
            #if os(iOS)
                Color(UIColor.opaqueSeparator)
            #elseif os(macOS)
                Color(NSColor.gridColor)
            #endif
        }()

        // MARK: - System Accent Colors
        public static let systemBlue: Color = {
            #if os(iOS)
                Color(UIColor.systemBlue)
            #elseif os(macOS)
                Color(NSColor.systemBlue)
            #endif
        }()

        public static let systemGreen: Color = {
            #if os(iOS)
                Color(UIColor.systemGreen)
            #elseif os(macOS)
                Color(NSColor.systemGreen)
            #endif
        }()

        public static let systemRed: Color = {
            #if os(iOS)
                Color(UIColor.systemRed)
            #elseif os(macOS)
                Color(NSColor.systemRed)
            #endif
        }()

        public static let systemOrange: Color = {
            #if os(iOS)
                Color(UIColor.systemOrange)
            #elseif os(macOS)
                Color(NSColor.systemOrange)
            #endif
        }()

        public static let systemGray: Color = {
            #if os(iOS)
                Color(UIColor.systemGray)
            #elseif os(macOS)
                Color(NSColor.systemGray)
            #endif
        }()

        public static let systemGray2: Color = {
            #if os(iOS)
                Color(UIColor.systemGray2)
            #elseif os(macOS)
                Color(NSColor.systemGray)
            #endif
        }()

        public static let systemGray3: Color = {
            #if os(iOS)
                Color(UIColor.systemGray3)
            #elseif os(macOS)
                Color(NSColor.systemGray)
            #endif
        }()

        public static let systemGray4: Color = {
            #if os(iOS)
                Color(UIColor.systemGray4)
            #elseif os(macOS)
                Color(NSColor.systemGray)
            #endif
        }()

        public static let systemGray5: Color = {
            #if os(iOS)
                Color(UIColor.systemGray5)
            #elseif os(macOS)
                Color(NSColor.systemGray)
            #endif
        }()

        public static let systemGray6: Color = {
            #if os(iOS)
                Color(UIColor.systemGray6)
            #elseif os(macOS)
                Color(NSColor.systemGray)
            #endif
        }()
    }
}
