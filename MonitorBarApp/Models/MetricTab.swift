//
//  MetricTab.swift
//  MonitorBarApp
//

import SwiftUI

enum MetricTab: String, CaseIterable {
    case cpu     = "CPU"
    case memory  = "Memory"
    case network = "Network"
    case disk    = "Disk"

    var icon: String {
        switch self {
        case .cpu:     return "cpu"
        case .memory:  return "memorychip"
        case .network: return "network"
        case .disk:    return "externaldrive"
        }
    }
}
