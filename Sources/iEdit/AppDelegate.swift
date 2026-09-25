import Cocoa

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {

    var windowControllers: [NSWindowController] = []
    private var hasRestoredSession = false
    private var fontPicker: FontPickerWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        buildMainMenu()
        // Defer the initial window by one runloop turn: if the app was launched to open
        // file(s), application(_:open:) fires around now too and will have already created a
        // window, so we don't want to also show an empty one alongside it.
        DispatchQueue.main.async { [weak self] in
            if self?.windowControllers.isEmpty == true {
                self?.newWindow()
            }
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    /// Handles files opened via Finder double-click, "Open With", drag-onto-dock-icon, or `open -a iEdit file.txt`.
    func application(_ application: NSApplication, open urls: [URL]) {
        var main = windowControllers.compactMap(mainController(for:)).last
        if main == nil {
            newWindow()
            main = windowControllers.compactMap(mainController(for:)).last
        }
        guard let main else { return }
        for url in urls {
            main.openFile(url: url)
        }
        windowControllers.last?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Unsaved changes on quit

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        let controllers = windowControllers.compactMap(mainController(for:))
        let dirtyCount = controllers.reduce(0) { $0 + $1.dirtyTabCount }

        guard dirtyCount > 0 else {
            controllers.forEach { $0.prepareForClose() }
            return .terminateNow
        }

        // A single unsaved file goes straight to the per-file prompt; several get a
        // summary first, matching how other macOS editors behave.
        if dirtyCount > 1 {
            let alert = NSAlert()
            alert.messageText = "You have \(dirtyCount) documents with unsaved changes. Do you want to review these changes before quitting?"
            alert.informativeText = "Your changes will be lost if you don't review them."
            alert.addButton(withTitle: "Review Changes…")
            alert.addButton(withTitle: "Discard All Changes")
            alert.addButton(withTitle: "Cancel")
            switch alert.runModal() {
            case .alertSecondButtonReturn:
                controllers.forEach { $0.prepareForClose() }
                return .terminateNow
            case .alertThirdButtonReturn:
                return .terminateCancel
            default:
                break
            }
        }

        for controller in controllers {
            controller.view.window?.makeKeyAndOrderFront(nil)
            if !controller.reviewUnsavedChanges() {
                return .terminateCancel
            }
        }
        controllers.forEach { $0.prepareForClose() }
        return .terminateNow
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard let main = (sender.contentViewController as? RootSplitViewController)?.main else { return true }
        guard main.reviewUnsavedChanges() else { return false }
        main.prepareForClose()
        return true
    }

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        windowControllers.removeAll { $0.window === window }
    }

    private func mainController(for controller: NSWindowController) -> MainViewController? {
        (controller.window?.contentViewController as? RootSplitViewController)?.main
    }

    @objc func newWindow(_ sender: Any? = nil) {
        newWindow()
    }

    private func newWindow() {
        // No .fullSizeContentView: the tab bar sits at the very top of the content
        // view and would otherwise be hidden underneath the title bar.
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1060, height: 680),
                               styleMask: [.titled, .closable, .miniaturizable, .resizable],
                               backing: .buffered,
                               defer: false)
        window.center()
        window.title = "Untitled"
        window.titlebarAppearsTransparent = false
        window.minSize = NSSize(width: 620, height: 360)
        window.delegate = self

        let restores = !hasRestoredSession
        hasRestoredSession = true
        let split = RootSplitViewController(restoresSession: restores)
        window.contentViewController = split

        let controller = NSWindowController(window: window)
        windowControllers.append(controller)
        controller.showWindow(nil)
    }

    // MARK: - Font

    @objc private func chooseEditorFont(_ sender: Any?) {
        let picker = FontPickerWindowController()
        fontPicker = picker
        picker.runModal()
        fontPicker = nil
    }

    // MARK: - Menu

    private func buildThemeMenu() -> NSMenu {
        let menu = NSMenu(title: "Theme")
        for themeID in ThemeID.allCases {
            let item = NSMenuItem(title: themeID.displayName, action: #selector(themeMenuItemSelected(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = themeID.rawValue
            item.state = (ThemeManager.shared.currentThemeID == themeID) ? .on : .off
            menu.addItem(item)
        }
        return menu
    }

    @objc private func themeMenuItemSelected(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let id = ThemeID(rawValue: raw) else { return }
        ThemeManager.shared.setTheme(id)
        updateThemeMenuChecks()
    }

    private func updateThemeMenuChecks() {
        guard let mainMenu = NSApp.mainMenu else { return }
        let currentID = ThemeManager.shared.currentThemeID
        for item in mainMenu.items {
            if let sub = item.submenu {
                updateChecks(in: sub, currentID: currentID)
            }
        }
    }

    private func updateChecks(in menu: NSMenu, currentID: ThemeID) {
        for subItem in menu.items {
            if let raw = subItem.representedObject as? String, let id = ThemeID(rawValue: raw) {
                subItem.state = (id == currentID) ? .on : .off
            }
            if let childMenu = subItem.submenu {
                updateChecks(in: childMenu, currentID: currentID)
            }
        }
    }

    private func buildMainMenu() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About iEdit", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        let fontItem = appMenu.addItem(withTitle: "Font…", action: #selector(chooseEditorFont(_:)), keyEquivalent: "t")
        fontItem.keyEquivalentModifierMask = [.command, .shift]
        fontItem.target = self
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Hide iEdit", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(withTitle: "Hide Others", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h").keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(withTitle: "Show All", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit iEdit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        let fileMenuItem = NSMenuItem()
        let fileMenu = NSMenu(title: "File")
        fileMenu.addItem(withTitle: "New Window", action: #selector(AppDelegate.newWindow(_:)), keyEquivalent: "n")
        fileMenu.addItem(withTitle: "New Tab", action: #selector(MainViewController.newTab(_:)), keyEquivalent: "t")
        fileMenu.addItem(withTitle: "Open…", action: #selector(MainViewController.openDocument(_:)), keyEquivalent: "o")
        fileMenu.addItem(withTitle: "Open Folder…", action: #selector(MainViewController.openFolder(_:)), keyEquivalent: "O")
        fileMenu.addItem(.separator())
        fileMenu.addItem(withTitle: "Close Tab", action: #selector(MainViewController.closeTab(_:)), keyEquivalent: "w")
        fileMenu.addItem(withTitle: "Save", action: #selector(MainViewController.saveDocument(_:)), keyEquivalent: "s")
        fileMenu.addItem(withTitle: "Save As…", action: #selector(MainViewController.saveDocumentAs(_:)), keyEquivalent: "S")
        fileMenuItem.submenu = fileMenu
        mainMenu.addItem(fileMenuItem)

        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        let findSubmenuItem = NSMenuItem(title: "Find", action: nil, keyEquivalent: "")
        let findSubmenu = NSMenu(title: "Find")
        findSubmenu.addItem(withTitle: "Find…", action: #selector(MainViewController.performFind(_:)), keyEquivalent: "f")
        let replaceItem = findSubmenu.addItem(withTitle: "Find and Replace…", action: #selector(MainViewController.performReplace(_:)), keyEquivalent: "f")
        replaceItem.keyEquivalentModifierMask = [.command, .option]
        findSubmenu.addItem(withTitle: "Find Next", action: #selector(MainViewController.findNextMenu(_:)), keyEquivalent: "g")
        findSubmenu.addItem(withTitle: "Find Previous", action: #selector(MainViewController.findPreviousMenu(_:)), keyEquivalent: "G")
        findSubmenu.addItem(.separator())
        findSubmenu.addItem(withTitle: "Find in Files…", action: #selector(MainViewController.findInFilesMenu(_:)), keyEquivalent: "F")
        findSubmenuItem.submenu = findSubmenu

        editMenu.addItem(findSubmenuItem)
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        let viewMenuItem = NSMenuItem()
        let viewMenu = NSMenu(title: "View")
        viewMenu.addItem(withTitle: "Toggle Sidebar", action: #selector(NSSplitViewController.toggleSidebar(_:)), keyEquivalent: "s").keyEquivalentModifierMask = [.command, .control]
        viewMenu.addItem(withTitle: "Word Wrap", action: #selector(MainViewController.toggleWordWrap(_:)), keyEquivalent: "w").keyEquivalentModifierMask = [.command, .option]
        viewMenu.addItem(.separator())
        viewMenu.addItem(withTitle: "Toggle Fold", action: #selector(MainViewController.toggleFold(_:)), keyEquivalent: "f").keyEquivalentModifierMask = [.command, .option]
        viewMenu.addItem(withTitle: "Unfold All", action: #selector(MainViewController.unfoldAll(_:)), keyEquivalent: "u").keyEquivalentModifierMask = [.command, .option]
        viewMenu.addItem(.separator())
        let viewThemeItem = NSMenuItem(title: "Theme", action: nil, keyEquivalent: "")
        viewThemeItem.submenu = buildThemeMenu()
        viewMenu.addItem(viewThemeItem)
        viewMenuItem.submenu = viewMenu
        mainMenu.addItem(viewMenuItem)

        let themeMenuItem = NSMenuItem()
        themeMenuItem.submenu = buildThemeMenu()
        mainMenu.addItem(themeMenuItem)

        let formatMenuItem = NSMenuItem()
        let formatMenu = NSMenu(title: "Format")
        // Highlighter choices, alphabetically sorted. "Text" is the default for new files.
        for language in Language.menuSelectable {
            let item = formatMenu.addItem(withTitle: language.rawValue,
                                          action: #selector(MainViewController.setSyntaxLanguage(_:)),
                                          keyEquivalent: "")
            item.representedObject = language.rawValue
        }
        formatMenu.addItem(.separator())
        formatMenu.addItem(withTitle: "Prettify JSON", action: #selector(MainViewController.formatJSONPretty(_:)), keyEquivalent: "j")
        formatMenu.addItem(withTitle: "Minify JSON", action: #selector(MainViewController.formatJSONMinify(_:)), keyEquivalent: "J")
        formatMenu.addItem(withTitle: "Validate JSON", action: #selector(MainViewController.validateJSON(_:)), keyEquivalent: "")
        formatMenu.addItem(.separator())
        formatMenu.addItem(withTitle: "Format HTML", action: #selector(MainViewController.formatHTML(_:)), keyEquivalent: "h").keyEquivalentModifierMask = [.command, .shift]
        formatMenuItem.submenu = formatMenu
        mainMenu.addItem(formatMenuItem)

        let windowMenuItem = NSMenuItem()
        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: "Zoom", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        windowMenu.addItem(.separator())
        windowMenu.addItem(withTitle: "Bring All to Front", action: #selector(NSApplication.arrangeInFront(_:)), keyEquivalent: "")
        windowMenuItem.submenu = windowMenu
        mainMenu.addItem(windowMenuItem)
        NSApp.windowsMenu = windowMenu

        NSApp.mainMenu = mainMenu
    }
}
