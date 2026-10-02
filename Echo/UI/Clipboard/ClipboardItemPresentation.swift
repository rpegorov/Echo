//
//  ClipboardItemPresentation.swift
//  Echo
//

import AppKit

/// Title and subtitle of a clipboard history row, kept out of the view so
/// the wording can be tested without rendering.
@MainActor
enum ClipboardItemPresentation {

    static func title(of item: ClipboardItem, using loc: Localizer) -> String {
        switch item.kind {
        case .text:
            return firstLine(of: item.text ?? "")
        case .image:
            return pixelSize(of: item.imageData) ?? loc.t(PopoverKey.clipboardImageLabel)
        case .file:
            let paths = item.filePaths ?? []
            let name = ((paths.first ?? "") as NSString).lastPathComponent
            guard paths.count > 1 else { return name }
            return "\(name) \(loc.t(PopoverKey.clipboardMoreFiles, Int64(paths.count - 1)))" // l10n-exempt: joins two localized parts
        }
    }

    static func subtitle(of item: ClipboardItem, using loc: Localizer) -> String {
        let time = item.date.formatted(Date.FormatStyle(date: .omitted, time: .shortened, locale: loc.locale))
        return "\(kindName(of: item, using: loc)) · \(loc.t(PopoverKey.clipboardCopiedAt, time))" // l10n-exempt: joins two localized parts
    }

    private static func kindName(of item: ClipboardItem, using loc: Localizer) -> String {
        switch item.kind {
        case .text:  return loc.t(PopoverKey.clipboardKindText)
        case .image: return loc.t(PopoverKey.clipboardImageLabel)
        case .file:  return loc.t(PopoverKey.clipboardKindFile)
        }
    }

    /// First non-blank line, so a copied paragraph reads as one row.
    private static func firstLine(of text: String) -> String {
        let line = text.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty }
        return line ?? text
    }

    private static func pixelSize(of data: Data?) -> String? {
        guard let data, let rep = NSBitmapImageRep(data: data) else { return nil }
        return "\(rep.pixelsWide) × \(rep.pixelsHigh)" // l10n-exempt: numeric dimensions only
    }
}
