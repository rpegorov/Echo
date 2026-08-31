//
//  InputSourceService.swift
//  MonitorBarApp
//

import AppKit
import Carbon.HIToolbox

/// Прямое управление раскладкой через Text Input Sources.
///
/// `TISSelectInputSource` переключает раскладку синхронно и без системного HUD —
/// в отличие от клавиши 🌐, которая проходит через WindowServer и заметно медленнее.
@MainActor
final class InputSourceService {

    /// Кэш включённых раскладок; сбрасывается по системному уведомлению.
    private var cached: [TISInputSource]?

    init() {
        DistributedNotificationCenter.default.addObserver(
            forName: NSNotification.Name(kTISNotifyEnabledKeyboardInputSourcesChanged as String),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.cached = nil }
        }
    }

    // MARK: - Public

    /// Алфавит текущей раскладки (`nil` — раскладка не ru и не en).
    func currentScript() -> KeyScript? {
        guard let current = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else { return nil }
        return Self.script(of: current)
    }

    /// Выбирает первую включённую раскладку нужного алфавита.
    @discardableResult
    func select(_ script: KeyScript) -> Bool {
        guard currentScript() != script else { return true }
        guard let target = selectableSources().first(where: { Self.script(of: $0) == script }) else {
            return false
        }
        return TISSelectInputSource(target) == noErr
    }

    /// Переключает ru ↔ en. Если текущая раскладка не из этой пары — включает латиницу.
    @discardableResult
    func toggle() -> Bool {
        select(currentScript()?.other ?? .latin)
    }

    /// Есть ли включённые раскладки для обоих алфавитов — иначе переключать нечего.
    func hasBothScripts() -> Bool {
        let scripts = Set(selectableSources().compactMap(Self.script(of:)))
        return scripts.contains(.latin) && scripts.contains(.cyrillic)
    }

    // MARK: - Private

    private func selectableSources() -> [TISInputSource] {
        if let cached { return cached }
        let filter: [CFString: Any] = [
            kTISPropertyInputSourceCategory: kTISCategoryKeyboardInputSource as Any,
            kTISPropertyInputSourceIsEnableCapable: true
        ]
        guard let list = TISCreateInputSourceList(filter as CFDictionary, false)?
            .takeRetainedValue() as? [TISInputSource] else {
            return []
        }
        let usable = list.filter { Self.boolProperty($0, kTISPropertyInputSourceIsSelectCapable) }
        cached = usable
        return usable
    }

    private static func script(of source: TISInputSource) -> KeyScript? {
        guard let languages = property(source, kTISPropertyInputSourceLanguages) as? [String],
              let first = languages.first else { return nil }
        if first.hasPrefix(KeyScript.cyrillic.inputLanguage) { return .cyrillic }
        if first.hasPrefix(KeyScript.latin.inputLanguage) { return .latin }
        return nil
    }

    private static func boolProperty(_ source: TISInputSource, _ key: CFString) -> Bool {
        (property(source, key) as? Bool) ?? false
    }

    private static func property(_ source: TISInputSource, _ key: CFString) -> AnyObject? {
        guard let pointer = TISGetInputSourceProperty(source, key) else { return nil }
        return Unmanaged<AnyObject>.fromOpaque(pointer).takeUnretainedValue()
    }
}
