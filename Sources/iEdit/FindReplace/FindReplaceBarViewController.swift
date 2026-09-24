import Cocoa

enum SearchScope: Int {
    case currentFile = 0
    case allOpenTabs = 1
    case directory = 2
}

final class MultiLineSearchInput: NSView, NSTextViewDelegate {

    let scrollView = NSScrollView()
    let textView = NSTextView()
    private let placeholderLabel = NSTextField(labelWithString: "")
    private var heightConstraint: NSLayoutConstraint!

    var onTextChanged: ((String) -> Void)?
    var onReturnPressed: (() -> Void)?
    var onShiftReturnPressed: (() -> Void)?
    var onEscapePressed: (() -> Void)?

    var isExpanded: Bool = false {
        didSet {
            heightConstraint.constant = isExpanded ? 64 : 26
            needsLayout = true
        }
    }

    var stringValue: String {
        get { textView.string }
        set {
            textView.string = newValue
            placeholderLabel.isHidden = !newValue.isEmpty
        }
    }

    init(placeholder: String) {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 5
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.separatorColor.cgColor

        placeholderLabel.stringValue = placeholder
        placeholderLabel.font = NSFont.systemFont(ofSize: 12)
        placeholderLabel.textColor = NSColor.placeholderTextColor
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false

        textView.isRichText = false
        textView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.textColor = NSColor.textColor
        textView.backgroundColor = NSColor.textBackgroundColor
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainerInset = NSSize(width: 4, height: 4)
        textView.delegate = self

        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(scrollView)
        addSubview(placeholderLabel)

        heightConstraint = heightAnchor.constraint(equalToConstant: 26)

        NSLayoutConstraint.activate([
            heightConstraint,
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),

            placeholderLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            placeholderLabel.centerYAnchor.constraint(equalTo: topAnchor, constant: 13),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func textDidChange(_ notification: Notification) {
        placeholderLabel.isHidden = !textView.string.isEmpty
        onTextChanged?(textView.string)
    }

    func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            let currentEvent = NSApp.currentEvent
            let shiftPressed = currentEvent?.modifierFlags.contains(.shift) ?? false
            let optionPressed = currentEvent?.modifierFlags.contains(.option) ?? false

            if isExpanded {
                if currentEvent?.modifierFlags.contains(.command) == true {
                    onReturnPressed?()
                    return true
                }
                return false // Insert newline in expanded mode
            } else {
                if shiftPressed {
                    onShiftReturnPressed?()
                    return true
                } else if optionPressed {
                    textView.insertText("\n", replacementRange: textView.selectedRange())
                    return true
                } else {
                    onReturnPressed?()
                    return true
                }
            }
        } else if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            onEscapePressed?()
            return true
        }
        return false
    }

    override func becomeFirstResponder() -> Bool {
        window?.makeFirstResponder(textView) ?? false
    }
}

final class FindReplaceBarViewController: NSViewController {

    weak var host: FindReplaceHost?

    private let findInput = MultiLineSearchInput(placeholder: "Find")
    private let replaceInput = MultiLineSearchInput(placeholder: "Replace with")
    private let matchCaseCheck = NSButton(checkboxWithTitle: "Match Case", target: nil, action: nil)
    private let wholeWordCheck = NSButton(checkboxWithTitle: "Whole Word", target: nil, action: nil)
    private let regexCheck = NSButton(checkboxWithTitle: "Regex", target: nil, action: nil)
    private let escapesCheck = NSButton(checkboxWithTitle: "\\n Escapes", target: nil, action: nil)
    private let wrapCheck = NSButton(checkboxWithTitle: "Wrap Around", target: nil, action: nil)
    private let scopePopup = NSPopUpButton()
    private let chooseFolderButton = NSButton(title: "Choose Folder…", target: nil, action: nil)
    private let folderLabel = NSTextField(labelWithString: "No folder selected")
    private let statusLabel = NSTextField(labelWithString: "")
    private let expandInputsButton = NSButton()
    private let progressIndicator = NSProgressIndicator()

