//
// PresentationStateTests.swift
// DICOMKit
//
// Created by DICOMKit on 2026-02-05.
// Copyright © 2026 DICOMKit. All rights reserved.
//

import XCTest
import DICOMCore
@testable import DICOMKit

final class PresentationStateTests: XCTestCase {
    
    // MARK: - ReferencedImage Tests
    
    func test_referencedImage_initialization() {
        let image = ReferencedImage(
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            sopInstanceUID: "1.2.3.4.5"
        )
        
        XCTAssertEqual(image.sopClassUID, "1.2.840.10008.5.1.4.1.1.2")
        XCTAssertEqual(image.sopInstanceUID, "1.2.3.4.5")
        XCTAssertNil(image.referencedFrameNumbers)
    }
    
    func test_referencedImage_withFrameNumbers() {
        let image = ReferencedImage(
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            sopInstanceUID: "1.2.3.4.5",
            referencedFrameNumbers: [1, 3, 5, 7]
        )
        
        XCTAssertEqual(image.referencedFrameNumbers, [1, 3, 5, 7])
    }
    
    func test_referencedImage_hashable() {
        let image1 = ReferencedImage(
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            sopInstanceUID: "1.2.3.4.5"
        )
        let image2 = ReferencedImage(
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            sopInstanceUID: "1.2.3.4.5"
        )
        let image3 = ReferencedImage(
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            sopInstanceUID: "1.2.3.4.6"
        )
        
        XCTAssertEqual(image1, image2)
        XCTAssertNotEqual(image1, image3)
        
        let set: Set = [image1, image2, image3]
        XCTAssertEqual(set.count, 2)
    }
    
    // MARK: - ReferencedSeries Tests
    
    func test_referencedSeries_initialization() {
        let image = ReferencedImage(
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            sopInstanceUID: "1.2.3.4.5"
        )
        let series = ReferencedSeries(
            seriesInstanceUID: "1.2.3.4",
            referencedImages: [image]
        )
        
        XCTAssertEqual(series.seriesInstanceUID, "1.2.3.4")
        XCTAssertEqual(series.referencedImages.count, 1)
        XCTAssertEqual(series.referencedImages[0].sopInstanceUID, "1.2.3.4.5")
    }
    
    func test_referencedSeries_multipleImages() {
        let images = (1...5).map { i in
            ReferencedImage(
                sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
                sopInstanceUID: "1.2.3.4.\(i)"
            )
        }
        let series = ReferencedSeries(
            seriesInstanceUID: "1.2.3.4",
            referencedImages: images
        )
        
        XCTAssertEqual(series.referencedImages.count, 5)
    }
    
    func test_referencedSeries_hashable() {
        let image = ReferencedImage(
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            sopInstanceUID: "1.2.3.4.5"
        )
        let series1 = ReferencedSeries(seriesInstanceUID: "1.2.3.4", referencedImages: [image])
        let series2 = ReferencedSeries(seriesInstanceUID: "1.2.3.4", referencedImages: [image])
        let series3 = ReferencedSeries(seriesInstanceUID: "1.2.3.5", referencedImages: [image])
        
        XCTAssertEqual(series1, series2)
        XCTAssertNotEqual(series1, series3)
    }
    
    // MARK: - GrayscalePresentationState Tests
    
    func test_grayscalePresentationState_minimal() {
        let image = ReferencedImage(
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            sopInstanceUID: "1.2.3.4.5"
        )
        let series = ReferencedSeries(seriesInstanceUID: "1.2.3.4", referencedImages: [image])
        
        let state = GrayscalePresentationState(
            sopInstanceUID: "1.2.3.4.5.6",
            referencedSeries: [series]
        )
        
        XCTAssertEqual(state.sopInstanceUID, "1.2.3.4.5.6")
        XCTAssertEqual(state.sopClassUID, .grayscaleSoftcopyPresentationStateStorage)
        XCTAssertEqual(state.referencedSeries.count, 1)
        XCTAssertNil(state.instanceNumber)
        XCTAssertNil(state.presentationLabel)
        XCTAssertNil(state.presentationDescription)
        XCTAssertNil(state.modalityLUT)
        XCTAssertNil(state.voiLUT)
        XCTAssertNil(state.presentationLUT)
        XCTAssertNil(state.spatialTransformation)
        XCTAssertNil(state.displayedArea)
        XCTAssertTrue(state.graphicLayers.isEmpty)
        XCTAssertTrue(state.graphicAnnotations.isEmpty)
        XCTAssertTrue(state.shutters.isEmpty)
    }
    
