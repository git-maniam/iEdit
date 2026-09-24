# iEdit

**iEdit** is a fast, lightweight, and powerful native macOS text and code editor built in pure Swift and AppKit. Inspired by the legendary **EditPlus** on Windows, iEdit is designed to address the shortcomings of native macOS editors by delivering:

- **EditPlus-grade Find & Replace** with regular expressions, multi-line searches, escape sequence translations (`\n`, `\t`, `\r`), and live in-viewport match highlighting.
- **Dedicated "Find in Files" Results Tab** with asynchronous directory searching and instant double-click jumping directly to file and line.
- **EditPlus Classic Syntax Highlighting** with high-contrast, crisp colors tailored for both macOS Light and Dark modes.
- **High Performance on Large Files** powered by non-contiguous layout rendering and $O(\log N)$ binary-search line numbering.
- **Built-in Developer Tools** including order-preserving JSON formatting/minification/validation, pragmatic HTML re-indentation, and brace-based code folding.
- **Zero Third-Party Dependencies** — 100% native AppKit/Cocoa, zero Electron bloat, instantaneous launch times, and minimal memory usage.

---

## Table of Contents
- [Features](#features)
- [Prerequisites](#prerequisites)
- [Clone & Build](#clone--build)
- [Keyboard Shortcuts](#keyboard-shortcuts)
- [Architecture & Codebase Overview](#architecture--codebase-overview)
- [Specification](#specification)
- [Contributing & Branching](#contributing--branching)
- [License](#license)

---

## Features

### 1. Advanced Find & Replace
- **Multiple Search Modes**: Plain text, Regular Expression (Regex with `(?s)` multiline support), and Escape Sequences (`\n`, `\t`, `\r`, `\\`, `\0`).
- **Flexible Options**: Match Case, Whole Word, and Wrap Around toggles.
- **Multi-line Search & Replace**: Expandable inputs allow drafting, pasting, and editing multi-line find and replace patterns.
- **Live Match Highlighting**: Matches in the active viewport are highlighted in real-time, displaying current occurrence indicators (e.g., `Match 3 of 42`).
- **Scoped Operations**:
  - **Current File**: Fast next/previous cycling, count, and single-undo replacement.
  - **All Open Tabs**: Global occurrence counting and safe batch replacement with confirmation dialogs.
  - **Directory (Find in Files)**: Non-blocking background directory search outputting to a dedicated `Find Results` tab.
- **EditPlus-style Double-Click Navigation**: Double-clicking any search result in the `Find Results` tab immediately opens the target file and jumps to the exact line and column.

### 2. High-Performance Text Engine & Ruler
- **Non-Contiguous Layout**: `NSLayoutManager.allowsNonContiguousLayout` ensures multi-megabyte JSON, HTML, and log files load instantaneously without freezing the UI.
- **Tactile Legacy Scrollbar**: Scrollbar track and thumb remain continuously visible and draggable, matching traditional desktop editors.
- **Flipped Line Ruler**: Custom `NSRulerView` with flipped coordinate math and $O(\log N)$ binary-search line indexing for smooth 60/120 FPS scrolling even in 100,000+ line documents.
- **Soft Word Wrapping**: Toggle between horizontal scrolling and clean word wrapping on demand (<kbd>Cmd</kbd>+<kbd>Option</kbd>+<kbd>W</kbd>).

### 3. Syntax Highlighting (EditPlus Classic)
Native syntax highlighters for:
- **JSON** (Keys, strings, numbers, literals)
- **HTML & XML** (Tags, delimiters, attributes, strings, comments)
- **CSS** (Selectors, properties, values, units, colors)
- **JavaScript** (Keywords, strings, numbers, comments)
- **Plain Text**

Colors strictly reproduce the vibrant, high-contrast EditPlus Windows defaults in Light Mode, with high-visibility brightened counterparts in Dark Mode. Large documents (>200,000 characters) utilize chunked background processing to maintain responsiveness while typing.

### 4. Code & Data Tooling
- **Order-Preserving JSON Engine**: Custom recursive-descent parser preserves JSON dictionary key insertion order (unlike Apple's `JSONSerialization`), providing reliable pretty-printing, minification, and strict syntax validation with line/column error reporting.
- **HTML Re-indenter**: Formats tag hierarchies, void elements, and inline content.
- **Brace Folding**: Fold any brace/bracket-delimited block (`{...}`, `[...]`, `(...)`). Folds automatically expand before file saving or global replacements to prevent data loss.
- **File Explorer Sidebar**: Collapsible directory browser with file-tree navigation (<kbd>Cmd</kbd>+<kbd>Ctrl</kbd>+<kbd>S</kbd>).

---

## Prerequisites

- **Operating System**: macOS 13.0 (Ventura) or newer (macOS Sonoma, Sequoia, and newer fully supported).
- **Tools**: Xcode Command Line Tools (or full Xcode installation):
  ```sh
  xcode-select --install
  ```

---

## Clone & Build

### 1. Clone the Repository
```sh
git clone https://github.com/git-maniam/iEdit.git
cd iEdit
```

### 2. Build the Application
Run the build script:
```sh
./build.sh
```

What `build.sh` does:
1. Compiles all Swift sources using `swiftc` into universal binaries (`arm64` Apple Silicon + `x86_64` Intel).
2. Uses `lipo` to produce a single universal executable.
3. Generates the custom application icon set via `Scripts/GenerateIcon.swift` and compiles `AppIcon.icns`.
4. Assembles the standalone `build/iEdit.app` bundle and signs it with local ad-hoc code signatures.

### 3. Run the App
Launch directly from the build directory:
```sh
open build/iEdit.app
```

Or install it to your Applications folder:
```sh
cp -R build/iEdit.app /Applications/
open /Applications/iEdit.app
```

---

## Keyboard Shortcuts

| Shortcut | Action |
| :--- | :--- |
| <kbd>Cmd</kbd> + <kbd>N</kbd> | New Window |
| <kbd>Cmd</kbd> + <kbd>T</kbd> | New Tab |
| <kbd>Cmd</kbd> + <kbd>W</kbd> | Close Tab |
| <kbd>Cmd</kbd> + <kbd>O</kbd> | Open File(s)... |
| <kbd>Cmd</kbd> + <kbd>Shift</kbd> + <kbd>O</kbd> | Open Folder (Sidebar Project Root)... |
| <kbd>Cmd</kbd> + <kbd>S</kbd> | Save File |
| <kbd>Cmd</kbd> + <kbd>Shift</kbd> + <kbd>S</kbd> | Save As... |
| <kbd>Cmd</kbd> + <kbd>F</kbd> | Show Find Panel |
| <kbd>Cmd</kbd> + <kbd>Option</kbd> + <kbd>F</kbd> | Show Find and Replace Panel |
| <kbd>Cmd</kbd> + <kbd>G</kbd> / <kbd>Enter</kbd> | Find Next |
| <kbd>Cmd</kbd> + <kbd>Shift</kbd> + <kbd>G</kbd> / <kbd>Shift</kbd>+<kbd>Enter</kbd> | Find Previous |
| <kbd>Cmd</kbd> + <kbd>Shift</kbd> + <kbd>F</kbd> | Find in Files (Directory Scope) |
| <kbd>Esc</kbd> | Dismiss Find / Replace Panel |
| <kbd>Cmd</kbd> + <kbd>Option</kbd> + <kbd>W</kbd> | Toggle Soft Word Wrap |
| <kbd>Cmd</kbd> + <kbd>Control</kbd> + <kbd>S</kbd> | Toggle Sidebar File Browser |
| <kbd>Cmd</kbd> + <kbd>Option</kbd> + <kbd>F</kbd> | Toggle Code Fold at Caret |
| <kbd>Cmd</kbd> + <kbd>Option</kbd> + <kbd>U</kbd> | Unfold All Folds |
| <kbd>Cmd</kbd> + <kbd>J</kbd> | Prettify JSON |
| <kbd>Cmd</kbd> + <kbd>Shift</kbd> + <kbd>J</kbd> | Minify JSON |
| <kbd>Cmd</kbd> + <kbd>Shift</kbd> + <kbd>H</kbd> | Format HTML |

---

## Architecture & Codebase Overview

```
iEdit/
├── Sources/
│   └── iEdit/
│       ├── main.swift                          # Application entry point
│       ├── AppDelegate.swift                   # Window management & system menus
│       ├── RootSplitViewController.swift       # Sidebar & editor split view controller
│       ├── SidebarViewController.swift         # Project tree / file explorer
│       ├── MainViewController.swift            # Tab coordinator, shortcuts, and jump router
│       ├── TabBarView.swift                    # Custom multi-tab bar component
│       ├── StatusBarView.swift                 # Bottom status indicator (Ln, Col, Enc, Lang, Path)
│       ├── Document.swift                      # Document model & character encoding support
│       ├── EditorViewController.swift          # Core editor controller & layout coordinator
│       ├── CodeEditorTextView.swift            # Custom NSTextView subclass with auto-indent & double-click
│       ├── LineNumberRulerView.swift           # Flipped NSRulerView with binary search line index
│       ├── SyntaxHighlighter.swift             # Tokenizer & EditPlus color rules
│       ├── JSONFormatter.swift                 # Key-order-preserving JSON parser & formatter
│       ├── HTMLFormatter.swift                 # Pragmatic HTML markup indenter
│       ├── CodeFolding.swift                   # Brace matching and non-destructive range folding
│       ├── Language.swift                      # Language detection and extensions
│       ├── PreferencesStore.swift              # Tab width, space/tab preferences, word wrap
│       └── FindReplace/
│           ├── SearchEngine.swift              # Regex builder, escape translator, batch engine
│           ├── FindReplaceBarViewController.swift # Docked search UI with expandable inputs
│           └── FindReplaceHost.swift           # Protocol decoupling Find UI from editor tabs
├── Resources/
│   └── Info.plist                              # App bundle metadata
├── Scripts/
│   └── GenerateIcon.swift                      # Procedural icon generator script
├── build.sh                                    # Universal compilation & packaging script
└── iedit_project_specification.md              # Original architectural specification
```

### Key Technical Patterns
1. **Flipped Ruler Synchronization**: In Cocoa, `NSRulerView` is unflipped while `NSTextView` is flipped. `LineNumberRulerView` overrides `isFlipped = true` and observes `NSView.boundsDidChangeNotification` on the clip view to maintain perfect alignment.
2. **$O(\log N)$ Binary Search Line Numbering**: Rather than re-counting `\n` characters on every draw call, `LineNumberRulerView` maintains an array of line-start character offsets and performs a binary search on the visible character range.
3. **Non-Destructive Viewport Highlighting**: Find occurrences are highlighted using `NSLayoutManager.addTemporaryAttribute(.backgroundColor, ...)` so document state and undo history remain untouched.
4. **Order-Preserving JSON AST**: Instead of decoding to an unordered `[String: Any]` dictionary, `JSONValue.object([(String, JSONValue)])` stores key-value pairs as an ordered tuple array to guarantee deterministic formatting.

---

## Specification

The original project vision and technical requirements are detailed in [`iedit_project_specification.md`](file:///Users/rsubramaniam/Projects/iEdit/iedit_project_specification.md).

---

## Contributing & Branching

Contributions, bug reports, and pull requests are welcome!

1. **Fork or Branch**:
   ```sh
   git checkout -b feature/my-cool-feature
   ```
2. **Make Changes**:
   Follow native AppKit / Swift idioms and keep dependencies at zero.
3. **Validate the Build**:
   ```sh
   ./build.sh
   open build/iEdit.app
   ```
4. **Submit a Pull Request**:
   Describe your changes and link any relevant issues.

---

## License

Created for macOS users who miss the speed, precision, and simplicity of EditPlus. Distributed under the MIT License.
