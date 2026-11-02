//
//  TranslationLanguageTests.swift
//  EchoTests
//
//  The translation feature only ever converts between Russian and English.
//  Unconstrained NLLanguageRecognizer classifies non-Russian Cyrillic text
//  (Ukrainian, Belarusian, Bulgarian) as its own language; the resulting
//  "bg -> ru"-style pair is unsupported on device, translationTask never
//  fires its action, and the translation silently never starts.
//

import Testing
@testable import Echo

@MainActor
struct TranslationLanguageTests {

    private func code(_ text: String) -> String {
        TranslationService.detectLanguage(of: text)?.languageCode?.identifier ?? "nil"
    }

    @Test("Cyrillic look-alikes resolve to the supported ru/en pair")
    func cyrillicResolvesToRussian() {
        #expect(code("Привіт, як справи?") == "ru")
        #expect(code("Здрасти, што новага?") == "ru")
        #expect(code("Привет, как дела?") == "ru")
    }

    @Test("Latin text resolves to English as the translation source")
    func latinResolvesToEnglish() {
        #expect(code("Hello there, how are you doing today") == "en")
    }
}
