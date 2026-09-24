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

    override func loadView() {
        let containerView = NSView()

        let textStorage = document.textStorage
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)
        let containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        let textContainer = NSTextContainer(containerSize: containerSize)
        textContainer.widthTracksTextView = true
        layoutManager.addTextContainer(textContainer)

        let tv = CodeEditorTextView(frame: .zero, textContainer: textContainer)
        tv.isEditable = true
        tv.isSelectable = true
        tv.isRichText = false
        tv.usesFontPanel = false
        tv.allowsUndo = true
        tv.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        tv.textColor = NSColor.labelColor
        tv.backgroundColor = NSColor.textBackgroundColor
        tv.isAutomaticQuoteSubstitutionEnabled = false
        tv.isAutomaticDashSubstitutionEnabled = false
        tv.isAutomaticSpellingCorrectionEnabled = false
        tv.isAutomaticTextReplacementEnabled = false
        tv.delegate = self
        tv.tabWidth = PreferencesStore.shared.tabWidth
        tv.useSpacesForTab = PreferencesStore.shared.useSpaces
        tv.textContainerInset = NSSize(width: 4, height: 6)
        self.textView = tv

        let sv = NSScrollView()
        sv.hasVerticalScroller = true
        sv.hasHorizontalScroller = true
        sv.autohidesScrollers = true
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

        applyWrapSetting()
        SyntaxHighlighter.highlight(textStorage: textStorage, range: NSRange(location: 0, length: textStorage.length), language: document.language)
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        reportStatus()
    }

    func applyWrapSetting() {
        guard let tv = textView, let container = tv.textContainer else { return }
        if wordWrapEnabled {
            container.widthTracksTextView = true
            tv.isHorizontallyResizable = false
            tv.autoresizingMask = [.width]
            scrollView.hasHorizontalScroller = false
            container.size = NSSize(width: scrollView.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        } else {
            container.widthTracksTextView = false
            tv.isHorizontallyResizable = true
            tv.autoresizingMask = []
            scrollView.hasHorizontalScroller = true
            container.size = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
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

    // MARK: NSTextStorageDelegate

    func textStorage(_ textStorage: NSTextStorage, didProcessEditing editedMask: NSTextStorageEditActions, range editedRange: NSRange, changeInLength delta: Int) {
        guard editedMask.contains(.editedCharacters) else { return }
        document.isDirty = true
        delegate?.editorDidChangeDirtyState(self, isDirty: true)

        let ns = textStorage.string as NSString
        let lineRange = ns.lineRange(for: NSRange(location: max(0, min(editedRange.location, ns.length)), length: 0))
        var expanded = NSUnionRange(editedRange, lineRange)
        expanded = ns.paragraphRange(for: NSRange(location: expanded.location, length: min(expanded.length, ns.length - expanded.location)))
        if textStorage.length > 3_000_000 {
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
