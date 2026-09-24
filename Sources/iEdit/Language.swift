import Foundation

enum Language: String, CaseIterable {
    case plainText = "Plain Text"
    case json = "JSON"
    case html = "HTML"
    case css = "CSS"
    case javascript = "JavaScript"
    case xml = "XML"
    case swift = "Swift"
    case python = "Python"
    case markdown = "Markdown"
    case shell = "Shell Script"
    case sql = "SQL"
    case yaml = "YAML"

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
