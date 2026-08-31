//
//  SnippetStore.swift
//  MonitorBarApp
//

import Foundation

/// Сокращение и то, во что оно разворачивается.
struct Snippet: Codable, Identifiable, Hashable, Sendable {
    var id = UUID()
    /// Что набирает пользователь, например `@@`.
    var abbreviation: String
    /// Что подставляется вместо него.
    var expansion: String
}

/// Хранилище сниппетов и поиск разворачиваемого сокращения.
///
/// Сокращение ищется без учёта регистра и раскладки: набранное в русской
/// раскладке `ЬЬ` находит сниппет `mm` — иначе автозамена и сниппеты мешали бы
/// друг другу, ведь пользователь редко замечает, в какой раскладке печатает.
@MainActor
final class SnippetStore: ObservableObject {

    @Published private(set) var snippets: [Snippet] {
        didSet { persist() }
    }

    private let defaults = UserDefaults.standard
    private static let storageKey = "snippets.items"

    init() {
        if let data = defaults.data(forKey: Self.storageKey),
           let stored = try? JSONDecoder().decode([Snippet].self, from: data) {
            snippets = stored
        } else {
            snippets = []
        }
    }

    // MARK: - Правка

    func add(abbreviation: String, expansion: String) {
        let trimmed = abbreviation.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !expansion.isEmpty else { return }

        // Одно сокращение — один сниппет: иначе разворачивался бы случайный.
        snippets.removeAll { $0.abbreviation.caseInsensitiveCompare(trimmed) == .orderedSame }
        snippets.append(Snippet(abbreviation: trimmed, expansion: expansion))
    }

    func remove(_ snippet: Snippet) {
        snippets.removeAll { $0.id == snippet.id }
    }

    // MARK: - Поиск

    /// Разворачивание для набранного слова, если такое сокращение есть.
    func expansion(for typed: String) -> String? {
        guard !typed.isEmpty else { return nil }

        // Вариант в другой раскладке: набрали сокращение, не переключившись.
        let alternate = LayoutTranslit.script(of: typed)
            .flatMap { LayoutTranslit.convert(typed, from: $0) }

        return snippets.first { snippet in
            snippet.matches(typed) || (alternate.map(snippet.matches) ?? false)
        }?.expansion
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(snippets) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
}

private extension Snippet {
    func matches(_ candidate: String) -> Bool {
        abbreviation.caseInsensitiveCompare(candidate) == .orderedSame
    }
}
