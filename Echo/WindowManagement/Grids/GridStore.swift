//
//  GridStore.swift
//  Echo
//

import Foundation

/// Owns the grid document. A change is written first and published only after the write succeeded.
@MainActor
final class GridStore: ObservableObject, ActiveGridProviding {
    @Published private(set) var document: GridDocument
    /// Why saved grids could not be read at launch; nil when they loaded or none existed.
    @Published private(set) var loadError: GridStorageError?

    private let storage: any GridDocumentStoring

    init(storage: any GridDocumentStoring) {
        self.storage = storage
        do {
            document = try storage.load()
            loadError = nil
        } catch {
            document = .empty
            loadError = error
        }
    }

    /// Writes are allowed after a clean load, with no file, or once an unreadable file was moved aside.
    /// Any other load failure leaves the file on disk exactly as found.
    var isReadOnly: Bool {
        guard let loadError else { return false }
        if case .unreadable = loadError { return false }
        return true
    }

    /// The settings message for `loadError`; nil when grids loaded normally.
    var loadNotice: GridLoadNotice? {
        switch loadError {
        case .unreadable(let fileName)?: return .loadFailed(fileName: fileName)
        case .newerSchema?:              return .newerVersion
        case nil:                        return nil
        default:                         return .unavailable
        }
    }

    func activeZones(for display: DisplayKey?, aspect: Double) -> [UnitRect] {
        document.activeZones(for: display, aspect: aspect)
    }

    func save(_ grid: ZoneGrid) throws(GridStorageError) {
        try save(grid, activatingOn: nil)
    }

    /// Saves the grid and, when `display` is given, makes it that display's active grid in the same write.
    func save(_ grid: ZoneGrid, activatingOn display: DisplayKey?) throws(GridStorageError) {
        guard GridEditing.isValid(grid.zones) else { throw .invalidGrid }
        try commit {
            $0.save(grid)
            if let display { $0.setActive(.saved(id: grid.id), for: display) }
        }
    }

    func rename(_ id: UUID, to name: String) throws(GridStorageError) {
        try commit { $0.rename(id, to: name) }
    }

    func delete(_ id: UUID) throws(GridStorageError) {
        try commit { $0.delete(id) }
    }

    func setActive(_ ref: ActiveGridRef, for display: DisplayKey) throws(GridStorageError) {
        try commit { $0.setActive(ref, for: display) }
    }

    private func commit(_ change: (inout GridDocument) -> Void) throws(GridStorageError) {
        guard !isReadOnly else { throw .readOnly }
        var next = document
        change(&next)
        try storage.save(next)
        document = next
    }
}
