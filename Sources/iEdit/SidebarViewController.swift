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

protocol SidebarViewControllerDelegate: AnyObject {
    func sidebarDidSelectFile(_ url: URL)
}

final class SidebarViewController: NSViewController, NSOutlineViewDataSource, NSOutlineViewDelegate {

    weak var delegate: SidebarViewControllerDelegate?
    private var rootNode: FileNode?
    private let outlineView = NSOutlineView()
    private let scrollView = NSScrollView()

    func setRoot(url: URL) {
        rootNode = FileNode(url: url, isDirectory: true)
        outlineView.reloadData()
        outlineView.expandItem(nil, expandChildren: false)
    }

    override func loadView() {
        let container = NSView()

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        column.title = "Name"
        outlineView.addTableColumn(column)
        outlineView.outlineTableColumn = column
        outlineView.headerView = nil
        outlineView.dataSource = self
        outlineView.delegate = self
        outlineView.rowSizeStyle = .small
        outlineView.floatsGroupRows = false
        outlineView.target = self
        outlineView.doubleAction = #selector(handleDoubleClick)

        scrollView.documentView = outlineView
        scrollView.hasVerticalScroller = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: container.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
        ])

        self.view = container
    }

    @objc private func handleDoubleClick() {
        let row = outlineView.clickedRow
        guard row >= 0, let node = outlineView.item(atRow: row) as? FileNode else { return }
        if !node.isDirectory {
            delegate?.sidebarDidSelectFile(node.url)
        } else {
            if outlineView.isItemExpanded(node) {
                outlineView.collapseItem(node)
            } else {
                outlineView.expandItem(node)
            }
        }
    }

    // MARK: NSOutlineViewDataSource

    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if item == nil { return rootNode == nil ? 0 : 1 }
        guard let node = item as? FileNode else { return 0 }
        return node.loadChildren().count
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if item == nil { return rootNode! }
        let node = item as! FileNode
        return node.loadChildren()[index]
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        (item as? FileNode)?.isDirectory ?? false
    }

    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        guard let node = item as? FileNode else { return nil }
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
        return cell
    }
}
