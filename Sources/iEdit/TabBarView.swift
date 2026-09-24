import Cocoa

final class TabChipView: NSView {
    let index: Int
    var isSelected: Bool = false { didSet { needsDisplay = true } }
    var isDirty: Bool = false { didSet { needsDisplay = true } }
    let titleField = NSTextField(labelWithString: "")
    let closeButton = NSButton()
    var onSelect: ((Int) -> Void)?
    var onClose: ((Int) -> Void)?

    init(index: Int, title: String) {
        self.index = index
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 6

        titleField.stringValue = title
        titleField.font = NSFont.systemFont(ofSize: 12)
        titleField.lineBreakMode = .byTruncatingTail
        titleField.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleField)

        closeButton.title = ""
        closeButton.isBordered = false
        closeButton.image = NSImage(systemSymbolName: "xmark", accessibilityDescription: "Close")
        closeButton.image?.isTemplate = true
        closeButton.imageScaling = .scaleProportionallyDown
        closeButton.target = self
        closeButton.action = #selector(closeTapped)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(closeButton)

        NSLayoutConstraint.activate([
            titleField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            titleField.centerYAnchor.constraint(equalTo: centerYAnchor),
            titleField.trailingAnchor.constraint(lessThanOrEqualTo: closeButton.leadingAnchor, constant: -6),

            closeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            closeButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 14),
            closeButton.heightAnchor.constraint(equalToConstant: 14),
        ])

        let click = NSClickGestureRecognizer(target: self, action: #selector(selectTapped))
        addGestureRecognizer(click)
    }

    required init?(coder: NSCoder) { fatalError() }

    func setTitle(_ title: String) {
        titleField.stringValue = isDirty ? "\u{2022} \(title)" : title
    }

    @objc private func selectTapped() { onSelect?(index) }
    @objc private func closeTapped() { onClose?(index) }

    override func draw(_ dirtyRect: NSRect) {
        (isSelected ? NSColor.controlAccentColor.withAlphaComponent(0.18) : NSColor.clear).setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 6, yRadius: 6).fill()
        super.draw(dirtyRect)
    }

    override var intrinsicContentSize: NSSize { NSSize(width: 140, height: 28) }
}

protocol TabBarViewDelegate: AnyObject {
    func tabBar(_ tabBar: TabBarView, didSelectIndex index: Int)
    func tabBar(_ tabBar: TabBarView, didCloseIndex index: Int)
    func tabBarDidRequestNewTab(_ tabBar: TabBarView)
}

final class TabBarView: NSView {
    weak var delegate: TabBarViewDelegate?
    private let stack = NSStackView()
    private let scrollView = NSScrollView()
    private let newTabButton = NSButton()
    private var chips: [TabChipView] = []

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        stack.orientation = .horizontal
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasHorizontalScroller = false
        scrollView.hasVerticalScroller = false
        scrollView.drawsBackground = false
        let clip = FlippedClipView()
        clip.drawsBackground = false
        scrollView.contentView = clip
        scrollView.documentView = stack

        newTabButton.title = ""
        newTabButton.isBordered = false
        newTabButton.image = NSImage(systemSymbolName: "plus", accessibilityDescription: "New Tab")
        newTabButton.target = self
        newTabButton.action = #selector(newTabTapped)
        newTabButton.translatesAutoresizingMaskIntoConstraints = false

        addSubview(scrollView)
        addSubview(newTabButton)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            scrollView.trailingAnchor.constraint(equalTo: newTabButton.leadingAnchor, constant: -4),

            newTabButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            newTabButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            newTabButton.widthAnchor.constraint(equalToConstant: 20),
            newTabButton.heightAnchor.constraint(equalToConstant: 20),

            stack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 4),
            stack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -4),
            stack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            stack.heightAnchor.constraint(equalToConstant: 28),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    @objc private func newTabTapped() { delegate?.tabBarDidRequestNewTab(self) }

    func reload(titles: [String], selectedIndex: Int, dirtyFlags: [Bool]) {
        stack.subviews.forEach { $0.removeFromSuperview() }
        chips.removeAll()
        for (i, title) in titles.enumerated() {
            let chip = TabChipView(index: i, title: title)
            chip.isDirty = i < dirtyFlags.count ? dirtyFlags[i] : false
            chip.setTitle(title)
            chip.isSelected = (i == selectedIndex)
            chip.onSelect = { [weak self] idx in
                guard let self else { return }
                self.delegate?.tabBar(self, didSelectIndex: idx)
            }
            chip.onClose = { [weak self] idx in
                guard let self else { return }
                self.delegate?.tabBar(self, didCloseIndex: idx)
            }
            chip.translatesAutoresizingMaskIntoConstraints = false
            chip.widthAnchor.constraint(equalToConstant: 150).isActive = true
            stack.addView(chip, in: .leading)
            chips.append(chip)
        }
    }
}

final class FlippedClipView: NSClipView {
    override var isFlipped: Bool { false }
}
