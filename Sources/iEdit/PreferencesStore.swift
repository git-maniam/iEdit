import Cocoa

final class PreferencesStore {
    static let shared = PreferencesStore()

    private let defaults = UserDefaults.standard

    var tabWidth: Int {
        get { defaults.object(forKey: "tabWidth") as? Int ?? 4 }
        set { defaults.set(newValue, forKey: "tabWidth") }
    }

    var useSpaces: Bool {
        get { defaults.object(forKey: "useSpaces") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "useSpaces") }
    }

    /// Word wrap is an app-wide setting: toggling it applies to every open tab,
    /// to tabs opened later, and persists across sessions.
    static let wordWrapDidChangeNotification = Notification.Name("iEdit.wordWrapDidChange")

    var wordWrapEnabled: Bool {
        get { defaults.object(forKey: "wordWrapEnabled") as? Bool ?? true }
        set {
            guard newValue != wordWrapEnabled else { return }
            defaults.set(newValue, forKey: "wordWrapEnabled")
            NotificationCenter.default.post(name: PreferencesStore.wordWrapDidChangeNotification, object: nil)
        }
    }

    var theme: String {
        get { defaults.string(forKey: "theme") ?? ThemeID.system.rawValue }
        set { defaults.set(newValue, forKey: "theme") }
    }

    // MARK: - Editor font

    var editorFontName: String? {
        get { defaults.string(forKey: "editorFontName") }
        set { defaults.set(newValue, forKey: "editorFontName") }
    }

    var editorFontSize: CGFloat {
        get {
            let stored = defaults.double(forKey: "editorFontSize")
            return stored > 0 ? CGFloat(stored) : 13
        }
        set { defaults.set(Double(newValue), forKey: "editorFontSize") }
    }

    // MARK: - Session

    /// Absolute paths of the on-disk files that were open when the app last quit,
    /// in tab order. Untitled/unsaved tabs are intentionally not persisted.
    var sessionFilePaths: [String] {
        get { defaults.stringArray(forKey: "sessionFilePaths") ?? [] }
        set { defaults.set(newValue, forKey: "sessionFilePaths") }
    }

    /// Index into `sessionFilePaths` of the tab that was active, or -1 if none.
    var sessionActiveIndex: Int {
        get { defaults.object(forKey: "sessionActiveIndex") as? Int ?? -1 }
        set { defaults.set(newValue, forKey: "sessionActiveIndex") }
    }

    /// Folder shown in the sidebar tree when the app last quit.
    var sessionFolderPath: String? {
        get { defaults.string(forKey: "sessionFolderPath") }
        set { defaults.set(newValue, forKey: "sessionFolderPath") }
    }
}
