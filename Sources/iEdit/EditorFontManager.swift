import Cocoa

/// Owns the single editor font used by every open tab. Changes are persisted to
/// `PreferencesStore` immediately and broadcast so live editors can restyle.
///
/// The stored value is a font *family* name (or nil for the system monospaced
/// font) plus a point size, so the choice survives across sessions.
final class EditorFontManager {
    static let shared = EditorFontManager()
    static let fontDidChangeNotification = Notification.Name("iEdit.editorFontDidChange")

    static let systemMonospaceLabel = "System Monospaced"
    static let defaultSize: CGFloat = 13
    static let minSize: CGFloat = 6
    static let maxSize: CGFloat = 72

    private(set) var font: NSFont
    /// nil means "the system monospaced font".
    private(set) var familyName: String?

    private init() {
        let prefs = PreferencesStore.shared
        let size = min(max(prefs.editorFontSize, EditorFontManager.minSize), EditorFontManager.maxSize)
        if size != prefs.editorFontSize { prefs.editorFontSize = size }

        let storedFamily = prefs.editorFontName
        if let storedFamily, let resolved = EditorFontManager.resolveFont(family: storedFamily, size: size) {
            familyName = storedFamily
            font = resolved
        } else {
            if storedFamily != nil { prefs.editorFontName = nil }
            familyName = nil
            font = NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
        }
    }

    /// Resolves a family name to a concrete regular-weight font, falling back to
    /// treating the name as a full PostScript font name.
    static func resolveFont(family: String, size: CGFloat) -> NSFont? {
        if let font = NSFontManager.shared.font(withFamily: family, traits: [], weight: 5, size: size) {
            return font
        }
        return NSFont(name: family, size: size)
    }

    /// Label for the current font, e.g. "Menlo 13".
    var displayDescription: String {
        "\(familyName ?? EditorFontManager.systemMonospaceLabel) \(Int(font.pointSize.rounded()))"
    }

    var size: CGFloat { font.pointSize }

    /// Sets the editor font. Pass `family: nil` for the system monospaced font.
    func setFont(family: String?, size: CGFloat) {
        let clamped = min(max(size, EditorFontManager.minSize), EditorFontManager.maxSize)
        if let family, let resolved = EditorFontManager.resolveFont(family: family, size: clamped) {
            familyName = family
            font = resolved
        } else {
            familyName = nil
            font = NSFont.monospacedSystemFont(ofSize: clamped, weight: .regular)
        }
        PreferencesStore.shared.editorFontName = familyName
        PreferencesStore.shared.editorFontSize = clamped
        NotificationCenter.default.post(name: EditorFontManager.fontDidChangeNotification, object: nil)
    }

    func resetToDefault() {
        setFont(family: nil, size: EditorFontManager.defaultSize)
    }

    /// A digit-aligned font scaled to the editor font, used by the line-number ruler
    /// so the gutter stays proportional to the code it labels.
    func rulerFont() -> NSFont {
        NSFont.monospacedDigitSystemFont(ofSize: max(8, font.pointSize - 2.5), weight: .regular)
    }

    /// Fixed-pitch font families available on this system, alphabetically sorted.
    static func availableMonospaceFamilies() -> [String] {
        let manager = NSFontManager.shared
        var families: [String] = []
        for family in manager.availableFontFamilies {
            guard let members = manager.availableMembers(ofFontFamily: family) else { continue }
            let isFixedPitch = members.contains { member in
                guard let name = member.first as? String, let font = NSFont(name: name, size: 12) else { return false }
                return font.isFixedPitch || font.fontDescriptor.symbolicTraits.contains(.monoSpace)
            }
            if isFixedPitch { families.append(family) }
        }
        return families.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }
}
