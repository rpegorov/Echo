//
//  GridFileStorage.swift
//  Echo
//

import Foundation

enum GridStorageError: Error, Equatable {
    case locationUnavailable
    /// The file could not be parsed; it was moved aside and the payload is the backup's file name.
    case unreadable(String)
    /// The file was written by a newer Echo and is left untouched.
    case newerSchema(Int)
    /// The file exists but its bytes could not be read.
    case readFailed(String)
    case readOnly
    case writeFailed(String)
    /// The grid's zones overlap, leave gaps or break the canonical order; nothing was written.
    case invalidGrid
}

/// Disk side of `GridStore`. `load` returns `.empty` when nothing was saved yet.
@MainActor
protocol GridDocumentStoring {
    func load() throws(GridStorageError) -> GridDocument
    func save(_ document: GridDocument) throws(GridStorageError)
}

/// `window-zones.json` in the app's Application Support folder, replaced atomically on every save.
struct GridFileStorage: GridDocumentStoring {
    static let schemaVersion = 1
    static let fileName = "window-zones.json"
    static let backupPrefix = "window-zones.corrupt-"
    static let backupSuffix = ".json"
    private static let backupStampFormat = "yyyyMMdd-HHmmss"

    let fileURL: URL
    /// Names the backup of an unreadable file.
    let now: () -> Date

    init(fileURL: URL, now: @escaping () -> Date = Date.init) {
        self.fileURL = fileURL
        self.now = now
    }

    static func defaultURL() throws(GridStorageError) -> URL {
        let fileManager = FileManager.default
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw .locationUnavailable
        }
        let directory = appSupport.appendingPathComponent(Bundle.main.bundleIdentifier ?? "Echo", isDirectory: true)
        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            throw .writeFailed(error.localizedDescription)
        }
        return directory.appendingPathComponent(fileName, isDirectory: false)
    }

    /// The schema version is read before the document, so a newer file is never judged by this version's shape.
    func load() throws(GridStorageError) -> GridDocument {
        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile && !isDanglingSymbolicLink {
            return .empty
        } catch {
            throw .readFailed(error.localizedDescription)
        }
        let version: Int
        do {
            version = try JSONDecoder().decode(SchemaProbe.self, from: data).schemaVersion
        } catch {
            throw setAsideUnreadableFile()
        }
        guard version <= Self.schemaVersion else { throw .newerSchema(version) }
        do {
            return try JSONDecoder().decode(GridFileEnvelope.self, from: data).document
        } catch {
            throw setAsideUnreadableFile()
        }
    }

    func save(_ document: GridDocument) throws(GridStorageError) {
        do {
            let envelope = GridFileEnvelope(schemaVersion: Self.schemaVersion, document: document)
            try JSONEncoder().encode(envelope).write(to: fileURL, options: .atomic)
        } catch {
            throw .writeFailed(error.localizedDescription)
        }
    }

    /// A link to a missing target is a file Echo cannot replace, not an absent file.
    private var isDanglingSymbolicLink: Bool {
        do {
            _ = try FileManager.default.destinationOfSymbolicLink(atPath: fileURL.path)
            return true
        } catch {
            return false
        }
    }

    /// `.unreadable` once the file is moved aside, `.writeFailed` when the move fails and the file stays.
    private func setAsideUnreadableFile() -> GridStorageError {
        let backupName = Self.backupPrefix + backupStamp() + Self.backupSuffix
        let backupURL = fileURL.deletingLastPathComponent().appendingPathComponent(backupName, isDirectory: false)
        do {
            try FileManager.default.moveItem(at: fileURL, to: backupURL)
            return .unreadable(backupName)
        } catch {
            return .writeFailed(error.localizedDescription)
        }
    }

    private func backupStamp() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = Self.backupStampFormat
        return formatter.string(from: now())
    }
}

struct GridFileEnvelope: Codable {
    let schemaVersion: Int
    let document: GridDocument
}

private struct SchemaProbe: Decodable {
    let schemaVersion: Int
}

/// Used when Application Support cannot be resolved: grids work in memory and every save reports why.
struct UnavailableGridStorage: GridDocumentStoring {
    let error: GridStorageError

    func load() throws(GridStorageError) -> GridDocument { throw error }
    func save(_ document: GridDocument) throws(GridStorageError) { throw error }
}
