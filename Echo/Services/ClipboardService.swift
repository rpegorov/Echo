//
//  ClipboardService.swift
//  MonitorBarApp
//

import AppKit
import Foundation

/// История буфера обмена: опрашивает NSPasteboard и хранит последние элементы.
/// Игнорирует «секретные»/временные элементы (менеджеры паролей помечают их
/// org.nspasteboard.ConcealedType / TransientType). История живёт в памяти.
@MainActor
final class ClipboardService: ObservableObject {

    @Published var isEnabled: Bool = false {
        didSet {
            guard oldValue != isEnabled else { return }
            isEnabled ? start() : stop()
        }
    }

    @Published private(set) var items: [ClipboardItem] = []

    private var timer: Timer?
    private var lastChangeCount = NSPasteboard.general.changeCount
    private let maxItems = 50

    private static let concealed = NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")
    private static let transient = NSPasteboard.PasteboardType("org.nspasteboard.TransientType")

    // MARK: - Lifecycle

    private func start() {
        lastChangeCount = NSPasteboard.general.changeCount
        timer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.poll() }
        }
    }

    private func stop() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Polling

    private func poll() {
        let pb = NSPasteboard.general
        guard pb.changeCount != lastChangeCount else { return }
        lastChangeCount = pb.changeCount

        let types = pb.types ?? []
        guard !types.contains(Self.concealed), !types.contains(Self.transient) else { return }

        // 1. Файлы (например, скопированные в Finder) — берём раньше строки,
        //    иначе сохранилось бы только имя файла как текст.
        if let urls = pb.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) as? [URL], !urls.isEmpty {
            addFiles(urls.map(\.path))
            return
        }

        // 2. Сырое изображение (скриншот, Preview и т. п.).
        if let data = pb.data(forType: .tiff) ?? pb.data(forType: .png) {
            addImage(data)
            return
        }

        // 3. Обычный текст.
        if let text = pb.string(forType: .string), !text.isEmpty {
            addText(text)
        }
    }

    private func addText(_ text: String) {
        if let first = items.first, first.kind == .text, first.text == text { return }
        items.insert(ClipboardItem(kind: .text, text: text, imageData: nil, filePaths: nil, date: .now), at: 0)
        trim()
    }

    private func addImage(_ data: Data) {
        if let first = items.first, first.kind == .image, first.imageData == data { return }
        items.insert(ClipboardItem(kind: .image, text: nil, imageData: data, filePaths: nil, date: .now), at: 0)
        trim()
    }

    private func addFiles(_ paths: [String]) {
        if let first = items.first, first.kind == .file, first.filePaths == paths { return }
        items.insert(ClipboardItem(kind: .file, text: nil, imageData: nil, filePaths: paths, date: .now), at: 0)
        trim()
    }

    private func trim() {
        if items.count > maxItems { items.removeLast(items.count - maxItems) }
    }

    // MARK: - Actions

    /// Возвращает элемент в системный буфер обмена.
    func copyToClipboard(_ item: ClipboardItem) {
        let pb = NSPasteboard.general
        pb.clearContents()
        switch item.kind {
        case .text:
            if let text = item.text { pb.setString(text, forType: .string) }
        case .image:
            if let data = item.imageData { pb.setData(data, forType: .tiff) }
        case .file:
            if let paths = item.filePaths {
                let urls = paths.map { URL(fileURLWithPath: $0) as NSURL }
                pb.writeObjects(urls)
            }
        }
        // Не перехватываем собственную запись как новый элемент.
        lastChangeCount = pb.changeCount
    }

    func clear() {
        items.removeAll()
    }
}
