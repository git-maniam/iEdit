import Cocoa

protocol FindReplaceHost: AnyObject {
    func frCurrentEditor() -> EditorViewController?
    func frAllEditors() -> [EditorViewController]
    func frOpenFile(url: URL)
    func frOpenFileAndJump(url: URL, line: Int, column: Int)
    func frSearchDirectory() -> URL?
    func frJumpToEditor(_ controller: EditorViewController)
    func frDisplayFindResults(query: String, directory: URL, results: [SearchMatchResult], isReplace: Bool, replaceCount: Int, filesChanged: Int)
}
