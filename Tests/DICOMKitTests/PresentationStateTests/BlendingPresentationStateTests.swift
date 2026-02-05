//
// BlendingPresentationStateTests.swift
// DICOMKit
//
// Created by DICOMKit on 2026-02-05.
// Copyright © 2026 DICOMKit. All rights reserved.
//

import XCTest
import DICOMCore
@testable import DICOMKit

final class BlendingPresentationStateTests: XCTestCase {
    
    // MARK: - BlendingMode Tests
    
    func test_blendingMode_alpha() {
        let mode = BlendingMode.alpha
        XCTAssertEqual(mode.rawValue, "ALPHA")
    }
    
    func test_blendingMode_maximumIntensity() {
        let mode = BlendingMode.maximumIntensity
        XCTAssertEqual(mode.rawValue, "MIP")
    }
    
    func test_blendingMode_minimumIntensity() {
        let mode = BlendingMode.minimumIntensity
        XCTAssertEqual(mode.rawValue, "MinIP")
    }
    
    func test_blendingMode_average() {
        let mode = BlendingMode.average
        XCTAssertEqual(mode.rawValue, "AVERAGE")
    }
    
    func test_blendingMode_additive() {
        let mode = BlendingMode.additive
        XCTAssertEqual(mode.rawValue, "ADD")
    }
    
    func test_blendingMode_subtractive() {
        let mode = BlendingMode.subtractive
        XCTAssertEqual(mode.rawValue, "SUBTRACT")
    }
    
    func test_blendingMode_allCases() {
        let allCases = BlendingMode.allCases
        XCTAssertEqual(allCases.count, 6)
        XCTAssertTrue(allCases.contains(.alpha))
        XCTAssertTrue(allCases.contains(.maximumIntensity))
        XCTAssertTrue(allCases.contains(.minimumIntensity))
        XCTAssertTrue(allCases.contains(.average))
        XCTAssertTrue(allCases.contains(.additive))
        XCTAssertTrue(allCases.contains(.subtractive))
    }
    
    func test_blendingMode_hashable() {
        let mode1 = BlendingMode.alpha
        let mode2 = BlendingMode.alpha
        let mode3 = BlendingMode.maximumIntensity
        
        XCTAssertEqual(mode1, mode2)
        XCTAssertNotEqual(mode1, mode3)
        
        let set: Set = [mode1, mode2, mode3]
        XCTAssertEqual(set.count, 2)
    }
    
    // MARK: - ReferencedImageForBlending Tests
    
    func test_referencedImageForBlending_minimal() {
        let refImage = ReferencedImageForBlending(sopInstanceUID: "1.2.3.4.5")
        
        XCTAssertEqual(refImage.sopInstanceUID, "1.2.3.4.5")
        XCTAssertNil(refImage.frameNumber)
        XCTAssertNil(refImage.presentationStateUID)
    }
    
    func test_referencedImageForBlending_withFrameNumber() {
        let refImage = ReferencedImageForBlending(
            sopInstanceUID: "1.2.3.4.5",
            frameNumber: 3
        )
        
        XCTAssertEqual(refImage.sopInstanceUID, "1.2.3.4.5")
        XCTAssertEqual(refImage.frameNumber, 3)
        XCTAssertNil(refImage.presentationStateUID)
    }
    
    func test_referencedImageForBlending_withPresentationState() {
        let refImage = ReferencedImageForBlending(
            sopInstanceUID: "1.2.3.4.5",
            presentationStateUID: "1.2.3.4.5.6"
        )
        
        XCTAssertEqual(refImage.sopInstanceUID, "1.2.3.4.5")
        XCTAssertEqual(refImage.presentationStateUID, "1.2.3.4.5.6")
        XCTAssertNil(refImage.frameNumber)
    }
    
    func test_referencedImageForBlending_complete() {
        let refImage = ReferencedImageForBlending(
            sopInstanceUID: "1.2.3.4.5",
            frameNumber: 2,
            presentationStateUID: "1.2.3.4.5.6"
        )
        
        XCTAssertEqual(refImage.sopInstanceUID, "1.2.3.4.5")
        XCTAssertEqual(refImage.frameNumber, 2)
        XCTAssertEqual(refImage.presentationStateUID, "1.2.3.4.5.6")
    }
    
