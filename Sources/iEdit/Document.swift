import Cocoa

final class EditorDocument {
    var fileURL: URL?
    var language: Language
    var encoding: String.Encoding = .utf8
    var isDirty: Bool = false
    var textStorage: NSTextStorage

    var displayName: String {
        fileURL?.lastPathComponent ?? "Untitled"
    }

    init(fileURL: URL? = nil, content: String = "") {
        self.fileURL = fileURL
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
        self.language = Language.detect(fromURL: url)
        self.isDirty = false
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
