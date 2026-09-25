import Cocoa

/// One entry in the window's tab list. A tab restored from the previous session
/// starts out with only a `fileURL`; its editor (and the file's contents) are
/// created the first time the tab is selected.
final class TabItem {
    var fileURL: URL?
    var placeholderTitle: String?
    var editor: EditorViewController?

    init(fileURL: URL? = nil, placeholderTitle: String? = nil, editor: EditorViewController? = nil) {
        self.fileURL = fileURL
        self.placeholderTitle = placeholderTitle
        self.editor = editor
    }

    var isLoaded: Bool { editor != nil }
    var isDirty: Bool { editor?.document.isDirty ?? false }

    var displayName: String {
        if let editor { return editor.document.displayName }
        return fileURL?.lastPathComponent ?? placeholderTitle ?? "Untitled"
    }
}

final class MainViewController: NSViewController, TabBarViewDelegate, EditorViewControllerDelegate, SidebarViewControllerDelegate, FindReplaceHost, NSMenuItemValidation {

    private let tabBar = TabBarView()
    private let editorContainer = NSView()
    private let statusBar = StatusBarView()
    private var findBarController: FindReplaceBarViewController!
    private var findBarHeightConstraint: NSLayoutConstraint!

    private(set) var tabs: [TabItem] = []
    private var selectedIndex: Int = -1
    var sidebarDirectory: URL?

    weak var sidebarProxy: SidebarViewController?

    /// Editors that have actually been instantiated. Tabs restored from the last
    /// session but never opened are not included.
    var editors: [EditorViewController] { tabs.compactMap { $0.editor } }

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

    override func viewDidAppear() {
        super.viewDidAppear()
        // Session restore runs during viewDidLoad, before the view has a window,
        // so the title has to be applied again once there is one.
        updateWindowTitle()
        if let editor = tabs[safe: selectedIndex]?.editor {
            view.window?.makeFirstResponder(editor.textView)
        }
    }

    // MARK: - Session restore

    /// Recreates the previous session's tabs without reading any file contents.
    /// Called by `RootSplitViewController` once the sidebar is wired up.
    func restoreSession() {
        let prefs = PreferencesStore.shared

        if let folderPath = prefs.sessionFolderPath,
           FileManager.default.fileExists(atPath: folderPath) {
            let url = URL(fileURLWithPath: folderPath)
            sidebarDirectory = url
            sidebarProxy?.setRoot(url: url)
        }

        let fm = FileManager.default
        for path in prefs.sessionFilePaths where fm.fileExists(atPath: path) {
            tabs.append(TabItem(fileURL: URL(fileURLWithPath: path)))
        }

        if tabs.isEmpty {
            addTab(document: EditorDocument())
        } else {
            let target = min(max(prefs.sessionActiveIndex, 0), tabs.count - 1)
            reloadTabBar()
            selectTab(at: target)
        }
    }

    /// Creates the single empty tab used by windows that don't restore a session.
    func startFresh() {
        if tabs.isEmpty {
            addTab(document: EditorDocument())
        }
    }

    private func persistSession() {
        let prefs = PreferencesStore.shared
        let paths = tabs.compactMap { $0.fileURL?.path }
        prefs.sessionFilePaths = paths
        // The active index refers to the persisted (file-backed) list, so map through it.
        if let activeURL = tabs[safe: selectedIndex]?.fileURL, let idx = paths.firstIndex(of: activeURL.path) {
            prefs.sessionActiveIndex = idx
        } else {
            prefs.sessionActiveIndex = paths.isEmpty ? -1 : 0
        }
        prefs.sessionFolderPath = sidebarDirectory?.path
    }

    // MARK: - Tab management

    func addTab(document: EditorDocument, select: Bool = true) {
        let tab = TabItem(fileURL: document.fileURL, placeholderTitle: document.customTitle)
        instantiateEditor(document: document, for: tab)
        tabs.append(tab)
        if select {
            selectTab(at: tabs.count - 1)
        } else {
            reloadTabBar()
        }
        persistSession()
    }

    private func instantiateEditor(document: EditorDocument, for tab: TabItem) {
        let controller = EditorViewController(document: document)
        controller.delegate = self
        _ = controller.view
        controller.textView?.onDoubleClickLine = { [weak self] line in
            self?.handleLineDoubleClick(line)
        }
        addChild(controller)
        tab.editor = controller
    }

    /// Materialises a restored tab's editor on first use. Returns false if the file
    /// can no longer be read, in which case the tab has been removed.
    @discardableResult
    private func ensureLoaded(at index: Int) -> Bool {
        guard let tab = tabs[safe: index] else { return false }
        if tab.isLoaded { return true }
        guard let url = tab.fileURL else {
            instantiateEditor(document: EditorDocument(), for: tab)
            return true
        }
        do {
            let document = try EditorDocument.load(url: url)
            instantiateEditor(document: document, for: tab)
            return true
        } catch {
            showErrorAlert(error)
            tabs.remove(at: index)
            if selectedIndex >= tabs.count { selectedIndex = tabs.count - 1 }
            reloadTabBar()
            persistSession()
            return false
        }
    }

