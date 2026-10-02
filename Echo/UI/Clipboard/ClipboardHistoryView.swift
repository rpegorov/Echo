//
//  ClipboardHistoryView.swift
//  MonitorBarApp
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ClipboardHistoryView: View {
    @ObservedObject var service: ClipboardService
    /// Закрывает окно истории: `dismiss` из окружения не действует на NSWindow
    /// с NSHostingController, поэтому владелец окна передаёт закрытие явно.
    let onClose: () -> Void
    @EnvironmentObject private var loc: Localizer
    @State private var hoveredID: ClipboardItem.ID?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().padding(.horizontal, 20)
            if service.items.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .frame(width: DS.clipboardSize.width, height: DS.clipboardSize.height)
        .glassEffect(.regular, in: .rect(cornerRadius: DS.cornerXL))
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.on.doc")
                .font(.system(size: 20))
            Text(loc.t(SystemKey.windowTitleClipboard))
                .font(.system(size: 20, weight: .medium))
            Spacer()
            Menu {
                Button(loc.t(PopoverKey.clear)) { service.clear() }
                    .disabled(service.items.isEmpty)
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14, weight: .semibold))
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .fixedSize()
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 14)
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
            LazyVStack(spacing: 2) {
                ForEach(service.items) { item in
                    Button {
                        service.copyToClipboard(item)
                        onClose()
                    } label: {
                        row(item, isHovered: hoveredID == item.id)
                    }
                    .buttonStyle(.plain)
                    .onHover { inside in
                        if inside {
                            hoveredID = item.id
                        } else if hoveredID == item.id {
                            hoveredID = nil
                        }
                    }
                }
            }
            .padding(10)
        }
    }

    private func row(_ item: ClipboardItem, isHovered: Bool) -> some View {
        HStack(spacing: 14) {
            ClipboardItemIcon(item: item)
            VStack(alignment: .leading, spacing: 3) {
                Text(ClipboardItemPresentation.title(of: item, using: loc))
                    .font(.system(size: 15, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(ClipboardItemPresentation.subtitle(of: item, using: loc))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Image(systemName: "doc.on.doc.fill")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(width: 30, height: 30)
                .background(Color.primary.opacity(0.1), in: Circle())
                .opacity(isHovered ? 1 : 0)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .background(
            isHovered ? DS.pressHighlight : Color.clear,
            in: RoundedRectangle(cornerRadius: DS.cornerMD)
        )
    }
}

// MARK: - Icon

/// Content preview with the source app's icon as a corner badge.
private struct ClipboardItemIcon: View {
    let item: ClipboardItem

    private static let size: CGFloat = 40
    private static let badgeSize: CGFloat = 20

    var body: some View {
        preview
            .frame(width: Self.size, height: Self.size)
            .overlay(alignment: .bottomTrailing) {
                if let app = item.sourceAppURL {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: app.path))
                        .resizable()
                        .frame(width: Self.badgeSize, height: Self.badgeSize)
                        .offset(x: Self.badgeSize / 4, y: Self.badgeSize / 4)
                }
            }
    }

    @ViewBuilder
    private var preview: some View {
        switch item.kind {
        case .text:
            typeIcon(.plainText)
        case .image:
            if let data = item.imageData, let image = NSImage(data: data) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: Self.size, height: Self.size)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                typeIcon(.image)
            }
        case .file:
            Image(nsImage: NSWorkspace.shared.icon(forFile: item.filePaths?.first ?? ""))
                .resizable()
                .scaledToFit()
        }
    }

    private func typeIcon(_ type: UTType) -> some View {
        Image(nsImage: NSWorkspace.shared.icon(for: type))
            .resizable()
            .scaledToFit()
    }
}
