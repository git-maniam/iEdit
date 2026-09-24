# iEdit

A fast, native macOS text/code editor (Swift + AppKit) focused on advanced Find & Replace,
JSON/HTML tooling, and a clean tabbed editing experience. See `iedit_project_specification.md`
for the full spec.

## Build

```sh
./build.sh
```

This compiles a universal (arm64 + x86_64) binary with `swiftc`, generates the notepad app
icon, and assembles `build/iEdit.app`.

> Note: this machine only has the Command Line Tools installed (no full Xcode.app), and its
> bundled Swift Package Manager has a broken `PackageDescription` link, so `swift build` will
> fail — `build.sh` compiles directly with `swiftc` instead, which works fine.

## Run

```sh
open build/iEdit.app
```

## Features

- Tabbed editor with sidebar file browser, line numbers, word wrap toggle, and status bar
  (line/column, encoding, file type, path).
- Syntax highlighting for Plain Text, JSON, HTML, CSS, JavaScript, and XML.
- Advanced Find & Replace: regex, escape sequences (`\n`/`\t`/`\r`), match case, whole word,
  wrap around, a live count, and scopes for the current file, all open tabs, or a whole
  directory (Find in Files), with multi-line support throughout.
- JSON prettify/minify/validate backed by a hand-written, order-preserving parser (not
  `JSONSerialization`, which does not preserve key order).
- A pragmatic HTML re-indenter.
- Lightweight code folding (Cmd+Option+F) via brace matching; folds always expand before
  save/find/format so text is never lost.