    func test_grayscalePresentationState_complete() {
        let image = ReferencedImage(
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            sopInstanceUID: "1.2.3.4.5"
        )
        let series = ReferencedSeries(seriesInstanceUID: "1.2.3.4", referencedImages: [image])
        
        let modalityLUT = ModalityLUT.rescale(slope: 1.0, intercept: -1024.0, type: "HU")
        let voiLUT = VOILUT.window(center: 40.0, width: 400.0, explanation: "Lung", function: .linear)
        let presentationLUT = PresentationLUT.identity
        let spatialTransform = SpatialTransformation(rotation: 90, horizontalFlip: true)
        let displayedArea = DisplayedArea(
            topLeft: (column: 0, row: 0),
            bottomRight: (column: 511, row: 511),
            sizeMode: .scaleToFit
        )
        let layer = GraphicLayer(name: "Annotations", order: 1)
        let shutter = DisplayShutter.rectangular(left: 10, right: 490, top: 10, bottom: 490, presentationValue: 0)
        
        let state = GrayscalePresentationState(
            sopInstanceUID: "1.2.3.4.5.6",
            instanceNumber: 1,
            presentationLabel: "Test State",
            presentationDescription: "Test presentation state for unit testing",
            presentationCreationDate: DICOMDate(year: 2026, month: 2, day: 5),
            presentationCreationTime: DICOMTime(hour: 12, minute: 30, second: 45),
            presentationCreatorsName: DICOMPersonName(familyName: "Smith", givenName: "John"),
            referencedSeries: [series],
            modalityLUT: modalityLUT,
            voiLUT: voiLUT,
            presentationLUT: presentationLUT,
            spatialTransformation: spatialTransform,
            displayedArea: displayedArea,
            graphicLayers: [layer],
            graphicAnnotations: [],
            shutters: [shutter]
        )
        
        XCTAssertEqual(state.instanceNumber, 1)
        XCTAssertEqual(state.presentationLabel, "Test State")
        XCTAssertEqual(state.presentationDescription, "Test presentation state for unit testing")
        XCTAssertNotNil(state.presentationCreationDate)
        XCTAssertNotNil(state.presentationCreationTime)
        XCTAssertNotNil(state.presentationCreatorsName)
        XCTAssertNotNil(state.modalityLUT)
        XCTAssertNotNil(state.voiLUT)
        XCTAssertNotNil(state.presentationLUT)
        XCTAssertNotNil(state.spatialTransformation)
        XCTAssertNotNil(state.displayedArea)
        XCTAssertEqual(state.graphicLayers.count, 1)
        XCTAssertEqual(state.shutters.count, 1)
    }
    
    func test_grayscalePresentationState_multipleReferencedSeries() {
        let series1 = ReferencedSeries(
            seriesInstanceUID: "1.2.3.4",
            referencedImages: [
                ReferencedImage(sopClassUID: "1.2.840.10008.5.1.4.1.1.2", sopInstanceUID: "1.2.3.4.1")
            ]
        )
        let series2 = ReferencedSeries(
            seriesInstanceUID: "1.2.3.5",
            referencedImages: [
                ReferencedImage(sopClassUID: "1.2.840.10008.5.1.4.1.1.2", sopInstanceUID: "1.2.3.5.1")
            ]
        )
        
        let state = GrayscalePresentationState(
            sopInstanceUID: "1.2.3.4.5.6",
            referencedSeries: [series1, series2]
        )
        
        XCTAssertEqual(state.referencedSeries.count, 2)
        XCTAssertEqual(state.referencedSeries[0].seriesInstanceUID, "1.2.3.4")
        XCTAssertEqual(state.referencedSeries[1].seriesInstanceUID, "1.2.3.5")
    }
    
    // MARK: - SOP Class UID Extension Tests
    
    func test_sopClassUID_grayscaleSoftcopyPresentationStateStorage() {
        XCTAssertEqual(String.grayscaleSoftcopyPresentationStateStorage, "1.2.840.10008.5.1.4.1.1.11.1")
    }
    
    func test_sopClassUID_colorSoftcopyPresentationStateStorage() {
        XCTAssertEqual(String.colorSoftcopyPresentationStateStorage, "1.2.840.10008.5.1.4.1.1.11.2")
    }
    
    func test_sopClassUID_pseudoColorSoftcopyPresentationStateStorage() {
        XCTAssertEqual(String.pseudoColorSoftcopyPresentationStateStorage, "1.2.840.10008.5.1.4.1.1.11.3")
    }
    
    func test_sopClassUID_blendingSoftcopyPresentationStateStorage() {
        XCTAssertEqual(String.blendingSoftcopyPresentationStateStorage, "1.2.840.10008.5.1.4.1.1.11.4")
    }
}
