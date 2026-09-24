import Cocoa

protocol EditorViewControllerDelegate: AnyObject {
    func editorDidChangeStatus(_ controller: EditorViewController, line: Int, column: Int, selectionLength: Int)
    func editorDidChangeDirtyState(_ controller: EditorViewController, isDirty: Bool)
}

final class EditorViewController: NSViewController, NSTextViewDelegate, NSTextStorageDelegate {

    let document: EditorDocument
    weak var delegate: EditorViewControllerDelegate?

    private(set) var scrollView: NSScrollView!
    private(set) var textView: CodeEditorTextView!
    private var rulerView: LineNumberRulerView!

    var wordWrapEnabled: Bool = true {
        didSet { applyWrapSetting() }
    }

    let foldManager = FoldManager()

    init(document: EditorDocument) {
        self.document = document
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func loadView() {
        let containerView = NSView()

        let textStorage = document.textStorage
        let layoutManager = NSLayoutManager()
        layoutManager.allowsNonContiguousLayout = true
        textStorage.addLayoutManager(layoutManager)

        let initialWidth: CGFloat = 800
        let containerSize = NSSize(width: initialWidth, height: CGFloat.greatestFiniteMagnitude)
        let textContainer = NSTextContainer(containerSize: containerSize)
        textContainer.widthTracksTextView = true
        layoutManager.addTextContainer(textContainer)

        let tv = CodeEditorTextView(frame: NSRect(x: 0, y: 0, width: initialWidth, height: 600), textContainer: textContainer)
        tv.isEditable = true
        tv.isSelectable = true
        tv.isRichText = false
        tv.usesFontPanel = false
        tv.allowsUndo = true
        tv.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        tv.isAutomaticQuoteSubstitutionEnabled = false
        tv.isAutomaticDashSubstitutionEnabled = false
        tv.isAutomaticSpellingCorrectionEnabled = false
        tv.isAutomaticTextReplacementEnabled = false
        tv.delegate = self
        tv.tabWidth = PreferencesStore.shared.tabWidth
        tv.useSpacesForTab = PreferencesStore.shared.useSpaces
        tv.textContainerInset = NSSize(width: 6, height: 8)
        tv.minSize = NSSize(width: 0, height: 0)
        tv.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        tv.isVerticallyResizable = true
        tv.isHorizontallyResizable = false
        tv.autoresizingMask = [.width]
        self.textView = tv

        let sv = NSScrollView()
        sv.hasVerticalScroller = true
        sv.hasHorizontalScroller = false
        sv.autohidesScrollers = false
        sv.scrollerStyle = .legacy
        sv.documentView = tv
        sv.translatesAutoresizingMaskIntoConstraints = false
        self.scrollView = sv

        let ruler = LineNumberRulerView(textView: tv)
        sv.verticalRulerView = ruler
        sv.hasVerticalRuler = true
        sv.rulersVisible = true
        self.rulerView = ruler

        containerView.addSubview(sv)
        NSLayoutConstraint.activate([
            sv.topAnchor.constraint(equalTo: containerView.topAnchor),
            sv.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            sv.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            sv.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
        ])

        self.view = containerView

        textStorage.delegate = self
        tv.onCaretChange = { [weak self] in self?.reportStatus() }

        NotificationCenter.default.addObserver(self, selector: #selector(themeDidChange), name: ThemeManager.themeDidChangeNotification, object: nil)

        applyCurrentTheme()
        applyWrapSetting()
        SyntaxHighlighter.highlight(textStorage: textStorage, range: NSRange(location: 0, length: textStorage.length), language: document.language)
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        applyWrapSetting()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        applyWrapSetting()
        reportStatus()
    }

    @objc private func themeDidChange(_ note: Notification) {
        applyCurrentTheme()
        rehighlightAll()
    }

    func applyCurrentTheme() {
        guard let tv = textView else { return }
        let theme = ThemeManager.shared.currentTheme
        tv.backgroundColor = theme.editorBackground
        tv.textColor = theme.editorForeground
        tv.insertionPointColor = theme.caretColor
        tv.selectedTextAttributes = [
            .backgroundColor: theme.selectionBackground,
            .foregroundColor: theme.editorForeground
        ]
        scrollView?.backgroundColor = theme.editorBackground
        rulerView?.needsDisplay = true
        tv.needsDisplay = true
    }

    func applyWrapSetting() {
        guard let tv = textView, let container = tv.textContainer, let sv = scrollView else { return }
        let currentWidth = sv.contentSize.width > 0 ? sv.contentSize.width : 800
        if wordWrapEnabled {
            container.widthTracksTextView = true
            tv.isHorizontallyResizable = false
            tv.autoresizingMask = [.width]
            sv.hasHorizontalScroller = false
            container.containerSize = NSSize(width: currentWidth, height: CGFloat.greatestFiniteMagnitude)
        } else {
            container.widthTracksTextView = false
            tv.isHorizontallyResizable = true
            tv.autoresizingMask = []
            sv.hasHorizontalScroller = true
            container.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
            tv.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        }
    }

    func reportStatus() {
        let ns = textView.string as NSString
        let selected = textView.selectedRange()
        var line = 1
        var idx = 0
        while idx < selected.location && idx < ns.length {
            if ns.character(at: idx) == 10 { line += 1 }
            idx += 1
        }
        let lineStart = ns.lineRange(for: NSRange(location: min(selected.location, ns.length), length: 0)).location
        let column = selected.location - lineStart + 1
        delegate?.editorDidChangeStatus(self, line: line, column: column, selectionLength: selected.length)
    }

    // MARK: - In-Editor Search Highlighting (Non-destructive)

    func clearSearchHighlights() {
        guard let layoutManager = textView?.layoutManager,
              let textStorage = textView?.textStorage else { return }
        let fullRange = NSRange(location: 0, length: textStorage.length)
        layoutManager.removeTemporaryAttribute(.backgroundColor, forCharacterRange: fullRange)
    }

    func highlightMatches(_ ranges: [NSRange], currentMatchIndex: Int?) {
        guard let layoutManager = textView?.layoutManager,
              let textStorage = textView?.textStorage else { return }
        clearSearchHighlights()
        let matchBg = NSColor.systemYellow.withAlphaComponent(0.35)
        let activeBg = NSColor.systemOrange.withAlphaComponent(0.70)

        for (idx, range) in ranges.enumerated() {
            guard range.location + range.length <= textStorage.length else { continue }
            let color = (idx == currentMatchIndex) ? activeBg : matchBg
            layoutManager.addTemporaryAttribute(.backgroundColor, value: color, forCharacterRange: range)
        }
    }

    // MARK: - NSTextStorageDelegate

    func textStorage(_ textStorage: NSTextStorage, didProcessEditing editedMask: NSTextStorageEditActions, range editedRange: NSRange, changeInLength delta: Int) {
        guard editedMask.contains(.editedCharacters) else { return }
        document.isDirty = true
        delegate?.editorDidChangeDirtyState(self, isDirty: true)
        rulerView?.rebuildLineIndices()

        let ns = textStorage.string as NSString
        let lineRange = ns.lineRange(for: NSRange(location: max(0, min(editedRange.location, ns.length)), length: 0))
        var expanded = NSUnionRange(editedRange, lineRange)
        expanded = ns.paragraphRange(for: NSRange(location: expanded.location, length: min(expanded.length, ns.length - expanded.location)))
        if textStorage.length > 300_000 {
            // Large file: only highlight the edited paragraph range to stay fast.
            SyntaxHighlighter.highlight(textStorage: textStorage, range: expanded, language: document.language)
        } else {
            SyntaxHighlighter.highlight(textStorage: textStorage, range: NSRange(location: 0, length: textStorage.length), language: document.language)
        }
    }

    func rehighlightAll() {
        SyntaxHighlighter.highlight(textStorage: document.textStorage, range: NSRange(location: 0, length: document.textStorage.length), language: document.language)
    }

    /// Restores any folded regions to their real text. Call before reading canonical
    /// document content (save, find/replace, formatters) so nothing is ever lost.
    func unfoldAllFolds() {
        guard foldManager.hasFolds else { return }
        foldManager.unfoldAll(in: document.textStorage)
        rehighlightAll()
    }

    @discardableResult
    func toggleFoldAtCursor() -> Bool {
        let location = textView.selectedRange().location
        if let id = foldManager.foldID(at: location, in: document.textStorage) {
            foldManager.unfold(id: id, in: document.textStorage)
            rehighlightAll()
            return true
        }
        guard let range = BraceMatcher.foldableRange(in: document.textStorage.string, at: location) else { return false }
        foldManager.fold(range: range, in: document.textStorage)
        return true
    }
}
