import Cocoa

struct TokenRule {
    let regex: NSRegularExpression
    let color: NSColor

    init(pattern: String, color: NSColor, options: NSRegularExpression.Options = []) {
        self.regex = try! NSRegularExpression(pattern: pattern, options: options)
        self.color = color
    }
}

enum SyntaxColors {
    static let keyword = NSColor.systemPink
    static let string = NSColor.systemRed
    static let number = NSColor.systemBlue
    static let comment = NSColor.systemGreen
    static let tag = NSColor.systemPurple
    static let attribute = NSColor.systemOrange
    static let key = NSColor.systemBlue
    static let literal = NSColor.systemPurple
    static let plain = NSColor.labelColor
}

final class SyntaxHighlighter {

    private static let jsonRules: [TokenRule] = [
        TokenRule(pattern: "\"(?:\\\\.|[^\"\\\\])*\"\\s*(?=:)", color: SyntaxColors.key),
        TokenRule(pattern: "\"(?:\\\\.|[^\"\\\\])*\"", color: SyntaxColors.string),
        TokenRule(pattern: "\\b(true|false|null)\\b", color: SyntaxColors.literal),
        TokenRule(pattern: "-?\\b\\d+(\\.\\d+)?([eE][+-]?\\d+)?\\b", color: SyntaxColors.number),
    ]

    private static let htmlRules: [TokenRule] = [
        TokenRule(pattern: "<!--[\\s\\S]*?-->", color: SyntaxColors.comment),
        TokenRule(pattern: "</?[A-Za-z][A-Za-z0-9:-]*", color: SyntaxColors.tag),
        TokenRule(pattern: "/?>", color: SyntaxColors.tag),
        TokenRule(pattern: "\\b[A-Za-z-]+(?=\\s*=)", color: SyntaxColors.attribute),
        TokenRule(pattern: "\"[^\"]*\"|'[^']*'", color: SyntaxColors.string),
    ]

    private static let xmlRules: [TokenRule] = htmlRules

    private static let cssRules: [TokenRule] = [
        TokenRule(pattern: "/\\*[\\s\\S]*?\\*/", color: SyntaxColors.comment),
        TokenRule(pattern: "[.#]?[-A-Za-z0-9_]+(?=\\s*\\{)", color: SyntaxColors.tag),
        TokenRule(pattern: "[-A-Za-z]+(?=\\s*:)", color: SyntaxColors.attribute),
        TokenRule(pattern: "\"[^\"]*\"|'[^']*'", color: SyntaxColors.string),
        TokenRule(pattern: "#[0-9A-Fa-f]{3,8}\\b", color: SyntaxColors.number),
        TokenRule(pattern: "-?\\b\\d+(\\.\\d+)?(px|em|rem|%|vh|vw|pt)?\\b", color: SyntaxColors.number),
    ]

    private static let jsKeywords = "\\b(var|let|const|function|return|if|else|for|while|do|switch|case|break|continue|class|extends|new|this|super|import|export|default|try|catch|finally|throw|typeof|instanceof|in|of|async|await|yield|null|undefined|true|false|static|get|set)\\b"

    private static let jsRules: [TokenRule] = [
        TokenRule(pattern: "//.*", color: SyntaxColors.comment),
        TokenRule(pattern: "/\\*[\\s\\S]*?\\*/", color: SyntaxColors.comment),
        TokenRule(pattern: "\"(?:\\\\.|[^\"\\\\])*\"|'(?:\\\\.|[^'\\\\])*'|`(?:\\\\.|[^`\\\\])*`", color: SyntaxColors.string),
        TokenRule(pattern: jsKeywords, color: SyntaxColors.keyword),
        TokenRule(pattern: "-?\\b\\d+(\\.\\d+)?\\b", color: SyntaxColors.number),
    ]

    static func rules(for language: Language) -> [TokenRule] {
        switch language {
        case .json: return jsonRules
        case .html: return htmlRules
        case .xml: return xmlRules
        case .css: return cssRules
        case .javascript: return jsRules
        case .plainText: return []
        }
    }

    /// Applies highlighting to the given range of the text storage using the rules for `language`.
    static func highlight(textStorage: NSTextStorage, range: NSRange, language: Language) {
        guard range.length > 0 else { return }
        let rules = rules(for: language)
        textStorage.beginEditing()
        textStorage.removeAttribute(.foregroundColor, range: range)
        textStorage.addAttribute(.foregroundColor, value: SyntaxColors.plain, range: range)
        let fullString = textStorage.string as NSString
        let searchRange = NSRange(location: range.location, length: min(range.length, fullString.length - range.location))
        for rule in rules {
            rule.regex.enumerateMatches(in: textStorage.string, options: [], range: searchRange) { match, _, _ in
                guard let match = match else { return }
                textStorage.addAttribute(.foregroundColor, value: rule.color, range: match.range)
            }
        }
        textStorage.endEditing()
    }
}
