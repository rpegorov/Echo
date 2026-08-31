//
//  ClipboardItem.swift
//  MonitorBarApp
//

import Foundation

/// Элемент истории буфера обмена.
struct ClipboardItem: Identifiable, Equatable {
    enum Kind: Equatable { case text, image, file }

    let id = UUID()
    let kind: Kind
    let text: String?
    let imageData: Data?
    /// Пути к файлам (например, скопированным в Finder).
    let filePaths: [String]?
    let date: Date

    static func == (lhs: ClipboardItem, rhs: ClipboardItem) -> Bool { lhs.id == rhs.id }
}