    func test_referencedImageForBlending_hashable() {
        let ref1 = ReferencedImageForBlending(sopInstanceUID: "1.2.3.4.5")
        let ref2 = ReferencedImageForBlending(sopInstanceUID: "1.2.3.4.5")
        let ref3 = ReferencedImageForBlending(sopInstanceUID: "1.2.3.4.6")
        
        XCTAssertEqual(ref1, ref2)
        XCTAssertNotEqual(ref1, ref3)
        
        let set: Set = [ref1, ref2, ref3]
        XCTAssertEqual(set.count, 2)
    }
    
    func test_referencedImageForBlending_multipleFrames() {
        let refs = (1...5).map { frameNum in
            ReferencedImageForBlending(
                sopInstanceUID: "1.2.3.4.5",
                frameNumber: frameNum
            )
        }
        
        XCTAssertEqual(refs.count, 5)
        XCTAssertEqual(refs[2].frameNumber, 3)
    }
    
    // MARK: - BlendingDisplaySet Tests
    
    func test_blendingDisplaySet_minimal() {
        let refImage = ReferencedImageForBlending(sopInstanceUID: "1.2.3.4.5")
        let displaySet = BlendingDisplaySet(
            displaySetNumber: 1,
            referencedImages: [refImage],
            relativeOpacities: [1.0]
        )
        
        XCTAssertEqual(displaySet.displaySetNumber, 1)
        XCTAssertEqual(displaySet.referencedImages.count, 1)
        XCTAssertEqual(displaySet.blendingMode, .alpha)
        XCTAssertEqual(displaySet.relativeOpacities.count, 1)
        XCTAssertEqual(displaySet.relativeOpacities[0], 1.0)
    }
    
    func test_blendingDisplaySet_withBlendingMode() {
        let refImage = ReferencedImageForBlending(sopInstanceUID: "1.2.3.4.5")
        let displaySet = BlendingDisplaySet(
            displaySetNumber: 2,
            referencedImages: [refImage],
            blendingMode: .maximumIntensity,
            relativeOpacities: [1.0]
        )
        
        XCTAssertEqual(displaySet.blendingMode, .maximumIntensity)
    }
    
    func test_blendingDisplaySet_twoImages() {
        let ref1 = ReferencedImageForBlending(sopInstanceUID: "1.2.3.4.5")
        let ref2 = ReferencedImageForBlending(sopInstanceUID: "1.2.3.4.6")
        let displaySet = BlendingDisplaySet(
            displaySetNumber: 1,
            referencedImages: [ref1, ref2],
            blendingMode: .alpha,
            relativeOpacities: [0.5, 0.5]
        )
        
        XCTAssertEqual(displaySet.referencedImages.count, 2)
        XCTAssertEqual(displaySet.relativeOpacities.count, 2)
        XCTAssertEqual(displaySet.relativeOpacities[0], 0.5)
        XCTAssertEqual(displaySet.relativeOpacities[1], 0.5)
    }
    
    func test_blendingDisplaySet_multipleImages() {
        let refs = (1...3).map { i in
            ReferencedImageForBlending(sopInstanceUID: "1.2.3.4.\(i)")
        }
        let displaySet = BlendingDisplaySet(
            displaySetNumber: 1,
            referencedImages: refs,
            blendingMode: .average,
            relativeOpacities: [0.33, 0.33, 0.34]
        )
        
        XCTAssertEqual(displaySet.referencedImages.count, 3)
        XCTAssertEqual(displaySet.relativeOpacities.count, 3)
        XCTAssertEqual(
            abs(displaySet.relativeOpacities.reduce(0, +) - 1.0),
            0,
            accuracy: 0.01
        )
    }
    
