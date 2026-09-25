import Cocoa

final class LineNumberRulerView: NSRulerView {

    weak var editorTextView: NSTextView?
    var foldedLineRanges: Set<Int> = []
    var onFoldToggle: ((Int) -> Void)?

    private var lineStartIndices: [Int] = [0]
    private var cachedStringLength: Int = -1

    override var isFlipped: Bool { true }

    init(textView: NSTextView) {
        self.editorTextView = textView
        super.init(scrollView: textView.enclosingScrollView, orientation: .verticalRuler)
        self.clientView = textView
        self.ruleThickness = 48

        NotificationCenter.default.addObserver(self, selector: #selector(contentBoundsDidChange), name: NSView.boundsDidChangeNotification, object: textView.enclosingScrollView?.contentView)
        NotificationCenter.default.addObserver(self, selector: #selector(textDidChange), name: NSText.didChangeNotification, object: textView)
        NotificationCenter.default.addObserver(self, selector: #selector(themeDidChange), name: ThemeManager.themeDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(fontDidChange), name: EditorFontManager.fontDidChangeNotification, object: nil)
        rebuildLineIndices()
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func contentBoundsDidChange(_ note: Notification) {
        needsDisplay = true
    }

    @objc func textDidChange(_ note: Notification? = nil) {
        rebuildLineIndices()
        needsDisplay = true
    }

    @objc private func themeDidChange(_ note: Notification) {
        needsDisplay = true
    }

    @objc private func fontDidChange(_ note: Notification) {
        needsDisplay = true
    }

    func rebuildLineIndices() {
        guard let textView = editorTextView else { return }
        let str = textView.string as NSString
        let len = str.length
        cachedStringLength = len

        var indices = [0]
        indices.reserveCapacity(max(16, len / 40))

        var idx = 0
        while idx < len {
            if str.character(at: idx) == 10 { // '\n'
                indices.append(idx + 1)
            }
            idx += 1
        }
        lineStartIndices = indices
    }

    /// Binary search to find the 1-based line number for a character index in O(log N)
    private func lineNumber(for charIndex: Int) -> Int {
        if lineStartIndices.isEmpty { return 1 }
        var low = 0
        var high = lineStartIndices.count - 1
        var result = 0
        while low <= high {
            let mid = (low + high) / 2
            if lineStartIndices[mid] <= charIndex {
                result = mid
                low = mid + 1
            } else {
                high = mid - 1
            }
        }
        return result + 1
    }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let textView = editorTextView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else { return }

        let theme = ThemeManager.shared.currentTheme

        // Ruler background - strictly within the ruler view bounds, never filling outside into text
        let rulerBgRect = NSRect(x: 0, y: bounds.minY, width: bounds.width, height: bounds.height)
        theme.rulerBackground.setFill()
        rulerBgRect.fill()

        // Subtle right divider border
        let borderRect = NSRect(x: bounds.maxX - 1, y: bounds.minY, width: 1, height: bounds.height)
        theme.rulerBorder.setFill()
        borderRect.fill()

        let visibleRect = textView.enclosingScrollView?.contentView.bounds ?? textView.bounds
        let containerOrigin = textView.textContainerOrigin

        // Visible glyph/character range
        let visibleGlyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: textContainer)
        guard visibleGlyphRange.length > 0 else { return }
        let visibleCharRange = layoutManager.characterRange(forGlyphRange: visibleGlyphRange, actualGlyphRange: nil)

        let string = textView.string as NSString
        if string.length != cachedStringLength {
            rebuildLineIndices()
        }

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .right
        let attrs: [NSAttributedString.Key: Any] = [
            .font: EditorFontManager.shared.rulerFont(),
            .foregroundColor: theme.rulerForeground,
            .paragraphStyle: paragraphStyle
        ]

        func drawNumber(_ number: Int, inFragment rect: NSRect) {
            // In flipped coordinates, y matches the text view top offset relative to the scroll clip view
            let y = rect.minY + containerOrigin.y - visibleRect.minY
            let numberString = "\(number)" as NSString
            let size = numberString.size(withAttributes: attrs)
            let drawRect = NSRect(x: 0, y: y + (rect.height - size.height) / 2, width: ruleThickness - 8, height: size.height)
            numberString.draw(in: drawRect, withAttributes: attrs)
        }

        var charIndex = visibleCharRange.location
        let endIndex = visibleCharRange.location + visibleCharRange.length

        while charIndex <= endIndex && charIndex < string.length {
            let lineGlyphRange = layoutManager.glyphRange(forCharacterRange: NSRange(location: charIndex, length: 0), actualCharacterRange: nil)
            var effectiveRange = NSRange(location: 0, length: 0)
            let lineFragmentRect = layoutManager.lineFragmentRect(forGlyphAt: min(lineGlyphRange.location, max(layoutManager.numberOfGlyphs - 1, 0)), effectiveRange: &effectiveRange, withoutAdditionalLayout: true)

            // With word wrap on, one logical line spans several fragments. Only the
            // fragment that starts the line gets a number; continuations stay blank.
            let startsLogicalLine = charIndex == 0 || string.character(at: charIndex - 1) == 10
            if lineFragmentRect.height > 0 && startsLogicalLine {
                drawNumber(lineNumber(for: charIndex), inFragment: lineFragmentRect)
            }

            let lineCharRange = layoutManager.characterRange(forGlyphRange: lineFragmentRect.isEmpty ? lineGlyphRange : effectiveRange, actualGlyphRange: nil)
            let nextLineStart = lineCharRange.location + lineCharRange.length
            if nextLineStart <= charIndex { break }
            charIndex = nextLineStart
        }

        // A trailing newline creates one more (empty) line that has no glyphs.
        if string.length > 0, string.character(at: string.length - 1) == 10 {
            let extraRect = layoutManager.extraLineFragmentRect
            if extraRect.height > 0 {
                drawNumber(lineStartIndices.count, inFragment: extraRect)
            }
        }
    }
}
