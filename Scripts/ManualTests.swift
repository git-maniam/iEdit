import Cocoa

var failures = 0
func check(_ condition: Bool, _ label: String) {
    if condition {
        print("PASS: \(label)")
    } else {
        print("FAIL: \(label)")
        failures += 1
    }
}

// MARK: JSONFormatter

let sampleJSON = """
{"b":1,"a":[1,2,3],"nested":{"z":true,"y":null,"x":"hi\\nthere"},"n":-1.5e2}
"""
do {
    let pretty = try JSONFormatter.prettyPrint(sampleJSON)
    check(pretty.contains("\"b\": 1"), "prettyPrint preserves key order (b before a)")
    check(pretty.contains("\n"), "prettyPrint adds newlines")
    let reparsed = try JSONFormatter.prettyPrint(pretty)
    check(reparsed == pretty, "prettyPrint is idempotent")

    let minified = try JSONFormatter.minify(pretty)
    check(!minified.contains("\n"), "minify strips whitespace")
    check(minified.contains("\"b\":1"), "minify preserves order/content")

    try JSONFormatter.validate(sampleJSON)
    print("PASS: validate accepts well-formed JSON")
} catch {
    print("FAIL: JSONFormatter threw unexpectedly: \(error)")
    failures += 1
}

do {
    try JSONFormatter.validate("{\"a\": }")
    print("FAIL: validate should have thrown on malformed JSON")
    failures += 1
} catch JSONFormatterError.syntax(_, let line, _) {
    check(line == 1, "validate reports correct line for malformed JSON")
} catch {
    print("FAIL: unexpected error type: \(error)")
    failures += 1
}

// MARK: SearchEngine

do {
    let text = "Hello world\nhello WORLD\nfoo hello bar"
    var opts = SearchOptions(matchCase: false, wholeWord: false, useRegex: false, useEscapes: true, wrapAround: true)
    let regex = try SearchEngine.buildRegex(find: "hello", options: opts)
    check(SearchEngine.countMatches(in: text, regex: regex) == 3, "case-insensitive literal count == 3")

    opts.matchCase = true
    let regexCase = try SearchEngine.buildRegex(find: "hello", options: opts)
    check(SearchEngine.countMatches(in: text, regex: regexCase) == 2, "match-case literal count == 2")

    opts.matchCase = false
    opts.wholeWord = true
    let regexWord = try SearchEngine.buildRegex(find: "foo", options: opts)
    check(SearchEngine.countMatches(in: text, regex: regexWord) == 1, "whole word match count == 1")

    let escOpts = SearchOptions(matchCase: true, wholeWord: false, useRegex: false, useEscapes: true, wrapAround: true)
    let multiline = "line1\nline2\nline3"
    let regexEsc = try SearchEngine.buildRegex(find: "line1\\nline2", options: escOpts)
    check(SearchEngine.countMatches(in: multiline, regex: regexEsc) == 1, "escape sequence \\n matches real newline")

    let regexOpts = SearchOptions(matchCase: true, wholeWord: false, useRegex: true, useEscapes: false, wrapAround: true)
    let regexRegex = try SearchEngine.buildRegex(find: "l\\w+\\d", options: regexOpts)
    check(SearchEngine.countMatches(in: multiline, regex: regexRegex) == 3, "regex mode matches word+digit pattern 3 times")

    let wrapText = "aXbXc"
    let wrapRegex = try SearchEngine.buildRegex(find: "X", options: SearchOptions())
    guard let firstMatch = SearchEngine.findNext(in: wrapText, regex: wrapRegex, after: 0, wrap: true) else {
        fatalError("expected match")
    }
    let afterLast = SearchEngine.findNext(in: wrapText, regex: wrapRegex, after: firstMatch.location + 10, wrap: true)
    check(afterLast != nil, "wrap-around find-next finds a match after end of text")

    let template = SearchEngine.replacementTemplate(for: "X", options: SearchOptions(useEscapes: false))
    let (replaced, count) = SearchEngine.replaceAll(in: "cat dog cat", regex: try SearchEngine.buildRegex(find: "cat", options: SearchOptions()), template: template)
    check(replaced == "X dog X", "replaceAll replaces all literal matches")
    check(count == 2, "replaceAll reports correct count")
} catch {
    print("FAIL: SearchEngine threw unexpectedly: \(error)")
    failures += 1
}

// MARK: HTMLFormatter

do {
    let html = "<div><p>Hello</p><br><span>World</span></div>"
    let formatted = HTMLFormatter.format(html)
    check(formatted.contains("<div>"), "HTML formatter preserves tags")
    check(formatted.components(separatedBy: "\n").count > 3, "HTML formatter splits onto multiple lines")
    print(formatted)
}

// MARK: BraceMatcher

do {
    let code = "function foo() {\n  let x = 1;\n  if (x) {\n    doThing();\n  }\n}\n"
    guard let range = BraceMatcher.foldableRange(in: code, at: 12) else {
        print("FAIL: BraceMatcher found no foldable range")
        failures += 1
        fatalError()
    }
    let ns = code as NSString
    let folded = ns.substring(with: range)
    check(folded.contains("if (x)"), "BraceMatcher fold range covers function body")
    check(!folded.hasSuffix("}\n}\n") && folded.hasSuffix("}\n"), "BraceMatcher fold range excludes only the outer closing brace line")
}

print(failures == 0 ? "\nALL TESTS PASSED" : "\n\(failures) TEST(S) FAILED")
exit(failures == 0 ? 0 : 1)
