import Carbon.HIToolbox
import Testing
@testable import Echo

private let firstID = UUID()
private let secondID = UUID()

private func skippedReport() -> ArrangementApplyReport {
    ArrangementApplyReport(
        placed: 2, total: 8, notRunning: 3, notRunningApps: ["Safari", "Notes"], noWindow: 2, displayMissing: 1)
}

@MainActor
@Suite("Arrangements popover menu model")
struct ArrangementsMenuModelTests {
    private let english = Localizer(preference: .fixed(.en))
    private let russian = Localizer(preference: .fixed(.ru))

    @Test("items keep document order and carry each arrangement's own shortcut")
    func itemsFollowDocumentOrder() {
        let shortcut = KeyboardShortcut(keyCode: UInt32(kVK_ANSI_1), flags: [.command, .option])
        let items = ArrangementsMenuModel.items(
            arrangements: [
                fixtureArrangement(id: secondID, name: "Review"), fixtureArrangement(id: firstID, name: "Focus")
            ],
            shortcuts: [firstID: shortcut])

        #expect(items.map(\.name) == ["Review", "Focus"])
        #expect(items.map(\.shortcut) == [nil, shortcut])
    }

    @Test("no arrangements give no items")
    func emptyDocumentGivesNoItems() {
        #expect(ArrangementsMenuModel.items(
            arrangements: [], shortcuts: [firstID: KeyboardShortcut(keyCode: 0, flags: .command)]).isEmpty)
    }

    @Test("a full apply reports only the placed count")
    func fullApplyIsOneLine() {
        let report = ArrangementApplyReport(placed: 4, total: 4)

        #expect(ArrangementsMenuModel.reportLines(report, using: english) == ["Placed 4 of 4 windows."])
    }

    @Test("every kind of skip gets its own line with its own count")
    func skipsAreCountedHonestly() {
        let lines = ArrangementsMenuModel.reportLines(skippedReport(), using: english)

        #expect(lines == [
            "Placed 2 of 8 windows.",
            "Not running: Safari and Notes",
            "2 app windows weren't found",
            "1 window is on a display that isn't connected"
        ])
    }

    @Test("a skipped entry without an app name does not produce an empty list")
    func notRunningWithoutNamesIsOmitted() {
        let report = ArrangementApplyReport(placed: 1, total: 2, notRunning: 1, notRunningApps: [])

        #expect(ArrangementsMenuModel.reportLines(report, using: english).count == 1)
    }

    @Test("Russian counts take the plural form of their number")
    func russianPlurals() {
        let lines = ArrangementsMenuModel.reportLines(
            ArrangementApplyReport(placed: 0, total: 6, notRunning: 0, noWindow: 5, displayMissing: 2), using: russian)

        #expect(lines.contains("не найдено 5 окон"))
        #expect(lines.contains("2 окна на неподключённом мониторе"))
    }
}
