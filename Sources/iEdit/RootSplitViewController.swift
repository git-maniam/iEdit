import Cocoa

final class RootSplitViewController: NSSplitViewController {

    let sidebar = SidebarViewController()
    let main = MainViewController()

    override func viewDidLoad() {
        super.viewDidLoad()
        splitView.dividerStyle = .thin

        let sidebarItem = NSSplitViewItem(sidebarWithViewController: sidebar)
        sidebarItem.minimumThickness = 160
        sidebarItem.maximumThickness = 400
        sidebarItem.canCollapse = true
        sidebarItem.isCollapsed = true

        let mainItem = NSSplitViewItem(viewController: main)
        mainItem.minimumThickness = 400

        addSplitViewItem(sidebarItem)
        addSplitViewItem(mainItem)

        sidebar.delegate = main
        main.sidebarProxy = sidebar
    }
}
