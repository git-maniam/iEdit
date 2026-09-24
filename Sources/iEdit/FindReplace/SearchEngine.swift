import Foundation

struct SearchOptions {
    var matchCase: Bool = false
    var wholeWord: Bool = false
    var useRegex: Bool = false
    var useEscapes: Bool = true
    var wrapAround: Bool = true
}

enum SearchEngineError: Error, LocalizedError {
    case invalidRegex(String)
    case emptyPattern

    var errorDescription: String? {
        switch self {
        case .invalidRegex(let message): return "Invalid regular expression: \(message)"
        case .emptyPattern: return "Find field is empty."
        }
    }
}

enum SearchEngine {

    /// Translates literal escape sequences like \n \t \r \\ into their real characters.
    static func unescape(_ input: String) -> String {
        var result = ""
        var iterator = input.makeIterator()
        while let ch = iterator.next() {
            if ch == "\\" {
                if let next = iterator.next() {
                    switch next {
                    case "n": result.append("\n")
                    case "t": result.append("\t")
                    case "r": result.append("\r")
                    case "0": result.append("\0")
                    case "\\": result.append("\\")
                    default:
                        result.append(ch)
                        result.append(next)
                    }
                } else {
                    result.append(ch)
                }
            } else {
                result.append(ch)
            }
        }
        return result
    }

    static func buildRegex(find: String, options: SearchOptions) throws -> NSRegularExpression {
        guard !find.isEmpty else { throw SearchEngineError.emptyPattern }
        var pattern: String
        if options.useRegex {
            pattern = find
        } else {
            let literal = options.useEscapes ? unescape(find) : find
            pattern = NSRegularExpression.escapedPattern(for: literal)
        }
        if options.wholeWord {
            pattern = "\\b(?:\(pattern))\\b"
        }
        var regexOptions: NSRegularExpression.Options = []
        if !options.matchCase { regexOptions.insert(.caseInsensitive) }
        do {
            return try NSRegularExpression(pattern: pattern, options: regexOptions)
        } catch {
            throw SearchEngineError.invalidRegex(error.localizedDescription)
        }
    }

    static func countMatches(in text: String, regex: NSRegularExpression) -> Int {
        let ns = text as NSString
        return regex.numberOfMatches(in: text, range: NSRange(location: 0, length: ns.length))
    }

    static func allMatches(in text: String, regex: NSRegularExpression) -> [NSTextCheckingResult] {
        let ns = text as NSString
        return regex.matches(in: text, range: NSRange(location: 0, length: ns.length))
    }

    /// Finds the next match after `location`. Wraps around if enabled and nothing found ahead.
    static func findNext(in text: String, regex: NSRegularExpression, after location: Int, wrap: Bool) -> NSRange? {
        let ns = text as NSString
        let searchStart = min(max(location, 0), ns.length)
        let forwardRange = NSRange(location: searchStart, length: ns.length - searchStart)
        if let match = regex.firstMatch(in: text, range: forwardRange) {
            return match.range
        }
        if wrap {
            let wrapRange = NSRange(location: 0, length: searchStart)
            if let match = regex.firstMatch(in: text, range: wrapRange) {
                return match.range
            }
        }
        return nil
    }

    static func findPrevious(in text: String, regex: NSRegularExpression, before location: Int, wrap: Bool) -> NSRange? {
        let ns = text as NSString
        let searchEnd = min(max(location, 0), ns.length)
        let backwardRange = NSRange(location: 0, length: searchEnd)
        let matches = regex.matches(in: text, range: backwardRange)
        if let last = matches.last {
            return last.range
        }
        if wrap {
            let wrapRange = NSRange(location: searchEnd, length: ns.length - searchEnd)
            let matches2 = regex.matches(in: text, range: wrapRange)
            if let last = matches2.last { return last.range }
        }
        return nil
    }

    static func replacementTemplate(for replaceText: String, options: SearchOptions) -> String {
        if options.useRegex {
            return replaceText
        }
        let literal = options.useEscapes ? unescape(replaceText) : replaceText
        return NSRegularExpression.escapedTemplate(for: literal)
    }

    /// Replaces all matches in `text` and returns the new string plus the number of replacements made.
    static func replaceAll(in text: String, regex: NSRegularExpression, template: String) -> (result: String, count: Int) {
        let ns = text as NSString
        let fullRange = NSRange(location: 0, length: ns.length)
        let matches = regex.matches(in: text, range: fullRange)
        guard !matches.isEmpty else { return (text, 0) }
        let mutable = NSMutableString(string: text)
        var offset = 0
        for match in matches {
            let adjustedRange = NSRange(location: match.range.location + offset, length: match.range.length)
            let replacement = regex.replacementString(for: match, in: mutable as String, offset: offset, template: template)
            mutable.replaceCharacters(in: adjustedRange, with: replacement)
            offset += (replacement as NSString).length - match.range.length
        }
        return (mutable as String, matches.count)
    }
}
