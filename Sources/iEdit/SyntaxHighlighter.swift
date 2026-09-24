import Cocoa

struct TokenRule {
    let regex: NSRegularExpression
    let color: NSColor

    init(pattern: String, color: NSColor, options: NSRegularExpression.Options = []) {
        self.regex = try! NSRegularExpression(pattern: pattern, options: options)
        self.color = color
    }
}

final class SyntaxHighlighter {

    static func rules(for language: Language, theme: AppTheme = ThemeManager.shared.currentTheme) -> [TokenRule] {
        switch language {
        case .json:
            return [
                TokenRule(pattern: "\"(?:\\\\.|[^\"\\\\])*\"(?=[ \\t]*:)", color: theme.key),
                TokenRule(pattern: "\"(?:\\\\.|[^\"\\\\])*\"(?![ \\t]*:)", color: theme.string),
                TokenRule(pattern: "\\b(true|false|null)\\b", color: theme.literal),
                TokenRule(pattern: "-?\\b\\d+(\\.\\d+)?([eE][+-]?\\d+)?\\b", color: theme.number),
            ]

        case .html, .xml:
            return [
                TokenRule(pattern: "<!--[\\s\\S]*?-->", color: theme.comment),
                TokenRule(pattern: "</?[A-Za-z][A-Za-z0-9:-]*", color: theme.tag),
                TokenRule(pattern: "/?>", color: theme.tag),
                TokenRule(pattern: "\\b[A-Za-z0-9_:-]+(?=\\s*=)", color: theme.attribute),
                TokenRule(pattern: "\"[^\"]*\"|'[^']*'", color: theme.string),
                TokenRule(pattern: "&[A-Za-z0-9#]+;", color: theme.literal),
            ]

        case .css:
            return [
                TokenRule(pattern: "/\\*[\\s\\S]*?\\*/", color: theme.comment),
                TokenRule(pattern: "[.#]?[-A-Za-z0-9_]+(?=\\s*\\{)", color: theme.tag),
                TokenRule(pattern: "[-A-Za-z]+(?=\\s*:)", color: theme.attribute),
                TokenRule(pattern: "\"[^\"]*\"|'[^']*'", color: theme.string),
                TokenRule(pattern: "#[0-9A-Fa-f]{3,8}\\b", color: theme.number),
                TokenRule(pattern: "-?\\b\\d+(\\.\\d+)?(px|em|rem|%|vh|vw|pt)?\\b", color: theme.number),
            ]

        case .javascript:
            let jsKeywords = "\\b(var|let|const|function|return|if|else|for|while|do|switch|case|break|continue|class|extends|new|this|super|import|export|default|try|catch|finally|throw|typeof|instanceof|in|of|async|await|yield|static|get|set|interface|type|enum|implements|public|private|protected|readonly)\\b"
            let jsLiterals = "\\b(true|false|null|undefined|NaN|Infinity)\\b"
            return [
                TokenRule(pattern: "//.*", color: theme.comment),
                TokenRule(pattern: "/\\*[\\s\\S]*?\\*/", color: theme.comment),
                TokenRule(pattern: "\"(?:\\\\.|[^\"\\\\])*\"|'(?:\\\\.|[^'\\\\])*'|`(?:\\\\.|[^`\\\\])*`", color: theme.string),
                TokenRule(pattern: jsKeywords, color: theme.keyword),
                TokenRule(pattern: jsLiterals, color: theme.literal),
                TokenRule(pattern: "-?\\b\\d+(\\.\\d+)?\\b", color: theme.number),
            ]

        case .swift:
            let swiftKeywords = "\\b(import|let|var|func|return|if|else|guard|switch|case|default|for|while|repeat|break|continue|fallthrough|do|try|catch|throw|throws|rethrows|class|struct|enum|protocol|extension|init|deinit|self|Self|super|public|private|fileprivate|internal|open|static|mutating|nonmutating|override|weak|unowned|lazy|async|await|actor|some|any|where|in|typealias|subscript|final|indirect|convenience|required)\\b"
            let swiftLiterals = "\\b(true|false|nil)\\b"
            let swiftTypes = "\\b(Int|Double|Float|Bool|String|Character|Array|Dictionary|Set|Optional|URL|Data|Date|Error|Void|Any|AnyObject|NS[A-Z][A-Za-z0-9]*|UI[A-Z][A-Za-z0-9]*)\\b"
            return [
                TokenRule(pattern: "//.*", color: theme.comment),
                TokenRule(pattern: "/\\*[\\s\\S]*?\\*/", color: theme.comment),
                TokenRule(pattern: "\"(?:\\\\.|[^\"\\\\])*\"", color: theme.string),
                TokenRule(pattern: swiftKeywords, color: theme.keyword),
                TokenRule(pattern: swiftTypes, color: theme.type),
                TokenRule(pattern: swiftLiterals, color: theme.literal),
                TokenRule(pattern: "-?\\b\\d+(\\.\\d+)?\\b", color: theme.number),
            ]

        case .python:
            let pyKeywords = "\\b(def|class|if|elif|else|for|while|try|except|finally|with|as|import|from|return|yield|break|continue|pass|raise|lambda|assert|global|nonlocal|async|await|del|is|not|and|or|in)\\b"
            let pyLiterals = "\\b(True|False|None|self|cls)\\b"
            return [
                TokenRule(pattern: "#.*", color: theme.comment),
                TokenRule(pattern: "\"\"\"[\\s\\S]*?\"\"\"|'''[\\s\\S]*?'''", color: theme.string),
                TokenRule(pattern: "\"(?:\\\\.|[^\"\\\\])*\"|'(?:\\\\.|[^'\\\\])*'", color: theme.string),
                TokenRule(pattern: pyKeywords, color: theme.keyword),
                TokenRule(pattern: pyLiterals, color: theme.literal),
                TokenRule(pattern: "-?\\b\\d+(\\.\\d+)?\\b", color: theme.number),
            ]

        case .markdown:
            return [
                TokenRule(pattern: "```[\\s\\S]*?```", color: theme.literal),
                TokenRule(pattern: "`[^`]+`", color: theme.literal),
                TokenRule(pattern: "^#{1,6}\\s.*", color: theme.keyword),
                TokenRule(pattern: "\\*\\*[^*]+\\*\\*", color: theme.tag),
                TokenRule(pattern: "\\*[^*]+\\*", color: theme.attribute),
                TokenRule(pattern: "\\[[^\\]]+\\]\\([^\\)]+\\)", color: theme.string),
            ]

        case .shell:
            let shKeywords = "\\b(if|then|else|elif|fi|case|esac|for|while|until|do|done|in|function|select|return|exit|source|export|alias|local)\\b"
            return [
                TokenRule(pattern: "#.*", color: theme.comment),
                TokenRule(pattern: "\\$[A-Za-z0-9_]+|\\$\\{[^}]+\\}", color: theme.key),
                TokenRule(pattern: "\"(?:\\\\.|[^\"\\\\])*\"|'[^']*'", color: theme.string),
                TokenRule(pattern: shKeywords, color: theme.keyword),
                TokenRule(pattern: "-?\\b\\d+\\b", color: theme.number),
            ]

        case .sql:
            let sqlKeywords = "\\b(SELECT|FROM|WHERE|INSERT|INTO|UPDATE|DELETE|JOIN|LEFT|RIGHT|INNER|OUTER|FULL|CROSS|ON|GROUP|BY|ORDER|HAVING|LIMIT|OFFSET|CREATE|TABLE|ALTER|DROP|INDEX|VIEW|TRIGGER|UNION|ALL|AND|OR|NOT|IN|IS|NULL|AS|SET|VALUES|DEFAULT|PRIMARY|KEY|FOREIGN|REFERENCES|DATABASE|SCHEMA|CASCADE|DISTINCT|BETWEEN|LIKE|EXISTS|CASE|WHEN|THEN|ELSE|END)\\b"
            return [
                TokenRule(pattern: "--.*", color: theme.comment),
                TokenRule(pattern: "/\\*[\\s\\S]*?\\*/", color: theme.comment),
                TokenRule(pattern: "'(?:''|[^'])*'", color: theme.string),
                TokenRule(pattern: sqlKeywords, color: theme.keyword, options: [.caseInsensitive]),
                TokenRule(pattern: "-?\\b\\d+(\\.\\d+)?\\b", color: theme.number),
            ]

        case .yaml:
            return [
                TokenRule(pattern: "#.*", color: theme.comment),
                TokenRule(pattern: "^[ \\t]*[A-Za-z0-9_-]+(?=\\s*:)", color: theme.key),
                TokenRule(pattern: "\"(?:\\\\.|[^\"\\\\])*\"|'[^']*'", color: theme.string),
                TokenRule(pattern: "\\b(true|false|yes|no|null)\\b", color: theme.literal, options: [.caseInsensitive]),
                TokenRule(pattern: "-?\\b\\d+(\\.\\d+)?\\b", color: theme.number),
            ]

        case .plainText:
            return []
        }
    }

