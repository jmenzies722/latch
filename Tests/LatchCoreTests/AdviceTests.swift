import XCTest
@testable import LatchCore

final class AdviceTests: XCTestCase {
    func testCodingWhenEditorBrowserTerminalArePresent() {
        let advice = DeskAdvisor.advise(
            DeskCensus(
                windowCount: 3,
                names: ["Cursor", "Safari", "Terminal"],
                nameByRole: [.editor: "Cursor", .browser: "Safari", .terminal: "Terminal"]
            )
        )
        XCTAssertEqual(advice.shape, .coding)
        XCTAssertEqual(advice.workMode, .coding)
        XCTAssertEqual(advice.line, "Cursor, Safari, and Terminal — coding desk.")
        XCTAssertEqual(advice.ghosts(on: CGRect(x: 0, y: 0, width: 1800, height: 1000)).count, 3)
    }

    func testResearchWhenEditorAndBrowserOnly() {
        let advice = DeskAdvisor.advise(
            DeskCensus(
                windowCount: 2,
                names: ["Safari", "Xcode"],
                nameByRole: [.browser: "Safari", .editor: "Xcode"]
            )
        )
        XCTAssertEqual(advice.shape, .research)
        XCTAssertEqual(advice.workMode, .research)
    }

    func testFocusWhenTheDeskIsAPile() {
        let advice = DeskAdvisor.advise(DeskCensus(windowCount: 6, names: ["Mail", "Slack", "Notes", "Music", "Maps", "Preview"]))
        XCTAssertEqual(advice.shape, .focus)
        XCTAssertEqual(advice.line, "6 windows — focus the front one.")
    }

    func testMaximizeForASoloWindow() {
        let advice = DeskAdvisor.advise(DeskCensus(windowCount: 1, names: ["Notes"]))
        XCTAssertEqual(advice.shape, .maximize)
        XCTAssertEqual(advice.snap, .maximize)
        XCTAssertEqual(advice.line, "Notes — maximize.")
    }

    func testSplitForTwoUnlabeledWindows() {
        let advice = DeskAdvisor.advise(DeskCensus(windowCount: 2, names: ["Slack", "Notes"]))
        XCTAssertEqual(advice.shape, .split)
        XCTAssertEqual(advice.ghosts(on: CGRect(x: 0, y: 0, width: 1000, height: 800)).count, 2)
    }

    func testEmptyDisplayWaits() {
        let advice = DeskAdvisor.advise(DeskCensus(windowCount: 0))
        XCTAssertEqual(advice.shape, .empty)
        XCTAssertEqual(advice.line, "Nothing open on this display.")
        XCTAssertTrue(advice.ghosts(on: .zero).isEmpty)
    }

    func testCodingBeatsAHighWindowCount() {
        let advice = DeskAdvisor.advise(
            DeskCensus(
                windowCount: 5,
                names: ["Cursor", "Safari", "Terminal", "Slack", "Mail"],
                nameByRole: [.editor: "Cursor", .browser: "Safari", .terminal: "Terminal"]
            )
        )
        XCTAssertEqual(advice.shape, .coding)
    }
}
