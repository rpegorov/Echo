//
//  ClipboardHistoryView.swift
//  MonitorBarApp
//

import AppKit
import SwiftUI

struct ClipboardHistoryView: View {
    @ObservedObject var service: ClipboardService
    /// Закрывает окно истории: `dismiss` из окружения не действует на NSWindow
    /// с NSHostingController, поэтому владелец окна передаёт закрытие явно.
    let onClose: () -> Void
    @EnvironmentObject private var loc: Localizer

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.15)
            if service.items.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .frame(width: 380, height: 460)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "doc.on.clipboard")
                .foregroundStyle(DS.accent)
            Text(loc.t(PopoverKey.clipboardHistoryTitle))
                .font(.system(size: 14, weight: .semibold))
            Spacer()
            Button(loc.t(PopoverKey.clear)) { service.clear() }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .disabled(service.items.isEmpty)
            Button(loc.t(PopoverKey.done)) { onClose() }
                .buttonStyle(.plain)
                .foregroundStyle(DS.accent)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Empty

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "clipboard")
                .font(.system(size: 30))
                .foregroundStyle(.tertiary)
            Text(loc.t(PopoverKey.clipboardEmptyTitle))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
            Text(loc.t(PopoverKey.clipboardEmptyHint))
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }

    // MARK: - List

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 6) {
                ForEach(service.items) { item in
                    Button {
                        service.copyToClipboard(item)
                        onClose()
                    } label: {
                        row(item)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
        }
    }

    @ViewBuilder
    private func row(_ item: ClipboardItem) -> some View {
        HStack(spacing: 10) {
            switch item.kind {
            case .text:
                Image(systemName: "text.alignleft")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(width: 28)
                Text(item.text ?? "")
                    .font(.system(size: 12))
                    .lineLimit(2)
                    .truncationMode(.tail)
            case .image:
                if let data = item.imageData, let image = NSImage(data: data) {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 28, height: 28)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                } else {
                    Image(systemName: "photo")
                        .frame(width: 28)
                }
                Text(loc.t(PopoverKey.clipboardImageLabel))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            case .file:
                let paths = item.filePaths ?? []
                Image(nsImage: NSWorkspace.shared.icon(forFile: paths.first ?? ""))
                    .resizable()
                    .scaledToFit()
                    .frame(width: 28, height: 28)
                VStack(alignment: .leading, spacing: 1) {
                    Text(((paths.first ?? "") as NSString).lastPathComponent)
                        .font(.system(size: 12))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    if paths.count > 1 {
                        Text(loc.t(PopoverKey.clipboardMoreFiles, Int64(paths.count - 1)))
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Spacer()

            Text(item.date, style: .time)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: DS.cornerSM))
    }
}
