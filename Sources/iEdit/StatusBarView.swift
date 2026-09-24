import Cocoa

final class StatusBarView: NSView {
    private let lineColLabel = NSTextField(labelWithString: "Ln 1, Col 1")
    private let encodingLabel = NSTextField(labelWithString: "UTF-8")
    private let languageLabel = NSTextField(labelWithString: "Plain Text")
    private let pathLabel = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        for label in [lineColLabel, encodingLabel, languageLabel, pathLabel] {
            label.font = NSFont.systemFont(ofSize: 11)
            label.textColor = .secondaryLabelColor
            label.translatesAutoresizingMaskIntoConstraints = false
            addSubview(label)
        }
        pathLabel.lineBreakMode = .byTruncatingHead

        NSLayoutConstraint.activate([
            pathLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            pathLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            pathLabel.trailingAnchor.constraint(lessThanOrEqualTo: languageLabel.leadingAnchor, constant: -16),

            languageLabel.trailingAnchor.constraint(equalTo: encodingLabel.leadingAnchor, constant: -16),
            languageLabel.centerYAnchor.constraint(equalTo: centerYAnchor),

            encodingLabel.trailingAnchor.constraint(equalTo: lineColLabel.leadingAnchor, constant: -16),
            encodingLabel.centerYAnchor.constraint(equalTo: centerYAnchor),

            lineColLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            lineColLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func update(line: Int, column: Int, selectionLength: Int, encoding: String, language: String, path: String) {
        lineColLabel.stringValue = selectionLength > 0 ? "Ln \(line), Col \(column) (\(selectionLength) selected)" : "Ln \(line), Col \(column)"
        encodingLabel.stringValue = encoding
        languageLabel.stringValue = language
        pathLabel.stringValue = path
    }
}
