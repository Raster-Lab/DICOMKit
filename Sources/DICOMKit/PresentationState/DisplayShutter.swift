//
// DisplayShutter.swift
// DICOMKit
//
// Created by DICOMKit on 2026-02-04.
// Copyright © 2026 DICOMKit. All rights reserved.
//

import Foundation
import DICOMCore

/// Display shutter for masking image regions
///
/// Shutters define areas of the image that should be masked (blacked out).
///
/// Reference: PS3.3 Section C.7.6.11 - Display Shutter Module
public enum DisplayShutter: Sendable, Hashable {
    /// Rectangular shutter
    case rectangular(left: Int, right: Int, top: Int, bottom: Int, presentationValue: Int?)
    
    /// Circular shutter
    case circular(centerColumn: Int, centerRow: Int, radius: Int, presentationValue: Int?)
    
    /// Polygonal shutter
    case polygonal(vertices: [(column: Int, row: Int)], presentationValue: Int?)
    
    /// Bitmap shutter (overlay group)
    case bitmap(overlayGroup: Int, presentationValue: Int?)
    
    /// Presentation value to use for shuttered area (grayscale value)
    public var presentationValue: Int? {
        switch self {
        case .rectangular(_, _, _, _, let value),
             .circular(_, _, _, let value),
             .polygonal(_, let value),
             .bitmap(_, let value):
            return value
        }
    }
    
    /// Check if a point is inside the shutter (should be masked)
    ///
    /// - Parameters:
    ///   - column: Column coordinate
    ///   - row: Row coordinate
    /// - Returns: true if the point is inside the shutter (should be masked)
    public func contains(column: Int, row: Int) -> Bool {
        switch self {
        case .rectangular(let left, let right, let top, let bottom, _):
            // Inside if within bounds
            return column >= left && column <= right && row >= top && row <= bottom
            
        case .circular(let centerColumn, let centerRow, let radius, _):
            // Inside if distance from center is less than radius
            let dx = Double(column - centerColumn)
            let dy = Double(row - centerRow)
            let distance = sqrt(dx * dx + dy * dy)
            return distance <= Double(radius)
            
        case .polygonal(let vertices, _):
            // Use ray casting algorithm to determine if point is inside polygon
            return isPointInPolygon(column: column, row: row, vertices: vertices)
            
        case .bitmap:
            // Bitmap shutter requires overlay data to determine
            // This would need to be evaluated with the actual overlay
            return false
        }
    }
    
    /// Ray casting algorithm to determine if a point is inside a polygon
    private func isPointInPolygon(column: Int, row: Int, vertices: [(column: Int, row: Int)]) -> Bool {
        guard vertices.count >= 3 else {
            return false
        }
        
        var inside = false
        let x = Double(column)
        let y = Double(row)
        
        var j = vertices.count - 1
        for i in 0..<vertices.count {
            let xi = Double(vertices[i].column)
            let yi = Double(vertices[i].row)
            let xj = Double(vertices[j].column)
            let yj = Double(vertices[j].row)
            
            let intersect = ((yi > y) != (yj > y)) &&
                           (x < (xj - xi) * (y - yi) / (yj - yi) + xi)
            
            if intersect {
                inside.toggle()
            }
            
            j = i
        }
        
        return inside
    }
}

// MARK: - Hashable conformance for vertex tuples

extension DisplayShutter {
    public static func == (lhs: DisplayShutter, rhs: DisplayShutter) -> Bool {
        switch (lhs, rhs) {
        case (.rectangular(let l1, let r1, let t1, let b1, let v1),
              .rectangular(let l2, let r2, let t2, let b2, let v2)):
            return l1 == l2 && r1 == r2 && t1 == t2 && b1 == b2 && v1 == v2
            
        case (.circular(let c1, let r1, let rad1, let v1),
              .circular(let c2, let r2, let rad2, let v2)):
            return c1 == c2 && r1 == r2 && rad1 == rad2 && v1 == v2
            
        case (.polygonal(let v1, let pv1), .polygonal(let v2, let pv2)):
            guard v1.count == v2.count && pv1 == pv2 else {
                return false
            }
            for i in 0..<v1.count {
                if v1[i].column != v2[i].column || v1[i].row != v2[i].row {
                    return false
                }
            }
            return true
            
        case (.bitmap(let g1, let v1), .bitmap(let g2, let v2)):
            return g1 == g2 && v1 == v2
            
        default:
            return false
        }
    }
    
    public func hash(into hasher: inout Hasher) {
        switch self {
        case .rectangular(let left, let right, let top, let bottom, let value):
            hasher.combine("rectangular")
            hasher.combine(left)
            hasher.combine(right)
            hasher.combine(top)
            hasher.combine(bottom)
            hasher.combine(value)
            
        case .circular(let centerColumn, let centerRow, let radius, let value):
            hasher.combine("circular")
            hasher.combine(centerColumn)
            hasher.combine(centerRow)
            hasher.combine(radius)
            hasher.combine(value)
            
        case .polygonal(let vertices, let value):
            hasher.combine("polygonal")
            for vertex in vertices {
                hasher.combine(vertex.column)
                hasher.combine(vertex.row)
            }
            hasher.combine(value)
            
        case .bitmap(let overlayGroup, let value):
            hasher.combine("bitmap")
            hasher.combine(overlayGroup)
            hasher.combine(value)
        }
    }
}

/// Shutter shape enumeration
///
/// Used in the Shutter Shape (0018,1600) element.
public enum ShutterShape: String, Sendable, Hashable {
    /// Rectangular shutter
    case rectangular = "RECTANGULAR"
    
    /// Circular shutter
    case circular = "CIRCULAR"
    
    /// Polygonal shutter
    case polygonal = "POLYGONAL"
    
    /// Bitmap shutter
    case bitmap = "BITMAP"
}
