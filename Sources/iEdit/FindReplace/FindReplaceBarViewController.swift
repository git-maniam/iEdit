import Cocoa

enum SearchScope: Int {
    case currentFile = 0
    case allOpenTabs = 1
    case directory = 2
}

struct FindInFilesResult {
    let url: URL
    let lineNumber: Int
    let lineText: String
    let matchRange: NSRange
}

final class FindReplaceBarViewController: NSViewController, NSTextFieldDelegate, NSTableViewDataSource, NSTableViewDelegate {

    weak var host: FindReplaceHost?

    private let findField = NSTextField()
    private let replaceField = NSTextField()
    private let matchCaseCheck = NSButton(checkboxWithTitle: "Match Case", target: nil, action: nil)
    private let wholeWordCheck = NSButton(checkboxWithTitle: "Whole Word", target: nil, action: nil)
    private let regexCheck = NSButton(checkboxWithTitle: "Regex", target: nil, action: nil)
    private let escapesCheck = NSButton(checkboxWithTitle: "\\n Escapes", target: nil, action: nil)
    private let wrapCheck = NSButton(checkboxWithTitle: "Wrap Around", target: nil, action: nil)
    private let scopePopup = NSPopUpButton()
    private let chooseFolderButton = NSButton(title: "Choose Folder…", target: nil, action: nil)
    private let folderLabel = NSTextField(labelWithString: "No folder selected")
    private let statusLabel = NSTextField(labelWithString: "")
    private let resultsTable = NSTableView()
    private let resultsScroll = NSScrollView()
    private var resultsHeightConstraint: NSLayoutConstraint!

    private(set) var searchDirectory: URL?
    private var results: [FindInFilesResult] = []

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
        root.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor

        findField.placeholderString = "Find"
        findField.delegate = self
        findField.target = self
        findField.action = #selector(findNext(_:))

        replaceField.placeholderString = "Replace with"
        replaceField.delegate = self

        wrapCheck.state = .on
        escapesCheck.state = .on

        scopePopup.addItems(withTitles: ["Current File", "All Open Tabs", "Directory"])
        scopePopup.target = self
        scopePopup.action = #selector(scopeChanged)

        chooseFolderButton.target = self
        chooseFolderButton.action = #selector(chooseFolder)
        chooseFolderButton.isHidden = true
        folderLabel.isHidden = true
        folderLabel.font = NSFont.systemFont(ofSize: 11)
        folderLabel.textColor = .secondaryLabelColor

        let findNextBtn = NSButton(title: "Next", target: self, action: #selector(findNext(_:)))
        let findPrevBtn = NSButton(title: "Previous", target: self, action: #selector(findPrevious(_:)))
        let countBtn = NSButton(title: "Count", target: self, action: #selector(countMatches))
        let replaceBtn = NSButton(title: "Replace", target: self, action: #selector(replaceOne))
        let replaceAllBtn = NSButton(title: "Replace All", target: self, action: #selector(replaceAll))
        let closeBtn = NSButton(title: "", target: self, action: #selector(closeBar))
        closeBtn.isBordered = false
        closeBtn.image = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: "Close")

        statusLabel.font = NSFont.systemFont(ofSize: 11)
        statusLabel.textColor = .secondaryLabelColor

        let toggles = NSStackView(views: [matchCaseCheck, wholeWordCheck, regexCheck, escapesCheck, wrapCheck])
        toggles.orientation = .horizontal
        toggles.spacing = 10

        let row1 = NSStackView(views: [findField, findPrevBtn, findNextBtn, countBtn, closeBtn])
        row1.orientation = .horizontal
        row1.spacing = 6
        findField.translatesAutoresizingMaskIntoConstraints = false

        let row2 = NSStackView(views: [replaceField, replaceBtn, replaceAllBtn])
        row2.orientation = .horizontal
        row2.spacing = 6
        replaceField.translatesAutoresizingMaskIntoConstraints = false

        let row3 = NSStackView(views: [scopePopup, chooseFolderButton, folderLabel, NSView(), statusLabel])
        row3.orientation = .horizontal
        row3.spacing = 10

        let column = NSStackView(views: [row1, row2, toggles, row3])
        column.orientation = .vertical
        column.alignment = .leading
        column.spacing = 6
        column.edgeInsets = NSEdgeInsets(top: 8, left: 10, bottom: 8, right: 10)
        column.translatesAutoresizingMaskIntoConstraints = false

        resultsTable.headerView = nil
        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("result"))
        resultsTable.addTableColumn(col)
        resultsTable.dataSource = self
        resultsTable.delegate = self
        resultsTable.target = self
        resultsTable.doubleAction = #selector(resultDoubleClicked)
        resultsScroll.documentView = resultsTable
        resultsScroll.hasVerticalScroller = true
        resultsScroll.translatesAutoresizingMaskIntoConstraints = false
        resultsScroll.isHidden = true

        root.addSubview(column)
        root.addSubview(resultsScroll)

        NSLayoutConstraint.activate([
            column.topAnchor.constraint(equalTo: root.topAnchor),
            column.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            column.trailingAnchor.constraint(equalTo: root.trailingAnchor),

            resultsScroll.topAnchor.constraint(equalTo: column.bottomAnchor),
            resultsScroll.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 10),
            resultsScroll.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -10),
            resultsScroll.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -8),
            findField.widthAnchor.constraint(greaterThanOrEqualToConstant: 240),
            replaceField.widthAnchor.constraint(greaterThanOrEqualToConstant: 240),
        ])
        resultsHeightConstraint = resultsScroll.heightAnchor.constraint(equalToConstant: 0)
        resultsHeightConstraint.isActive = true

        self.view = root
    }