    func test_blendingDisplaySet_allBlendingModes() {
        let refImage = ReferencedImageForBlending(sopInstanceUID: "1.2.3.4.5")
        
        for mode in BlendingMode.allCases {
            let displaySet = BlendingDisplaySet(
                displaySetNumber: 1,
                referencedImages: [refImage],
                blendingMode: mode,
                relativeOpacities: [1.0]
            )
            
            XCTAssertEqual(displaySet.blendingMode, mode)
        }
    }
    
    func test_blendingDisplaySet_withPresentationStates() {
        let ref1 = ReferencedImageForBlending(
            sopInstanceUID: "1.2.3.4.5",
            presentationStateUID: "1.2.3.4.5.6"
        )
        let ref2 = ReferencedImageForBlending(
            sopInstanceUID: "1.2.3.4.6",
            presentationStateUID: "1.2.3.4.6.7"
        )
        let displaySet = BlendingDisplaySet(
            displaySetNumber: 1,
            referencedImages: [ref1, ref2],
            blendingMode: .alpha,
            relativeOpacities: [0.5, 0.5]
        )
        
        XCTAssertEqual(displaySet.referencedImages[0].presentationStateUID, "1.2.3.4.5.6")
        XCTAssertEqual(displaySet.referencedImages[1].presentationStateUID, "1.2.3.4.6.7")
    }
    
    func test_blendingDisplaySet_hashable() {
        let ref = ReferencedImageForBlending(sopInstanceUID: "1.2.3.4.5")
        let set1 = BlendingDisplaySet(
            displaySetNumber: 1,
            referencedImages: [ref],
            relativeOpacities: [1.0]
        )
        let set2 = BlendingDisplaySet(
            displaySetNumber: 1,
            referencedImages: [ref],
            relativeOpacities: [1.0]
        )
        let set3 = BlendingDisplaySet(
            displaySetNumber: 2,
            referencedImages: [ref],
            relativeOpacities: [1.0]
        )
        
        XCTAssertEqual(set1, set2)
        XCTAssertNotEqual(set1, set3)
        
        let hashSet: Set = [set1, set2, set3]
        XCTAssertEqual(hashSet.count, 2)
    }
    
    // MARK: - BlendingPresentationState Tests
    
    func test_blendingPresentationState_minimal() {
        let image = ReferencedImage(
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            sopInstanceUID: "1.2.3.4.5"
        )
        let series = ReferencedSeries(
            seriesInstanceUID: "1.2.3.4",
            referencedImages: [image]
        )
        let refImage = ReferencedImageForBlending(sopInstanceUID: "1.2.3.4.5")
        let displaySet = BlendingDisplaySet(
            displaySetNumber: 1,
            referencedImages: [refImage],
            relativeOpacities: [1.0]
        )
        
        let ps = BlendingPresentationState(
            sopInstanceUID: "1.2.3.4.5.6",
            referencedSeries: [series],
            blendingDisplaySets: [displaySet]
        )
        
        XCTAssertEqual(ps.sopInstanceUID, "1.2.3.4.5.6")
        XCTAssertEqual(ps.sopClassUID, "1.2.840.10008.5.1.4.1.1.11.4")
        XCTAssertEqual(ps.referencedSeries.count, 1)
        XCTAssertEqual(ps.blendingDisplaySets.count, 1)
        XCTAssertNil(ps.spatialTransformation)
        XCTAssertNil(ps.displayedArea)
        XCTAssertTrue(ps.graphicLayers.isEmpty)
        XCTAssertTrue(ps.graphicAnnotations.isEmpty)
        XCTAssertTrue(ps.shutters.isEmpty)
    }
    
    func test_blendingPresentationState_withIdentificationInfo() {
        let image = ReferencedImage(
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            sopInstanceUID: "1.2.3.4.5"
        )
        let series = ReferencedSeries(
            seriesInstanceUID: "1.2.3.4",
            referencedImages: [image]
        )
        let refImage = ReferencedImageForBlending(sopInstanceUID: "1.2.3.4.5")
        let displaySet = BlendingDisplaySet(
            displaySetNumber: 1,
            referencedImages: [refImage],
            relativeOpacities: [1.0]
        )
        
        let ps = BlendingPresentationState(
            sopInstanceUID: "1.2.3.4.5.6",
            instanceNumber: 1,
            presentationLabel: "PET/CT Blend",
            presentationDescription: "PET and CT blended image",
            referencedSeries: [series],
            blendingDisplaySets: [displaySet]
        )
        
        XCTAssertEqual(ps.instanceNumber, 1)
        XCTAssertEqual(ps.presentationLabel, "PET/CT Blend")
        XCTAssertEqual(ps.presentationDescription, "PET and CT blended image")
    }
    