    private(set) var searchDirectory: URL?
    private var currentMatchRanges: [NSRange] = []
    private var currentMatchIndex: Int = -1

    var options: SearchOptions {
        SearchOptions(
            matchCase: matchCaseCheck.state == .on,
            wholeWord: wholeWordCheck.state == .on,
            useRegex: regexCheck.state == .on,
            useEscapes: escapesCheck.state == .on,
            wrapAround: wrapCheck.state == .on
        )
    }

    var scope: SearchScope { SearchScope(rawValue: scopePopup.indexOfSelectedItem) ?? .currentFile }

    override func loadView() {
        let root = NSView()
        root.wantsLayer = true
        root.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        // Top subtle divider border
        let topBorder = NSView()
        topBorder.wantsLayer = true
        topBorder.layer?.backgroundColor = NSColor.separatorColor.cgColor
        topBorder.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(topBorder)

        wrapCheck.state = .on
        escapesCheck.state = .on

        for toggle in [matchCaseCheck, wholeWordCheck, regexCheck, escapesCheck, wrapCheck] {
            toggle.target = self
            toggle.action = #selector(optionsChanged)
        }

        scopePopup.addItems(withTitles: ["Current File", "All Open Tabs", "Directory (Find in Files)"])
        scopePopup.target = self
        scopePopup.action = #selector(scopeChanged)

        chooseFolderButton.target = self
        chooseFolderButton.action = #selector(chooseFolder)
        chooseFolderButton.isHidden = true
        folderLabel.isHidden = true
        folderLabel.font = NSFont.systemFont(ofSize: 11)
        folderLabel.textColor = .secondaryLabelColor
        folderLabel.lineBreakMode = .byTruncatingHead

        expandInputsButton.title = ""
        expandInputsButton.image = NSImage(systemSymbolName: "arrow.up.left.and.down.right.and.arrow.up.right.and.down.left", accessibilityDescription: "Expand Multi-line")
        expandInputsButton.isBordered = false
        expandInputsButton.toolTip = "Toggle multi-line search and replace input"
        expandInputsButton.target = self
        expandInputsButton.action = #selector(toggleExpandInputs)

        let findNextBtn = NSButton(title: "Next", target: self, action: #selector(findNextAction))
        let findPrevBtn = NSButton(title: "Previous", target: self, action: #selector(findPreviousAction))
        let countBtn = NSButton(title: "Count", target: self, action: #selector(countMatchesAction))
        let replaceBtn = NSButton(title: "Replace", target: self, action: #selector(replaceOneAction))
        let replaceAllBtn = NSButton(title: "Replace All", target: self, action: #selector(replaceAllAction))
        let closeBtn = NSButton(title: "", target: self, action: #selector(closeBar))
        closeBtn.isBordered = false
        closeBtn.image = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: "Close")

        progressIndicator.style = .spinning
        progressIndicator.controlSize = .small
        progressIndicator.isDisplayedWhenStopped = false
        progressIndicator.translatesAutoresizingMaskIntoConstraints = false

        statusLabel.font = NSFont.systemFont(ofSize: 11)
        statusLabel.textColor = .secondaryLabelColor

        findInput.onTextChanged = { [weak self] _ in self?.refreshLiveHighlights() }
        findInput.onReturnPressed = { [weak self] in self?.findNextAction() }
        findInput.onShiftReturnPressed = { [weak self] in self?.findPreviousAction() }
        findInput.onEscapePressed = { [weak self] in self?.closeBar() }

        replaceInput.onReturnPressed = { [weak self] in self?.replaceOneAction() }
        replaceInput.onEscapePressed = { [weak self] in self?.closeBar() }

        let toggles = NSStackView(views: [matchCaseCheck, wholeWordCheck, regexCheck, escapesCheck, wrapCheck])
        toggles.orientation = .horizontal
        toggles.spacing = 10

        let row1 = NSStackView(views: [findInput, expandInputsButton, findPrevBtn, findNextBtn, countBtn, closeBtn])
        row1.orientation = .horizontal
        row1.spacing = 6
        findInput.translatesAutoresizingMaskIntoConstraints = false

        let row2 = NSStackView(views: [replaceInput, replaceBtn, replaceAllBtn])
        row2.orientation = .horizontal
        row2.spacing = 6
        replaceInput.translatesAutoresizingMaskIntoConstraints = false

        let row3 = NSStackView(views: [scopePopup, chooseFolderButton, folderLabel, progressIndicator, NSView(), statusLabel])
        row3.orientation = .horizontal
        row3.spacing = 8

        let mainStack = NSStackView(views: [row1, row2, toggles, row3])
        mainStack.orientation = .vertical
        mainStack.alignment = .leading
        mainStack.spacing = 6
        mainStack.edgeInsets = NSEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        mainStack.translatesAutoresizingMaskIntoConstraints = false

        root.addSubview(mainStack)

        NSLayoutConstraint.activate([
            topBorder.topAnchor.constraint(equalTo: root.topAnchor),
            topBorder.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            topBorder.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            topBorder.heightAnchor.constraint(equalToConstant: 1),

            mainStack.topAnchor.constraint(equalTo: root.topAnchor, constant: 1),
            mainStack.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            mainStack.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            mainStack.bottomAnchor.constraint(equalTo: root.bottomAnchor),

            findInput.widthAnchor.constraint(greaterThanOrEqualToConstant: 280),
            replaceInput.widthAnchor.constraint(greaterThanOrEqualToConstant: 280),
            folderLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 250),
        ])

        self.view = root
    }

    func focusFindField() {
        if let editor = host?.frCurrentEditor() {
            let selectedText = (editor.textView.string as NSString).substring(with: editor.textView.selectedRange())
            if !selectedText.isEmpty && !selectedText.contains("\n") {
                findInput.stringValue = selectedText
            }
        }
        view.window?.makeFirstResponder(findInput.textView)
        refreshLiveHighlights()
    }

    func focusReplaceField() {
        focusFindField()
        view.window?.makeFirstResponder(replaceInput.textView)
    }

    func clearHighlights() {
        host?.frCurrentEditor()?.clearSearchHighlights()
        currentMatchRanges.removeAll()
        currentMatchIndex = -1
    }

    @objc private func toggleExpandInputs() {
        let expand = !findInput.isExpanded
        findInput.isExpanded = expand
        replaceInput.isExpanded = expand
        expandInputsButton.image = NSImage(
            systemSymbolName: expand ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.down.right.and.arrow.up.right.and.down.left",
            accessibilityDescription: "Toggle Multi-line"
        )
    }

    @objc private func optionsChanged() {
        refreshLiveHighlights()
    }

    func setScope(_ newScope: SearchScope) {
        scopePopup.selectItem(at: newScope.rawValue)
        scopeChanged()
    }

    @objc func scopeChanged() {
        let isDir = scope == .directory
        chooseFolderButton.isHidden = !isDir
        folderLabel.isHidden = !isDir
        if isDir && searchDirectory == nil {
            if let dir = host?.frSearchDirectory() {
                self.searchDirectory = dir
                folderLabel.stringValue = dir.path
            }
        }
        refreshLiveHighlights()
    }

    @objc private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        if let initial = searchDirectory ?? host?.frSearchDirectory() {
            panel.directoryURL = initial
        }
        panel.begin { [weak self] response in
            guard let self, response == .OK, let url = panel.url else { return }
            self.searchDirectory = url
            self.folderLabel.stringValue = url.path
        }
    }

    private func setStatus(_ text: String) {
        statusLabel.stringValue = text
    }

    // MARK: - Live Match Highlighting

    private func refreshLiveHighlights() {
        guard let editor = host?.frCurrentEditor() else {
            clearHighlights()
            setStatus("")
            return
        }

        let query = findInput.stringValue
        guard !query.isEmpty else {
            clearHighlights()
            setStatus("")
            return
        }

        do {
            let regex = try SearchEngine.buildRegex(find: query, options: options)
            let text = editor.textView.string
            let matches = SearchEngine.allMatches(in: text, regex: regex)
            currentMatchRanges = matches.map { $0.range }

            let caretLocation = editor.textView.selectedRange().location
            if let idx = currentMatchRanges.firstIndex(where: { $0.location >= caretLocation }) {
                currentMatchIndex = idx
            } else if !currentMatchRanges.isEmpty {
                currentMatchIndex = 0
            } else {
                currentMatchIndex = -1
            }

            editor.highlightMatches(currentMatchRanges, currentMatchIndex: currentMatchIndex >= 0 ? currentMatchIndex : nil)

            if currentMatchRanges.isEmpty {
                setStatus("No matches")
            } else {
                let currentStr = currentMatchIndex >= 0 ? "\(currentMatchIndex + 1) of " : ""
                setStatus("\(currentStr)\(currentMatchRanges.count) match\(currentMatchRanges.count == 1 ? "" : "es")")
            }
        } catch {
            clearHighlights()
            setStatus(error.localizedDescription)
        }
    }

    // MARK: - Actions

    @objc func findNextAction() {
        performFind(forward: true)
    }

    @objc func findPreviousAction() {
        performFind(forward: false)
    }

    private func performFind(forward: Bool) {
        guard let editor = host?.frCurrentEditor() else { return }
        do {
            let regex = try SearchEngine.buildRegex(find: findInput.stringValue, options: options)
            let text = editor.textView.string
            let current = editor.textView.selectedRange()
            let range: NSRange?

            if forward {
                range = SearchEngine.findNext(in: text, regex: regex, after: current.location + current.length, wrap: options.wrapAround)
            } else {
                range = SearchEngine.findPrevious(in: text, regex: regex, before: current.location, wrap: options.wrapAround)
            }

            if let range {
                editor.textView.scrollRangeToVisible(range)
                editor.textView.setSelectedRange(range)
                view.window?.makeFirstResponder(editor.textView)
                refreshLiveHighlights()
            } else {
                setStatus("No matches found")
            }
        } catch {
            setStatus(error.localizedDescription)
        }
    }

    @objc func countMatchesAction() {
        do {
            let regex = try SearchEngine.buildRegex(find: findInput.stringValue, options: options)
            switch scope {
            case .currentFile:
                guard let editor = host?.frCurrentEditor() else { return }
                let count = SearchEngine.countMatches(in: editor.textView.string, regex: regex)
                setStatus("\(count) occurrence\(count == 1 ? "" : "s") in this file")
            case .allOpenTabs:
                var total = 0
                for editor in host?.frAllEditors() ?? [] {
                    total += SearchEngine.countMatches(in: editor.textView.string, regex: regex)
                }
                setStatus("\(total) occurrence\(total == 1 ? "" : "s") across all open tabs")
            case .directory:
                runDirectorySearch(regex: regex, isReplace: false)
            }
        } catch {
            setStatus(error.localizedDescription)
        }
    }

    @objc func replaceOneAction() {
        guard let editor = host?.frCurrentEditor() else { return }
        do {
            let regex = try SearchEngine.buildRegex(find: findInput.stringValue, options: options)
            let selected = editor.textView.selectedRange()
            if selected.length > 0, regex.firstMatch(in: editor.textView.string, range: selected) != nil {
                let template = SearchEngine.replacementTemplate(for: replaceInput.stringValue, options: options)
                let match = regex.firstMatch(in: editor.textView.string, range: selected)!
                let replacement = regex.replacementString(for: match, in: editor.textView.string, offset: 0, template: template)
                if editor.textView.shouldChangeText(in: selected, replacementString: replacement) {
                    editor.textView.replaceCharacters(in: selected, with: replacement)
                    editor.textView.didChangeText()
                    editor.textView.setSelectedRange(NSRange(location: selected.location, length: (replacement as NSString).length))
                }
            }
            performFind(forward: true)
        } catch {
            setStatus(error.localizedDescription)
        }
    }

    @objc func replaceAllAction() {
        do {
            let regex = try SearchEngine.buildRegex(find: findInput.stringValue, options: options)
            let template = SearchEngine.replacementTemplate(for: replaceInput.stringValue, options: options)

            switch scope {
            case .currentFile:
                guard let editor = host?.frCurrentEditor() else { return }
                editor.unfoldAllFolds()
                let (result, count) = SearchEngine.replaceAll(in: editor.textView.string, regex: regex, template: template)
                if count > 0 {
                    let full = NSRange(location: 0, length: (editor.textView.string as NSString).length)
                    if editor.textView.shouldChangeText(in: full, replacementString: result) {
                        editor.textView.replaceCharacters(in: full, with: result)
                        editor.textView.didChangeText()
                        editor.rehighlightAll()
                    }
                }
                setStatus("Replaced \(count) occurrence\(count == 1 ? "" : "s")")
                refreshLiveHighlights()

            case .allOpenTabs:
                let editors = host?.frAllEditors() ?? []
                var previewCount = 0
                for ed in editors {
                    previewCount += SearchEngine.countMatches(in: ed.textView.string, regex: regex)
                }

                guard previewCount > 0 else {
                    setStatus("No matches found to replace")
                    return
                }

                let alert = NSAlert()
                alert.messageText = "Replace in All Open Tabs?"
                alert.informativeText = "This will replace \(previewCount) occurrence\(previewCount == 1 ? "" : "s") across \(editors.count) open tab\(editors.count == 1 ? "" : "s")."
                alert.addButton(withTitle: "Replace All")
                alert.addButton(withTitle: "Cancel")
                guard alert.runModal() == .alertFirstButtonReturn else { return }

                var total = 0
                for ed in editors {
                    ed.unfoldAllFolds()
                    let (result, count) = SearchEngine.replaceAll(in: ed.textView.string, regex: regex, template: template)
                    if count > 0 {
                        let full = NSRange(location: 0, length: (ed.textView.string as NSString).length)
                        if ed.textView.shouldChangeText(in: full, replacementString: result) {
                            ed.textView.replaceCharacters(in: full, with: result)
                            ed.textView.didChangeText()
                            ed.rehighlightAll()
                        }
                        total += count
                    }
                }
                setStatus("Replaced \(total) occurrence\(total == 1 ? "" : "s") across \(editors.count) open tabs")
                refreshLiveHighlights()

            case .directory:
                runDirectoryReplace(regex: regex, template: template)
            }
        } catch {
            setStatus(error.localizedDescription)
        }
    }

    @objc private func closeBar() {
        clearHighlights()
        (parent as? MainViewController)?.hideFindBar()
    }

    // MARK: - Directory Search (Asynchronous with dedicated Find Results tab)

    private func directoryFiles() -> [URL] {
        guard let dir = searchDirectory ?? host?.frSearchDirectory() else { return [] }
        let fm = FileManager.default
        var out: [URL] = []
        guard let enumerator = fm.enumerator(at: dir, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) else { return [] }
        let allowedExtensions: Set<String> = [
            "txt", "json", "html", "htm", "css", "js", "xml", "md", "swift",
            "plist", "log", "csv", "yml", "yaml", "sh", "py", "c", "h", "cpp"
        ]
        for case let url as URL in enumerator {
            if allowedExtensions.contains(url.pathExtension.lowercased()) {
                out.append(url)
            }
        }
        return out
    }

    private func runDirectorySearch(regex: NSRegularExpression, isReplace: Bool) {
        guard let dir = searchDirectory ?? host?.frSearchDirectory() else {
            setStatus("Please choose a folder to search.")
            return
        }

        let query = findInput.stringValue
        progressIndicator.startAnimation(nil)
        setStatus("Searching in \(dir.lastPathComponent)…")

        let files = directoryFiles()

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            var results: [SearchMatchResult] = []

            for url in files {
                guard let content = try? String(contentsOf: url, encoding: .utf8) else { continue }
                let ns = content as NSString
                let matches = regex.matches(in: content, range: NSRange(location: 0, length: ns.length))
                guard !matches.isEmpty else { continue }

                var lineStarts = [0]
                for i in 0..<ns.length {
                    if ns.character(at: i) == 10 { lineStarts.append(i + 1) }
                }

                for match in matches {
                    let matchLoc = match.range.location
                    // Binary search for line number
                    var low = 0, high = lineStarts.count - 1, lineIdx = 0
                    while low <= high {
                        let mid = (low + high) / 2
                        if lineStarts[mid] <= matchLoc { lineIdx = mid; low = mid + 1 } else { high = mid - 1 }
                    }
                    let lineStart = lineStarts[lineIdx]
                    let lineRange = ns.lineRange(for: match.range)
                    let lineText = ns.substring(with: lineRange).trimmingCharacters(in: .newlines)
                    let column = matchLoc - lineStart + 1

                    results.append(SearchMatchResult(url: url, lineNumber: lineIdx + 1, columnNumber: column, lineText: lineText, range: match.range))
                }
            }

            DispatchQueue.main.async {
                self.progressIndicator.stopAnimation(nil)
                self.setStatus("Found \(results.count) match\(results.count == 1 ? "" : "es") across \(Set(results.compactMap { $0.url }).count) file(s)")
                self.host?.frDisplayFindResults(query: query, directory: dir, results: results, isReplace: false, replaceCount: 0, filesChanged: 0)
            }
        }
    }

    private func runDirectoryReplace(regex: NSRegularExpression, template: String) {
        guard let dir = searchDirectory ?? host?.frSearchDirectory() else {
            setStatus("Please choose a folder to search.")
            return
        }

        let query = findInput.stringValue
        progressIndicator.startAnimation(nil)
        setStatus("Scanning directory for replacements…")

        let files = directoryFiles()

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            var matchingFiles: [(URL, String, Int)] = []
            var totalMatches = 0

            for url in files {
                guard let content = try? String(contentsOf: url, encoding: .utf8) else { continue }
                let count = SearchEngine.countMatches(in: content, regex: regex)
                if count > 0 {
                    matchingFiles.append((url, content, count))
                    totalMatches += count
                }
            }

            DispatchQueue.main.async {
                self.progressIndicator.stopAnimation(nil)
                guard totalMatches > 0 else {
                    self.setStatus("No matches found to replace.")
                    return
                }

                let alert = NSAlert()
                alert.messageText = "Replace in Files?"
                alert.informativeText = "Found \(totalMatches) occurrence\(totalMatches == 1 ? "" : "s") in \(matchingFiles.count) file\(matchingFiles.count == 1 ? "" : "s") in \"\(dir.lastPathComponent)\". Are you sure you want to replace all occurrences?"
                alert.addButton(withTitle: "Replace All")
                alert.addButton(withTitle: "Cancel")

                guard alert.runModal() == .alertFirstButtonReturn else {
                    self.setStatus("Replace in files cancelled.")
                    return
                }

                self.progressIndicator.startAnimation(nil)
                self.setStatus("Replacing in files…")

                DispatchQueue.global(qos: .userInitiated).async {
                    var totalReplaced = 0
                    var filesChanged = 0
                    for (url, content, _) in matchingFiles {
                        let (result, count) = SearchEngine.replaceAll(in: content, regex: regex, template: template)
                        if count > 0 {
                            do {
                                try result.write(to: url, atomically: true, encoding: .utf8)
                                totalReplaced += count
                                filesChanged += 1
                            } catch {
                                // continue
                            }
                        }
                    }

                    DispatchQueue.main.async {
                        self.progressIndicator.stopAnimation(nil)
                        self.setStatus("Replaced \(totalReplaced) occurrence\(totalReplaced == 1 ? "" : "s") in \(filesChanged) file(s)")
                        self.host?.frDisplayFindResults(query: query, directory: dir, results: [], isReplace: true, replaceCount: totalReplaced, filesChanged: filesChanged)
                    }
                }
            }
        }
    }
}
