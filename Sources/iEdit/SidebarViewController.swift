import Cocoa

final class FileNode {
    let url: URL
    let isDirectory: Bool
    var children: [FileNode]?

    init(url: URL, isDirectory: Bool) {
        self.url = url
        self.isDirectory = isDirectory
    }

    func loadChildren() -> [FileNode] {
        if let children { return children }
        guard isDirectory else { return [] }
        let fm = FileManager.default
        let contents = (try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])) ?? []
        let nodes = contents.sorted { a, b in
            a.lastPathComponent.localizedCaseInsensitiveCompare(b.lastPathComponent) == .orderedAscending
        }.map { childURL -> FileNode in
            var isDir: ObjCBool = false
            fm.fileExists(atPath: childURL.path, isDirectory: &isDir)
            return FileNode(url: childURL, isDirectory: isDir.boolValue)
        }
        children = nodes
        return nodes
    }
}

/// A row in the "Open Files" section, mirroring one tab by position.
final class OpenFileNode {
    let index: Int
    let title: String
    let isDirty: Bool
    let isLoaded: Bool

    init(index: Int, title: String, isDirty: Bool, isLoaded: Bool) {
        self.index = index
        self.title = title
        self.isDirty = isDirty
        self.isLoaded = isLoaded
    }
}

/// A non-selectable section header.
final class SidebarGroupNode {
    enum Kind { case openFiles, folder }
    let kind: Kind
    let title: String

    init(kind: Kind, title: String) {
        self.kind = kind
        self.title = title
    }
}

protocol SidebarViewControllerDelegate: AnyObject {
    func sidebarDidSelectFile(_ url: URL)
    func sidebarDidSelectOpenFile(at index: Int)
    func sidebarDidCloseOpenFile(at index: Int)
    func sidebarDidRequestNewTab()
}

final class SidebarViewController: NSViewController, NSOutlineViewDataSource, NSOutlineViewDelegate {

    weak var delegate: SidebarViewControllerDelegate?
    private var rootNode: FileNode?
    private let outlineView = NSOutlineView()
    private let scrollView = NSScrollView()
    private let newTabButton = NSButton()

    private let openFilesGroup = SidebarGroupNode(kind: .openFiles, title: "OPEN FILES")
    private let folderGroup = SidebarGroupNode(kind: .folder, title: "FOLDER")
    private var openFileNodes: [OpenFileNode] = []
    private var selectedOpenFileIndex: Int = -1
    /// Set while the controller drives selection itself, so programmatic changes
    /// don't echo back to the delegate as a user tab switch.
    private var isSyncingSelection = false

    func setRoot(url: URL) {
        rootNode = FileNode(url: url, isDirectory: true)
        folderGroupTitle = url.lastPathComponent.uppercased()
        outlineView.reloadData()
        expandGroups()
    }

    private var folderGroupTitle: String = "FOLDER"

    /// Rebuilds the "Open Files" section from the window's tabs.
    func updateOpenFiles(titles: [String], dirtyFlags: [Bool], loadedFlags: [Bool], selectedIndex: Int) {
        openFileNodes = titles.enumerated().map { index, title in
            OpenFileNode(index: index,
                         title: title,
                         isDirty: index < dirtyFlags.count ? dirtyFlags[index] : false,
                         isLoaded: index < loadedFlags.count ? loadedFlags[index] : true)
        }
        selectedOpenFileIndex = selectedIndex
        outlineView.reloadData()
        expandGroups()
        syncSelection()
    }

    private func expandGroups() {
        outlineView.expandItem(openFilesGroup, expandChildren: false)
        if rootNode != nil {
            outlineView.expandItem(folderGroup, expandChildren: false)
        }
    }

    private func syncSelection() {
        isSyncingSelection = true
        defer { isSyncingSelection = false }
        guard selectedOpenFileIndex >= 0, selectedOpenFileIndex < openFileNodes.count else {
            outlineView.deselectAll(nil)
            return
        }
        let row = outlineView.row(forItem: openFileNodes[selectedOpenFileIndex])
        if row >= 0 {
            outlineView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        }
    }

