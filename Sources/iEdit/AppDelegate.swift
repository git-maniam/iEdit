import Cocoa

final class AppDelegate: NSObject, NSApplicationDelegate {

    var windowControllers: [NSWindowController] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        buildMainMenu()
        // Defer the initial blank window by one runloop turn: if the app was launched to open
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

    private func mainController(for controller: NSWindowController) -> MainViewController? {
        (controller.window?.contentViewController as? RootSplitViewController)?.main
    }

    @objc func newWindow(_ sender: Any? = nil) {
        newWindow()
    }

    private func newWindow() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 980, height: 640),
                               styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                               backing: .buffered,
                               defer: false)
        window.center()
        window.title = "Untitled"
        window.titlebarAppearsTransparent = false
        window.minSize = NSSize(width: 520, height: 360)

        let split = RootSplitViewController()
        window.contentViewController = split

        let controller = NSWindowController(window: window)
        windowControllers.append(controller)
        controller.showWindow(nil)
    }

    // MARK: - Menu

    private func buildMainMenu() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About iEdit", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        let prefsItem = appMenu.addItem(withTitle: "Preferences…", action: nil, keyEquivalent: ",")
        prefsItem.isEnabled = false
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
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Find…", action: #selector(MainViewController.performFind(_:)), keyEquivalent: "f")
        editMenu.addItem(withTitle: "Find in Files…", action: #selector(MainViewController.findInFilesMenu(_:)), keyEquivalent: "F")
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        let viewMenuItem = NSMenuItem()
        let viewMenu = NSMenu(title: "View")
        viewMenu.addItem(withTitle: "Toggle Sidebar", action: #selector(NSSplitViewController.toggleSidebar(_:)), keyEquivalent: "s").keyEquivalentModifierMask = [.command, .control]
        viewMenu.addItem(withTitle: "Toggle Word Wrap", action: #selector(MainViewController.toggleWordWrap(_:)), keyEquivalent: "w").keyEquivalentModifierMask = [.command, .option]
        viewMenu.addItem(.separator())
        viewMenu.addItem(withTitle: "Toggle Fold", action: #selector(MainViewController.toggleFold(_:)), keyEquivalent: "f").keyEquivalentModifierMask = [.command, .option]
        viewMenu.addItem(withTitle: "Unfold All", action: #selector(MainViewController.unfoldAll(_:)), keyEquivalent: "u").keyEquivalentModifierMask = [.command, .option]
        viewMenuItem.submenu = viewMenu
        mainMenu.addItem(viewMenuItem)

        let formatMenuItem = NSMenuItem()
        let formatMenu = NSMenu(title: "Format")
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
