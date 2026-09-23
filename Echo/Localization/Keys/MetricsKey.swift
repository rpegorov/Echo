//
//  MetricsKey.swift
//  Echo
//

import Foundation

/// Strings for the metrics detail window (S1b owns further cases and the Metrics table).
enum MetricsKey: String, LocalizedKey {
    case tabCPU
    case tabMemory
    case tabNetwork
    case tabDisk
    case tabBattery

    case speedUnitKB
    case speedUnitMB

    case cpuTooltipValue
    case cpuCoresCount
    case ramTooltipValue
    case ramAxisGB
    case memoryUsageGB
    case diskUsageGB
    case diskUsageTB
    case networkTooltipTitle
    case networkDownloadValue
    case networkUploadValue
    case networkLegendDownload
    case networkLegendUpload

    case networkStatDownload
    case networkStatUpload
    case networkStatPeakDown
    case networkStatPeakUp
    case networkStatAvgDown
    case networkStatAvgUp

    case diskUsedPercent
    case diskStatUsed
    case diskStatFree
    case diskStatTotal
    case diskTopLargestFiles
    case diskCleanSystemButton
    case diskNoLargeFiles
    case diskShowInFinder
    case diskMoveToTrash
    case diskRevealHelp

    case moleTitle
    case moleDone
    case moleSearching
    case moleNotInstalledTitle
    case moleNotInstalledDescription
    case moleCopyCommandHelp
    case moleOpenOnGitHub
    case moleCheckAgain
    case molePreviewDryRun
    case moleRunInTerminal
    case moleDryRunExplanation
    case moleInteractiveExplanation

    case moleCleanTitle
    case moleCleanSubtitle
    case molePurgeTitle
    case molePurgeSubtitle
    case moleAnalyzeTitle
    case moleAnalyzeSubtitle
    case moleUninstallTitle
    case moleUninstallSubtitle

    case terminateProcessHelp

    case processValueCPU
    case processValueMemory
    case processValueEnergyShare

    static var table: String { "Metrics" }
}

extension MetricTab {
    /// Localized display name; `rawValue` stays a persisted identifier.
    var titleKey: MetricsKey {
        switch self {
        case .cpu:     return .tabCPU
        case .memory:  return .tabMemory
        case .network: return .tabNetwork
        case .disk:    return .tabDisk
        case .battery: return .tabBattery
        }
    }
}

extension MoleCommand {
    /// Localized display name; `rawValue` stays the `mole` CLI subcommand identifier.
    var titleKey: MetricsKey {
        switch self {
        case .clean:     return .moleCleanTitle
        case .purge:     return .molePurgeTitle
        case .analyze:   return .moleAnalyzeTitle
        case .uninstall: return .moleUninstallTitle
        }
    }

    var subtitleKey: MetricsKey {
        switch self {
        case .clean:     return .moleCleanSubtitle
        case .purge:     return .molePurgeSubtitle
        case .analyze:   return .moleAnalyzeSubtitle
        case .uninstall: return .moleUninstallSubtitle
        }
    }
}