    override func loadView() {
        let container = NSView()

        newTabButton.title = "New Tab +"
        newTabButton.bezelStyle = .rounded
        newTabButton.controlSize = .regular
        newTabButton.target = self
        newTabButton.action = #selector(newTabTapped)
        newTabButton.translatesAutoresizingMaskIntoConstraints = false

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        column.title = "Name"
        outlineView.addTableColumn(column)
        outlineView.outlineTableColumn = column
        outlineView.headerView = nil
        outlineView.dataSource = self
        outlineView.delegate = self
        outlineView.rowSizeStyle = .small
        outlineView.floatsGroupRows = false
        outlineView.indentationPerLevel = 12
        outlineView.target = self
        outlineView.doubleAction = #selector(handleDoubleClick)

        scrollView.documentView = outlineView
        scrollView.hasVerticalScroller = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(newTabButton)
        container.addSubview(scrollView)

        NSLayoutConstraint.activate([
            newTabButton.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            newTabButton.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
            newTabButton.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8),

            scrollView.topAnchor.constraint(equalTo: newTabButton.bottomAnchor, constant: 8),
            scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
        ])

        self.view = container
        outlineView.reloadData()
        expandGroups()
    }

    @objc private func newTabTapped() {
        delegate?.sidebarDidRequestNewTab()
    }

    @objc private func closeOpenFileTapped(_ sender: NSButton) {
        delegate?.sidebarDidCloseOpenFile(at: sender.tag)
    }

    @objc private func handleDoubleClick() {
        let row = outlineView.clickedRow
        guard row >= 0 else { return }
        let item = outlineView.item(atRow: row)
        if let node = item as? FileNode {
            if !node.isDirectory {
                delegate?.sidebarDidSelectFile(node.url)
            } else if outlineView.isItemExpanded(node) {
                outlineView.collapseItem(node)
            } else {
                outlineView.expandItem(node)
            }
        } else if let group = item as? SidebarGroupNode {
            if outlineView.isItemExpanded(group) {
                outlineView.collapseItem(group)
            } else {
                outlineView.expandItem(group)
            }
        }
    }

    // MARK: NSOutlineViewDataSource

    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if item == nil { return rootNode == nil ? 1 : 2 }
        if let group = item as? SidebarGroupNode {
            switch group.kind {
            case .openFiles: return openFileNodes.count
            case .folder: return rootNode == nil ? 0 : 1
            }
        }
        guard let node = item as? FileNode else { return 0 }
        return node.loadChildren().count
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if item == nil {
            return index == 0 ? openFilesGroup : folderGroup
        }
        if let group = item as? SidebarGroupNode {
            switch group.kind {
            case .openFiles: return openFileNodes[index]
            case .folder: return rootNode!
            }
        }
        let node = item as! FileNode
        return node.loadChildren()[index]
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        if item is SidebarGroupNode { return true }
        return (item as? FileNode)?.isDirectory ?? false
    }

    func outlineView(_ outlineView: NSOutlineView, isGroupItem item: Any) -> Bool {
        item is SidebarGroupNode
    }

    func outlineView(_ outlineView: NSOutlineView, shouldSelectItem item: Any) -> Bool {
        !(item is SidebarGroupNode)
    }

    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        if let group = item as? SidebarGroupNode {
            return groupCell(for: group)
        }
        if let openFile = item as? OpenFileNode {
            return openFileCell(for: openFile)
        }
        if let node = item as? FileNode {
            return fileCell(for: node)
        }
        return nil
    }

    func outlineViewSelectionDidChange(_ notification: Notification) {
        guard !isSyncingSelection else { return }
        let row = outlineView.selectedRow
        guard row >= 0, let node = outlineView.item(atRow: row) as? OpenFileNode else { return }
        guard node.index != selectedOpenFileIndex else { return }
        delegate?.sidebarDidSelectOpenFile(at: node.index)
    }

    // MARK: - Cells

    private func groupCell(for group: SidebarGroupNode) -> NSView {
        let identifier = NSUserInterfaceItemIdentifier("groupCell")
        var cell = outlineView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView
        if cell == nil {
            cell = NSTableCellView()
            cell?.identifier = identifier
            let field = NSTextField(labelWithString: "")
            field.font = NSFont.systemFont(ofSize: 10, weight: .semibold)
            field.textColor = .secondaryLabelColor
            field.translatesAutoresizingMaskIntoConstraints = false
            cell?.addSubview(field)
            cell?.textField = field
            NSLayoutConstraint.activate([
                field.leadingAnchor.constraint(equalTo: cell!.leadingAnchor, constant: 2),
                field.trailingAnchor.constraint(equalTo: cell!.trailingAnchor, constant: -2),
                field.centerYAnchor.constraint(equalTo: cell!.centerYAnchor),
            ])
        }
        cell?.textField?.stringValue = group.kind == .folder ? folderGroupTitle : group.title
        return cell!
    }

    private func openFileCell(for node: OpenFileNode) -> NSView {
        let identifier = NSUserInterfaceItemIdentifier("openFileCell")
        var cell = outlineView.makeView(withIdentifier: identifier, owner: self) as? OpenFileCellView
        if cell == nil {
            cell = OpenFileCellView()
            cell?.identifier = identifier
            cell?.closeButton.target = self
            cell?.closeButton.action = #selector(closeOpenFileTapped(_:))
        }
        cell?.configure(node: node)
        return cell!
    }

    private func fileCell(for node: FileNode) -> NSView {
        let identifier = NSUserInterfaceItemIdentifier("cell")
        var cell = outlineView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView
        if cell == nil {
            cell = NSTableCellView()
            cell?.identifier = identifier
            let imageView = NSImageView()
            let textField = NSTextField(labelWithString: "")
            textField.font = NSFont.systemFont(ofSize: 12)
            imageView.translatesAutoresizingMaskIntoConstraints = false
            textField.translatesAutoresizingMaskIntoConstraints = false
            cell?.addSubview(imageView)
            cell?.addSubview(textField)
            cell?.imageView = imageView
            cell?.textField = textField
            NSLayoutConstraint.activate([
                imageView.leadingAnchor.constraint(equalTo: cell!.leadingAnchor, constant: 2),
                imageView.centerYAnchor.constraint(equalTo: cell!.centerYAnchor),
                imageView.widthAnchor.constraint(equalToConstant: 16),
                imageView.heightAnchor.constraint(equalToConstant: 16),
                textField.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 4),
                textField.trailingAnchor.constraint(equalTo: cell!.trailingAnchor, constant: -2),
                textField.centerYAnchor.constraint(equalTo: cell!.centerYAnchor),
            ])
        }
        cell?.textField?.stringValue = node.url.lastPathComponent
        let symbolName = node.isDirectory ? "folder" : "doc.text"
        cell?.imageView?.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
        return cell!
    }
}

