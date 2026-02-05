//
// DisplayShutterTests.swift
// DICOMKit
//
// Created by DICOMKit on 2026-02-05.
// Copyright © 2026 DICOMKit. All rights reserved.
//

import XCTest
import DICOMCore
@testable import DICOMKit

final class DisplayShutterTests: XCTestCase {
    
    // MARK: - Rectangular Shutter Tests
    
    func test_rectangularShutter_initialization() {
        let shutter = DisplayShutter.rectangular(
            left: 100,
            right: 400,
            top: 100,
            bottom: 400,
            presentationValue: 0
        )
        
        XCTAssertEqual(shutter.presentationValue, 0)
    }
    
    func test_rectangularShutter_contains_inside() {
        let shutter = DisplayShutter.rectangular(
            left: 100,
            right: 400,
            top: 100,
            bottom: 400,
            presentationValue: nil
        )
        
        // Point inside the shutter
        XCTAssertTrue(shutter.contains(column: 200, row: 200))
        XCTAssertTrue(shutter.contains(column: 100, row: 100))  // Top-left corner
        XCTAssertTrue(shutter.contains(column: 400, row: 400))  // Bottom-right corner
    }
    
    func test_rectangularShutter_contains_outside() {
        let shutter = DisplayShutter.rectangular(
            left: 100,
            right: 400,
            top: 100,
            bottom: 400,
            presentationValue: nil
        )
        
        // Points outside the shutter
        XCTAssertFalse(shutter.contains(column: 50, row: 200))   // Left
        XCTAssertFalse(shutter.contains(column: 450, row: 200))  // Right
        XCTAssertFalse(shutter.contains(column: 200, row: 50))   // Top
        XCTAssertFalse(shutter.contains(column: 200, row: 450))  // Bottom
    }
    
    // MARK: - Circular Shutter Tests
    
    func test_circularShutter_initialization() {
        let shutter = DisplayShutter.circular(
            centerColumn: 256,
            centerRow: 256,
            radius: 100,
            presentationValue: 0
        )
        
        XCTAssertEqual(shutter.presentationValue, 0)
    }
    
    func test_circularShutter_contains_center() {
        let shutter = DisplayShutter.circular(
            centerColumn: 256,
            centerRow: 256,
            radius: 100,
            presentationValue: nil
        )
        
        // Center point should be inside
        XCTAssertTrue(shutter.contains(column: 256, row: 256))
    }
    
    func test_circularShutter_contains_inside() {
        let shutter = DisplayShutter.circular(
            centerColumn: 256,
            centerRow: 256,
            radius: 100,
            presentationValue: nil
        )
        
        // Points clearly inside the circle
        XCTAssertTrue(shutter.contains(column: 256, row: 300))  // Vertically inside
        XCTAssertTrue(shutter.contains(column: 300, row: 256))  // Horizontally inside
    }
    
    func test_circularShutter_contains_onEdge() {
        let shutter = DisplayShutter.circular(
            centerColumn: 256,
            centerRow: 256,
            radius: 100,
            presentationValue: nil
        )
        
        // Point exactly on the edge (distance = radius)
        XCTAssertTrue(shutter.contains(column: 356, row: 256))  // Right edge
        XCTAssertTrue(shutter.contains(column: 156, row: 256))  // Left edge
    }
    
    func test_circularShutter_contains_outside() {
        let shutter = DisplayShutter.circular(
            centerColumn: 256,
            centerRow: 256,
            radius: 100,
            presentationValue: nil
        )
        
        // Points clearly outside the circle
        XCTAssertFalse(shutter.contains(column: 400, row: 256))
        XCTAssertFalse(shutter.contains(column: 256, row: 400))
        XCTAssertFalse(shutter.contains(column: 0, row: 0))
    }
    
    // MARK: - Polygonal Shutter Tests
    
    func test_polygonalShutter_initialization() {
        let vertices = [
            (column: 100, row: 100),
            (column: 200, row: 100),
            (column: 200, row: 200),
            (column: 100, row: 200)
        ]
        let shutter = DisplayShutter.polygonal(vertices: vertices, presentationValue: 0)
        
        XCTAssertEqual(shutter.presentationValue, 0)
    }
    
    func test_polygonalShutter_square_inside() {
        // Square polygon
        let vertices = [
            (column: 100, row: 100),
            (column: 200, row: 100),
            (column: 200, row: 200),
            (column: 100, row: 200)
        ]
        let shutter = DisplayShutter.polygonal(vertices: vertices, presentationValue: nil)
        
        // Point inside the square
        XCTAssertTrue(shutter.contains(column: 150, row: 150))
    }
    
    func test_polygonalShutter_square_outside() {
        // Square polygon
        let vertices = [
            (column: 100, row: 100),
            (column: 200, row: 100),
            (column: 200, row: 200),
            (column: 100, row: 200)
        ]
        let shutter = DisplayShutter.polygonal(vertices: vertices, presentationValue: nil)
        
        // Points outside the square
        XCTAssertFalse(shutter.contains(column: 50, row: 150))
        XCTAssertFalse(shutter.contains(column: 250, row: 150))
    }
    
    func test_polygonalShutter_triangle() {
        // Triangle polygon
        let vertices = [
            (column: 150, row: 100),  // Top
            (column: 200, row: 200),  // Bottom-right
            (column: 100, row: 200)   // Bottom-left
        ]
        let shutter = DisplayShutter.polygonal(vertices: vertices, presentationValue: nil)
        
        // Point inside the triangle
        XCTAssertTrue(shutter.contains(column: 150, row: 150))
        
        // Point outside the triangle
        XCTAssertFalse(shutter.contains(column: 150, row: 50))
    }
    
