import Foundation
import Testing
@testable import Echo

private func entries(_ hints: [String?]) -> [ArrangedWindow] {
    hints.map { fixtureWindow(titleHint: $0) }
}

private func windows(_ titles: [String?]) -> [WindowSnapshot] {
    titles.enumerated().map { snapshotWindow(title: $1, ordinal: $0) }
}

private func pairs(_ matches: [WindowMatch]) -> [[Int]] {
    matches.map { [$0.entry, $0.window] }
}

@Suite("Window matcher")
struct WindowMatcherTests {

    @Test("a title beats window order")
    func titleBeatsOrder() {
        let result = WindowMatcher.match(entries: entries(["a", "b"]), windows: windows(["b", "a"]))
        #expect(pairs(result) == [[0, 1], [1, 0]])
    }

    @Test("equal titles are taken in order")
    func equalTitlesInOrder() {
        let result = WindowMatcher.match(entries: entries(["x", "x"]), windows: windows(["x", "x"]))
        #expect(pairs(result) == [[0, 0], [1, 1]])
    }

    @Test("an untitled entry takes the first window nobody asked for by title")
    func untitledEntryTakesFirstFree() {
        let result = WindowMatcher.match(entries: entries([nil, "b"]), windows: windows(["b", "a"]))
        #expect(pairs(result) == [[0, 1], [1, 0]])
    }

    @Test("an untitled entry alone takes the first window")
    func untitledEntryTakesFirstWindow() {
        let result = WindowMatcher.match(entries: entries([nil]), windows: windows(["a", "b"]))
        #expect(pairs(result) == [[0, 0]])
    }

    @Test("untitled entries take windows in order")
    func untitledEntriesInOrder() {
        let result = WindowMatcher.match(entries: entries([nil, nil]), windows: windows(["a", "b", "c"]))
        #expect(pairs(result) == [[0, 0], [1, 1]])
    }

    @Test("fewer windows than entries leaves the last entries unmatched")
    func fewerWindowsThanEntries() {
        let result = WindowMatcher.match(entries: entries([nil, nil, nil]), windows: windows(["a", "b"]))
        #expect(pairs(result) == [[0, 0], [1, 1]])
    }

    @Test("a title match survives a shortage of windows for earlier untitled entries")
    func titledEntryKeepsItsWindowWhenWindowsRunOut() {
        let result = WindowMatcher.match(entries: entries([nil, "b"]), windows: windows(["b"]))
        #expect(pairs(result) == [[1, 0]])
    }

    @Test("more windows than entries leaves the extra windows alone")
    func moreWindowsThanEntries() {
        let result = WindowMatcher.match(entries: entries(["c"]), windows: windows(["a", "b", "c"]))
        #expect(pairs(result) == [[0, 2]])
    }

    @Test("a title that is not found falls back to window order")
    func missingTitleFallsBack() {
        let result = WindowMatcher.match(entries: entries(["gone"]), windows: windows(["a", "b"]))
        #expect(pairs(result) == [[0, 0]])
    }

    @Test("a fallback entry does not take a window a later entry names")
    func fallbackDoesNotStealTitledWindow() {
        let result = WindowMatcher.match(entries: entries(["gone", "a"]), windows: windows(["a", "b"]))
        #expect(pairs(result) == [[0, 1], [1, 0]])
    }

    @Test("a second entry with a used title falls back to the remaining window")
    func duplicateHintFallsBack() {
        let result = WindowMatcher.match(entries: entries(["x", "x"]), windows: windows(["y", "x"]))
        #expect(pairs(result) == [[0, 1], [1, 0]])
    }

    @Test("titles compare exactly")
    func exactTitleComparison() {
        let result = WindowMatcher.match(entries: entries(["build"]), windows: windows(["Build", "build "]))
        #expect(pairs(result) == [[0, 0]])
        let exact = WindowMatcher.match(entries: entries(["build"]), windows: windows(["Build", "build"]))
        #expect(pairs(exact) == [[0, 1]])
    }

    @Test("an entry without a hint is not matched to an untitled window by equality")
    func missingHintIsNotATitle() {
        let result = WindowMatcher.match(entries: entries([nil]), windows: windows(["z", nil]))
        #expect(pairs(result) == [[0, 0]])
    }

    @Test("no entries or no windows gives no matches")
    func emptySides() {
        #expect(WindowMatcher.match(entries: [], windows: windows(["a"])).isEmpty)
        #expect(WindowMatcher.match(entries: entries(["a"]), windows: []).isEmpty)
    }

    @Test("random inputs never reuse a window or an entry and always fill what they can")
    func randomInputsKeepInvariants() {
        var generator = SeededGenerator(seed: 0xEC40)
        let titles: [String?] = [nil, "a", "b", "c"]
        for _ in 0..<500 {
            let hints = (0..<Int.random(in: 0...6, using: &generator)).map { _ in titles.randomElement(using: &generator) ?? nil }
            let names = (0..<Int.random(in: 0...6, using: &generator)).map { _ in titles.randomElement(using: &generator) ?? nil }
            let result = WindowMatcher.match(entries: entries(hints), windows: windows(names))
            #expect(result.map(\.entry) == result.map(\.entry).sorted())
            #expect(Set(result.map(\.entry)).count == result.count)
            #expect(Set(result.map(\.window)).count == result.count)
            #expect(result.count == min(hints.count, names.count))
            #expect(result.allSatisfy { $0.entry < hints.count && $0.window < names.count })
        }
    }
}
