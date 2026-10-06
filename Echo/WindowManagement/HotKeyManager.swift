//
//  HotKeyManager.swift
//  MonitorBarApp
//

import AppKit
import Carbon.HIToolbox
import os

/// Один физический пропуск клавиши — одно срабатывание хоткея.
///
/// Carbon доставляет kEventHotKeyPressed и на автоповторе зажатого сочетания,
/// а команды вроде конвертации слова — тумблеры: повтор внутри одного
/// удержания перевернул бы результат обратно. Удержание, для которого
/// потерялся kEventHotKeyReleased, освобождается по таймауту — иначе один
/// сбой навсегда заглушил бы хоткей.
struct HotKeyFireGate {
    private var holds: [UInt32: TimeInterval] = [:]

    /// Отмечает нажатие и отвечает, должно ли оно сработать.
    mutating func shouldFire(id: UInt32, now: TimeInterval) -> Bool {
        holds = holds.filter { now - $0.value < Self.stuckHoldTimeout }
        guard holds[id] == nil else { return false }
        holds[id] = now
        return true
    }

    mutating func released(id: UInt32) {
        holds[id] = nil
    }

    private static let stuckHoldTimeout: TimeInterval = 2
}

/// Регистрирует глобальные горячие клавиши через Carbon (RegisterEventHotKey).
/// Глобальные хоткеи не требуют Accessibility; права нужны только для действий
/// над окнами (см. WindowManagerService).
final class HotKeyManager {

    private var hotKeyRefs: [EventHotKeyRef?] = []
    private var actions: [UInt32: () -> Void] = [:]
    private var handlerRef: EventHandlerRef?
    private var nextID: UInt32 = 1
    private var gate = HotKeyFireGate()
    private let signature: OSType = 0x4D4F4E49 // 'MONI'

    private static let log = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "Echo",
        category: "HotKeys"
    )

    init() {
        let specs = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased))
        ]
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let event, let userData else { return noErr }
                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                guard status == noErr else { return noErr }
                let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
                switch GetEventKind(event) {
                case UInt32(kEventHotKeyPressed):
                    let now = Date().timeIntervalSinceReferenceDate
                    if manager.gate.shouldFire(id: hotKeyID.id, now: now) {
                        manager.fire(id: hotKeyID.id)
                    }
                case UInt32(kEventHotKeyReleased):
                    manager.gate.released(id: hotKeyID.id)
                default:
                    break
                }
                return noErr
            },
            specs.count, specs, selfPtr, &handlerRef
        )
    }

    private func fire(id: UInt32) {
        Self.log.debug("Сработал хоткей #\(id, privacy: .public)")
        actions[id]?()
    }

    /// Регистрирует сочетание. `action` вызывается на главном потоке (Carbon).
    /// `label` попадает в лог: молчащий хоткей иначе неотличим от неработающей команды.
    func register(_ shortcut: KeyboardShortcut, label: String = "", action: @escaping () -> Void) {
        let id = nextID
        nextID += 1
        actions[id] = action

        var ref: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: signature, id: id)
        let status = RegisterEventHotKey(
            shortcut.keyCode,
            shortcut.carbonModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )
        if status == noErr {
            hotKeyRefs.append(ref)
            Self.log.notice("Хоткей \(label, privacy: .public) — \(shortcut.displayString, privacy: .public): зарегистрирован") // l10n-exempt: log, not user-facing
        } else {
            Self.log.error("Хоткей \(label, privacy: .public) — \(shortcut.displayString, privacy: .public): ошибка \(status, privacy: .public)")
        }
    }

    func unregisterAll() {
        for ref in hotKeyRefs where ref != nil { UnregisterEventHotKey(ref) }
        hotKeyRefs.removeAll()
        actions.removeAll()
        nextID = 1
    }

    deinit {
        unregisterAll()
        if let handlerRef { RemoveEventHandler(handlerRef) }
    }
}
