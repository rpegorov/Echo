//
//  ContentView.swift
//  MonitorBarApp
//
//  Поповер строки меню — направление B (LiquidGlass / фирменный).
//  Сервисы и обработчик выбора метрики внедряются снаружи (из MenuBarController),
//  чтобы поповер и детальное окно работали с одним экземпляром MetricsService.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var metrics: MetricsService
    @ObservedObject var utilities: SystemUtilitiesService
    @ObservedObject var clipboard: ClipboardService
    @ObservedObject var settings: AppSettings
    @ObservedObject var ultraSwitch: UltraSwitchService

    /// Открыть детальное окно для выбранной метрики (реализуется владельцем поповера).
    let onSelect: (MetricTab) -> Void
    /// Открыть окно истории буфера обмена.
    let onOpenClipboard: () -> Void
    /// Открыть настройки.
    let onOpenPreferences: () -> Void

    var body: some View {
        Group {
            VStack(spacing: 0) {
                header

                ringsRow
                    .padding(.horizontal, 12)
                    .padding(.top, 4)

                networkRow
                    .padding(.horizontal, 12)
                    .padding(.top, 10)

                sectionDivider
                    .padding(.top, 12)

                utilitiesSection

                sectionDivider

                footer
            }
            .padding(.vertical, 12)
            .frame(width: DS.popoverWidth)
        }
        .onAppear { metrics.start() }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 7) {
            Image("MenuBarIcon")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 15, height: 15)
            Text(appName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    /// Отображаемое имя приложения (CFBundleDisplayName → CFBundleName → fallback).
    private var appName: String {
        (Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String)
            ?? (Bundle.main.infoDictionary?["CFBundleName"] as? String)
            ?? "Echo"
    }

    // MARK: - Rings row (CPU / MEM / DISK)

    private var ringsRow: some View {
        HStack(spacing: 4) {
            ringCell(.cpu)
            ringCell(.memory)
            ringCell(.disk)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.cornerLG))
    }

    @ViewBuilder
    private func ringCell(_ tab: MetricTab) -> some View {
        let d = metricData(for: tab)
        CircularProgressView(
            progress:  d.progress,
            valueText: d.value,
            unitText:  d.unit,
            name:      tab.rawValue.uppercased(),
            subLabel:  d.sub,
            action: { onSelect(tab) }
        )
    }

    // MARK: - Network row

    private var networkRow: some View {
        Button { onSelect(.network) } label: {
            HStack(spacing: 10) {
                Image(systemName: "network")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(DS.accent)
                Text("Network")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    speedLine(icon: "arrow.down", value: metrics.metrics.network.download, color: .blue)
                    speedLine(icon: "arrow.up",   value: metrics.metrics.network.upload,   color: .green)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.cornerMD))
    }

    /// Одна строка скорости: стрелка направления + значение.
    private func speedLine(icon: String, value: Double, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(color)
            Text(formatSpeed(value))
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.primary)
        }
    }

    // MARK: - Utilities

    private var utilitiesSection: some View {
        VStack(spacing: 0) {
            HStack {
                Text("UTILITIES")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .tracking(1.2)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 6)

            UtilityToggleRow(title: "Keyboard Cleaning", isOn: $utilities.keyboardCleaningEnabled)
            if utilities.keyboardCleaningNeedsPermission {
                Text("Grant Accessibility access, then toggle again.")
                    .font(.system(size: 10))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 4)
                    .transition(.opacity)
            }
            UtilityToggleRow(title: "Prevent Sleep", isOn: $utilities.preventSleepEnabled)

            UtilityToggleRow(title: "Auto Layout Fix", isOn: autoLayoutFix)
            if ultraSwitch.status.isBlocked {
                Button { ultraSwitch.requestAccess() } label: {
                    Text("Нужен доступ Accessibility — разрешить")
                        .font(.system(size: 10))
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 4)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .transition(.opacity)
            }

            UtilityToggleRow(title: "Clipboard History", isOn: $clipboard.isEnabled)
            if clipboard.isEnabled {
                Button { onOpenClipboard() } label: {
                    HStack {
                        Text("Open history")
                            .font(.system(size: 12))
                            .foregroundStyle(DS.accent)
                        Spacer()
                        Text("\(clipboard.items.count)")
                            .font(.system(size: 11, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.tertiary)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .transition(.opacity)
            }
        }
        .padding(.bottom, 6)
    }

    /// Тумблер поповера включает автоисправление вместе с самой фичей,
    /// а выключает только автозамену — хоткеи раскладки остаются рабочими.
    private var autoLayoutFix: Binding<Bool> {
        Binding(
            get: { settings.ultraSwitchEnabled && settings.autoConvertEnabled },
            set: { isOn in
                if isOn { settings.ultraSwitchEnabled = true }
                settings.autoConvertEnabled = isOn
            }
        )
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Button { onOpenPreferences() } label: {
                HStack(spacing: 5) {
                    Image(systemName: "gearshape")
                    Text("Preferences")
                }
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Text("Quit")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
    }

    // MARK: - Shared bits

    private var sectionDivider: some View {
        Divider().opacity(0.15).padding(.horizontal, 12)
    }

    private func metricData(for tab: MetricTab) -> (progress: Double, value: String, unit: String, sub: String) {
        switch tab {
        case .cpu:
            let pct = metrics.metrics.cpu.usage
            return (pct, "\(Int(pct))", "%", "\(metrics.metrics.cpu.coreCount) cores")

        case .memory:
            let pct  = metrics.metrics.ram.usagePercent
            let used = Double(metrics.metrics.ram.used)  / 1_073_741_824
            let tot  = Double(metrics.metrics.ram.total) / 1_073_741_824
            return (pct, "\(Int(pct))", "%", String(format: "%.0f/%.0f GB", used, tot))

        case .disk:
            let pct  = metrics.metrics.disk.usagePercent
            let used = ByteCountFormatter.string(fromByteCount: metrics.metrics.disk.used,  countStyle: .decimal)
            let tot  = ByteCountFormatter.string(fromByteCount: metrics.metrics.disk.total, countStyle: .decimal)
            return (pct, "\(Int(pct))", "%", "\(used)/\(tot)")

        case .network:
            return (0, "", "", "")
        }
    }

    /// Форматирует скорость (вход в КБ/с) в КБ/с или МБ/с.
    private func formatSpeed(_ kbPerSec: Double) -> String {
        if kbPerSec >= 1024 {
            return String(format: "%.1f MB/s", kbPerSec / 1024)
        }
        return String(format: "%.0f KB/s", kbPerSec)
    }
}

// MARK: - UtilityToggleRow

struct UtilityToggleRow: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Spacer()
            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
                .labelsHidden()
                .tint(DS.accent)
                .scaleEffect(0.8)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 5)
    }
}
