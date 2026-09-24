import Cocoa

final class CodeEditorTextView: NSTextView {

    var useSpacesForTab: Bool = true
    var tabWidth: Int = 4
    var onCaretChange: (() -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func insertTab(_ sender: Any?) {
        if useSpacesForTab {
            insertText(String(repeating: " ", count: tabWidth), replacementRange: selectedRange())
        } else {
            super.insertTab(sender)
        }
    }

    override func insertNewline(_ sender: Any?) {
        let ns = string as NSString
        let lineRange = ns.lineRange(for: NSRange(location: selectedRange().location, length: 0))
        let currentLine = ns.substring(with: lineRange)
        var indent = ""
        for ch in currentLine {
            if ch == " " || ch == "\t" {
                indent.append(ch)
            } else {
                break
            }
        }
        let trimmed = currentLine.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasSuffix("{") || trimmed.hasSuffix("[") || trimmed.hasSuffix(":") {
            if useSpacesForTab {
                indent += String(repeating: " ", count: tabWidth)
            } else {
                indent += "\t"
            }
        }
        super.insertNewline(sender)
        insertText(indent, replacementRange: selectedRange())
    }

    override func didChangeText() {
        super.didChangeText()
    }

    override func setSelectedRange(_ charRange: NSRange, affinity: NSSelectionAffinity, stillSelecting stillSelectingFlag: Bool) {
        super.setSelectedRange(charRange, affinity: affinity, stillSelecting: stillSelectingFlag)
        onCaretChange?()
    }
}
