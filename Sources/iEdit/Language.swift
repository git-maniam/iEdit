import Foundation

enum Language: String, CaseIterable {
    case plainText = "Plain Text"
    case json = "JSON"
    case html = "HTML"
    case css = "CSS"
    case javascript = "JavaScript"
    case xml = "XML"

    static func detect(fromExtension ext: String) -> Language {
        switch ext.lowercased() {
        case "json": return .json
        case "html", "htm": return .html
        case "css": return .css
        case "js", "mjs", "cjs": return .javascript
        case "xml", "xhtml", "plist", "svg": return .xml
        default: return .plainText
        }
    }

    static func detect(fromURL url: URL?) -> Language {
        guard let url else { return .plainText }
        return detect(fromExtension: url.pathExtension)
    }
}