    /// Applies highlighting to the given range of the text storage using the rules for `language`.
    static func highlight(textStorage: NSTextStorage, range: NSRange, language: Language) {
        guard range.length > 0 else { return }
        let theme = ThemeManager.shared.currentTheme
        let rules = rules(for: language, theme: theme)

        guard !rules.isEmpty else {
            textStorage.beginEditing()
            textStorage.removeAttribute(.foregroundColor, range: range)
            textStorage.addAttribute(.foregroundColor, value: theme.editorForeground, range: range)
            textStorage.addAttribute(.font, value: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular), range: range)
            textStorage.endEditing()
            return
        }

        let fullString = textStorage.string as NSString
        guard range.location < fullString.length else { return }
        let clampedLength = min(range.length, fullString.length - range.location)
        let searchRange = NSRange(location: range.location, length: clampedLength)

        // For large files (> 200,000 characters), avoid blocking the UI thread for multiple seconds.
        // We highlight the first 50,000 characters synchronously, then dispatch remaining chunks asynchronously.
        if clampedLength > 200_000 {
            let initialChunk = NSRange(location: searchRange.location, length: min(50_000, clampedLength))
            applyRules(rules, to: textStorage, range: initialChunk, theme: theme)

            let remainingStart = searchRange.location + initialChunk.length
            let remainingLength = searchRange.length - initialChunk.length
            if remainingLength > 0 {
                let remainingRange = NSRange(location: remainingStart, length: remainingLength)
                let textSnapshot = textStorage.string
                DispatchQueue.global(qos: .userInitiated).async {
                    var matchesToApply: [(NSRange, NSColor)] = []
                    for rule in rules {
                        rule.regex.enumerateMatches(in: textSnapshot, options: [], range: remainingRange) { match, _, _ in
                            guard let match = match else { return }
                            matchesToApply.append((match.range, rule.color))
                        }
                    }
                    DispatchQueue.main.async {
                        guard textStorage.string == textSnapshot else { return }
                        textStorage.beginEditing()
                        for (r, color) in matchesToApply {
                            if r.location + r.length <= textStorage.length {
                                textStorage.addAttribute(.foregroundColor, value: color, range: r)
                            }
                        }
                        textStorage.endEditing()
                    }
                }
            }
        } else {
            applyRules(rules, to: textStorage, range: searchRange, theme: theme)
        }
    }

    private static func applyRules(_ rules: [TokenRule], to textStorage: NSTextStorage, range: NSRange, theme: AppTheme) {
        textStorage.beginEditing()
        textStorage.removeAttribute(.foregroundColor, range: range)
        textStorage.addAttribute(.foregroundColor, value: theme.editorForeground, range: range)
        textStorage.addAttribute(.font, value: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular), range: range)
        for rule in rules {
            rule.regex.enumerateMatches(in: textStorage.string, options: [], range: range) { match, _, _ in
                guard let match = match else { return }
                textStorage.addAttribute(.foregroundColor, value: rule.color, range: match.range)
            }
        }
        textStorage.endEditing()
    }
}
