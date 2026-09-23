//
//  LocalizedKey.swift
//  Echo
//

import Foundation

/// A key into one String Catalog table. Each feature area owns one conforming enum and one table.
protocol LocalizedKey: RawRepresentable<String>, CaseIterable, Sendable {
    static var table: String { get }
}
