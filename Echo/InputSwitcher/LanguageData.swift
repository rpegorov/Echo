//
//  LanguageData.swift
//  MonitorBarApp
//

import Foundation

/// Словари и триграммные модели для русского и английского.
///
/// Системный `NSSpellChecker` для этой задачи не годится: он умеет со временем
/// начать считать корректным вообще любое слово, и автозамена молча замолкает.
/// Поэтому данные свои и неизменные — списки слов плюс логарифмические
/// вероятности трёхбуквенных сочетаний (см. THIRD_PARTY.md).
final class LanguageData: @unchecked Sendable {

    static let shared = LanguageData()

    private var words: [KeyScript: Set<String>] = [:]
    private var trigrams: [KeyScript: [String: Double]] = [:]
    private let lock = NSLock()
    private var isLoaded = false

    private init() {}

    /// Читает данные с диска. Стоит десятки миллисекунд, поэтому вызывается
    /// заранее и не с главного потока.
    func load() {
        lock.lock()
        defer { lock.unlock() }
        guard !isLoaded else { return }

        for script in [KeyScript.latin, .cyrillic] {
            words[script] = Self.decode([String].self, named: "words_\(script.dataSuffix)")
                .map(Set.init) ?? []
            trigrams[script] = Self.decode([String: Double].self, named: "trigrams_\(script.dataSuffix)") ?? [:]
        }
        isLoaded = true
    }

    /// Есть ли слово в словаре своего алфавита.
    func isWord(_ word: String, script: KeyScript) -> Bool {
        load()
        lock.lock()
        defer { lock.unlock() }
        return words[script]?.contains(word.lowercased()) ?? false
    }

    /// Правдоподобность строки для языка: средняя логарифмическая вероятность
    /// её триграмм. Чем больше, тем естественнее выглядит слово.
    ///
    /// Нужна для слов, которых нет в словаре, — имён, сленга, опечаток:
    /// «ghbdtn» и «привет» различаются здесь очень уверенно.
    func plausibility(_ word: String, script: KeyScript) -> Double {
        load()
        lock.lock()
        let table = trigrams[script] ?? [:]
        lock.unlock()
        guard !table.isEmpty else { return -.infinity }

        let padded = Array(" \(word.lowercased()) ")
        guard padded.count >= 3 else { return -.infinity }

        // Отсутствующая триграмма — не «невозможно», а «очень редко»:
        // иначе одно незнакомое сочетание обнуляло бы всё слово.
        let missingPenalty = -20.0
        var total = 0.0
        var count = 0
        for index in 0...(padded.count - 3) {
            let key = String(padded[index..<(index + 3)])
            total += table[key] ?? missingPenalty
            count += 1
        }
        return total / Double(count)
    }

    // MARK: - Private

    private static func decode<T: Decodable>(_ type: T.Type, named name: String) -> T? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}

private extension KeyScript {
    /// Суффикс в именах файлов с данными.
    var dataSuffix: String {
        switch self {
        case .latin:    return "en"
        case .cyrillic: return "ru"
        }
    }
}
