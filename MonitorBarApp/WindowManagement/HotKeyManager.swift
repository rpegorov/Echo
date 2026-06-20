//
//  HotKeyManager.swift
//  MonitorBarApp
//

import AppKit
import Carbon.HIToolbox

/// Регистрирует глобальные горячие клавиши через Carbon (RegisterEventHotKey).
/// Глобальные хоткеи не требуют Accessibility; права нужны только для действий
/// над окнами (см. WindowManagerService).
final class HotKeyManager {

    private var hotKeyRefs: [EventHotKeyRef?] = []
    private var actions: [UInt32: () -> Void] = [:]
    private var handlerRef: EventHandlerRef?
    private var nextID: UInt32 = 1
    private let signature: OSType = 0x4D4F4E49 // 'MONI'

    init() {
        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
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
                manager.fire(id: hotKeyID.id)
                return noErr
            },
            1, &spec, selfPtr, &handlerRef
        )
    }

    private func fire(id: UInt32) {
        actions[id]?()
    }

    /// Регистрирует сочетание. `action` вызывается на главном потоке (Carbon).
    func register(_ shortcut: KeyboardShortcut, action: @escaping () -> Void) {
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
        if status == noErr { hotKeyRefs.append(ref) }
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
