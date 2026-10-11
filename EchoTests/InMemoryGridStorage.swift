import Foundation
@testable import Echo

/// Grid storage double: keeps the document in memory so no test touches the user's grid file.
@MainActor
final class InMemoryGridStorage: GridDocumentStoring {
    var document: GridDocument
    var loadError: GridStorageError?
    var saveError: GridStorageError?
    private(set) var saveCount = 0

    init(document: GridDocument = .empty, loadError: GridStorageError? = nil, saveError: GridStorageError? = nil) {
        self.document = document
        self.loadError = loadError
        self.saveError = saveError
    }

    func load() throws(GridStorageError) -> GridDocument {
        if let loadError { throw loadError }
        return document
    }

    func save(_ document: GridDocument) throws(GridStorageError) {
        saveCount += 1
        if let saveError { throw saveError }
        self.document = document
    }
}
