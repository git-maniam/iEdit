import Cocoa

final class MainViewController: NSViewController, TabBarViewDelegate, EditorViewControllerDelegate, SidebarViewControllerDelegate, FindReplaceHost {

    private let tabBar = TabBarView()
    private let editorContainer = NSView()
    private let statusBar = StatusBarView()
    private var findBarController: FindReplaceBarViewController!
    private var findBarHeightConstraint: NSLayoutConstraint!

    private(set) var editors: [EditorViewController] = []
    private var selectedIndex: Int = -1
    var sidebarDirectory: URL?

    weak var sidebarProxy: SidebarViewController?

    override func loadView() {
        let root = NSView()

        tabBar.translatesAutoresizingMaskIntoConstraints = false
        tabBar.delegate = self

        editorContainer.translatesAutoresizingMaskIntoConstraints = false

        findBarController = FindReplaceBarViewController()
        findBarController.host = self
        addChild(findBarController)
        findBarController.view.translatesAutoresizingMaskIntoConstraints = false
        findBarController.view.isHidden = true

        statusBar.translatesAutoresizingMaskIntoConstraints = false

        root.addSubview(tabBar)
        root.addSubview(editorContainer)
        root.addSubview(findBarController.view)
        root.addSubview(statusBar)

        findBarHeightConstraint = findBarController.view.heightAnchor.constraint(equalToConstant: 0)

        NSLayoutConstraint.activate([
            tabBar.topAnchor.constraint(equalTo: root.topAnchor),
            tabBar.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            tabBar.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            tabBar.heightAnchor.constraint(equalToConstant: 36),

            editorContainer.topAnchor.constraint(equalTo: tabBar.bottomAnchor),
            editorContainer.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            editorContainer.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            editorContainer.bottomAnchor.constraint(equalTo: findBarController.view.topAnchor),

            findBarController.view.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            findBarController.view.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            findBarController.view.bottomAnchor.constraint(equalTo: statusBar.topAnchor),
            findBarHeightConstraint,

            statusBar.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            statusBar.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            statusBar.bottomAnchor.constraint(equalTo: root.bottomAnchor),
            statusBar.heightAnchor.constraint(equalToConstant: 22),
        ])

        self.view = root
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        if editors.isEmpty {
            addTab(document: EditorDocument())
        }
    }

    // MARK: - Tab management

    func addTab(document: EditorDocument, select: Bool = true) {
        let controller = EditorViewController(document: document)
        controller.delegate = self
        controller.wordWrapEnabled = PreferencesStore.shared.wordWrapEnabled
        _ = controller.view
        controller.textView?.onDoubleClickLine = { [weak self] line in
            self?.handleLineDoubleClick(line)
        }
        addChild(controller)
        editors.append(controller)
        if select {
            selectTab(at: editors.count - 1)
        } else {
            reloadTabBar()
        }
    }

    private func reloadTabBar() {
        let titles = editors.map { $0.document.displayName }
        let dirty = editors.map { $0.document.isDirty }
        tabBar.reload(titles: titles, selectedIndex: selectedIndex, dirtyFlags: dirty)
    }

    private func selectTab(at index: Int) {
        guard index >= 0, index < editors.count else { return }
        if selectedIndex >= 0 && selectedIndex < editors.count {
            editors[selectedIndex].view.removeFromSuperview()
            editors[selectedIndex].clearSearchHighlights()
        }
        selectedIndex = index
        let controller = editors[index]
        controller.view.translatesAutoresizingMaskIntoConstraints = false
        editorContainer.subviews.forEach { $0.removeFromSuperview() }
        editorContainer.addSubview(controller.view)
        NSLayoutConstraint.activate([
            controller.view.topAnchor.constraint(equalTo: editorContainer.topAnchor),
            controller.view.bottomAnchor.constraint(equalTo: editorContainer.bottomAnchor),
            controller.view.leadingAnchor.constraint(equalTo: editorContainer.leadingAnchor),
            controller.view.trailingAnchor.constraint(equalTo: editorContainer.trailingAnchor),
        ])
        controller.applyWrapSetting()
        reloadTabBar()
        updateWindowTitle()
        controller.reportStatus()
        view.window?.makeFirstResponder(controller.textView)

        if !findBarController.view.isHidden {
            findBarController.focusFindField()
        }
    }

    private func updateWindowTitle() {
        guard selectedIndex >= 0, selectedIndex < editors.count else { return }
        let doc = editors[selectedIndex].document
        view.window?.title = doc.displayName
        view.window?.representedURL = doc.fileURL
        view.window?.isDocumentEdited = doc.isDirty
        updateStatusBar()
    }

