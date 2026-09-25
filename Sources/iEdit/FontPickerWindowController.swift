import Cocoa

/// Modal sheet-style picker listing the system's fixed-pitch font families with a
/// size field and a live preview. Applying writes through `EditorFontManager`,
/// which persists the choice for this and future sessions.
final class FontPickerWindowController: NSWindowController, NSTableViewDelegate, NSTableViewDataSource, NSWindowDelegate {

    private let tableView = NSTableView()
    private let sizeField = NSTextField()
    private let sizeStepper = NSStepper()
    private let previewView = NSTextView()
    private var families: [String] = []

    /// Row 0 is always the system monospaced font; `families` follows.
    private var selectedFamily: String?
    private var selectedSize: CGFloat = EditorFontManager.defaultSize

    convenience init() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 460, height: 420),
                              styleMask: [.titled, .closable],
                              backing: .buffered,
                              defer: false)
        window.title = "Editor Font"
        self.init(window: window)
        buildUI()
    }

    private func buildUI() {
        guard let window else { return }
        families = EditorFontManager.availableMonospaceFamilies()
        selectedFamily = EditorFontManager.shared.familyName
        selectedSize = EditorFontManager.shared.size

        let content = NSView()

        let fontLabel = NSTextField(labelWithString: "Font")
        let sizeLabel = NSTextField(labelWithString: "Size")
        let previewLabel = NSTextField(labelWithString: "Preview")
        for label in [fontLabel, sizeLabel, previewLabel] {
            label.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
            label.textColor = .secondaryLabelColor
            label.translatesAutoresizingMaskIntoConstraints = false
        }

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("family"))
        column.title = "Font"
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowSizeStyle = .default
        tableView.allowsEmptySelection = false

        let scroll = NSScrollView()
        scroll.documentView = tableView
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder
        scroll.translatesAutoresizingMaskIntoConstraints = false

        sizeField.translatesAutoresizingMaskIntoConstraints = false
        sizeField.alignment = .right
        sizeField.target = self
        sizeField.action = #selector(sizeFieldChanged)
        sizeField.stringValue = "\(Int(selectedSize.rounded()))"

        sizeStepper.translatesAutoresizingMaskIntoConstraints = false
        sizeStepper.minValue = Double(EditorFontManager.minSize)
        sizeStepper.maxValue = Double(EditorFontManager.maxSize)
        sizeStepper.increment = 1
        sizeStepper.integerValue = Int(selectedSize.rounded())
        sizeStepper.target = self
        sizeStepper.action = #selector(stepperChanged)

        previewView.isEditable = false
        previewView.isSelectable = false
        previewView.drawsBackground = true
        previewView.backgroundColor = .textBackgroundColor
        previewView.textContainerInset = NSSize(width: 6, height: 6)
        let previewScroll = NSScrollView()
        previewScroll.documentView = previewView
        previewScroll.hasVerticalScroller = false
        previewScroll.borderType = .bezelBorder
        previewScroll.translatesAutoresizingMaskIntoConstraints = false

        let resetButton = NSButton(title: "Use Default", target: self, action: #selector(resetTapped))
        let cancelButton = NSButton(title: "Cancel", target: self, action: #selector(cancelTapped))
        let applyButton = NSButton(title: "Apply", target: self, action: #selector(applyTapped))
        applyButton.keyEquivalent = "\r"
        cancelButton.keyEquivalent = "\u{1b}"
        for button in [resetButton, cancelButton, applyButton] {
            button.bezelStyle = .rounded
            button.translatesAutoresizingMaskIntoConstraints = false
            content.addSubview(button)
        }

        content.addSubview(fontLabel)
        content.addSubview(scroll)
        content.addSubview(sizeLabel)
        content.addSubview(sizeField)
        content.addSubview(sizeStepper)
        content.addSubview(previewLabel)
        content.addSubview(previewScroll)

        NSLayoutConstraint.activate([
            fontLabel.topAnchor.constraint(equalTo: content.topAnchor, constant: 14),
            fontLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 18),

            scroll.topAnchor.constraint(equalTo: fontLabel.bottomAnchor, constant: 4),
            scroll.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 18),
            scroll.trailingAnchor.constraint(equalTo: sizeLabel.leadingAnchor, constant: -14),
            scroll.heightAnchor.constraint(equalToConstant: 220),

            sizeLabel.topAnchor.constraint(equalTo: fontLabel.topAnchor),
            sizeLabel.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -18),
            sizeLabel.widthAnchor.constraint(equalToConstant: 74),

            sizeField.topAnchor.constraint(equalTo: scroll.topAnchor),
            sizeField.leadingAnchor.constraint(equalTo: sizeLabel.leadingAnchor),
            sizeField.widthAnchor.constraint(equalToConstant: 50),

            sizeStepper.centerYAnchor.constraint(equalTo: sizeField.centerYAnchor),
            sizeStepper.leadingAnchor.constraint(equalTo: sizeField.trailingAnchor, constant: 4),

            previewLabel.topAnchor.constraint(equalTo: scroll.bottomAnchor, constant: 14),
            previewLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 18),

            previewScroll.topAnchor.constraint(equalTo: previewLabel.bottomAnchor, constant: 4),
            previewScroll.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 18),
            previewScroll.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -18),
            previewScroll.heightAnchor.constraint(equalToConstant: 72),

            resetButton.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 18),
            resetButton.topAnchor.constraint(equalTo: previewScroll.bottomAnchor, constant: 14),
            resetButton.bottomAnchor.constraint(lessThanOrEqualTo: content.bottomAnchor, constant: -14),

            applyButton.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -18),
            applyButton.centerYAnchor.constraint(equalTo: resetButton.centerYAnchor),
            applyButton.widthAnchor.constraint(greaterThanOrEqualTo: cancelButton.widthAnchor),

            cancelButton.trailingAnchor.constraint(equalTo: applyButton.leadingAnchor, constant: -10),
            cancelButton.centerYAnchor.constraint(equalTo: resetButton.centerYAnchor),
        ])

        window.contentView = content
        tableView.reloadData()
        selectCurrentRow()
        updatePreview()
    }

    private func selectCurrentRow() {
        let row: Int
        if let family = selectedFamily, let index = families.firstIndex(of: family) {
            row = index + 1
        } else {
            row = 0
        }
        tableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        tableView.scrollRowToVisible(row)
    }

    private func currentFont() -> NSFont {
        if let family = selectedFamily, let font = EditorFontManager.resolveFont(family: family, size: selectedSize) {
            return font
        }
        return NSFont.monospacedSystemFont(ofSize: selectedSize, weight: .regular)
    }

    private func updatePreview() {
        previewView.string = "func greet(name: String) {\n    print(\"Hello, \\(name)!\")  // 0123456789\n}"
        previewView.font = currentFont()
        previewView.textColor = .textColor
    }

    // MARK: - Actions

    @objc private func sizeFieldChanged() {
        let value = CGFloat(sizeField.doubleValue)
        selectedSize = min(max(value, EditorFontManager.minSize), EditorFontManager.maxSize)
        sizeField.stringValue = "\(Int(selectedSize.rounded()))"
        sizeStepper.integerValue = Int(selectedSize.rounded())
        updatePreview()
    }

    @objc private func stepperChanged() {
        selectedSize = CGFloat(sizeStepper.integerValue)
        sizeField.stringValue = "\(Int(selectedSize.rounded()))"
        updatePreview()
    }

    @objc private func resetTapped() {
        selectedFamily = nil
        selectedSize = EditorFontManager.defaultSize
        sizeField.stringValue = "\(Int(selectedSize.rounded()))"
        sizeStepper.integerValue = Int(selectedSize.rounded())
        selectCurrentRow()
        updatePreview()
    }

    @objc private func cancelTapped() {
        close()
    }

    @objc private func applyTapped() {
        // Commit any in-progress edit in the size field before reading it.
        window?.makeFirstResponder(nil)
        sizeFieldChanged()
        EditorFontManager.shared.setFont(family: selectedFamily, size: selectedSize)
        close()
    }

    func runModal() {
        guard let window else { return }
        window.delegate = self
        window.center()
        showWindow(nil)
        NSApp.runModal(for: window)
    }

    /// Covers every way out of the sheet — Apply, Cancel, Escape and the close
    /// button all funnel through here, so the modal session always ends.
    func windowWillClose(_ notification: Notification) {
        NSApp.stopModal()
    }

    // MARK: - NSTableViewDataSource / Delegate

    func numberOfRows(in tableView: NSTableView) -> Int { families.count + 1 }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let identifier = NSUserInterfaceItemIdentifier("familyCell")
        var cell = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView
        if cell == nil {
            cell = NSTableCellView()
            cell?.identifier = identifier
            let field = NSTextField(labelWithString: "")
            field.translatesAutoresizingMaskIntoConstraints = false
            cell?.addSubview(field)
            cell?.textField = field
            NSLayoutConstraint.activate([
                field.leadingAnchor.constraint(equalTo: cell!.leadingAnchor, constant: 4),
                field.trailingAnchor.constraint(equalTo: cell!.trailingAnchor, constant: -4),
                field.centerYAnchor.constraint(equalTo: cell!.centerYAnchor),
            ])
        }
        let family = row == 0 ? nil : families[row - 1]
        cell?.textField?.stringValue = family ?? EditorFontManager.systemMonospaceLabel
        // Render each row in its own face so the list is self-describing.
        if let family, let font = EditorFontManager.resolveFont(family: family, size: 13) {
            cell?.textField?.font = font
        } else {
            cell?.textField?.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        }
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let row = tableView.selectedRow
        guard row >= 0 else { return }
        selectedFamily = row == 0 ? nil : families[row - 1]
        updatePreview()
    }
}
