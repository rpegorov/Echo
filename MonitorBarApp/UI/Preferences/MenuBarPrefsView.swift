//
//  MenuBarPrefsView.swift
//  MonitorBarApp
//

import AppKit
import SwiftUI

/// Раздел Preferences: что показывать в строке меню.
struct MenuBarPrefsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var metrics: MetricsService

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PrefTitle("Menu Bar")

            PrefCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Что показывать")
                        .font(.system(size: 13, weight: .medium))
                    Picker("", selection: $settings.menuBarIconMode) {
                        ForEach(MenuBarIconMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
            }

            switch settings.menuBarIconMode {
            case .metrics: metricsPicker
            case .custom:  customPicker
            case .appIcon: EmptyView()
            }
        }
    }

    // MARK: - Метрики

    private var metricsPicker: some View {
        PrefCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Метрики в строке меню")
                        .font(.system(size: 13, weight: .medium))
                    Spacer()
                    Text(preview)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                PrefCaption("Обновляются с тем же интервалом, что и остальной мониторинг.")

                ForEach(MetricTab.allCases, id: \.self) { tab in
                    Toggle(isOn: binding(for: tab)) {
                        Label(tab.rawValue, systemImage: tab.icon)
                            .font(.system(size: 12))
                    }
                    .toggleStyle(.checkbox)
                }
            }
        }
    }

    /// Живой пример того, что окажется в строке меню.
    private var preview: String {
        StatusItemPresenter.text(for: metrics.metrics, shownMetrics: settings.menuBarMetrics)
    }

    /// Порядок в строке меню сохраняем таким же, как в списке настроек, —
    /// иначе метрики переставлялись бы местами при каждом включении.
    private func binding(for tab: MetricTab) -> Binding<Bool> {
        Binding(
            get: { settings.menuBarMetrics.contains(tab) },
            set: { isOn in
                var selected = settings.menuBarMetrics
                if isOn {
                    guard !selected.contains(tab) else { return }
                    selected.append(tab)
                } else {
                    selected.removeAll { $0 == tab }
                }
                settings.menuBarMetrics = MetricTab.allCases.filter { selected.contains($0) }
            }
        )
    }

    // MARK: - Своя картинка

    private var customPicker: some View {
        PrefCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    preview(of: settings.customIconPath)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(settings.customIconPath.map(URL.init(fileURLWithPath:))?.lastPathComponent
                             ?? "Картинка не выбрана")
                            .font(.system(size: 13, weight: .medium))
                        PrefCaption("PNG или SVG. Изображение масштабируется по высоте строки меню и красится в цвет системы.")
                    }
                    Spacer()
                }
                HStack(spacing: 10) {
                    Button("Выбрать…", action: chooseIcon)
                        .buttonStyle(.borderedProminent)
                        .tint(DS.accent)
                    if settings.customIconPath != nil {
                        Button("Убрать") { settings.customIconPath = nil }
                            .buttonStyle(.bordered)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func preview(of path: String?) -> some View {
        if let path, let image = NSImage(contentsOfFile: path) {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
        } else {
            Image(systemName: "photo")
                .font(.system(size: 20))
                .foregroundStyle(.tertiary)
                .frame(width: 24, height: 24)
        }
    }

    private func chooseIcon() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .svg, .pdf, .jpeg]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        settings.customIconPath = url.path
    }
}