    func test_blendingPresentationState_petCtBlending() {
        let ctImage = ReferencedImage(
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            sopInstanceUID: "1.2.3.4.5"
        )
        let petImage = ReferencedImage(
            sopClassUID: "1.2.840.10008.5.1.4.1.1.128.1",
            sopInstanceUID: "1.2.3.4.6"
        )
        let series = ReferencedSeries(
            seriesInstanceUID: "1.2.3.4",
            referencedImages: [ctImage, petImage]
        )
        
        let ctRef = ReferencedImageForBlending(sopInstanceUID: "1.2.3.4.5")
        let petRef = ReferencedImageForBlending(sopInstanceUID: "1.2.3.4.6")
        let displaySet = BlendingDisplaySet(
            displaySetNumber: 1,
            referencedImages: [ctRef, petRef],
            blendingMode: .alpha,
            relativeOpacities: [0.6, 0.4]
        )
        
        let ps = BlendingPresentationState(
            sopInstanceUID: "1.2.3.4.5.6",
            referencedSeries: [series],
            blendingDisplaySets: [displaySet]
        )
        
        XCTAssertEqual(ps.blendingDisplaySets[0].referencedImages.count, 2)
        XCTAssertEqual(ps.blendingDisplaySets[0].relativeOpacities[0], 0.6)
        XCTAssertEqual(ps.blendingDisplaySets[0].relativeOpacities[1], 0.4)
    }
    
    func test_blendingPresentationState_maximumIntensityProjection() {
        let refImages = (1...3).map { i in
            ReferencedImageForBlending(
                sopInstanceUID: "1.2.3.4.\(String(i))",
                frameNumber: i
            )
        }
        let image = ReferencedImage(
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            sopInstanceUID: "1.2.3.4.5"
        )
        let series = ReferencedSeries(
            seriesInstanceUID: "1.2.3.4",
            referencedImages: [image]
        )
        let displaySet = BlendingDisplaySet(
            displaySetNumber: 1,
            referencedImages: refImages,
            blendingMode: .maximumIntensity,
            relativeOpacities: [1.0, 1.0, 1.0]
        )
        
        let ps = BlendingPresentationState(
            sopInstanceUID: "1.2.3.4.5.6",
            presentationLabel: "MIP Reconstruction",
            referencedSeries: [series],
            blendingDisplaySets: [displaySet]
        )
        
        XCTAssertEqual(ps.blendingDisplaySets[0].blendingMode, .maximumIntensity)
        XCTAssertEqual(ps.blendingDisplaySets[0].referencedImages.count, 3)
    }
    
    func test_blendingPresentationState_withSpatialTransformation() {
        let image = ReferencedImage(
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            sopInstanceUID: "1.2.3.4.5"
        )
        let series = ReferencedSeries(
            seriesInstanceUID: "1.2.3.4",
            referencedImages: [image]
        )
        let refImage = ReferencedImageForBlending(sopInstanceUID: "1.2.3.4.5")
        let displaySet = BlendingDisplaySet(
            displaySetNumber: 1,
            referencedImages: [refImage],
            relativeOpacities: [1.0]
        )
        let transform = SpatialTransformation(rotation: 180)
        
        let ps = BlendingPresentationState(
            sopInstanceUID: "1.2.3.4.5.6",
            referencedSeries: [series],
            blendingDisplaySets: [displaySet],
            spatialTransformation: transform
        )
        
        XCTAssertNotNil(ps.spatialTransformation)
        XCTAssertEqual(ps.spatialTransformation?.rotation, 180)
    }
    
