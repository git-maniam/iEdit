import Cocoa

/// Finds the range of a brace/bracket-delimited block enclosing (or starting at) a location.
enum BraceMatcher {
    private static let openers: Set<Character> = ["{", "[", "("]
    private static let closers: [Character: Character] = ["}": "{", "]": "[", ")": "("]

    /// Returns the foldable range for the block whose opening brace is on the line containing `location`,
    /// or that encloses `location`. The range spans from just after the opening brace's line end to just
    /// before the matching closing brace's line, so folding leaves the opening and closing lines visible.
    static func foldableRange(in text: String, at location: Int) -> NSRange? {
        let ns = text as NSString
        guard ns.length > 0 else { return nil }
        let lineRange = ns.lineRange(for: NSRange(location: min(location, ns.length), length: 0))

        var openIndex: Int?
        var searchIndex = lineRange.location + lineRange.length - 1
        while searchIndex >= lineRange.location {
            let ch = Character(UnicodeScalar(ns.character(at: searchIndex))!)
            if openers.contains(ch) {
                openIndex = searchIndex
                break
            }
            searchIndex -= 1
        }

        let braceIndex: Int
        if let openIndex {
            braceIndex = openIndex
        } else if let enclosing = enclosingOpenBrace(in: ns, before: location) {
            braceIndex = enclosing
        } else {
            return nil
        }

        guard let closeIndex = matchingCloseIndex(in: ns, openIndex: braceIndex) else { return nil }

        let afterOpenLine = ns.lineRange(for: NSRange(location: braceIndex, length: 0))
        let foldStart = afterOpenLine.location + afterOpenLine.length
        let closeLine = ns.lineRange(for: NSRange(location: closeIndex, length: 0))
        let foldEnd = closeLine.location
        guard foldEnd > foldStart else { return nil }
        return NSRange(location: foldStart, length: foldEnd - foldStart)
    }

    private static func enclosingOpenBrace(in ns: NSString, before location: Int) -> Int? {
        var depth = 0
        var i = min(location, ns.length) - 1
        while i >= 0 {
            let ch = Character(UnicodeScalar(ns.character(at: i))!)
            if let _ = closers[ch] {
                depth += 1
            } else if openers.contains(ch) {
                if depth == 0 { return i }
                depth -= 1
            }
            i -= 1
        }
        return nil
    }

    private static func matchingCloseIndex(in ns: NSString, openIndex: Int) -> Int? {
        let openChar = Character(UnicodeScalar(ns.character(at: openIndex))!)
        var depth = 1
        var i = openIndex + 1
        while i < ns.length {
            let ch = Character(UnicodeScalar(ns.character(at: i))!)
            if ch == openChar {
                depth += 1
            } else if let match = closers[ch], match == openChar {
                depth -= 1
                if depth == 0 { return i }
            }
            i += 1
        }
        return nil
    }
}

/// Manages visual folding (collapsing) of text ranges without ever losing data:
/// folded text is stashed and can be fully restored, and callers should invoke
/// `unfoldAll` before reading canonical document content (save, find, formatters).
final class FoldManager {
    static let foldAttributeKey = NSAttributedString.Key("iEditFoldID")

    private struct Fold {
        let id: UUID
        let originalText: String
    }

    private var folds: [UUID: Fold] = [:]

    var hasFolds: Bool { !folds.isEmpty }

    func fold(range: NSRange, in textStorage: NSTextStorage) {
        guard range.length > 0 else { return }
        let ns = textStorage.string as NSString
        let original = ns.substring(with: range)
        let lineCount = original.components(separatedBy: "\n").count
        let id = UUID()
        folds[id] = Fold(id: id, originalText: original)

        let summary = " \u{25B8} \(lineCount) folded line\(lineCount == 1 ? "" : "s") \u{25B8} "
        let placeholder = NSMutableAttributedString(string: summary)
        let full = NSRange(location: 0, length: (summary as NSString).length)
        placeholder.addAttribute(.foregroundColor, value: NSColor.white, range: full)
        placeholder.addAttribute(.backgroundColor, value: NSColor.systemGray, range: full)
        placeholder.addAttribute(.font, value: NSFont.monospacedSystemFont(ofSize: 11, weight: .medium), range: full)
        placeholder.addAttribute(Self.foldAttributeKey, value: id, range: full)

        textStorage.replaceCharacters(in: range, with: placeholder)
    }

    @discardableResult
    func unfold(id: UUID, in textStorage: NSTextStorage) -> Bool {
        guard let fold = folds[id] else { return false }
        let full = NSRange(location: 0, length: textStorage.length)
        var targetRange: NSRange?
        textStorage.enumerateAttribute(Self.foldAttributeKey, in: full, options: []) { value, range, stop in
            if let v = value as? UUID, v == id {
                targetRange = range
                stop.pointee = true
            }
        }
        folds.removeValue(forKey: id)
        guard let range = targetRange else { return false }
        textStorage.replaceCharacters(in: range, with: fold.originalText)
        return true
    }

    /// Finds the fold id at (or overlapping) a given character location, if any.
    func foldID(at location: Int, in textStorage: NSTextStorage) -> UUID? {
        guard textStorage.length > 0, location >= 0, location < textStorage.length else { return nil }
        return textStorage.attribute(Self.foldAttributeKey, at: location, effectiveRange: nil) as? UUID
    }

    func unfoldAll(in textStorage: NSTextStorage) {
        let ids = Array(folds.keys)
        for id in ids { unfold(id: id, in: textStorage) }
    }
}
