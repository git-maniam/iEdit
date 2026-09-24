import Cocoa

protocol FindReplaceHost: AnyObject {
    func frCurrentEditor() -> EditorViewController?
    func frAllEditors() -> [EditorViewController]
    func frOpenFile(url: URL)
    func frSearchDirectory() -> URL?
    func frJumpToEditor(_ controller: EditorViewController)
}