    func test_blendingPresentationState_withGraphicLayers() {
        let image = ReferencedImage(
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            sopInstanceUID: "1.2.3.4.5"
        )
        let series = ReferencedSeries(
            seriesInstanceUID: "1.2.3.4",
            referencedImages: [image]
        )
        let refImage = ReferencedImageForBlending(sopInstanceUID: "1.2.3.4.5")
        let displaySet = BlendingDisplaySet(
            displaySetNumber: 1,
            referencedImages: [refImage],
            relativeOpacities: [1.0]
        )
        let layer = GraphicLayer(
            name: "Fusion Markers",
            order: 1,
            description: "Markers for fusion verification"
        )
        
        let ps = BlendingPresentationState(
            sopInstanceUID: "1.2.3.4.5.6",
            referencedSeries: [series],
            blendingDisplaySets: [displaySet],
            graphicLayers: [layer]
        )
        
        XCTAssertEqual(ps.graphicLayers.count, 1)
        XCTAssertEqual(ps.graphicLayers[0].name, "Fusion Markers")
    }
    
    func test_blendingPresentationState_withGraphicAnnotations() {
        let image = ReferencedImage(
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            sopInstanceUID: "1.2.3.4.5"
        )
        let series = ReferencedSeries(
            seriesInstanceUID: "1.2.3.4",
            referencedImages: [image]
        )
        let refImage = ReferencedImageForBlending(sopInstanceUID: "1.2.3.4.5")
        let displaySet = BlendingDisplaySet(
            displaySetNumber: 1,
            referencedImages: [refImage],
            relativeOpacities: [1.0]
        )
        let text = TextObject(
            text: "Tumor Site",
            boundingBoxTopLeft: (column: 100.0, row: 100.0),
            boundingBoxBottomRight: (column: 200.0, row: 120.0),
            anchorPoint: (column: 150.0, row: 110.0),
            anchorPointVisible: true
        )
        let annotation = GraphicAnnotation(
            layer: "Fusion Markers",
            referencedImages: [image],
            textObjects: [text]
        )
        
        let ps = BlendingPresentationState(
            sopInstanceUID: "1.2.3.4.5.6",
            referencedSeries: [series],
            blendingDisplaySets: [displaySet],
            graphicAnnotations: [annotation]
        )
        
        XCTAssertEqual(ps.graphicAnnotations.count, 1)
        XCTAssertEqual(ps.graphicAnnotations[0].textObjects.count, 1)
    }
    
    func test_blendingPresentationState_withShutters() {
        let image = ReferencedImage(
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            sopInstanceUID: "1.2.3.4.5"
        )
        let series = ReferencedSeries(
            seriesInstanceUID: "1.2.3.4",
            referencedImages: [image]
        )
        let refImage = ReferencedImageForBlending(sopInstanceUID: "1.2.3.4.5")
        let displaySet = BlendingDisplaySet(
            displaySetNumber: 1,
            referencedImages: [refImage],
            relativeOpacities: [1.0]
        )
        let shutter = DisplayShutter.circular(
            centerColumn: 256, centerRow: 256, radius: 200,
            presentationValue: 0
        )
        
        let ps = BlendingPresentationState(
            sopInstanceUID: "1.2.3.4.5.6",
            referencedSeries: [series],
            blendingDisplaySets: [displaySet],
            shutters: [shutter]
        )
        
        XCTAssertEqual(ps.shutters.count, 1)
    }
    
    func test_blendingPresentationState_multipleDisplaySets() {
        let image = ReferencedImage(
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            sopInstanceUID: "1.2.3.4.5"
        )
        let series = ReferencedSeries(
            seriesInstanceUID: "1.2.3.4",
            referencedImages: [image]
        )
        
        let displaySets = (1...3).map { setNum in
            let refImage = ReferencedImageForBlending(
                sopInstanceUID: "1.2.3.4.\(setNum + 10)"
            )
            return BlendingDisplaySet(
                displaySetNumber: setNum,
                referencedImages: [refImage],
                relativeOpacities: [1.0]
            )
        }
        
        let ps = BlendingPresentationState(
            sopInstanceUID: "1.2.3.4.5.6",
            referencedSeries: [series],
            blendingDisplaySets: displaySets
        )
        
        XCTAssertEqual(ps.blendingDisplaySets.count, 3)
        XCTAssertEqual(ps.blendingDisplaySets[1].displaySetNumber, 2)
    }
    
