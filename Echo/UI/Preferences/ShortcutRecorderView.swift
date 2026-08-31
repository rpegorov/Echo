//
//  ShortcutRecorderView.swift
//  MonitorBarApp
//

import AppKit
import SwiftUI

/// Поле записи горячей клавиши: клик → «Press keys…», ловит следующее нажатие.
struct ShortcutRecorderView: View {
    let command: WMCommand
    @ObservedObject var settings: AppSettings

    @State private var recording = false
    @State private var monitor: Any?

    var body: some View {
        HStack(spacing: 6) {
            Button(action: toggleRecording) {
                Text(label)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(recording ? DS.accent : .primary)
                    .frame(minWidth: 70)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: DS.cornerSM))
            }
            .buttonStyle(.plain)

            if settings.shortcut(for: command) != nil {
                Button {
                    stopRecording()
                    settings.setShortcut(nil, for: command)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .onDisappear { stopRecording() }
    }

    private var label: String {
        if recording { return "Press keys…" }
        return settings.shortcut(for: command)?.displayString ?? "None"
    }

    private func toggleRecording() {
        recording ? stopRecording() : startRecording()
    }

    private func startRecording() {
        recording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Локальный монитор срабатывает на главном потоке.
            MainActor.assumeIsolated {
                if event.keyCode != 53 { // 53 = Esc (отмена)
                    let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
                    let shortcut = KeyboardShortcut(keyCode: UInt32(event.keyCode), flags: flags)
                    settings.setShortcut(shortcut, for: command)
                }
                stopRecording()
            }
            return nil // поглощаем событие
        }
    }

    private func stopRecording() {
        recording = false
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }
}
