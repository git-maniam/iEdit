import Cocoa

final class EditorDocument {
    var fileURL: URL?
    var customTitle: String?
    var language: Language
    var encoding: String.Encoding = .utf8
    var isDirty: Bool = false
    var textStorage: NSTextStorage

    var displayName: String {
        customTitle ?? fileURL?.lastPathComponent ?? "Untitled"
    }

    init(fileURL: URL? = nil, content: String = "", customTitle: String? = nil) {
        self.fileURL = fileURL
        self.customTitle = customTitle
        self.language = Language.detect(fromURL: fileURL)
        self.textStorage = NSTextStorage(string: content)
    }

    static func load(url: URL) throws -> EditorDocument {
        var encoding: String.Encoding = .utf8
        let content: String
        do {
            content = try String(contentsOf: url, usedEncoding: &encoding)
        } catch {
            content = try String(contentsOf: url, encoding: .isoLatin1)
            encoding = .isoLatin1
        }
        let doc = EditorDocument(fileURL: url, content: content)
        doc.encoding = encoding
        return doc
    }

    func save(to url: URL) throws {
        let string = textStorage.string
        try string.write(to: url, atomically: true, encoding: encoding)
        self.fileURL = url
        self.customTitle = nil
        // The saved name is authoritative: a file written as .md highlights as Markdown
        // even if JSON was picked in the Format menu.
        self.language = Language.detect(fromURL: url)
        self.isDirty = false
    }

    /// Name to pre-fill in the Save panel. For a document that has never been saved
    /// this appends the current highlighter's extension, e.g. "Untitled.json".
    var suggestedFileName: String {
        if let fileURL { return fileURL.lastPathComponent }
        let base = customTitle ?? "Untitled"
        let ext = language.defaultExtension
        if (base as NSString).pathExtension.lowercased() == ext { return base }
        return "\((base as NSString).deletingPathExtension).\(ext)"
    }

    var encodingName: String {
        switch encoding {
        case .utf8: return "UTF-8"
        case .utf16: return "UTF-16"
        case .isoLatin1: return "ISO Latin 1"
        case .ascii: return "ASCII"
        default: return "UTF-8"
        }
    }
}
