// Each test owns a uniquely named pasteboard and defaults suite, so the
// developer's real clipboard and settings are never touched.

import AppKit
import Foundation
import Testing
@testable import Echo

@MainActor
private func isolatedService(sourceApp: URL?) -> (ClipboardService, NSPasteboard) {
    let pasteboard = NSPasteboard(name: NSPasteboard.Name("EchoTests.\(UUID().uuidString)"))
    let defaults = UserDefaults(suiteName: "EchoTests.Clipboard.\(UUID().uuidString)")!
    let service = ClipboardService(defaults: defaults, pasteboard: pasteboard, sourceApp: { sourceApp })
    return (service, pasteboard)
}

@MainActor
@Suite("Clipboard history")
struct ClipboardHistoryTests {

    private let safari = URL(fileURLWithPath: "/Applications/Safari.app")

    @Test("a new copy records the app that was frontmost as its source")
    func copyRecordsSourceApp() {
        let (service, pasteboard) = isolatedService(sourceApp: safari)
        pasteboard.clearContents()
        pasteboard.setString("hello", forType: .string)

        service.poll()

        #expect(service.items.first?.text == "hello")
        #expect(service.items.first?.sourceAppURL == safari)
    }

    @Test("putting a history item back on the pasteboard does not add it again")
    func restoringItemIsNotRecaptured() throws {
        let (service, pasteboard) = isolatedService(sourceApp: safari)
        pasteboard.clearContents()
        pasteboard.setString("first", forType: .string)
        service.poll()
        pasteboard.clearContents()
        pasteboard.setString("second", forType: .string)
        service.poll()

        service.copyToClipboard(try #require(service.items.last))
        service.poll()

        #expect(service.items.map(\.text) == ["second", "first"])
    }

    @Test("a multi-line text row is titled by its first non-blank line")
    func textTitleIsFirstLine() {
        let item = ClipboardItem(
            kind: .text, text: "\n   \n  Anime of the fall season \nsecond line",
            imageData: nil, filePaths: nil, date: .now, sourceAppURL: nil
        )

        let title = ClipboardItemPresentation.title(of: item, using: Localizer(preference: .fixed(.en)))

        #expect(title == "Anime of the fall season")
    }

    @Test("a row's subtitle names the kind and the copy time in the UI language")
    func subtitleNamesKindAndTime() {
        let item = ClipboardItem(
            kind: .text, text: "x", imageData: nil, filePaths: nil, date: .now, sourceAppURL: nil
        )

        let subtitle = ClipboardItemPresentation.subtitle(of: item, using: Localizer(preference: .fixed(.en)))

        #expect(subtitle.hasPrefix("Text · Copied "))
    }
}