    private func updateStatusBar() {
        guard selectedIndex >= 0, selectedIndex < editors.count else { return }
        let editor = editors[selectedIndex]
        let selected = editor.textView.selectedRange()
        let ns = editor.textView.string as NSString
        var line = 1
        var idx = 0
        while idx < selected.location && idx < ns.length {
            if ns.character(at: idx) == 10 { line += 1 }
            idx += 1
        }
        let lineStart = ns.lineRange(for: NSRange(location: min(selected.location, ns.length), length: 0)).location
        let column = selected.location - lineStart + 1
        statusBar.update(line: line, column: column, selectionLength: selected.length,
                          encoding: editor.document.encodingName,
                          language: editor.document.language.rawValue,
                          path: editor.document.fileURL?.path ?? editor.document.displayName)
    }

    @objc func newTab(_ sender: Any?) {
        addTab(document: EditorDocument())
    }

    @objc func closeTab(_ sender: Any?) {
        closeTab(at: selectedIndex)
    }

    private func closeTab(at index: Int) {
        guard index >= 0, index < editors.count else { return }
        let controller = editors[index]
        if controller.document.isDirty {
            let alert = NSAlert()
            alert.messageText = "Do you want to save the changes made to \"\(controller.document.displayName)\"?"
            alert.informativeText = "Your changes will be lost if you don't save them."
            alert.addButton(withTitle: "Save")
            alert.addButton(withTitle: "Don't Save")
            alert.addButton(withTitle: "Cancel")
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                let saved = performSave(for: controller)
                if !saved { return }
            } else if response == .alertThirdButtonReturn {
                return
            }
        }
        controller.view.removeFromSuperview()
        controller.removeFromParent()
        editors.remove(at: index)
        if editors.isEmpty {
            addTab(document: EditorDocument())
            return
        }
        let newIndex = min(index, editors.count - 1)
        selectedIndex = -1
        selectTab(at: newIndex)
    }

    func tabBar(_ tabBar: TabBarView, didSelectIndex index: Int) {
        selectTab(at: index)
    }

    func tabBar(_ tabBar: TabBarView, didCloseIndex index: Int) {
        closeTab(at: index)
    }

    func tabBarDidRequestNewTab(_ tabBar: TabBarView) {
        newTab(nil)
    }

    // MARK: - File operations

    @objc func openDocument(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.begin { [weak self] response in
            guard let self, response == .OK else { return }
            for url in panel.urls {
                self.openFile(url: url)
            }
        }
    }

    func openFile(url: URL) {
        if let index = editors.firstIndex(where: { $0.document.fileURL == url }) {
            selectTab(at: index)
            return
        }
        do {
            let doc = try EditorDocument.load(url: url)
            if editors.count == 1, editors[0].document.fileURL == nil, !editors[0].document.isDirty, editors[0].textView.string.isEmpty {
                editors[0].removeFromParent()
                editors[0].view.removeFromSuperview()
                editors.removeAll()
                selectedIndex = -1
            }
            addTab(document: doc)
        } catch {
            showErrorAlert(error)
        }
    }

    @objc func openFolder(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.begin { [weak self] response in
            guard let self, response == .OK, let url = panel.url else { return }
            self.sidebarDirectory = url
            self.sidebarProxy?.setRoot(url: url)
        }
    }

    @objc func saveDocument(_ sender: Any?) {
        guard selectedIndex >= 0, selectedIndex < editors.count else { return }
        performSave(for: editors[selectedIndex])
    }

    @objc func saveDocumentAs(_ sender: Any?) {
        guard selectedIndex >= 0, selectedIndex < editors.count else { return }
        performSaveAs(for: editors[selectedIndex])
    }

    @discardableResult
    private func performSave(for controller: EditorViewController) -> Bool {
        controller.unfoldAllFolds()
        if let url = controller.document.fileURL {
            do {
                try controller.document.save(to: url)
                reloadTabBar()
                updateWindowTitle()
                return true
            } catch {
                showErrorAlert(error)
                return false
            }
        } else {
            return performSaveAs(for: controller)
        }
    }

    @discardableResult
    private func performSaveAs(for controller: EditorViewController) -> Bool {
        controller.unfoldAllFolds()
        let panel = NSSavePanel()
        panel.nameFieldStringValue = controller.document.displayName
        let response = panel.runModal()
        guard response == .OK, let url = panel.url else { return false }
        do {
            try controller.document.save(to: url)
            reloadTabBar()
            updateWindowTitle()
            return true
        } catch {
            showErrorAlert(error)
            return false
        }
    }

    private func showErrorAlert(_ error: Error) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "An error occurred"
        alert.informativeText = error.localizedDescription
        alert.runModal()
    }

    // MARK: - View options

    @objc func toggleWordWrap(_ sender: Any?) {
        guard selectedIndex >= 0, selectedIndex < editors.count else { return }
        let editor = editors[selectedIndex]
        editor.wordWrapEnabled.toggle()
        PreferencesStore.shared.wordWrapEnabled = editor.wordWrapEnabled
    }

    @objc func toggleFold(_ sender: Any?) {
        guard selectedIndex >= 0, selectedIndex < editors.count else { return }
        if !editors[selectedIndex].toggleFoldAtCursor() {
            NSSound.beep()
        }
    }

    @objc func unfoldAll(_ sender: Any?) {
        guard selectedIndex >= 0, selectedIndex < editors.count else { return }
        editors[selectedIndex].unfoldAllFolds()
    }

    // MARK: - Find & Replace

    @objc func performFind(_ sender: Any?) {
        showFindBar(focusReplace: false)
    }

    @objc func performReplace(_ sender: Any?) {
        showFindBar(focusReplace: true)
    }

    @objc func findNextMenu(_ sender: Any?) {
        if findBarController.view.isHidden {
            showFindBar(focusReplace: false)
        } else {
            findBarController.findNextAction()
        }
    }

    @objc func findPreviousMenu(_ sender: Any?) {
        if findBarController.view.isHidden {
            showFindBar(focusReplace: false)
        } else {
            findBarController.findPreviousAction()
        }
    }

    @objc func findInFilesMenu(_ sender: Any?) {
        showFindBar(focusReplace: false, scope: .directory)
    }

    private func showFindBar(focusReplace: Bool = false, scope: SearchScope? = nil) {
        guard selectedIndex >= 0, selectedIndex < editors.count else { return }
        editors[selectedIndex].unfoldAllFolds()
        findBarController.view.isHidden = false
        findBarHeightConstraint.isActive = false
        if let scope {
            findBarController.setScope(scope)
        }
        if focusReplace {
            findBarController.focusReplaceField()
        } else {
            findBarController.focusFindField()
        }
    }

    func hideFindBar() {
        findBarController.clearHighlights()
        findBarController.view.isHidden = true
        findBarHeightConstraint.isActive = true
        view.window?.makeFirstResponder(editors[safe: selectedIndex]?.textView)
    }

    // MARK: - Double Click Results Navigation

    private func handleLineDoubleClick(_ line: String) {
        // Match EditPlus format: /path/to/file.ext (line, col): content
        // Or standard: /path/to/file.ext:line:col:
        let pattern1 = "^(/.+?)\\s*\\(([0-9]+)(?:,\\s*([0-9]+))?\\):"
        let pattern2 = "^(/.+?):([0-9]+)(?::([0-9]+))?:"

        for pattern in [pattern1, pattern2] {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { continue }
            let ns = line as NSString
            if let match = regex.firstMatch(in: line, range: NSRange(location: 0, length: ns.length)) {
                let filePath = ns.substring(with: match.range(at: 1))
                let lineNum = Int(ns.substring(with: match.range(at: 2))) ?? 1
                var colNum = 1
                if match.numberOfRanges > 3 && match.range(at: 3).location != NSNotFound {
                    colNum = Int(ns.substring(with: match.range(at: 3))) ?? 1
                }
                let url = URL(fileURLWithPath: filePath)
                if FileManager.default.fileExists(atPath: url.path) {
                    frOpenFileAndJump(url: url, line: lineNum, column: colNum)
                    return
                }
            }
        }
    }

    // MARK: - JSON / HTML tools

    @objc func formatJSONPretty(_ sender: Any?) {
        runJSONTransform { try JSONFormatter.prettyPrint($0) }
    }

    @objc func formatJSONMinify(_ sender: Any?) {
        runJSONTransform { try JSONFormatter.minify($0) }
    }

    @objc func validateJSON(_ sender: Any?) {
        guard let editor = currentEditorChecked() else { return }
        editor.unfoldAllFolds()
        do {
            try JSONFormatter.validate(editor.textView.string)
            let alert = NSAlert()
            alert.messageText = "Valid JSON"
            alert.informativeText = "No syntax errors were found."
            alert.runModal()
        } catch {
            showErrorAlert(error)
        }
    }

    @objc func formatHTML(_ sender: Any?) {
        guard let editor = currentEditorChecked() else { return }
        editor.unfoldAllFolds()
        let formatted = HTMLFormatter.format(editor.textView.string)
        replaceEditorContent(editor, with: formatted)
    }

    private func runJSONTransform(_ transform: (String) throws -> String) {
        guard let editor = currentEditorChecked() else { return }
        editor.unfoldAllFolds()
        do {
            let result = try transform(editor.textView.string)
            replaceEditorContent(editor, with: result)
        } catch {
            showErrorAlert(error)
        }
    }

    private func replaceEditorContent(_ editor: EditorViewController, with newText: String) {
        let full = NSRange(location: 0, length: (editor.textView.string as NSString).length)
        if editor.textView.shouldChangeText(in: full, replacementString: newText) {
            editor.textView.replaceCharacters(in: full, with: newText)
            editor.textView.didChangeText()
            editor.rehighlightAll()
        }
    }

    private func currentEditorChecked() -> EditorViewController? {
        guard selectedIndex >= 0, selectedIndex < editors.count else { return nil }
        return editors[selectedIndex]
    }

    // MARK: - EditorViewControllerDelegate

    func editorDidChangeStatus(_ controller: EditorViewController, line: Int, column: Int, selectionLength: Int) {
        guard controller === editors[safe: selectedIndex] else { return }
        statusBar.update(line: line, column: column, selectionLength: selectionLength,
                          encoding: controller.document.encodingName,
                          language: controller.document.language.rawValue,
                          path: controller.document.fileURL?.path ?? controller.document.displayName)
    }

    func editorDidChangeDirtyState(_ controller: EditorViewController, isDirty: Bool) {
        reloadTabBar()
        if controller === editors[safe: selectedIndex] {
            view.window?.isDocumentEdited = isDirty
        }
    }

    // MARK: - SidebarViewControllerDelegate

    func sidebarDidSelectFile(_ url: URL) {
        openFile(url: url)
    }

    // MARK: - FindReplaceHost

    func frCurrentEditor() -> EditorViewController? { currentEditorChecked() }
    func frAllEditors() -> [EditorViewController] { editors }
    func frOpenFile(url: URL) { openFile(url: url) }
    func frSearchDirectory() -> URL? { sidebarDirectory }
    func frJumpToEditor(_ controller: EditorViewController) {
        if let idx = editors.firstIndex(where: { $0 === controller }) {
            selectTab(at: idx)
        }
    }

    func frOpenFileAndJump(url: URL, line: Int, column: Int) {
        openFile(url: url)
        guard let editor = currentEditorChecked() else { return }
        let text = editor.textView.string as NSString
        var currentLine = 1
        var lineStart = 0
        var i = 0
        while i < text.length {
            if currentLine == line {
                lineStart = i
                break
            }
            if text.character(at: i) == 10 {
                currentLine += 1
            }
            i += 1
        }
        let targetLoc = min(lineStart + max(0, column - 1), text.length)
        let lineRange = text.lineRange(for: NSRange(location: targetLoc, length: 0))
        editor.textView.setSelectedRange(NSRange(location: targetLoc, length: 0))
        editor.textView.scrollRangeToVisible(lineRange)
        view.window?.makeFirstResponder(editor.textView)
    }

    func frDisplayFindResults(query: String, directory: URL, results: [SearchMatchResult], isReplace: Bool, replaceCount: Int, filesChanged: Int) {
        var output = ""
        let sep = String(repeating: "-", count: 80)
        if isReplace {
            output += "Replace in Files: \"\(query)\"\n"
            output += "Directory: \(directory.path)\n"
            output += "\(sep)\n"
            output += "Replaced \(replaceCount) occurrence(s) across \(filesChanged) file(s).\n"
        } else {
            output += "Find in Files: \"\(query)\"\n"
            output += "Directory: \(directory.path)\n"
            output += "\(sep)\n"
            for res in results {
                let filePath = res.url?.path ?? "Unknown"
                output += "\(filePath) (\(res.lineNumber), \(res.columnNumber)): \(res.lineText)\n"
            }
            output += "\(sep)\n"
            let uniqueFiles = Set(results.compactMap { $0.url }).count
            output += "Found \(results.count) occurrence(s) in \(uniqueFiles) file(s).\n"
            output += "(Double-click on any line above to open and jump to that file and location)\n"
        }

        if let existingIdx = editors.firstIndex(where: { $0.document.displayName == "Find Results" }) {
            let ed = editors[existingIdx]
            let fullRange = NSRange(location: 0, length: (ed.textView.string as NSString).length)
            if ed.textView.shouldChangeText(in: fullRange, replacementString: output) {
                ed.textView.replaceCharacters(in: fullRange, with: output)
                ed.textView.didChangeText()
            }
            selectTab(at: existingIdx)
        } else {
            let doc = EditorDocument(fileURL: nil, content: output, customTitle: "Find Results")
            addTab(document: doc, select: true)
        }
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
