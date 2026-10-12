//
//  EdgeSnapResolver.swift
//  Echo
//

import CoreGraphics

enum EdgeSnapResolver {
    static let edgeThreshold: CGFloat = 4
    static let cornerSize: CGFloat = 120

    /// Layout for a cursor at `point` on a screen with `screenFrame`: corners -> quarters,
    /// top edge -> maximize, left/right -> halves, bottom -> bottom half; nil away from edges.
    static func layout(at point: CGPoint, in screenFrame: CGRect) -> WindowLayout? {
        let nearLeft = point.x <= screenFrame.minX + edgeThreshold
        let nearRight = point.x >= screenFrame.maxX - edgeThreshold
        let nearTop = point.y >= screenFrame.maxY - edgeThreshold
        let nearBottom = point.y <= screenFrame.minY + edgeThreshold

        let leftSide = point.x <= screenFrame.minX + cornerSize
        let rightSide = point.x >= screenFrame.maxX - cornerSize
        let topSide = point.y >= screenFrame.maxY - cornerSize
        let bottomSide = point.y <= screenFrame.minY + cornerSize

        if (nearTop && leftSide) || (nearLeft && topSide) { return .topLeft }
        if (nearTop && rightSide) || (nearRight && topSide) { return .topRight }
        if (nearBottom && leftSide) || (nearLeft && bottomSide) { return .bottomLeft }
        if (nearBottom && rightSide) || (nearRight && bottomSide) { return .bottomRight }
        if nearTop { return .maximize }
        if nearLeft { return .leftHalf }
        if nearRight { return .rightHalf }
        if nearBottom { return .bottomHalf }
        return nil
    }
}
