import Cocoa

final class LineNumberRulerView: NSRulerView {

    weak var editorTextView: NSTextView?
    var foldedLineRanges: Set<Int> = []
    var onFoldToggle: ((Int) -> Void)?

    init(textView: NSTextView) {
        self.editorTextView = textView
        super.init(scrollView: textView.enclosingScrollView, orientation: .verticalRuler)
        clientView = textView
        ruleThickness = 48
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let textView = editorTextView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else { return }

        NSColor.textBackgroundColor.withAlphaComponent(0.4).setFill()
        rect.fill()

        let visibleRect = textView.enclosingScrollView?.contentView.bounds ?? textView.bounds
        let visibleGlyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: textContainer)
        let visibleCharRange = layoutManager.characterRange(forGlyphRange: visibleGlyphRange, actualGlyphRange: nil)

        let string = textView.string as NSString
        var lineNumber = 1
        var index = 0
        while index < visibleCharRange.location {
            if string.character(at: index) == 10 { lineNumber += 1 }
            index += 1
        }

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .right
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 10.5, weight: .regular),
            .foregroundColor: NSColor.secondaryLabelColor,
            .paragraphStyle: paragraphStyle
        ]

        var charIndex = visibleCharRange.location
        let endIndex = visibleCharRange.location + visibleCharRange.length
        let containerOrigin = textView.textContainerOrigin

        while charIndex <= endIndex {
            let lineGlyphRange = layoutManager.glyphRange(forCharacterRange: NSRange(location: charIndex, length: 0), actualCharacterRange: nil)
            var effectiveRange = NSRange(location: 0, length: 0)
            let lineFragmentRect = layoutManager.lineFragmentRect(forGlyphAt: min(lineGlyphRange.location, max(layoutManager.numberOfGlyphs - 1, 0)), effectiveRange: &effectiveRange, withoutAdditionalLayout: true)

            let y = lineFragmentRect.minY + containerOrigin.y - visibleRect.minY
            let numberString = "\(lineNumber)" as NSString
            let size = numberString.size(withAttributes: attrs)
            let drawRect = NSRect(x: 0, y: y + (lineFragmentRect.height - size.height) / 2, width: ruleThickness - 8, height: size.height)
            numberString.draw(in: drawRect, withAttributes: attrs)

            let lineCharRange = layoutManager.characterRange(forGlyphRange: lineFragmentRect.isEmpty ? lineGlyphRange : effectiveRange, actualGlyphRange: nil)
            let nextLineStart = lineCharRange.location + lineCharRange.length
            if nextLineStart <= charIndex { break }
            charIndex = nextLineStart
            lineNumber += 1
            if charIndex >= string.length { break }
        }
    }
}
