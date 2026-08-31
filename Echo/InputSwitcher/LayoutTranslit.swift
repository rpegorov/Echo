//
//  LayoutTranslit.swift
//  MonitorBarApp
//

import Foundation

/// Алфавит, в котором набрано слово. Определяет и раскладку, и словарь проверки.
enum KeyScript: Sendable {
    case latin
    case cyrillic

    /// Код языка для NSSpellChecker.
    var spellLanguage: String {
        switch self {
        case .latin:    return "en"
        case .cyrillic: return "ru"
        }
    }

    /// Префикс языка входного источника (kTISPropertyInputSourceLanguages).
    var inputLanguage: String {
        switch self {
        case .latin:    return "en"
        case .cyrillic: return "ru"
        }
    }

    var other: KeyScript {
        switch self {
        case .latin:    return .cyrillic
        case .cyrillic: return .latin
        }
    }
}

/// Позиционный перенос символов между раскладками QWERTY и ЙЦУКЕН.
///
/// Таблицы статические и неизменяемые: перевод не аллоцирует ничего, кроме
/// результирующей строки длиной с исходное слово.
enum LayoutTranslit {

    // Символы стоят строго на одинаковых физических клавишах.
    private static let latinRow  = "qwertyuiop[]asdfghjkl;'zxcvbnm,./`"
    private static let cyrillicRow = "йцукенгшщзхъфывапролджэячсмитьбю.ё"
    private static let latinShift = "QWERTYUIOP{}ASDFGHJKL:\"ZXCVBNM<>?~"
    private static let cyrillicShift = "ЙЦУКЕНГШЩЗХЪФЫВАПРОЛДЖЭЯЧСМИТЬБЮ,Ё"

    private static let latinToCyrillic: [Character: Character] =
        pairs(from: latinRow, to: cyrillicRow).merging(
            pairs(from: latinShift, to: cyrillicShift)
        ) { first, _ in first }

    private static let cyrillicToLatin: [Character: Character] =
        pairs(from: cyrillicRow, to: latinRow).merging(
            pairs(from: cyrillicShift, to: latinShift)
        ) { first, _ in first }

    private static func pairs(from: String, to: String) -> [Character: Character] {
        Dictionary(uniqueKeysWithValues: zip(from, to))
    }

    /// Алфавит слова. `nil` — слово смешанное, пустое или в третьем алфавите:
    /// в этих случаях конвертация заведомо не нужна.
    static func script(of word: String) -> KeyScript? {
        var sawLatin = false
        var sawCyrillic = false
        for character in word where character.isLetter {
            guard let scalar = character.unicodeScalars.first else { return nil }
            switch scalar.value {
            case 0x0041...0x005A, 0x0061...0x007A:              sawLatin = true
            case 0x0400...0x04FF:                                sawCyrillic = true
            default:                                             return nil
            }
            if sawLatin && sawCyrillic { return nil }
        }
        if sawCyrillic { return .cyrillic }
        return sawLatin ? .latin : nil
    }

    /// Переносит слово на те же клавиши в другой раскладке.
    /// `nil` — хотя бы один символ не имеет пары (значит, конвертация бессмысленна).
    static func convert(_ word: String, from script: KeyScript) -> String? {
        let table = script == .latin ? latinToCyrillic : cyrillicToLatin
        var result = ""
        result.reserveCapacity(word.count)
        for character in word {
            guard let mapped = table[character] else { return nil }
            result.append(mapped)
        }
        return result
    }
}