/// Open-files row: icon, name (with a dot when unsaved) and a close button.
final class OpenFileCellView: NSTableCellView {
    private let icon = NSImageView()
    private let label = NSTextField(labelWithString: "")
    let closeButton = NSButton()

    init() {
        super.init(frame: .zero)

        icon.translatesAutoresizingMaskIntoConstraints = false
        label.font = NSFont.systemFont(ofSize: 12)
        label.lineBreakMode = .byTruncatingMiddle
        label.translatesAutoresizingMaskIntoConstraints = false

        closeButton.isBordered = false
        closeButton.title = ""
        closeButton.image = NSImage(systemSymbolName: "xmark", accessibilityDescription: "Close Tab")
        closeButton.image?.isTemplate = true
        closeButton.imageScaling = .scaleProportionallyDown
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.setAccessibilityLabel("Close Tab")

        addSubview(icon)
        addSubview(label)
        addSubview(closeButton)
        self.imageView = icon
        self.textField = label

        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 2),
            icon.centerYAnchor.constraint(equalTo: centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 14),
            icon.heightAnchor.constraint(equalToConstant: 14),

            label.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 4),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            label.trailingAnchor.constraint(lessThanOrEqualTo: closeButton.leadingAnchor, constant: -4),

            closeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            closeButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 13),
            closeButton.heightAnchor.constraint(equalToConstant: 13),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(node: OpenFileNode) {
        label.stringValue = node.isDirty ? "\u{2022} \(node.title)" : node.title
        // Not-yet-loaded tabs restored from the last session read as dimmed.
        label.textColor = node.isLoaded ? .labelColor : .secondaryLabelColor
        icon.image = NSImage(systemSymbolName: "doc.text", accessibilityDescription: nil)
        closeButton.tag = node.index
    }
}
