import Foundation
import Testing
@testable import Echo

/// Wave-end regression guards from the plan. Completeness and the orphan
/// check are enforced as hard failures already: whatever key types are
/// populated so far (CommonKey, MetricsKey as of this commit) must be fully
/// and correctly translated the moment they exist — an enum with zero cases
/// vacuously satisfies both, so a not-yet-started key type (Popover,
/// Preferences, Input, System) does not fail them prematurely.
///
/// The hard-coded-string scan and the unwired-capabilities check are still
/// genuinely red at this point in the wave — those two stay wrapped in
/// `withKnownIssue` until the remaining S-tasks and the W integration task
/// land. Swift Testing itself flags an unexpected pass inside
/// `withKnownIssue`, which is the signal to drop that wrapper too.
@Suite("Wave-end localization guards")
struct CatalogGuardTests {

    @Test("every registered key has a non-empty, specifier-matching translation in en and ru")
    func everyKeyIsTranslatedInBothLanguages() {
        for keyType in LocalizationRegistry.allKeyTypes {
            checkAllCasesTranslated(of: keyType)
        }
    }

    @Test("catalog keys match the registry with no orphans, all entries translated")
    func catalogHasNoOrphansAndAllTranslated() {
        let tablesDir = RepoLocator.echoSourceRoot.appendingPathComponent("Localization/Tables")
        for keyType in LocalizationRegistry.allKeyTypes {
            checkCatalog(for: keyType, in: tablesDir)
        }
    }

    @Test("no hard-coded user-facing string literals outside Localization/")
    func noHardCodedUserFacingStrings() {
        withKnownIssue("Phase A only — S-tasks migrate literals to Localizer calls later in this wave") {
            let violations = scanForHardCodedStrings()
            #expect(violations.isEmpty, "Hard-coded strings found:\n\(violations.joined(separator: "\n"))")
        }
    }

    @Test("no unwired capabilities remain by the end of the wave")
    func unwiredCapabilitiesIsEmpty() {
        withKnownIssue("Phase A only — cleared by the W integration task at the end of this wave") {
            #expect(UnwiredCapabilities.items.isEmpty)
        }
    }
}

// MARK: - Completeness

private func checkAllCasesTranslated<K: LocalizedKey>(of keyType: K.Type) {
    for key in K.allCases {
        let en = lookup(key, language: .en)
        let ru = lookup(key, language: .ru)
        #expect(en != nil && !(en ?? "").isEmpty, "\(K.self).\(key) has no English value")
        #expect(ru != nil && !(ru ?? "").isEmpty, "\(K.self).\(key) has no Russian value")
        if let en, let ru {
            #expect(specifierCount(en) == specifierCount(ru), "\(K.self).\(key) format specifiers differ between en and ru")
        }
    }
}

private func lookup<K: LocalizedKey>(_ key: K, language: AppLanguage) -> String? {
    let sentinel = "__l10n_missing__"
    guard
        let lprojURL = Bundle.main.url(forResource: language.rawValue, withExtension: "lproj"),
        let bundle = Bundle(url: lprojURL)
    else {
        return nil
    }
    let value = bundle.localizedString(forKey: key.rawValue, value: sentinel, table: K.table)
    return value == sentinel ? nil : value
}

private func specifierCount(_ value: String) -> Int {
    (try? NSRegularExpression(pattern: "%[0-9]*\\$?[@dlf]+"))
        .map { $0.numberOfMatches(in: value, range: NSRange(value.startIndex..., in: value)) } ?? 0
}

// MARK: - Catalog (.xcstrings) orphan check

private struct XCStringsCatalog: Decodable {
    struct StringUnit: Decodable { let state: String }
    struct Localization: Decodable { let stringUnit: StringUnit? }
    struct Entry: Decodable { let localizations: [String: Localization]? }
    let strings: [String: Entry]
}

private func checkCatalog<K: LocalizedKey>(for keyType: K.Type, in tablesDir: URL) {
    let url = tablesDir.appendingPathComponent("\(K.table).xcstrings")
    guard let data = try? Data(contentsOf: url) else {
        Issue.record("Could not read catalog at \(url.path)")
        return
    }
    guard let catalog = try? JSONDecoder().decode(XCStringsCatalog.self, from: data) else {
        Issue.record("Could not decode catalog at \(url.path)")
        return
    }

    let registryKeys = Set(K.allCases.map(\.rawValue))
    let catalogKeys = Set(catalog.strings.keys)
    #expect(catalogKeys == registryKeys, "\(K.table).xcstrings keys do not match \(K.self): orphans or gaps present")

    for (key, entry) in catalog.strings {
        for language in ["en", "ru"] {
            let state = entry.localizations?[language]?.stringUnit?.state
            #expect(state == "translated", "\(K.table).xcstrings key '\(key)' is not translated for \(language)")
        }
    }
}

// MARK: - Hard-coded string scan

private let exemptRelativePaths: Set<String> = [
    "InputSwitcher/LayoutTranslit.swift",
    "InputSwitcher/LanguageData.swift",
]

private let uiLiteralMarkers = [
    "Text(\"", "Button(\"", "Label(\"", "Toggle(\"", "TextField(\"", "Picker(\"",
    "Section(\"", "Menu(\"", ".help(\"", ".accessibilityLabel(\"", ".confirmationDialog(\"",
    ".alert(\"", "PrefTitle(\"", "PrefCaption(\"", "title: \"", ".title = \"",
    "accessibilityDescription: \"",
]

private let logMarkers = ["Logger", ".debug(", ".info(", ".error(", ".warning(", ".fault(", ".trace("]

private func scanForHardCodedStrings() -> [String] {
    let root = RepoLocator.echoSourceRoot
    var violations: [String] = []
    guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) else {
        return violations
    }
    while let element = enumerator.nextObject() {
        guard let fileURL = element as? URL, fileURL.pathExtension == "swift" else { continue }
        let relativePath = String(fileURL.path.dropFirst(root.path.count + 1))
        if relativePath.hasPrefix("Localization/") { continue }
        if exemptRelativePaths.contains(relativePath) { continue }
        guard let contents = try? String(contentsOf: fileURL, encoding: .utf8) else { continue }

        for (index, rawLine) in contents.components(separatedBy: .newlines).enumerated() {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("//") || line.isEmpty { continue }
            if line.contains("l10n-exempt:") { continue }
            if logMarkers.contains(where: line.contains) { continue }

            let hasUILiteral = uiLiteralMarkers.contains { line.contains($0) }
            let hasCyrillic = line.unicodeScalars.contains { (0x0400...0x04FF).contains($0.value) }
            if hasUILiteral || hasCyrillic {
                violations.append("\(relativePath):\(index + 1): \(line)")
            }
        }
    }
    return violations
}

// MARK: - Repo location

private enum RepoLocator {
    /// EchoTests/CatalogGuardTests.swift -> EchoTests/ -> repo root.
    static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
    static var echoSourceRoot: URL { repoRoot.appendingPathComponent("Echo") }
}
