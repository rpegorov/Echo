//
//  DiskDetailView.swift
//  MonitorBarApp
//
//  Created by Ростислав Егоров on 08.12.2025.
//

import AppKit
import SwiftUI

struct DiskDetailView: View {
    let diskUsed: Int64
    let diskTotal: Int64
    @State private var topFiles: [FileInfo] = []
    @State private var isLoading = true
    @State private var processMonitor = ProcessMonitor()
    @State private var showCleanup = false

    var diskUsagePercent: Double {
        guard diskTotal > 0 else { return 0 }
        return Double(diskUsed) / Double(diskTotal) * 100.0
    }

    var diskFree: Int64 {
        return diskTotal - diskUsed
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Компактная сводка одной строкой — процент уже виден в баре сверху.
            HStack(spacing: 10) {
                summaryStat("Used",  ByteCountFormatter.string(fromByteCount: diskUsed,  countStyle: .file))
                summaryStat("Free",  ByteCountFormatter.string(fromByteCount: diskFree,  countStyle: .file))
                summaryStat("Total", ByteCountFormatter.string(fromByteCount: diskTotal, countStyle: .file))
            }

            HStack {
                Text("Top 10 Largest Files")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    showCleanup = true
                } label: {
                    Label("Clean system…", systemImage: "sparkles")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.borderedProminent)
                .tint(DS.accent)
            }

            // Список заполняет всё оставшееся пространство.
            Group {
                if isLoading {
                    Text("Loading...")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                } else if topFiles.isEmpty {
                    Text("No large files found")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                } else {
                    ScrollView(showsIndicators: true) {
                        VStack(spacing: 6) {
                            ForEach(Array(topFiles.enumerated()), id: \.element.path) { index, file in
                                FileRowView(
                                    rank: index + 1,
                                    file: file,
                                    onReveal: { reveal(file) },
                                    onTrash:  { trash(file) }
                                )
                            }
                        }
                    }
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .task {
            isLoading = true
            topFiles  = await processMonitor.topFilesBySize(limit: 10)
            isLoading = false
        }
        .sheet(isPresented: $showCleanup) {
            MoleCleanupView()
        }
    }

    /// Компактная ячейка сводки (заголовок + значение) в стеклянной карточке.
    private func summaryStat(_ title: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.tertiary)
            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.cornerSM))
    }

    /// Показать файл в Finder.
    private func reveal(_ file: FileInfo) {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: file.path)])
    }

    /// Переместить файл в Корзину и убрать из списка.
    private func trash(_ file: FileInfo) {
        let url = URL(fileURLWithPath: file.path)
        do {
            try FileManager.default.trashItem(at: url, resultingItemURL: nil)
            topFiles.removeAll { $0.path == file.path }
        } catch {
            NSSound.beep()
        }
    }
}

struct FileRowView: View {
    let rank: Int
    let file: FileInfo
    let onReveal: () -> Void
    let onTrash: () -> Void

    var body: some View {
        Button(action: onReveal) {
            HStack(spacing: 12) {
                // Номер в топе
                Text("\(rank)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(width: 20, alignment: .trailing)

                // Путь к файлу
                VStack(alignment: .leading, spacing: 2) {
                    Text(fileName)
                        .font(.system(.body, design: .monospaced))
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Text(filePath)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.head)
                }

                Spacer()

                // Размер файла
                Text(
                    ByteCountFormatter.string(fromByteCount: file.size, countStyle: .file)
                )
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(DS.accent)

                Image(systemName: "arrow.up.forward.app")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: DS.cornerSM))
        .help("Открыть в Finder")
        .contextMenu {
            Button { onReveal() } label: { Label("Show in Finder", systemImage: "folder") }
            Button(role: .destructive) { onTrash() } label: { Label("Move to Trash", systemImage: "trash") }
        }
    }

    /// Получить имя файла из полного пути
    private var fileName: String {
        (file.path as NSString).lastPathComponent
    }

    /// Получить путь к директории файла
    private var filePath: String {
        (file.path as NSString).deletingLastPathComponent
    }
}
