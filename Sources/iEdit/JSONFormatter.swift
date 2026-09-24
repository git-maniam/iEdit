import Foundation

enum JSONFormatterError: Error, LocalizedError {
    case syntax(message: String, line: Int, column: Int)

    var errorDescription: String? {
        switch self {
        case .syntax(let message, let line, let column):
            return "\(message) (line \(line), column \(column))"
        }
    }
}

/// A minimal JSON value tree that preserves object key order, unlike JSONSerialization.
indirect enum JSONValue {
    case object([(String, JSONValue)])
    case array([JSONValue])
    case string(String)
    case number(String)
    case bool(Bool)
    case null
}

/// Hand-written JSON parser (order-preserving) and pretty/minify printer.
enum JSONFormatter {

    static func validate(_ text: String) throws {
        _ = try parse(text)
    }

    static func prettyPrint(_ text: String, indent: String = "  ") throws -> String {
        let value = try parse(text)
        var out = ""
        write(value, indent: indent, level: 0, into: &out)
        return out
    }

    static func minify(_ text: String) throws -> String {
        let value = try parse(text)
        var out = ""
        writeMinified(value, into: &out)
        return out
    }

    // MARK: - Parsing

    private final class Parser {
        let scalars: [Character]
        var index = 0
        var line = 1
        var column = 1

        init(_ text: String) {
            self.scalars = Array(text)
        }

        func peek() -> Character? { index < scalars.count ? scalars[index] : nil }

        func advance() -> Character? {
            guard index < scalars.count else { return nil }
            let ch = scalars[index]
            index += 1
            if ch == "\n" { line += 1; column = 1 } else { column += 1 }
            return ch
        }

        func skipWhitespace() {
            while let ch = peek(), ch == " " || ch == "\t" || ch == "\n" || ch == "\r" {
                _ = advance()
            }
        }

        func error(_ message: String) -> JSONFormatterError {
            .syntax(message: message, line: line, column: column)
        }

        func parseValue() throws -> JSONValue {
            skipWhitespace()
            guard let ch = peek() else { throw error("Unexpected end of input") }
            switch ch {
            case "{": return try parseObject()
            case "[": return try parseArray()
            case "\"": return .string(try parseString())
            case "t", "f": return try parseBool()
            case "n": return try parseNull()
            default: return try parseNumber()
            }
        }

        func expect(_ ch: Character) throws {
            skipWhitespace()
            guard peek() == ch else { throw error("Expected '\(ch)'") }
            _ = advance()
        }

        func parseObject() throws -> JSONValue {
            try expect("{")
            var pairs: [(String, JSONValue)] = []
            skipWhitespace()
            if peek() == "}" { _ = advance(); return .object(pairs) }
            while true {
                skipWhitespace()
                guard peek() == "\"" else { throw error("Expected string key") }
                let key = try parseString()
                skipWhitespace()
                try expect(":")
                let value = try parseValue()
                pairs.append((key, value))
                skipWhitespace()
                guard let ch = peek() else { throw error("Unterminated object") }
                if ch == "," { _ = advance(); continue }
                if ch == "}" { _ = advance(); break }
                throw error("Expected ',' or '}'")
            }
            return .object(pairs)
        }

        func parseArray() throws -> JSONValue {
            try expect("[")
            var items: [JSONValue] = []
            skipWhitespace()
            if peek() == "]" { _ = advance(); return .array(items) }
            while true {
                let value = try parseValue()
                items.append(value)
                skipWhitespace()
                guard let ch = peek() else { throw error("Unterminated array") }
                if ch == "," { _ = advance(); continue }
                if ch == "]" { _ = advance(); break }
                throw error("Expected ',' or ']'")
            }
            return .array(items)
        }

        func parseString() throws -> String {
            try expect("\"")
            var result = ""
            while let ch = advance() {
                if ch == "\"" { return result }
                if ch == "\\" {
                    guard let esc = advance() else { throw error("Unterminated escape") }
                    switch esc {
                    case "\"": result.append("\"")
                    case "\\": result.append("\\")
                    case "/": result.append("/")
                    case "n": result.append("\n")
                    case "t": result.append("\t")
                    case "r": result.append("\r")
                    case "b": result.append("\u{08}")
                    case "f": result.append("\u{0C}")
                    case "u":
                        var hex = ""
                        for _ in 0..<4 {
                            guard let h = advance() else { throw error("Invalid unicode escape") }
                            hex.append(h)
                        }
                        guard let code = UInt32(hex, radix: 16), let scalar = Unicode.Scalar(code) else {
                            throw error("Invalid unicode escape")
                        }
                        result.append(Character(scalar))
                    default:
                        throw error("Invalid escape sequence")
                    }
                } else {
                    result.append(ch)
                }
            }
            throw error("Unterminated string")
        }

