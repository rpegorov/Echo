//
//  KeystrokeBuffer.swift
//  MonitorBarApp
//

import Foundation

/// Текущее набираемое слово — единственное, что приложение держит в памяти.
///
/// Буфер существует потому, что читать текст из чужого поля через Accessibility
/// можно далеко не везде: Pages не отдаёт его вовсе, а движки на Chromium
/// принимают запись и молча игнорируют. Набранное же известно всегда.
///
/// Границы жёсткие: одно слово, не длиннее лимита, только буквы, ничего не
/// пишется на диск. Всё, что делает позицию каретки неизвестной — клик, стрелки,
/// сочетание с модификатором, смена приложения, — обнуляет буфер: иначе
/// последующие Backspace стёрли бы чужой текст.
@MainActor
final class KeystrokeBuffer {

    /// Длиннее этого слов не бывает, а память расти не должна.
    private static let maxWordLength = 64

    /// Слово, которое набирается прямо сейчас.
    private(set) var currentWord = ""

    /// Последнее завершённое слово и разделители после него.
    private(set) var completedWord = ""
    private(set) var completedTail = ""

    // MARK: - Ввод

    /// Добавляет напечатанный символ.
    ///
    /// Слово завершает только пробельный символ, а не любой не-буквенный:
    /// сокращения сниппетов сплошь и рядом состоят из знаков (`@@`, `;sig`),
    /// и обрыв на первом же символе делал бы их ненаходимыми.
    func append(_ character: Character) {
        guard !character.isWhitespace else {
            complete(with: String(character))
            return
        }
        // Новое слово началось сразу после завершённого — прошлое больше не наше.
        if !completedWord.isEmpty && currentWord.isEmpty { dropCompleted() }

        guard currentWord.count < Self.maxWordLength else { clear(); return }
        currentWord.append(character)
    }

    func backspace() {
        if currentWord.isEmpty {
            // Стёрли за пределы своего слова — где каретка, мы больше не знаем.
            clear()
        } else {
            currentWord.removeLast()
        }
    }

    /// Слово завершено разделителем.
    private func complete(with separator: String) {
        if currentWord.isEmpty {
            completedTail += separator
            if completedTail.count > Self.maxWordLength { dropCompleted() }
        } else {
            completedWord = currentWord
            completedTail = separator
            currentWord = ""
        }
    }

    /// Полный сброс: позиция каретки стала неизвестной.
    func clear() {
        currentWord = ""
        dropCompleted()
    }

    private func dropCompleted() {
        completedWord = ""
        completedTail = ""
    }

    // MARK: - Выдача

    /// Завершённый разделителем кусок целиком, вместе со знаками, — для сниппетов.
    /// `deleteCount` — сколько символов придётся стереть, включая хвост.
    func completedToken() -> (token: String, tail: String, deleteCount: Int)? {
        guard !completedWord.isEmpty, currentWord.isEmpty else { return nil }
        return (completedWord, completedTail, completedWord.count + completedTail.count)
    }

    /// Слово для автозамены раскладки: только буквенное начало куска.
    /// Знаки после него уезжают в хвост и печатаются обратно как есть —
    /// иначе «привет,» не исправлялось бы из-за запятой.
    func completedForConversion() -> (word: String, tail: String, deleteCount: Int)? {
        guard let completed = completedToken() else { return nil }

        let letters = completed.token.prefix { $0.isLetter }
        guard !letters.isEmpty else { return nil }

        let trailingSigns = completed.token.dropFirst(letters.count)
        return (String(letters), String(trailingSigns) + completed.tail, completed.deleteCount)
    }

    /// Слово для ручной конвертации по хоткею: сначала то, что набирается
    /// сейчас, иначе последнее завершённое.
    func wordForManualConversion() -> (word: String, tail: String, deleteCount: Int)? {
        if !currentWord.isEmpty {
            return (currentWord, "", currentWord.count)
        }
        return completedForConversion()
    }

    /// Заменяет содержимое буфера на исправленный вариант — чтобы повторная
    /// конвертация работала как отмена, а не как замена «в никуда».
    func replaceCompleted(with word: String) {
        guard !completedWord.isEmpty else {
            currentWord = word
            return
        }
        completedWord = word
    }
}
