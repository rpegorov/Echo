//
//  GridTemplate.swift
//  Echo
//

import Foundation

/// Starting points for grids; zones are listed in reading order.
enum GridTemplate: String, Codable, CaseIterable, Sendable {
    case twoColumns, threeColumns, twoByTwo, mainAndSide, mainAndTwoSides

    /// Width-to-height ratio of the visible area from which a display counts as ultrawide.
    static let ultrawideAspect: Double = 2.0

    /// The grid a display gets until the user picks one.
    static func `default`(forAspect aspect: Double) -> GridTemplate {
        aspect >= ultrawideAspect ? .threeColumns : .twoColumns
    }

    var zones: [UnitRect] {
        let half = 0.5
        let third = 1.0 / 3
        let main = 0.6
        let side = 0.25
        switch self {
        case .twoColumns:
            return [UnitRect(x: 0, y: 0, width: half, height: 1),
                    UnitRect(x: half, y: 0, width: half, height: 1)]
        case .threeColumns:
            return [UnitRect(x: 0, y: 0, width: third, height: 1),
                    UnitRect(x: third, y: 0, width: third, height: 1),
                    UnitRect(x: 2 * third, y: 0, width: third, height: 1)]
        case .twoByTwo:
            return [UnitRect(x: 0, y: half, width: half, height: half),
                    UnitRect(x: half, y: half, width: half, height: half),
                    UnitRect(x: 0, y: 0, width: half, height: half),
                    UnitRect(x: half, y: 0, width: half, height: half)]
        case .mainAndSide:
            return [UnitRect(x: 0, y: 0, width: main, height: 1),
                    UnitRect(x: main, y: 0, width: 1 - main, height: 1)]
        case .mainAndTwoSides:
            return [UnitRect(x: 0, y: 0, width: side, height: 1),
                    UnitRect(x: side, y: 0, width: 1 - 2 * side, height: 1),
                    UnitRect(x: 1 - side, y: 0, width: side, height: 1)]
        }
    }

    var titleKey: InputKey {
        switch self {
        case .twoColumns:      return .gridTemplateTwoColumns
        case .threeColumns:    return .gridTemplateThreeColumns
        case .twoByTwo:        return .gridTemplateTwoByTwo
        case .mainAndSide:     return .gridTemplateMainAndSide
        case .mainAndTwoSides: return .gridTemplateMainAndTwoSides
        }
    }

    /// A new grid with this template's zones; `name` is the localized template title or the user's text.
    func makeGrid(named name: String) -> ZoneGrid {
        ZoneGrid(id: UUID(), name: name, zones: zones)
    }
}
