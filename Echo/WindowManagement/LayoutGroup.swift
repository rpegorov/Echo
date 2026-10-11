//
//  LayoutGroup.swift
//  Echo
//

/// Families of layouts shown together on the zone map in Preferences.
enum LayoutGroup: CaseIterable, Sendable {
    case halves, verticalHalves, quarters, thirds, twoThirds, centerAndFull

    var layouts: [WindowLayout] { WindowLayout.allCases.filter { $0.group == self } }

    /// Zones of these groups overlap, so each zone needs its own screen drawing.
    var hasOverlap: Bool { self == .twoThirds || self == .centerAndFull }

    var titleKey: InputKey {
        switch self {
        case .halves:         return .zoneGroupHalves
        case .verticalHalves: return .zoneGroupVerticalHalves
        case .quarters:       return .zoneGroupQuarters
        case .thirds:         return .zoneGroupThirds
        case .twoThirds:      return .zoneGroupTwoThirds
        case .centerAndFull:  return .zoneGroupCenterAndFull
        }
    }
}