    func test_polygonalShutter_insufficientVertices() {
        // Less than 3 vertices
        let vertices = [
            (column: 100, row: 100),
            (column: 200, row: 100)
        ]
        let shutter = DisplayShutter.polygonal(vertices: vertices, presentationValue: nil)
        
        // Should return false for any point with < 3 vertices
        XCTAssertFalse(shutter.contains(column: 150, row: 150))
    }
    
    // MARK: - Bitmap Shutter Tests
    
    func test_bitmapShutter_initialization() {
        let shutter = DisplayShutter.bitmap(overlayGroup: 0x6000, presentationValue: 0)
        
        XCTAssertEqual(shutter.presentationValue, 0)
    }
    
    func test_bitmapShutter_contains() {
        let shutter = DisplayShutter.bitmap(overlayGroup: 0x6000, presentationValue: nil)
        
        // Bitmap shutter always returns false without overlay data
        XCTAssertFalse(shutter.contains(column: 100, row: 100))
        XCTAssertFalse(shutter.contains(column: 200, row: 200))
    }
    
    // MARK: - Equality and Hashable Tests
    
    func test_displayShutter_equality_rectangular() {
        let shutter1 = DisplayShutter.rectangular(left: 100, right: 400, top: 100, bottom: 400, presentationValue: 0)
        let shutter2 = DisplayShutter.rectangular(left: 100, right: 400, top: 100, bottom: 400, presentationValue: 0)
        let shutter3 = DisplayShutter.rectangular(left: 100, right: 400, top: 100, bottom: 400, presentationValue: nil)
        
        XCTAssertEqual(shutter1, shutter2)
        XCTAssertNotEqual(shutter1, shutter3)
    }
    
    func test_displayShutter_equality_circular() {
        let shutter1 = DisplayShutter.circular(centerColumn: 256, centerRow: 256, radius: 100, presentationValue: 0)
        let shutter2 = DisplayShutter.circular(centerColumn: 256, centerRow: 256, radius: 100, presentationValue: 0)
        let shutter3 = DisplayShutter.circular(centerColumn: 256, centerRow: 256, radius: 50, presentationValue: 0)
        
        XCTAssertEqual(shutter1, shutter2)
        XCTAssertNotEqual(shutter1, shutter3)
    }
    
    func test_displayShutter_equality_polygonal() {
        let vertices1 = [(column: 100, row: 100), (column: 200, row: 100), (column: 200, row: 200)]
        let vertices2 = [(column: 100, row: 100), (column: 200, row: 100), (column: 200, row: 200)]
        let vertices3 = [(column: 100, row: 100), (column: 200, row: 100), (column: 150, row: 200)]
        
        let shutter1 = DisplayShutter.polygonal(vertices: vertices1, presentationValue: 0)
        let shutter2 = DisplayShutter.polygonal(vertices: vertices2, presentationValue: 0)
        let shutter3 = DisplayShutter.polygonal(vertices: vertices3, presentationValue: 0)
        
        XCTAssertEqual(shutter1, shutter2)
        XCTAssertNotEqual(shutter1, shutter3)
    }
    
    func test_displayShutter_equality_bitmap() {
        let shutter1 = DisplayShutter.bitmap(overlayGroup: 0x6000, presentationValue: 0)
        let shutter2 = DisplayShutter.bitmap(overlayGroup: 0x6000, presentationValue: 0)
        let shutter3 = DisplayShutter.bitmap(overlayGroup: 0x6002, presentationValue: 0)
        
        XCTAssertEqual(shutter1, shutter2)
        XCTAssertNotEqual(shutter1, shutter3)
    }
    
    func test_displayShutter_equality_differentTypes() {
        let rectangular = DisplayShutter.rectangular(left: 100, right: 400, top: 100, bottom: 400, presentationValue: 0)
        let circular = DisplayShutter.circular(centerColumn: 256, centerRow: 256, radius: 100, presentationValue: 0)
        
        XCTAssertNotEqual(rectangular, circular)
    }
    
    func test_displayShutter_hashable() {
        let shutter1 = DisplayShutter.rectangular(left: 100, right: 400, top: 100, bottom: 400, presentationValue: 0)
        let shutter2 = DisplayShutter.rectangular(left: 100, right: 400, top: 100, bottom: 400, presentationValue: 0)
        let shutter3 = DisplayShutter.circular(centerColumn: 256, centerRow: 256, radius: 100, presentationValue: 0)
        
        let set: Set = [shutter1, shutter2, shutter3]
        XCTAssertEqual(set.count, 2)
    }
    
    // MARK: - ShutterShape Tests
    
    func test_shutterShape_rectangular() {
        XCTAssertEqual(ShutterShape.rectangular.rawValue, "RECTANGULAR")
    }
    
    func test_shutterShape_circular() {
        XCTAssertEqual(ShutterShape.circular.rawValue, "CIRCULAR")
    }
    
    func test_shutterShape_polygonal() {
        XCTAssertEqual(ShutterShape.polygonal.rawValue, "POLYGONAL")
    }
    
    func test_shutterShape_bitmap() {
        XCTAssertEqual(ShutterShape.bitmap.rawValue, "BITMAP")
    }
}
