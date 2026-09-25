import Cocoa

final class RootSplitViewController: NSSplitViewController {

    let sidebar = SidebarViewController()
    let main = MainViewController()

    /// Only the first window of a launch reopens the previous session's files.
    private let restoresSession: Bool

    init(restoresSession: Bool) {
        self.restoresSession = restoresSession
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        splitView.dividerStyle = .thin

        let sidebarItem = NSSplitViewItem(sidebarWithViewController: sidebar)
        sidebarItem.minimumThickness = 180
        sidebarItem.maximumThickness = 400
        sidebarItem.canCollapse = true
        sidebarItem.isCollapsed = false

        let mainItem = NSSplitViewItem(viewController: main)
        mainItem.minimumThickness = 400

        addSplitViewItem(sidebarItem)
        addSplitViewItem(mainItem)

        sidebar.delegate = main
        main.sidebarProxy = sidebar

        // Deliberately after the sidebar is wired up, so restored tabs appear in it.
        if restoresSession {
            main.restoreSession()
        } else {
            main.startFresh()
        }
    }
}
