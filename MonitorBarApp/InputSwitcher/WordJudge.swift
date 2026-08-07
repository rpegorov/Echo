//
//  WordJudge.swift
//  MonitorBarApp
//

import AppKit

/// Решает, набрано ли слово не в той раскладке.
///
/// Словари не хранятся в приложении: используется системный `NSSpellChecker`
/// с русским и английским словарями macOS. Ни одно проверенное слово никуда
/// не записывается — метод чистый, состояние ограничено флагом доступности языков.
@MainActor
final class WordJudge {

    struct Verdict {
        /// Слово, перенесённое на те же клавиши в другой раскладке.
        let converted: String
        /// Алфавит (и раскладка), в котором слово осмысленно.
        let target: KeyScript
    }

    /// Слова короче двух и длиннее сорока символов не рассматриваем:
    /// на коротких словарь даёт слишком много ложных срабатываний.
    private static let lengthRange = 2...40

    private let checker = NSSpellChecker.shared
    private let supportsBothLanguages: Bool

    init() {
        let available = Set(NSSpellChecker.shared.availableLanguages)
        supportsBothLanguages = available.contains(KeyScript.latin.spellLanguage)
            && available.contains(KeyScript.cyrillic.spellLanguage)
    }

    /// Прогрев словарей, чтобы первая проверка не стоила сотню миллисекунд.
    func warmUp() {
        _ = isKnown("test", language: KeyScript.latin.spellLanguage)
        _ = isKnown("тест", language: KeyScript.cyrillic.spellLanguage)
    }

    /// Вердикт для слова. `nil` — слово набрано правильно либо разобрать его нельзя.
    func verdict(for word: String) -> Verdict? {
        guard supportsBothLanguages,
              Self.lengthRange.contains(word.count),
              word.allSatisfy(\.isLetter),
              let script = LayoutTranslit.script(of: word) else { return nil }

        // Слово есть в словаре своего языка — оно набрано осознанно.
        guard !isKnown(word, language: script.spellLanguage) else { return nil }

        let target = script.other
        guard let converted = LayoutTranslit.convert(word, from: script), converted != word,
              isKnown(converted, language: target.spellLanguage) else { return nil }

        return Verdict(converted: converted, target: target)
    }

    /// Проверка ведётся словарём того же алфавита, что и само слово:
    /// кириллица, проверенная английским словарём, всегда «корректна».
    private func isKnown(_ word: String, language: String) -> Bool {
        let range = checker.checkSpelling(
            of: word,
            startingAt: 0,
            language: language,
            wrap: false,
            inSpellDocumentWithTag: 0,
            wordCount: nil
        )
        return range.location == NSNotFound
    }
}
