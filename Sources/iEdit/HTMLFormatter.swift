import Foundation

/// A pragmatic, regex-based HTML re-indenter. Not a full parser, but handles
/// typical hand-written or generated markup well.
enum HTMLFormatter {

    private static let voidElements: Set<String> = [
        "area", "base", "br", "col", "embed", "hr", "img", "input",
        "link", "meta", "param", "source", "track", "wbr"
    ]

    private static let tagRegex = try! NSRegularExpression(pattern: "<(/?)([A-Za-z][A-Za-z0-9-]*)([^>]*)>|([^<]+)", options: [])

    static func format(_ html: String, indent: String = "  ") -> String {
        let ns = html as NSString
        let matches = tagRegex.matches(in: html, range: NSRange(location: 0, length: ns.length))
        var result = ""
        var level = 0
        var lastWasBlockClose = false

        for match in matches {
            if match.range(at: 4).location != NSNotFound {
                let text = ns.substring(with: match.range(at: 4)).trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty {
                    result += String(repeating: indent, count: level) + text + "\n"
                }
                continue
            }
            let isClosing = ns.substring(with: match.range(at: 1)) == "/"
            let tagName = ns.substring(with: match.range(at: 2)).lowercased()
            let attrs = ns.substring(with: match.range(at: 3))
            let selfClosing = attrs.hasSuffix("/") || voidElements.contains(tagName)

            if isClosing {
                level = max(0, level - 1)
                result += String(repeating: indent, count: level) + "</\(tagName)>\n"
                lastWasBlockClose = true
            } else {
                result += String(repeating: indent, count: level) + "<\(tagName)\(attrs)>\n"
                if !selfClosing {
                    level += 1
                }
                lastWasBlockClose = false
            }
        }
        _ = lastWasBlockClose
        return result.trimmingCharacters(in: .whitespacesAndNewlines) + "\n"
    }
}