    private func reloadTabBar() {
        let titles = tabs.map { $0.displayName }
        let dirty = tabs.map { $0.isDirty }
        tabBar.reload(titles: titles, selectedIndex: selectedIndex, dirtyFlags: dirty)
        sidebarProxy?.updateOpenFiles(titles: titles,
                                      dirtyFlags: dirty,
                                      loadedFlags: tabs.map { $0.isLoaded },
                                      selectedIndex: selectedIndex)
    }

    private func selectTab(at index: Int) {
        guard index >= 0, index < tabs.count else { return }
        guard ensureLoaded(at: index) else {
            // The file vanished; fall back to whatever tab is now at this position.
            if tabs.isEmpty { addTab(document: EditorDocument()) } else { selectTab(at: min(index, tabs.count - 1)) }
            return
        }
        if let previous = tabs[safe: selectedIndex]?.editor {
            previous.view.removeFromSuperview()
            previous.clearSearchHighlights()
        }
        selectedIndex = index
        guard let controller = tabs[index].editor else { return }
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
        persistSession()

        if !findBarController.view.isHidden {
            findBarController.focusFindField()
        }
    }

    private func updateWindowTitle() {
        guard let tab = tabs[safe: selectedIndex] else { return }
        view.window?.title = tab.displayName
        view.window?.representedURL = tab.fileURL
        view.window?.isDocumentEdited = tab.isDirty
        updateStatusBar()
    }

    private func updateStatusBar() {
        guard let editor = tabs[safe: selectedIndex]?.editor else { return }
        editor.reportStatus()
    }

    @objc func newTab(_ sender: Any?) {
        addTab(document: EditorDocument())
    }

    @objc func closeTab(_ sender: Any?) {
        closeTab(at: selectedIndex)
    }

