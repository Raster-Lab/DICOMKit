// Volume3DTests.swift
// DICOMViewer visionOS Tests - Volume3D Model Tests
//
// Copyright 2024 DICOMKit. All rights reserved.
// SPDX-License-Identifier: MIT

import Testing
import Foundation
@testable import DICOMViewer

@Suite("Volume3D Tests")
struct Volume3DTests {
    
    @Test("Volume initialization with valid data")
    func testVolumeInitialization() {
        let width = 256
        let height = 256
        let depth = 128
        let voxelCount = width * height * depth
        let voxelData = Array(repeating: UInt16(1000), count: voxelCount)
        
        let volume = Volume3D(
            width: width,
            height: height,
            depth: depth,
            voxelData: voxelData,
            minValue: 0,
            maxValue: 4095,
            spacing: [1.0, 1.0, 2.0],
            patientName: "Test Patient",
            modality: "CT"
        )
        
        #expect(volume.width == 256)
        #expect(volume.height == 256)
        #expect(volume.depth == 128)
        #expect(volume.voxelCount == voxelCount)
    }
    
    @Test("Voxel access within bounds")
    func testVoxelAccess() {
        let volume = createTestVolume()
        
        let voxel = volume.voxel(at: 0, y: 0, z: 0)
        #expect(voxel != nil)
    }
    
    @Test("Voxel access out of bounds returns nil")
    func testVoxelAccessOutOfBounds() {
        let volume = createTestVolume()
        
        let voxel = volume.voxel(at: 1000, y: 0, z: 0)
        #expect(voxel == nil)
    }
    
    @Test("Axial slice extraction")
    func testAxialSliceExtraction() {
        let volume = createTestVolume()
        
        let slice = volume.axialSlice(at: 0)
        #expect(slice != nil)
        #expect(slice?.orientation == .axial)
    }
    
    @Test("Physical dimensions calculation")
    func testPhysicalDimensions() {
        let volume = createTestVolume()
        
        #expect(volume.physicalWidth > 0)
        #expect(volume.physicalHeight > 0)
        #expect(volume.physicalDepth > 0)
    }
    
    // Helper
    private func createTestVolume() -> Volume3D {
        let width = 256, height = 256, depth = 128
        let voxelData = Array(repeating: UInt16(1000), count: width * height * depth)
        return Volume3D(
            width: width,
            height: height,
            depth: depth,
            voxelData: voxelData,
            minValue: 0,
            maxValue: 4095,
            spacing: [1.0, 1.0, 2.0],
            patientName: "Test",
            modality: "CT"
        )
    }
}
