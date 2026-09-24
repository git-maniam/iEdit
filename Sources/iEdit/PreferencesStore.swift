import Foundation

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

    var wordWrapEnabled: Bool {
        get { defaults.object(forKey: "wordWrapEnabled") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "wordWrapEnabled") }
    }

    var theme: String {
        get { defaults.string(forKey: "theme") ?? ThemeID.system.rawValue }
        set { defaults.set(newValue, forKey: "theme") }
    }
}

