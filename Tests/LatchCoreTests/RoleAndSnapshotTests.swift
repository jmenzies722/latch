import XCTest
@testable import LatchCore

private struct Live: Equatable {
    var bundleId: String
    var title: String
    var pid: Int32?
    var focused: Bool = false
}

final class RoleAndSnapshotTests: XCTestCase {
    func testKnownBundleIDsMapToRoles() {
        XCTAssertEqual(RoleCatalog.role(bundleId: "com.todesktop.230313mzl4w4u92"), .editor)
        XCTAssertEqual(RoleCatalog.role(bundleId: "com.microsoft.VSCode"), .editor)
        XCTAssertEqual(RoleCatalog.role(bundleId: "com.apple.dt.Xcode"), .editor)
        XCTAssertEqual(RoleCatalog.role(bundleId: "dev.zed.Zed"), .editor)
        XCTAssertEqual(RoleCatalog.role(bundleId: "com.jetbrains.intellij"), .editor)
        XCTAssertEqual(RoleCatalog.role(bundleId: "com.apple.Safari"), .browser)
        XCTAssertEqual(RoleCatalog.role(bundleId: "com.google.Chrome"), .browser)
        XCTAssertEqual(RoleCatalog.role(bundleId: "company.thebrowser.Browser"), .browser)
        XCTAssertEqual(RoleCatalog.role(bundleId: "com.apple.Terminal"), .terminal)
        XCTAssertEqual(RoleCatalog.role(bundleId: "com.mitchellh.ghostty"), .terminal)
        XCTAssertEqual(RoleCatalog.role(bundleId: "com.googlecode.iterm2"), .terminal)
    }

    func testUnlistedAppsHaveNoRole() {
        XCTAssertNil(RoleCatalog.role(bundleId: "com.apple.finder"))
        XCTAssertNil(RoleCatalog.role(bundleId: "com.tinyspeck.slackmacgap"))
    }

    func testFrontmostPrefersFocusedWindowOfThatRole() {
        let windows = [
            Live(bundleId: "com.apple.Safari", title: "Docs", focused: false),
            Live(bundleId: "com.google.Chrome", title: "PR", focused: true),
            Live(bundleId: "com.apple.Terminal", title: "zsh", focused: false),
        ]
        let browser = RoleCatalog.pickFrontmost(
            role: .browser,
            from: windows,
            bundleId: \.bundleId,
            focused: \.focused
        )
        XCTAssertEqual(browser?.title, "PR")
    }

    func testFrontmostFallsBackToFirstWhenNoneFocused() {
        let windows = [
            Live(bundleId: "com.todesktop.230313mzl4w4u92", title: "latch", focused: false),
            Live(bundleId: "com.microsoft.VSCode", title: "other", focused: false),
        ]
        let editor = RoleCatalog.pickFrontmost(
            role: .editor,
            from: windows,
            bundleId: \.bundleId,
            focused: \.focused
        )
        XCTAssertEqual(editor?.title, "latch")
    }

    func testSnapshotMatchesPidThenTitleThenUniqueBundle() {
        let saved = [
            DeskWindow(bundleId: "com.apple.Safari", title: "Old", frame: LatchRect(x: 0, y: 0, width: 10, height: 10), pid: 42),
            DeskWindow(bundleId: "com.apple.Terminal", title: "build", frame: LatchRect(x: 1, y: 1, width: 10, height: 10)),
            DeskWindow(bundleId: "com.microsoft.VSCode", title: "gone", frame: LatchRect(x: 2, y: 2, width: 10, height: 10)),
        ]
        let live = [
            Live(bundleId: "com.apple.Safari", title: "New tab", pid: 42),
            Live(bundleId: "com.apple.Terminal", title: "build", pid: 9),
            Live(bundleId: "com.microsoft.VSCode", title: "latch", pid: 11),
            Live(bundleId: "com.apple.finder", title: "Desktop", pid: 3),
        ]
        let pairs = SnapshotMatch.assignments(
            saved: saved,
            live: live,
            bundleId: \.bundleId,
            title: \.title,
            pid: \.pid
        )
        XCTAssertEqual(pairs.count, 3)
        XCTAssertEqual(pairs[0].1.pid, 42)
        XCTAssertEqual(pairs[1].1.title, "build")
        XCTAssertEqual(pairs[2].1.bundleId, "com.microsoft.VSCode")
    }

    func testSnapshotDoesNotReuseALiveWindow() {
        let saved = [
            DeskWindow(bundleId: "com.apple.Safari", title: "A", frame: LatchRect(x: 0, y: 0, width: 1, height: 1)),
            DeskWindow(bundleId: "com.apple.Safari", title: "B", frame: LatchRect(x: 0, y: 0, width: 1, height: 1)),
        ]
        let live = [
            Live(bundleId: "com.apple.Safari", title: "A", pid: 1),
        ]
        let pairs = SnapshotMatch.assignments(
            saved: saved,
            live: live,
            bundleId: \.bundleId,
            title: \.title,
            pid: \.pid
        )
        XCTAssertEqual(pairs.count, 1)
        XCTAssertEqual(pairs[0].0.title, "A")
    }

    func testMissingWindowsAreSkipped() {
        let saved = [
            DeskWindow(bundleId: "com.apple.Safari", title: "gone", frame: LatchRect(x: 0, y: 0, width: 1, height: 1)),
        ]
        let pairs = SnapshotMatch.assignments(
            saved: saved,
            live: [Live](),
            bundleId: \.bundleId,
            title: \.title,
            pid: \.pid
        )
        XCTAssertTrue(pairs.isEmpty)
    }
}