    func test_blendingPresentationState_withAllComponents() {
        let image = ReferencedImage(
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            sopInstanceUID: "1.2.3.4.5"
        )
        let series = ReferencedSeries(
            seriesInstanceUID: "1.2.3.4",
            referencedImages: [image]
        )
        let refImage = ReferencedImageForBlending(sopInstanceUID: "1.2.3.4.5")
        let displaySet = BlendingDisplaySet(
            displaySetNumber: 1,
            referencedImages: [refImage],
            blendingMode: .alpha,
            relativeOpacities: [1.0]
        )
        let transform = SpatialTransformation(rotation: 90)
        let layer = GraphicLayer(name: "Annotations", order: 1)
        let annotation = GraphicAnnotation(layer: "Annotations", referencedImages: [image])
        let shutter = DisplayShutter.rectangular(
            left: 0, right: 512, top: 0, bottom: 512,
            presentationValue: 0
        )
        
        let ps = BlendingPresentationState(
            sopInstanceUID: "1.2.3.4.5.6",
            instanceNumber: 1,
            presentationLabel: "Full Blending State",
            presentationDescription: "Complete blending presentation",
            referencedSeries: [series],
            blendingDisplaySets: [displaySet],
            spatialTransformation: transform,
            graphicLayers: [layer],
            graphicAnnotations: [annotation],
            shutters: [shutter]
        )
        
        XCTAssertEqual(ps.blendingDisplaySets.count, 1)
        XCTAssertNotNil(ps.spatialTransformation)
        XCTAssertEqual(ps.graphicLayers.count, 1)
        XCTAssertEqual(ps.graphicAnnotations.count, 1)
        XCTAssertEqual(ps.shutters.count, 1)
        XCTAssertEqual(ps.instanceNumber, 1)
        XCTAssertEqual(ps.presentationLabel, "Full Blending State")
    }
    
    func test_blendingPresentationState_averageBlending() {
        let refs = (1...4).map { i in
            ReferencedImageForBlending(sopInstanceUID: "1.2.3.4.\(i)")
        }
        let image = ReferencedImage(
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            sopInstanceUID: "1.2.3.4.5"
        )
        let series = ReferencedSeries(
            seriesInstanceUID: "1.2.3.4",
            referencedImages: [image]
        )
        let displaySet = BlendingDisplaySet(
            displaySetNumber: 1,
            referencedImages: refs,
            blendingMode: .average,
            relativeOpacities: [0.25, 0.25, 0.25, 0.25]
        )
        
        let ps = BlendingPresentationState(
            sopInstanceUID: "1.2.3.4.5.6",
            referencedSeries: [series],
            blendingDisplaySets: [displaySet]
        )
        
        XCTAssertEqual(ps.blendingDisplaySets[0].blendingMode, .average)
        XCTAssertEqual(ps.blendingDisplaySets[0].referencedImages.count, 4)
    }
    
    func test_blendingPresentationState_additiveBlending() {
        let ref1 = ReferencedImageForBlending(sopInstanceUID: "1.2.3.4.5")
        let ref2 = ReferencedImageForBlending(sopInstanceUID: "1.2.3.4.6")
        let image = ReferencedImage(
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            sopInstanceUID: "1.2.3.4.5"
        )
        let series = ReferencedSeries(
            seriesInstanceUID: "1.2.3.4",
            referencedImages: [image]
        )
        let displaySet = BlendingDisplaySet(
            displaySetNumber: 1,
            referencedImages: [ref1, ref2],
            blendingMode: .additive,
            relativeOpacities: [0.7, 0.3]
        )
        
        let ps = BlendingPresentationState(
            sopInstanceUID: "1.2.3.4.5.6",
            referencedSeries: [series],
            blendingDisplaySets: [displaySet]
        )
        
        XCTAssertEqual(ps.blendingDisplaySets[0].blendingMode, .additive)
    }
    