    private func closeTab(at index: Int) {
        guard index >= 0, index < tabs.count else { return }
        let tab = tabs[index]
        if tab.isDirty {
            switch promptToSave(tabIndex: index) {
            case .cancelled: return
            case .saved, .discarded: break
            }
        }
        if let editor = tab.editor {
            editor.view.removeFromSuperview()
            editor.removeFromParent()
        }
        tabs.remove(at: index)
        if tabs.isEmpty {
            selectedIndex = -1
            addTab(document: EditorDocument())
            return
        }
        let newIndex = min(index, tabs.count - 1)
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

    // MARK: - Unsaved-changes handling

    private enum SavePromptResult { case saved, discarded, cancelled }

    /// Shows the standard Save / Don't Save / Cancel alert for one tab, bringing it
    /// to the front first so the user can see what they're deciding about.
    private func promptToSave(tabIndex: Int) -> SavePromptResult {
        guard let tab = tabs[safe: tabIndex], let editor = tab.editor else { return .discarded }
        if tabIndex != selectedIndex { selectTab(at: tabIndex) }

        let alert = NSAlert()
        alert.messageText = "Do you want to save the changes made to \"\(tab.displayName)\"?"
        alert.informativeText = "Your changes will be lost if you don't save them."
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Don't Save")
        alert.addButton(withTitle: "Cancel")
        switch alert.runModal() {
        case .alertFirstButtonReturn:
            return performSave(for: editor) ? .saved : .cancelled
        case .alertThirdButtonReturn:
            return .cancelled
        default:
            return .discarded
        }
    }

    var dirtyTabCount: Int { tabs.filter { $0.isDirty }.count }

    /// Walks every tab with unsaved changes. Returns false if the user cancelled,
    /// meaning the enclosing close/quit should be abandoned.
    func reviewUnsavedChanges() -> Bool {
        while let index = tabs.firstIndex(where: { $0.isDirty }) {
            if promptToSave(tabIndex: index) == .cancelled { return false }
            // A discarded tab is still dirty, so clear the flag to move past it.
            tabs[index].editor?.document.isDirty = false
            reloadTabBar()
        }
        persistSession()
        return true
    }

    /// Persists the tab list; called before the window closes or the app quits.
    func prepareForClose() {
        persistSession()
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
        if let index = tabs.firstIndex(where: { $0.fileURL == url }) {
            selectTab(at: index)
            return
        }
        do {
            let doc = try EditorDocument.load(url: url)
            // Reuse a single pristine Untitled tab rather than leaving it behind.
            if tabs.count == 1, let only = tabs.first, only.fileURL == nil, !only.isDirty,
               only.editor?.textView.string.isEmpty ?? true {
                only.editor?.removeFromParent()
                only.editor?.view.removeFromSuperview()
                tabs.removeAll()
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
            self.persistSession()
        }
    }

    @objc func saveDocument(_ sender: Any?) {
        guard let editor = currentEditorChecked() else { return }
        performSave(for: editor)
    }

    @objc func saveDocumentAs(_ sender: Any?) {
        guard let editor = currentEditorChecked() else { return }
        performSaveAs(for: editor)
    }

    @discardableResult
    private func performSave(for controller: EditorViewController) -> Bool {
        controller.unfoldAllFolds()
        if let url = controller.document.fileURL {
            do {
                try controller.document.save(to: url)
                afterSave(controller)
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
        // Pre-fill the extension implied by the active highlighter, e.g. "Untitled.json".
        panel.nameFieldStringValue = controller.document.suggestedFileName
        let response = panel.runModal()
        guard response == .OK, let url = panel.url else { return false }
        do {
            try controller.document.save(to: url)
            afterSave(controller)
            return true
        } catch {
            showErrorAlert(error)
            return false
        }
    }

    private func afterSave(_ controller: EditorViewController) {
        if let tab = tabs.first(where: { $0.editor === controller }) {
            tab.fileURL = controller.document.fileURL
            tab.placeholderTitle = nil
        }
        // The saved name may have changed the language, so repaint.
        controller.rehighlightAll()
        reloadTabBar()
        updateWindowTitle()
        persistSession()
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
        PreferencesStore.shared.wordWrapEnabled.toggle()
    }

    @objc func toggleFold(_ sender: Any?) {
        guard let editor = currentEditorChecked() else { return }
        if !editor.toggleFoldAtCursor() {
            NSSound.beep()
        }
    }

    @objc func unfoldAll(_ sender: Any?) {
        currentEditorChecked()?.unfoldAllFolds()
    }

    // MARK: - Syntax highlighting

    @objc func setSyntaxLanguage(_ sender: Any?) {
        guard let item = sender as? NSMenuItem,
              let raw = item.representedObject as? String,
              let language = Language(rawValue: raw),
              let editor = currentEditorChecked() else { return }
        editor.setLanguage(language)
        updateWindowTitle()
    }

    // MARK: - NSMenuItemValidation

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.action {
        case #selector(toggleWordWrap(_:)):
            menuItem.state = PreferencesStore.shared.wordWrapEnabled ? .on : .off
            return true
        case #selector(setSyntaxLanguage(_:)):
            let current = tabs[safe: selectedIndex]?.editor?.document.language
            if let raw = menuItem.representedObject as? String {
                menuItem.state = (raw == current?.rawValue) ? .on : .off
            }
            return currentEditorChecked() != nil
        default:
            return true
        }
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
        guard let editor = currentEditorChecked() else { return }
        editor.unfoldAllFolds()
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
        view.window?.makeFirstResponder(tabs[safe: selectedIndex]?.editor?.textView)
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
        tabs[safe: selectedIndex]?.editor
    }

    // MARK: - EditorViewControllerDelegate

    func editorDidChangeStatus(_ controller: EditorViewController, line: Int, column: Int, selectionLength: Int) {
        guard controller === tabs[safe: selectedIndex]?.editor else { return }
        statusBar.update(line: line, column: column, selectionLength: selectionLength,
                          encoding: controller.document.encodingName,
                          language: controller.document.language.rawValue,
                          path: controller.document.fileURL?.path ?? controller.document.displayName)
    }

    func editorDidChangeDirtyState(_ controller: EditorViewController, isDirty: Bool) {
        reloadTabBar()
        if controller === tabs[safe: selectedIndex]?.editor {
            view.window?.isDocumentEdited = isDirty
        }
    }

    // MARK: - SidebarViewControllerDelegate

    func sidebarDidSelectFile(_ url: URL) {
        openFile(url: url)
    }

    func sidebarDidSelectOpenFile(at index: Int) {
        selectTab(at: index)
    }

    func sidebarDidCloseOpenFile(at index: Int) {
        closeTab(at: index)
    }

    func sidebarDidRequestNewTab() {
        newTab(nil)
    }

    // MARK: - FindReplaceHost

    func frCurrentEditor() -> EditorViewController? { currentEditorChecked() }
    func frAllEditors() -> [EditorViewController] { editors }
    func frOpenFile(url: URL) { openFile(url: url) }
    func frSearchDirectory() -> URL? { sidebarDirectory }
    func frJumpToEditor(_ controller: EditorViewController) {
        if let idx = tabs.firstIndex(where: { $0.editor === controller }) {
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

        if let existingIdx = tabs.firstIndex(where: { $0.displayName == "Find Results" }),
           let ed = tabs[existingIdx].editor {
            let fullRange = NSRange(location: 0, length: (ed.textView.string as NSString).length)
            if ed.textView.shouldChangeText(in: fullRange, replacementString: output) {
                ed.textView.replaceCharacters(in: fullRange, with: output)
                ed.textView.didChangeText()
            }
            // Search output isn't user-authored content; don't prompt to save it.
            ed.document.isDirty = false
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
