//
//  LayoutJudge.swift
//  MonitorBarApp
//

import Foundation

/// Решает, набрано ли слово не в той раскладке.
///
/// Порядок проверок важен: словарь своего языка защищает осмысленно набранное
/// («qwerty», «swift»), словарь чужого — уверенно ловит «ghbdtn». И только
/// когда обоих словарей не хватило, спор решают триграммы: они умеют отличить
/// правдоподобное слово от набора согласных, которого не бывает в языке.
struct LayoutJudge: Sendable {

    struct Verdict: Sendable {
        /// Слово, перенесённое на те же клавиши в другой раскладке.
        let converted: String
        /// Алфавит (и раскладка), в котором слово осмысленно.
        let target: KeyScript
    }

    /// Слова короче трёх букв не трогаем: на них любая эвристика врёт.
    private static let lengthRange = 3...40

    /// Насколько правдоподобнее должен быть перенос, чтобы менять слово,
    /// когда ни одного из вариантов нет в словарях.
    private static let plausibilityMargin = 1.5

    private let data: LanguageData

    init(data: LanguageData = .shared) {
        self.data = data
    }

    func warmUp() {
        data.load()
    }

    /// Вердикт для слова. `nil` — слово набрано правильно либо разобрать его нельзя.
    func verdict(for word: String) -> Verdict? {
        guard Self.lengthRange.contains(word.count),
              word.allSatisfy(\.isLetter),
              word.unicodeScalars.allSatisfy({ $0.isASCII || $0.value >= 0x0400 }),
              let script = LayoutTranslit.script(of: word),
              let converted = LayoutTranslit.convert(word, from: script),
              converted != word else { return nil }

        let target = script.other

        // Слово есть в своём словаре — оно набрано осознанно.
        if data.isWord(word, script: script) { return nil }

        // Перенос даёт настоящее слово другого языка — самый уверенный случай.
        if data.isWord(converted, script: target) {
            return Verdict(converted: converted, target: target)
        }

        // Ни там, ни там: сравниваем правдоподобность по триграммам.
        let asTyped = data.plausibility(word, script: script)
        let asConverted = data.plausibility(converted, script: target)
        guard asConverted - asTyped > Self.plausibilityMargin else { return nil }

        return Verdict(converted: converted, target: target)
    }
}