    func test_blendingPresentationState_subtractiveBlending() {
        let ref1 = ReferencedImageForBlending(sopInstanceUID: "1.2.3.4.5")
        let ref2 = ReferencedImageForBlending(sopInstanceUID: "1.2.3.4.6")
        let image = ReferencedImage(
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            sopInstanceUID: "1.2.3.4.5"
        )
        let series = ReferencedSeries(
            seriesInstanceUID: "1.2.3.4",
            referencedImages: [image]
        )
        let displaySet = BlendingDisplaySet(
            displaySetNumber: 1,
            referencedImages: [ref1, ref2],
            blendingMode: .subtractive,
            relativeOpacities: [1.0, 1.0]
        )
        
        let ps = BlendingPresentationState(
            sopInstanceUID: "1.2.3.4.5.6",
            referencedSeries: [series],
            blendingDisplaySets: [displaySet]
        )
        
        XCTAssertEqual(ps.blendingDisplaySets[0].blendingMode, .subtractive)
    }
    
    func test_blendingPresentationState_minimumIntensityProjection() {
        let refs = (1...5).map { i in
            ReferencedImageForBlending(sopInstanceUID: "1.2.3.4.\(i)")
        }
        let image = ReferencedImage(
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            sopInstanceUID: "1.2.3.4.5"
        )
        let series = ReferencedSeries(
            seriesInstanceUID: "1.2.3.4",
            referencedImages: [image]
        )
        let displaySet = BlendingDisplaySet(
            displaySetNumber: 1,
            referencedImages: refs,
            blendingMode: .minimumIntensity,
            relativeOpacities: Array(repeating: 1.0, count: 5)
        )
        
        let ps = BlendingPresentationState(
            sopInstanceUID: "1.2.3.4.5.6",
            referencedSeries: [series],
            blendingDisplaySets: [displaySet]
        )
        
        XCTAssertEqual(ps.blendingDisplaySets[0].blendingMode, .minimumIntensity)
    }
    
    func test_blendingPresentationState_multipleReferencedSeries() {
        let images = (1...3).map { i in
            ReferencedImage(
                sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
                sopInstanceUID: "1.2.3.4.\(i)"
            )
        }
        let series = ReferencedSeries(
            seriesInstanceUID: "1.2.3.4",
            referencedImages: images
        )
        let refImage = ReferencedImageForBlending(sopInstanceUID: "1.2.3.4.1")
        let displaySet = BlendingDisplaySet(
            displaySetNumber: 1,
            referencedImages: [refImage],
            relativeOpacities: [1.0]
        )
        
        let ps = BlendingPresentationState(
            sopInstanceUID: "1.2.3.4.5.6",
            referencedSeries: [series],
            blendingDisplaySets: [displaySet]
        )
        
        XCTAssertEqual(ps.referencedSeries.count, 1)
        XCTAssertEqual(ps.referencedSeries[0].referencedImages.count, 3)
    }
    
    func test_blendingPresentationState_sendable() {
        let image = ReferencedImage(
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            sopInstanceUID: "1.2.3.4.5"
        )
        let series = ReferencedSeries(
            seriesInstanceUID: "1.2.3.4",
            referencedImages: [image]
        )
        let refImage = ReferencedImageForBlending(sopInstanceUID: "1.2.3.4.5")
        let displaySet = BlendingDisplaySet(
            displaySetNumber: 1,
            referencedImages: [refImage],
            relativeOpacities: [1.0]
        )
        
        let ps = BlendingPresentationState(
            sopInstanceUID: "1.2.3.4.5.6",
            referencedSeries: [series],
            blendingDisplaySets: [displaySet]
        )
        
        // Verify that it's Sendable by using it in a concurrent context
        let queue = DispatchQueue(label: "test", attributes: .concurrent)
        queue.async {
            _ = ps.sopInstanceUID
            _ = ps.sopClassUID
        }
        
        queue.sync { }
    }
}
