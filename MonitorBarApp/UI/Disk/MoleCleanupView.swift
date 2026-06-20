//
//  MoleCleanupView.swift
//  MonitorBarApp
//
//  Очистка системы через Mole (https://github.com/tw93/Mole).
//  Превью — dry-run внутри приложения; выполнение — в Terminal.
//

import SwiftUI

struct MoleCleanupView: View {
    @StateObject private var mole = MoleService()
    @Environment(\.dismiss) private var dismiss
    @State private var selected: MoleCommand = .clean

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.15)
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 560, height: 520)
        .task { await mole.detect() }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .foregroundStyle(DS.accent)
            Text("System Cleanup")
                .font(.system(size: 14, weight: .semibold))
            Spacer()
            Button("Done") { dismiss() }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Content routing

    @ViewBuilder
    private var content: some View {
        switch mole.status {
        case .checking:
            ProgressView("Ищу Mole…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .notInstalled:
            notInstalled
        case .ready:
            ready
        }
    }

    // MARK: - Not installed

    private var notInstalled: some View {
        VStack(spacing: 14) {
            Image(systemName: "shippingbox")
                .font(.system(size: 34))
                .foregroundStyle(.secondary)
            Text("Mole не установлен")
                .font(.system(size: 15, weight: .semibold))
            Text("Mole — бесплатная утилита очистки macOS (MIT). Установите её, чтобы пользоваться очисткой из приложения.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)

            HStack(spacing: 8) {
                Text(mole.installCommand)
                    .font(.system(size: 12, design: .monospaced))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.cornerSM))
                Button {
                    copyToPasteboard(mole.installCommand)
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.plain)
                .help("Скопировать команду")
            }

            HStack(spacing: 10) {
                Button("Открыть на GitHub") { mole.openRepo() }
                    .buttonStyle(.bordered)
                Button("Проверить снова") { Task { await mole.detect() } }
                    .buttonStyle(.borderedProminent)
                    .tint(DS.accent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }

    // MARK: - Ready

    private var ready: some View {
        VStack(spacing: 12) {
            commandChips

            previewPanel
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            actionBar
        }
        .padding(16)
    }

    private var commandChips: some View {
        HStack(spacing: 8) {
            ForEach(MoleCommand.allCases) { command in
                Button {
                    selected = command
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: command.icon)
                            .font(.system(size: 12, weight: .medium))
                        Text(command.title)
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(selected == command ? DS.accent : .secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background {
                        if selected == command {
                            Color.clear.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.cornerSM))
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(6)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.cornerMD))
    }

    private var previewPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(selected.title)
                .font(.system(size: 15, weight: .semibold))
            Text(selected.subtitle)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            HStack(spacing: 6) {
                Image(systemName: "terminal")
                    .foregroundStyle(.tertiary)
                Text("mole \(selected.rawValue)")
                    .font(.system(size: 12, design: .monospaced))
                    .textSelection(.enabled)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.cornerSM))

            Text(selected.supportsDryRun
                 ? "«Preview» запустит команду с --dry-run: Mole только покажет, что будет удалено, ничего не меняя. «Run» выполнит реально. Обе откроются в Terminal — там вы подтвердите действия и при необходимости введёте sudo/Touch ID."
                 : "Откроется в Terminal — Mole покажет интерактивный обзор.")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var actionBar: some View {
        HStack(spacing: 10) {
            if selected.supportsDryRun {
                Button {
                    mole.runInTerminal(selected, dryRun: true)
                } label: {
                    Label("Preview (dry-run)", systemImage: "eye")
                }
                .buttonStyle(.bordered)
            }

            Spacer()

            Button {
                mole.runInTerminal(selected)
            } label: {
                Label("Run in Terminal", systemImage: "terminal")
            }
            .buttonStyle(.borderedProminent)
            .tint(DS.accent)
        }
    }

    // MARK: - Helpers

    private func copyToPasteboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}
