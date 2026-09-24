# Project Specification: iEdit (macOS Text Editor)

## 1. Project Overview
**Name:** iEdit
**Platform:** macOS Desktop (Native)
**Target OS:** Optimized for macOS Tahoe (and newer), with backward compatibility for older macOS versions (e.g., Ventura/Sonoma).
**Objective:** Create a fast, lightweight, and powerful text editor for macOS that rivals the functionality of 'EditPlus' on Windows. The primary focus is on superior handling of Text, JSON, and HTML files, alongside a highly advanced and reliable Find and Replace system, addressing the shortcomings of native macOS text editors.

## 2. Core Features & Requirements

### 2.1 Advanced Find and Replace (CRITICAL)
This must be at par with or better than EditPlus on Windows.
*   **Modes:** Standard text search, Regular Expression (Regex) support, and Escape Sequence support (e.g., `\n`, `\t`).
*   **Toggles:** Match Case, Whole Word, Wrap Around.
*   **Scope:** Find/Replace in current file, Find/Replace in all open tabs, and Find/Replace in a specified directory (Find in Files).
*   **UI:** A dedicated, non-intrusive floating panel or anchored bottom panel that does not obscure the text being edited. Include a "Count" button to show the number of occurrences.
*   **Multi-line:** Full support for multi-line find and replace operations.

### 2.2 Text and Code Editing
*   **Syntax Highlighting:** Native support for plain text, JSON (with formatting/validation), HTML, CSS, JavaScript, and XML.
*   **Performance:** Must be able to open large log files or JSON files quickly without freezing.
*   **Formatting:** Built-in JSON prettify/minify and HTML formatting tools.
*   **Line Management:** Line numbers, line wrapping toggle, and code folding.
*   **Indentation:** Configurable tab size (spaces vs. tabs) with auto-indentation.

### 2.3 User Interface (UI / UX)
*   **Tabbed Interface:** Ability to open multiple files in tabs within a single window.
*   **Sidebar:** Optional file explorer sidebar for navigating project directories.
*   **Themes:** Native macOS Light and Dark mode support. Clean, minimal, native Mac aesthetic (using standard macOS HIG).
*   **Status Bar:** Display current line/column number, file encoding (UTF-8, etc.), file type, and file path.

## 3. Technical Constraints & Architecture
*   **Tech Stack:** Please evaluate and suggest the best approach for a high-performance native macOS feel (e.g., Swift/SwiftUI, AppKit for older OS compatibility, or a lightweight Rust/Tauri wrapper if it guarantees EditPlus-level speed and text handling). 
*   **Build/Packaging:** The final output must be a compiled `.app` file that can be run on macOS.

## 4. Execution Plan (Vibe Coding Phases)
Please execute this build step-by-step. Do not move to the next phase until the current one is fully functional and approved:
1.  **Phase 1: Foundation & UI Shell:** Initialize the project, set up the window, tab system, and basic text view.
2.  **Phase 2: File I/O:** Implement fast file loading, saving, and basic syntax highlighting for JSON and HTML.
3.  **Phase 3: The Find & Replace Engine:** (Focus heavily here) Build the advanced search, regex integration, and UI panel for find/replace.
4.  **Phase 4: Advanced Features:** Add JSON formatting, code folding, and directory search.
5.  **Phase 5: Packaging & Polish:** Final bug fixes, performance profiling for large files, and creating the final executable build.