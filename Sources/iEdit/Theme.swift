import Cocoa

enum ThemeID: String, CaseIterable {
    case system = "system"
    case editPlusClassic = "editplus_classic"
    case editPlusDark = "editplus_dark"
    case monokai = "monokai"
    case githubLight = "github_light"
    case githubDark = "github_dark"
    case solarizedLight = "solarized_light"
    case solarizedDark = "solarized_dark"
    case dracula = "dracula"

    var displayName: String {
        switch self {
        case .system: return "System (Auto Light/Dark)"
        case .editPlusClassic: return "EditPlus Classic (Light)"
        case .editPlusDark: return "EditPlus Dark"
        case .monokai: return "Monokai"
        case .githubLight: return "GitHub Light"
        case .githubDark: return "GitHub Dark"
        case .solarizedLight: return "Solarized Light"
        case .solarizedDark: return "Solarized Dark"
        case .dracula: return "Dracula"
        }
    }
}

struct AppTheme {
    let id: ThemeID
    let name: String
    let isDark: Bool
    let editorBackground: NSColor
    let editorForeground: NSColor
    let caretColor: NSColor
    let selectionBackground: NSColor
    let rulerBackground: NSColor
    let rulerForeground: NSColor
    let rulerBorder: NSColor

    // Syntax colors
    let keyword: NSColor
    let string: NSColor
    let number: NSColor
    let comment: NSColor
    let tag: NSColor
    let attribute: NSColor
    let key: NSColor
    let literal: NSColor
    let type: NSColor
}

final class ThemeManager {
    static let shared = ThemeManager()
    static let themeDidChangeNotification = Notification.Name("iEditThemeDidChangeNotification")

    private(set) var currentThemeID: ThemeID
    private(set) var currentTheme: AppTheme

    private init() {
        let savedRaw = PreferencesStore.shared.theme
        let initialID = ThemeID(rawValue: savedRaw) ?? .system
        self.currentThemeID = initialID
        self.currentTheme = Self.buildTheme(for: initialID)
    }

    func setTheme(_ id: ThemeID) {
        self.currentThemeID = id
        PreferencesStore.shared.theme = id.rawValue
        self.currentTheme = Self.buildTheme(for: id)
        NotificationCenter.default.post(name: Self.themeDidChangeNotification, object: currentTheme)
    }