        func parseBool() throws -> JSONValue {
            if matchLiteral("true") { return .bool(true) }
            if matchLiteral("false") { return .bool(false) }
            throw error("Invalid literal")
        }

        func parseNull() throws -> JSONValue {
            if matchLiteral("null") { return .null }
            throw error("Invalid literal")
        }

        func matchLiteral(_ literal: String) -> Bool {
            let chars = Array(literal)
            guard index + chars.count <= scalars.count else { return false }
            for i in 0..<chars.count {
                if scalars[index + i] != chars[i] { return false }
            }
            for _ in 0..<chars.count { _ = advance() }
            return true
        }

        func parseNumber() throws -> JSONValue {
            var text = ""
            if peek() == "-" { text.append(advance()!) }
            while let ch = peek(), ch.isNumber { text.append(advance()!) }
            if peek() == "." {
                text.append(advance()!)
                while let ch = peek(), ch.isNumber { text.append(advance()!) }
            }
            if peek() == "e" || peek() == "E" {
                text.append(advance()!)
                if peek() == "+" || peek() == "-" { text.append(advance()!) }
                while let ch = peek(), ch.isNumber { text.append(advance()!) }
            }
            guard !text.isEmpty, text != "-" else { throw error("Invalid number") }
            return .number(text)
        }

        func finish() throws {
            skipWhitespace()
            if index != scalars.count { throw error("Unexpected trailing content") }
        }
    }

    static func parse(_ text: String) throws -> JSONValue {
        let parser = Parser(text)
        let value = try parser.parseValue()
        try parser.finish()
        return value
    }

    // MARK: - Printing

    private static func escapeString(_ s: String) -> String {
        var out = "\""
        for ch in s {
            switch ch {
            case "\"": out += "\\\""
            case "\\": out += "\\\\"
            case "\n": out += "\\n"
            case "\t": out += "\\t"
            case "\r": out += "\\r"
            default: out.append(ch)
            }
        }
        out += "\""
        return out
    }

    private static func write(_ value: JSONValue, indent: String, level: Int, into out: inout String) {
        let pad = String(repeating: indent, count: level)
        let padInner = String(repeating: indent, count: level + 1)
        switch value {
        case .object(let pairs):
            if pairs.isEmpty { out += "{}"; return }
            out += "{\n"
            for (i, pair) in pairs.enumerated() {
                out += padInner + escapeString(pair.0) + ": "
                write(pair.1, indent: indent, level: level + 1, into: &out)
                out += (i < pairs.count - 1) ? ",\n" : "\n"
            }
            out += pad + "}"
        case .array(let items):
            if items.isEmpty { out += "[]"; return }
            out += "[\n"
            for (i, item) in items.enumerated() {
                out += padInner
                write(item, indent: indent, level: level + 1, into: &out)
                out += (i < items.count - 1) ? ",\n" : "\n"
            }
            out += pad + "]"
        case .string(let s): out += escapeString(s)
        case .number(let n): out += n
        case .bool(let b): out += b ? "true" : "false"
        case .null: out += "null"
        }
    }

    private static func writeMinified(_ value: JSONValue, into out: inout String) {
        switch value {
        case .object(let pairs):
            out += "{"
            for (i, pair) in pairs.enumerated() {
                out += escapeString(pair.0) + ":"
                writeMinified(pair.1, into: &out)
                if i < pairs.count - 1 { out += "," }
            }
            out += "}"
        case .array(let items):
            out += "["
            for (i, item) in items.enumerated() {
                writeMinified(item, into: &out)
                if i < items.count - 1 { out += "," }
            }
            out += "]"
        case .string(let s): out += escapeString(s)
        case .number(let n): out += n
        case .bool(let b): out += b ? "true" : "false"
        case .null: out += "null"
        }
    }
}