    func focusFindField() {
        view.window?.makeFirstResponder(findField)
    }

    @objc private func scopeChanged() {
        let isDir = scope == .directory
        chooseFolderButton.isHidden = !isDir
        folderLabel.isHidden = !isDir
        resultsScroll.isHidden = !isDir
        resultsHeightConstraint.constant = isDir ? 160 : 0
    }

    @objc private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        if let initial = host?.frSearchDirectory() {
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

    // MARK: Actions

    @objc func findNext(_ sender: Any?) {
        performFind(forward: true)
    }

    @objc func findPrevious(_ sender: Any?) {
        performFind(forward: false)
    }

    private func performFind(forward: Bool) {
        guard let editor = host?.frCurrentEditor() else { return }
        do {
            let regex = try SearchEngine.buildRegex(find: findField.stringValue, options: options)
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
                editor.view.window?.makeFirstResponder(editor.textView)
                setStatus("Match found")
            } else {
                setStatus("No matches found")
            }
        } catch {
            setStatus(error.localizedDescription)
        }
    }

    @objc func countMatches() {
        do {
            let regex = try SearchEngine.buildRegex(find: findField.stringValue, options: options)
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
                runDirectorySearch(regex: regex, countOnly: true)
            }
        } catch {
            setStatus(error.localizedDescription)
        }
    }

    @objc func replaceOne() {
        guard let editor = host?.frCurrentEditor() else { return }
        do {
            let regex = try SearchEngine.buildRegex(find: findField.stringValue, options: options)
            let selected = editor.textView.selectedRange()
            let text = editor.textView.string as NSString
            if selected.length > 0, regex.firstMatch(in: editor.textView.string, range: selected) != nil {
                let template = SearchEngine.replacementTemplate(for: replaceField.stringValue, options: options)
                let match = regex.firstMatch(in: editor.textView.string, range: selected)!
                let replacement = regex.replacementString(for: match, in: editor.textView.string, offset: 0, template: template)
                if editor.textView.shouldChangeText(in: selected, replacementString: replacement) {
                    editor.textView.replaceCharacters(in: selected, with: replacement)
                    editor.textView.didChangeText()
                    editor.textView.setSelectedRange(NSRange(location: selected.location, length: (replacement as NSString).length))
                }
            }
            _ = text
            performFind(forward: true)
        } catch {
            setStatus(error.localizedDescription)
        }
    }

    @objc func replaceAll() {
        do {
            let regex = try SearchEngine.buildRegex(find: findField.stringValue, options: options)
            let template = SearchEngine.replacementTemplate(for: replaceField.stringValue, options: options)
            switch scope {
            case .currentFile:
                guard let editor = host?.frCurrentEditor() else { return }
                let (result, count) = SearchEngine.replaceAll(in: editor.textView.string, regex: regex, template: template)
                if count > 0 {
                    let full = NSRange(location: 0, length: (editor.textView.string as NSString).length)
                    editor.textView.textStorage?.replaceCharacters(in: full, with: result)
                    editor.textView.didChangeText()
                    editor.rehighlightAll()
                }
                setStatus("Replaced \(count) occurrence\(count == 1 ? "" : "s")")
            case .allOpenTabs:
                var total = 0
                for editor in host?.frAllEditors() ?? [] {
                    let (result, count) = SearchEngine.replaceAll(in: editor.textView.string, regex: regex, template: template)
                    if count > 0 {
                        let full = NSRange(location: 0, length: (editor.textView.string as NSString).length)
                        editor.textView.textStorage?.replaceCharacters(in: full, with: result)
                        editor.textView.didChangeText()
                        editor.rehighlightAll()
                    }
                    total += count
                }
                setStatus("Replaced \(total) occurrence\(total == 1 ? "" : "s") across all open tabs")
            case .directory:
                runDirectorySearchAndReplace(regex: regex, template: template)
            }
        } catch {
            setStatus(error.localizedDescription)
        }
    }

    @objc private func closeBar() {
        (parent as? MainViewController)?.hideFindBar()
    }

    // MARK: Directory search

    private func directoryFiles() -> [URL] {
        guard let dir = searchDirectory ?? host?.frSearchDirectory() else { return [] }
        let fm = FileManager.default
        var out: [URL] = []
        guard let enumerator = fm.enumerator(at: dir, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) else { return [] }
        let allowedExtensions: Set<String> = ["txt", "json", "html", "htm", "css", "js", "xml", "md", "swift", "plist", "log", "csv", "yml", "yaml"]
        for case let url as URL in enumerator {
            if allowedExtensions.contains(url.pathExtension.lowercased()) {
                out.append(url)
            }
        }
        return out
    }

    private func runDirectorySearch(regex: NSRegularExpression, countOnly: Bool) {
        results.removeAll()
        var totalCount = 0
        for url in directoryFiles() {
            guard let content = try? String(contentsOf: url, encoding: .utf8) else { continue }
            let ns = content as NSString
            let matches = regex.matches(in: content, range: NSRange(location: 0, length: ns.length))
            totalCount += matches.count
            if !countOnly {
                for match in matches {
                    let lineRange = ns.lineRange(for: match.range)
                    let lineText = ns.substring(with: lineRange).trimmingCharacters(in: .newlines)
                    var lineNumber = 1
                    var idx = 0
                    while idx < lineRange.location {
                        if ns.character(at: idx) == 10 { lineNumber += 1 }
                        idx += 1
                    }
                    results.append(FindInFilesResult(url: url, lineNumber: lineNumber, lineText: lineText, matchRange: match.range))
                }
            }
        }
        resultsTable.reloadData()
        setStatus("\(totalCount) occurrence\(totalCount == 1 ? "" : "s") in \(directoryFiles().count) files")
    }

    private func runDirectorySearchAndReplace(regex: NSRegularExpression, template: String) {
        var totalCount = 0
        var filesChanged = 0
        for url in directoryFiles() {
            guard let content = try? String(contentsOf: url, encoding: .utf8) else { continue }
            let (result, count) = SearchEngine.replaceAll(in: content, regex: regex, template: template)
            if count > 0 {
                try? result.write(to: url, atomically: true, encoding: .utf8)
                totalCount += count
                filesChanged += 1
            }
        }
        setStatus("Replaced \(totalCount) occurrence\(totalCount == 1 ? "" : "s") in \(filesChanged) file\(filesChanged == 1 ? "" : "s")")
    }

    @objc private func resultDoubleClicked() {
        let row = resultsTable.clickedRow
        guard row >= 0, row < results.count else { return }
        let result = results[row]
        host?.frOpenFile(url: result.url)
        if let editor = host?.frCurrentEditor() {
            editor.textView.scrollRangeToVisible(result.matchRange)
            editor.textView.setSelectedRange(result.matchRange)
        }
    }

    // MARK: NSTableViewDataSource / Delegate

    func numberOfRows(in tableView: NSTableView) -> Int { results.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let identifier = NSUserInterfaceItemIdentifier("resultCell")
        var cell = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView
        if cell == nil {
            cell = NSTableCellView()
            cell?.identifier = identifier
            let tf = NSTextField(labelWithString: "")
            tf.font = NSFont.systemFont(ofSize: 11)
            tf.lineBreakMode = .byTruncatingTail
            tf.translatesAutoresizingMaskIntoConstraints = false
            cell?.addSubview(tf)
            cell?.textField = tf
            NSLayoutConstraint.activate([
                tf.leadingAnchor.constraint(equalTo: cell!.leadingAnchor, constant: 4),
                tf.trailingAnchor.constraint(equalTo: cell!.trailingAnchor, constant: -4),
                tf.centerYAnchor.constraint(equalTo: cell!.centerYAnchor),
            ])
        }
        let result = results[row]
        cell?.textField?.stringValue = "\(result.url.lastPathComponent):\(result.lineNumber)  \(result.lineText)"
        return cell
    }
}
