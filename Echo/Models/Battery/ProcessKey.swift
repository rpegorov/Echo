//
//  ProcessKey.swift
//  Echo
//

import Foundation

/// Identifies a process instance across samples: pid alone is reused by the OS,
/// so it is paired with the process's start time (`ri_proc_start_abstime`).
struct ProcessKey: Hashable {
    let pid: Int32
    let startAbstime: UInt64
}
