import Foundation

enum Language: String, CaseIterable {
    case plainText = "Text"
    case json = "JSON"
    case html = "HTML"
    case css = "CSS"
    case javascript = "JavaScript"
    case xml = "XML"
    case swift = "Swift"
    case python = "Python"
    case go = "Go"
    case markdown = "Markdown"
    case shell = "Shell Script"
    case sql = "SQL"
    case yaml = "YAML"

    /// The highlighters offered in the Format menu, alphabetically sorted.
    /// Languages outside this list (Swift, Markdown, Shell Script, SQL) are still
    /// applied automatically when a matching file is opened.
    static let menuSelectable: [Language] = [
        .css, .go, .html, .javascript, .json, .python, .plainText, .xml, .yaml,
    ]

    /// Extension suggested in the Save panel for a document using this highlighter.
    var defaultExtension: String {
        switch self {
        case .plainText: return "txt"
        case .json: return "json"
        case .html: return "html"
        case .css: return "css"
        case .javascript: return "js"
        case .xml: return "xml"
        case .swift: return "swift"
        case .python: return "py"
        case .go: return "go"
        case .markdown: return "md"
        case .shell: return "sh"
        case .sql: return "sql"
        case .yaml: return "yaml"
        }
    }

    static func detect(fromExtension ext: String) -> Language {
        switch ext.lowercased() {
        case "json":
            return .json
        case "html", "htm":
            return .html
        case "css", "scss", "sass", "less":
            return .css
        case "js", "mjs", "cjs", "ts", "tsx", "jsx":
            return .javascript
        case "xml", "xhtml", "plist", "svg":
            return .xml
        case "swift":
            return .swift
        case "py", "pyw", "python":
            return .python
        case "go":
            return .go
        case "md", "markdown", "mdown":
            return .markdown
        case "sh", "bash", "zsh", "fish":
            return .shell
        case "sql":
            return .sql
        case "yaml", "yml":
            return .yaml
        default:
            return .plainText
        }
    }

    static func detect(fromURL url: URL?) -> Language {
        guard let url else { return .plainText }
        return detect(fromExtension: url.pathExtension)
    }
}