    static func dynamicColor(light: NSColor, dark: NSColor) -> NSColor {
        NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
        }
    }

    static func buildTheme(for id: ThemeID) -> AppTheme {
        switch id {
        case .system:
            return AppTheme(
                id: .system,
                name: "System",
                isDark: false,
                editorBackground: NSColor.textBackgroundColor,
                editorForeground: NSColor.labelColor,
                caretColor: NSColor.labelColor,
                selectionBackground: NSColor.selectedTextBackgroundColor,
                rulerBackground: NSColor.windowBackgroundColor,
                rulerForeground: NSColor.secondaryLabelColor.withAlphaComponent(0.85),
                rulerBorder: NSColor.separatorColor.withAlphaComponent(0.6),
                keyword: dynamicColor(
                    light: NSColor(srgbRed: 0.00, green: 0.00, blue: 0.95, alpha: 1.0),
                    dark: NSColor(srgbRed: 0.35, green: 0.70, blue: 1.00, alpha: 1.0)
                ),
                string: dynamicColor(
                    light: NSColor(srgbRed: 0.65, green: 0.08, blue: 0.08, alpha: 1.0),
                    dark: NSColor(srgbRed: 1.00, green: 0.50, blue: 0.50, alpha: 1.0)
                ),
                number: dynamicColor(
                    light: NSColor(srgbRed: 0.00, green: 0.50, blue: 0.50, alpha: 1.0),
                    dark: NSColor(srgbRed: 0.20, green: 0.90, blue: 0.95, alpha: 1.0)
                ),
                comment: dynamicColor(
                    light: NSColor(srgbRed: 0.00, green: 0.52, blue: 0.00, alpha: 1.0),
                    dark: NSColor(srgbRed: 0.35, green: 0.88, blue: 0.45, alpha: 1.0)
                ),
                tag: dynamicColor(
                    light: NSColor(srgbRed: 0.00, green: 0.15, blue: 0.85, alpha: 1.0),
                    dark: NSColor(srgbRed: 0.40, green: 0.80, blue: 1.00, alpha: 1.0)
                ),
                attribute: dynamicColor(
                    light: NSColor(srgbRed: 0.55, green: 0.00, blue: 0.55, alpha: 1.0),
                    dark: NSColor(srgbRed: 0.92, green: 0.50, blue: 0.98, alpha: 1.0)
                ),
                key: dynamicColor(
                    light: NSColor(srgbRed: 0.02, green: 0.20, blue: 0.80, alpha: 1.0),
                    dark: NSColor(srgbRed: 0.35, green: 0.85, blue: 1.00, alpha: 1.0)
                ),
                literal: dynamicColor(
                    light: NSColor(srgbRed: 0.00, green: 0.00, blue: 0.95, alpha: 1.0),
                    dark: NSColor(srgbRed: 0.45, green: 0.75, blue: 1.00, alpha: 1.0)
                ),
                type: dynamicColor(
                    light: NSColor(srgbRed: 0.75, green: 0.35, blue: 0.00, alpha: 1.0),
                    dark: NSColor(srgbRed: 1.00, green: 0.75, blue: 0.30, alpha: 1.0)
                )
            )

        case .editPlusClassic:
            return AppTheme(
                id: .editPlusClassic,
                name: "EditPlus Classic",
                isDark: false,
                editorBackground: NSColor(srgbRed: 1.00, green: 1.00, blue: 1.00, alpha: 1.0),
                editorForeground: NSColor(srgbRed: 0.00, green: 0.00, blue: 0.00, alpha: 1.0),
                caretColor: NSColor.black,
                selectionBackground: NSColor(srgbRed: 0.70, green: 0.82, blue: 0.98, alpha: 1.0),
                rulerBackground: NSColor(srgbRed: 0.95, green: 0.95, blue: 0.96, alpha: 1.0),
                rulerForeground: NSColor(srgbRed: 0.50, green: 0.50, blue: 0.55, alpha: 1.0),
                rulerBorder: NSColor(srgbRed: 0.84, green: 0.84, blue: 0.86, alpha: 1.0),
                keyword: NSColor(srgbRed: 0.00, green: 0.00, blue: 0.95, alpha: 1.0),
                string: NSColor(srgbRed: 0.65, green: 0.08, blue: 0.08, alpha: 1.0),
                number: NSColor(srgbRed: 0.00, green: 0.50, blue: 0.50, alpha: 1.0),
                comment: NSColor(srgbRed: 0.00, green: 0.52, blue: 0.00, alpha: 1.0),
                tag: NSColor(srgbRed: 0.00, green: 0.15, blue: 0.85, alpha: 1.0),
                attribute: NSColor(srgbRed: 0.55, green: 0.00, blue: 0.55, alpha: 1.0),
                key: NSColor(srgbRed: 0.02, green: 0.20, blue: 0.80, alpha: 1.0),
                literal: NSColor(srgbRed: 0.00, green: 0.00, blue: 0.95, alpha: 1.0),
                type: NSColor(srgbRed: 0.75, green: 0.35, blue: 0.00, alpha: 1.0)
            )

        case .editPlusDark:
            return AppTheme(
                id: .editPlusDark,
                name: "EditPlus Dark",
                isDark: true,
                editorBackground: NSColor(srgbRed: 0.12, green: 0.13, blue: 0.15, alpha: 1.0),
                editorForeground: NSColor(srgbRed: 0.92, green: 0.93, blue: 0.95, alpha: 1.0),
                caretColor: NSColor.white,
                selectionBackground: NSColor(srgbRed: 0.22, green: 0.35, blue: 0.55, alpha: 1.0),
                rulerBackground: NSColor(srgbRed: 0.10, green: 0.11, blue: 0.13, alpha: 1.0),
                rulerForeground: NSColor(srgbRed: 0.45, green: 0.48, blue: 0.55, alpha: 1.0),
                rulerBorder: NSColor(srgbRed: 0.20, green: 0.22, blue: 0.25, alpha: 1.0),
                keyword: NSColor(srgbRed: 0.30, green: 0.70, blue: 1.00, alpha: 1.0),
                string: NSColor(srgbRed: 1.00, green: 0.50, blue: 0.50, alpha: 1.0),
                number: NSColor(srgbRed: 0.25, green: 0.90, blue: 0.95, alpha: 1.0),
                comment: NSColor(srgbRed: 0.35, green: 0.88, blue: 0.45, alpha: 1.0),
                tag: NSColor(srgbRed: 0.40, green: 0.80, blue: 1.00, alpha: 1.0),
                attribute: NSColor(srgbRed: 0.92, green: 0.50, blue: 0.98, alpha: 1.0),
                key: NSColor(srgbRed: 0.35, green: 0.85, blue: 1.00, alpha: 1.0),
                literal: NSColor(srgbRed: 0.45, green: 0.75, blue: 1.00, alpha: 1.0),
                type: NSColor(srgbRed: 1.00, green: 0.75, blue: 0.30, alpha: 1.0)
            )

        case .monokai:
            return AppTheme(
                id: .monokai,
                name: "Monokai",
                isDark: true,
                editorBackground: NSColor(srgbRed: 0.15, green: 0.16, blue: 0.13, alpha: 1.0),
                editorForeground: NSColor(srgbRed: 0.97, green: 0.97, blue: 0.95, alpha: 1.0),
                caretColor: NSColor(srgbRed: 0.97, green: 0.97, blue: 0.95, alpha: 1.0),
                selectionBackground: NSColor(srgbRed: 0.31, green: 0.31, blue: 0.28, alpha: 1.0),
                rulerBackground: NSColor(srgbRed: 0.12, green: 0.13, blue: 0.11, alpha: 1.0),
                rulerForeground: NSColor(srgbRed: 0.55, green: 0.55, blue: 0.50, alpha: 1.0),
                rulerBorder: NSColor(srgbRed: 0.22, green: 0.23, blue: 0.20, alpha: 1.0),
                keyword: NSColor(srgbRed: 0.98, green: 0.15, blue: 0.45, alpha: 1.0), // Pink
                string: NSColor(srgbRed: 0.90, green: 0.86, blue: 0.45, alpha: 1.0),  // Yellow
                number: NSColor(srgbRed: 0.68, green: 0.51, blue: 1.00, alpha: 1.0),  // Purple
                comment: NSColor(srgbRed: 0.46, green: 0.44, blue: 0.36, alpha: 1.0), // Muted Olive
                tag: NSColor(srgbRed: 0.98, green: 0.15, blue: 0.45, alpha: 1.0),
                attribute: NSColor(srgbRed: 0.65, green: 0.89, blue: 0.18, alpha: 1.0), // Green
                key: NSColor(srgbRed: 0.40, green: 0.85, blue: 0.94, alpha: 1.0),       // Cyan
                literal: NSColor(srgbRed: 0.68, green: 0.51, blue: 1.00, alpha: 1.0),
                type: NSColor(srgbRed: 0.40, green: 0.85, blue: 0.94, alpha: 1.0)
            )

        case .githubLight:
            return AppTheme(
                id: .githubLight,
                name: "GitHub Light",
                isDark: false,
                editorBackground: NSColor(srgbRed: 1.00, green: 1.00, blue: 1.00, alpha: 1.0),
                editorForeground: NSColor(srgbRed: 0.14, green: 0.16, blue: 0.18, alpha: 1.0),
                caretColor: NSColor(srgbRed: 0.14, green: 0.16, blue: 0.18, alpha: 1.0),
                selectionBackground: NSColor(srgbRed: 0.78, green: 0.88, blue: 0.98, alpha: 1.0),
                rulerBackground: NSColor(srgbRed: 0.98, green: 0.98, blue: 0.99, alpha: 1.0),
                rulerForeground: NSColor(srgbRed: 0.60, green: 0.62, blue: 0.65, alpha: 1.0),
                rulerBorder: NSColor(srgbRed: 0.90, green: 0.91, blue: 0.93, alpha: 1.0),
                keyword: NSColor(srgbRed: 0.84, green: 0.14, blue: 0.22, alpha: 1.0), // Red
                string: NSColor(srgbRed: 0.01, green: 0.20, blue: 0.55, alpha: 1.0),  // Navy
                number: NSColor(srgbRed: 0.00, green: 0.36, blue: 0.77, alpha: 1.0),  // Blue
                comment: NSColor(srgbRed: 0.42, green: 0.46, blue: 0.51, alpha: 1.0), // Slate
                tag: NSColor(srgbRed: 0.14, green: 0.55, blue: 0.24, alpha: 1.0),      // Green
                attribute: NSColor(srgbRed: 0.44, green: 0.26, blue: 0.76, alpha: 1.0), // Purple
                key: NSColor(srgbRed: 0.00, green: 0.36, blue: 0.77, alpha: 1.0),
                literal: NSColor(srgbRed: 0.00, green: 0.36, blue: 0.77, alpha: 1.0),
                type: NSColor(srgbRed: 0.44, green: 0.26, blue: 0.76, alpha: 1.0)
            )

        case .githubDark:
            return AppTheme(
                id: .githubDark,
                name: "GitHub Dark",
                isDark: true,
                editorBackground: NSColor(srgbRed: 0.05, green: 0.07, blue: 0.09, alpha: 1.0),
                editorForeground: NSColor(srgbRed: 0.79, green: 0.82, blue: 0.86, alpha: 1.0),
                caretColor: NSColor(srgbRed: 0.35, green: 0.65, blue: 1.00, alpha: 1.0),
                selectionBackground: NSColor(srgbRed: 0.16, green: 0.27, blue: 0.44, alpha: 1.0),
                rulerBackground: NSColor(srgbRed: 0.04, green: 0.05, blue: 0.07, alpha: 1.0),
                rulerForeground: NSColor(srgbRed: 0.40, green: 0.44, blue: 0.50, alpha: 1.0),
                rulerBorder: NSColor(srgbRed: 0.18, green: 0.21, blue: 0.25, alpha: 1.0),
                keyword: NSColor(srgbRed: 1.00, green: 0.48, blue: 0.53, alpha: 1.0), // Coral
                string: NSColor(srgbRed: 0.63, green: 0.85, blue: 1.00, alpha: 1.0),  // Light Blue
                number: NSColor(srgbRed: 0.47, green: 0.76, blue: 1.00, alpha: 1.0),  // Cyan
                comment: NSColor(srgbRed: 0.55, green: 0.59, blue: 0.64, alpha: 1.0), // Gray
                tag: NSColor(srgbRed: 0.44, green: 0.86, blue: 0.55, alpha: 1.0),      // Mint
                attribute: NSColor(srgbRed: 0.84, green: 0.67, blue: 1.00, alpha: 1.0), // Lavender
                key: NSColor(srgbRed: 0.47, green: 0.76, blue: 1.00, alpha: 1.0),
                literal: NSColor(srgbRed: 0.47, green: 0.76, blue: 1.00, alpha: 1.0),
                type: NSColor(srgbRed: 1.00, green: 0.65, blue: 0.42, alpha: 1.0)
            )

        case .solarizedLight:
            return AppTheme(
                id: .solarizedLight,
                name: "Solarized Light",
                isDark: false,
                editorBackground: NSColor(srgbRed: 0.99, green: 0.96, blue: 0.89, alpha: 1.0),
                editorForeground: NSColor(srgbRed: 0.40, green: 0.48, blue: 0.51, alpha: 1.0),
                caretColor: NSColor(srgbRed: 0.35, green: 0.43, blue: 0.46, alpha: 1.0),
                selectionBackground: NSColor(srgbRed: 0.93, green: 0.91, blue: 0.82, alpha: 1.0),
                rulerBackground: NSColor(srgbRed: 0.95, green: 0.93, blue: 0.86, alpha: 1.0),
                rulerForeground: NSColor(srgbRed: 0.58, green: 0.63, blue: 0.63, alpha: 1.0),
                rulerBorder: NSColor(srgbRed: 0.88, green: 0.86, blue: 0.79, alpha: 1.0),
                keyword: NSColor(srgbRed: 0.52, green: 0.60, blue: 0.00, alpha: 1.0), // Green
                string: NSColor(srgbRed: 0.16, green: 0.63, blue: 0.60, alpha: 1.0),  // Cyan
                number: NSColor(srgbRed: 0.83, green: 0.21, blue: 0.51, alpha: 1.0),  // Magenta
                comment: NSColor(srgbRed: 0.58, green: 0.63, blue: 0.63, alpha: 1.0),
                tag: NSColor(srgbRed: 0.15, green: 0.55, blue: 0.82, alpha: 1.0),      // Blue
                attribute: NSColor(srgbRed: 0.71, green: 0.54, blue: 0.00, alpha: 1.0), // Yellow
                key: NSColor(srgbRed: 0.15, green: 0.55, blue: 0.82, alpha: 1.0),
                literal: NSColor(srgbRed: 0.83, green: 0.21, blue: 0.51, alpha: 1.0),
                type: NSColor(srgbRed: 0.71, green: 0.54, blue: 0.00, alpha: 1.0)
            )

        case .solarizedDark:
            return AppTheme(
                id: .solarizedDark,
                name: "Solarized Dark",
                isDark: true,
                editorBackground: NSColor(srgbRed: 0.00, green: 0.17, blue: 0.21, alpha: 1.0),
                editorForeground: NSColor(srgbRed: 0.51, green: 0.58, blue: 0.59, alpha: 1.0),
                caretColor: NSColor(srgbRed: 0.58, green: 0.63, blue: 0.63, alpha: 1.0),
                selectionBackground: NSColor(srgbRed: 0.03, green: 0.21, blue: 0.26, alpha: 1.0),
                rulerBackground: NSColor(srgbRed: 0.00, green: 0.14, blue: 0.17, alpha: 1.0),
                rulerForeground: NSColor(srgbRed: 0.35, green: 0.43, blue: 0.46, alpha: 1.0),
                rulerBorder: NSColor(srgbRed: 0.05, green: 0.23, blue: 0.28, alpha: 1.0),
                keyword: NSColor(srgbRed: 0.52, green: 0.60, blue: 0.00, alpha: 1.0),
                string: NSColor(srgbRed: 0.16, green: 0.63, blue: 0.60, alpha: 1.0),
                number: NSColor(srgbRed: 0.83, green: 0.21, blue: 0.51, alpha: 1.0),
                comment: NSColor(srgbRed: 0.35, green: 0.43, blue: 0.46, alpha: 1.0),
                tag: NSColor(srgbRed: 0.15, green: 0.55, blue: 0.82, alpha: 1.0),
                attribute: NSColor(srgbRed: 0.71, green: 0.54, blue: 0.00, alpha: 1.0),
                key: NSColor(srgbRed: 0.15, green: 0.55, blue: 0.82, alpha: 1.0),
                literal: NSColor(srgbRed: 0.83, green: 0.21, blue: 0.51, alpha: 1.0),
                type: NSColor(srgbRed: 0.71, green: 0.54, blue: 0.00, alpha: 1.0)
            )

        case .dracula:
            return AppTheme(
                id: .dracula,
                name: "Dracula",
                isDark: true,
                editorBackground: NSColor(srgbRed: 0.16, green: 0.16, blue: 0.21, alpha: 1.0),
                editorForeground: NSColor(srgbRed: 0.95, green: 0.95, blue: 0.96, alpha: 1.0),
                caretColor: NSColor(srgbRed: 0.95, green: 0.95, blue: 0.96, alpha: 1.0),
                selectionBackground: NSColor(srgbRed: 0.27, green: 0.28, blue: 0.35, alpha: 1.0),
                rulerBackground: NSColor(srgbRed: 0.13, green: 0.13, blue: 0.18, alpha: 1.0),
                rulerForeground: NSColor(srgbRed: 0.38, green: 0.44, blue: 0.64, alpha: 1.0),
                rulerBorder: NSColor(srgbRed: 0.22, green: 0.23, blue: 0.30, alpha: 1.0),
                keyword: NSColor(srgbRed: 1.00, green: 0.48, blue: 0.64, alpha: 1.0), // Pink
                string: NSColor(srgbRed: 0.95, green: 0.98, blue: 0.55, alpha: 1.0),  // Yellow
                number: NSColor(srgbRed: 0.74, green: 0.58, blue: 0.98, alpha: 1.0),  // Purple
                comment: NSColor(srgbRed: 0.38, green: 0.44, blue: 0.64, alpha: 1.0), // Blue-Gray
                tag: NSColor(srgbRed: 1.00, green: 0.48, blue: 0.64, alpha: 1.0),
                attribute: NSColor(srgbRed: 0.31, green: 0.98, blue: 0.48, alpha: 1.0), // Green
                key: NSColor(srgbRed: 0.55, green: 0.91, blue: 0.99, alpha: 1.0),       // Cyan
                literal: NSColor(srgbRed: 0.74, green: 0.58, blue: 0.98, alpha: 1.0),
                type: NSColor(srgbRed: 0.55, green: 0.91, blue: 0.99, alpha: 1.0)
            )
        }
    }
}
