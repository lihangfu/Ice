//
//  MenuBarScreenGeometry.swift
//  Ice
//

import CoreGraphics

enum MenuBarScreenGeometry {
    static func screenIndex(at point: CGPoint, frames: [CGRect]) -> Int? {
        // A menu-bar click can be exactly on maxY. At a vertical seam, prefer
        // that menu bar over the bottom edge of the display above it.
        if let index = frames.firstIndex(where: {
            point.y == $0.maxY && point.x >= $0.minX && point.x < $0.maxX
        }) {
            return index
        }
        if let index = frames.firstIndex(where: { $0.contains(point) }) {
            return index
        }
        // Include an outer right edge only after resolving shared edges above.
        return frames.firstIndex {
            point.x >= $0.minX && point.x <= $0.maxX &&
            point.y >= $0.minY && point.y <= $0.maxY
        }
    }
}
