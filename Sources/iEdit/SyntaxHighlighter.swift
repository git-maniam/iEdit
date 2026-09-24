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
    private static func dynamicColor(light: NSColor, dark: NSColor) -> NSColor {
        NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
        }
    }

    /// EditPlus Classic Keyword: Rich Royal Blue in light mode, Bright Electric Blue in dark mode
    static let keyword = dynamicColor(
        light: NSColor(srgbRed: 0.00, green: 0.00, blue: 0.95, alpha: 1.0),
        dark: NSColor(srgbRed: 0.25, green: 0.65, blue: 1.00, alpha: 1.0)
    )

    /// EditPlus Classic String: Deep Crimson/Red in light mode, Vibrant Coral/Red in dark mode
    static let string = dynamicColor(
        light: NSColor(srgbRed: 0.65, green: 0.08, blue: 0.08, alpha: 1.0),
        dark: NSColor(srgbRed: 1.00, green: 0.45, blue: 0.45, alpha: 1.0)
    )

    /// EditPlus Classic Number: Teal / Dark Cyan in light mode, Vivid Aqua Cyan in dark mode
    static let number = dynamicColor(
        light: NSColor(srgbRed: 0.00, green: 0.50, blue: 0.50, alpha: 1.0),
        dark: NSColor(srgbRed: 0.15, green: 0.88, blue: 0.95, alpha: 1.0)
    )

    /// EditPlus Classic Comment: Forest Green in light mode, Bright Lime Green in dark mode
    static let comment = dynamicColor(
        light: NSColor(srgbRed: 0.00, green: 0.52, blue: 0.00, alpha: 1.0),
        dark: NSColor(srgbRed: 0.30, green: 0.88, blue: 0.40, alpha: 1.0)
    )

    /// EditPlus Classic HTML/XML Tag: Bold Blue in light mode, Bright Sky Blue in dark mode
    static let tag = dynamicColor(
        light: NSColor(srgbRed: 0.00, green: 0.15, blue: 0.85, alpha: 1.0),
        dark: NSColor(srgbRed: 0.35, green: 0.75, blue: 1.00, alpha: 1.0)
    )

    /// EditPlus Classic Attribute: Purple/Magenta in light mode, Vivid Orchid/Magenta in dark mode
    static let attribute = dynamicColor(
        light: NSColor(srgbRed: 0.55, green: 0.00, blue: 0.55, alpha: 1.0),
        dark: NSColor(srgbRed: 0.92, green: 0.45, blue: 0.98, alpha: 1.0)
    )

    /// EditPlus Classic JSON Key: Deep Royal Navy in light mode, Bright Azure in dark mode
    static let key = dynamicColor(
        light: NSColor(srgbRed: 0.02, green: 0.20, blue: 0.80, alpha: 1.0),
        dark: NSColor(srgbRed: 0.30, green: 0.80, blue: 1.00, alpha: 1.0)
    )

    /// EditPlus Classic Literal: Bold Blue in light mode, Bright Electric Blue in dark mode
    static let literal = dynamicColor(
        light: NSColor(srgbRed: 0.00, green: 0.00, blue: 0.95, alpha: 1.0),
        dark: NSColor(srgbRed: 0.40, green: 0.70, blue: 1.00, alpha: 1.0)
    )

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
        guard !rules.isEmpty else {
            textStorage.beginEditing()
            textStorage.removeAttribute(.foregroundColor, range: range)
            textStorage.addAttribute(.foregroundColor, value: SyntaxColors.plain, range: range)
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
            applyRules(rules, to: textStorage, range: initialChunk, string: fullString)

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
            applyRules(rules, to: textStorage, range: searchRange, string: fullString)
        }
    }

    private static func applyRules(_ rules: [TokenRule], to textStorage: NSTextStorage, range: NSRange, string: NSString) {
        textStorage.beginEditing()
        textStorage.removeAttribute(.foregroundColor, range: range)
        textStorage.addAttribute(.foregroundColor, value: SyntaxColors.plain, range: range)
        for rule in rules {
            rule.regex.enumerateMatches(in: textStorage.string, options: [], range: range) { match, _, _ in
                guard let match = match else { return }
                textStorage.addAttribute(.foregroundColor, value: rule.color, range: match.range)
            }
        }
        textStorage.endEditing()
    }
}
