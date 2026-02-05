//
// RealWorldValueLUTParser.swift
// DICOMKit
//
// Created by DICOMKit on 2026-02-05.
// Copyright © 2026 DICOMKit. All rights reserved.
//

import Foundation
import DICOMCore

/// Parser for Real World Value LUT information from DICOM data sets
///
/// Reference: PS3.3 C.7.6.16.2.11 - Real World Value Mapping Functional Group
/// Reference: PS3.3 C.11.1 - Modality LUT Module
public struct RealWorldValueLUTParser {
    
    /// Parse Real World Value LUT from a data set
    ///
    /// This method supports both:
    /// - Legacy Modality LUT (Rescale Slope/Intercept)
    /// - Modern Real World Value Mapping Sequence
    ///
    /// - Parameter dataSet: DataSet (DICOM data set wrapper)
    /// - Returns: Array of parsed RealWorldValueLUT objects
    public static func parse(from dataSet: DataSet) -> [RealWorldValueLUT] {
        var luts: [RealWorldValueLUT] = []
        
        // Try parsing from Real World Value Mapping Sequence first (modern approach)
        if let rwvMappingLUTs = parseRealWorldValueMappingSequence(from: dataSet) {
            luts.append(contentsOf: rwvMappingLUTs)
        }
        
        // Fall back to Modality LUT (Rescale Slope/Intercept) if no RWV mapping found
        if luts.isEmpty, let modalityLUT = parseModalityLUT(from: dataSet) {
            luts.append(modalityLUT)
        }
        
        return luts
    }
    
    // MARK: - Real World Value Mapping Sequence Parsing
    
    /// Parse Real World Value Mapping Sequence
    ///
    /// - Parameter dataSet: The DICOM data set
    /// - Returns: Array of RealWorldValueLUT objects, or nil if not present
    private static func parseRealWorldValueMappingSequence(
        from dataSet: DataSet
    ) -> [RealWorldValueLUT]? {
        // Real World Value Mapping Sequence is typically in Shared or Per-Frame Functional Groups
        // First check Shared Functional Groups
        if let sharedGroups = dataSet.sequence(for: Tag.sharedFunctionalGroupsSequence),
           let firstGroup = sharedGroups.first,
           let rwvLUTs = parseRWVMappingFromFunctionalGroup(firstGroup) {
            return rwvLUTs
        }
        
        // If not in shared, check Per-Frame Functional Groups (frame 1)
        if let perFrameGroups = dataSet.sequence(for: Tag.perFrameFunctionalGroupsSequence),
           let firstFrame = perFrameGroups.first,
           let rwvLUTs = parseRWVMappingFromFunctionalGroup(firstFrame) {
            return rwvLUTs
        }
        
        return nil
    }
    
    /// Parse RWV Mapping from a functional group item
    ///
    /// - Parameter functionalGroup: Functional group sequence item
    /// - Returns: Array of RealWorldValueLUT objects, or nil if not present
    private static func parseRWVMappingFromFunctionalGroup(
        _ functionalGroup: SequenceItem
    ) -> [RealWorldValueLUT]? {
        // Real World Value Mapping Sequence (0040,9096)
        guard let rwvSequence = functionalGroup.dataSet.sequence(for: Tag(group: 0x0040, element: 0x9096)) else {
            return nil
        }
        
        return rwvSequence.compactMap { item in
            parseRWVMappingItem(item.dataSet)
        }
    }
    
    /// Parse a single Real World Value Mapping item
    ///
    /// - Parameter dataSet: Data set from Real World Value Mapping Sequence item
    /// - Returns: RealWorldValueLUT, or nil if parsing fails
    private static func parseRWVMappingItem(_ dataSet: DataSet) -> RealWorldValueLUT? {
        // LUT Label (0040,9210)
        let label = dataSet.string(for: Tag(group: 0x0040, element: 0x9210))
        
        // LUT Explanation (0040,9211)
        let explanation = dataSet.string(for: Tag(group: 0x0040, element: 0x9211))
        
        // Measurement Units Code Sequence (0040,08EA)
        guard let unitsSequence = dataSet.sequence(for: Tag(group: 0x0040, element: 0x08EA)),
              let unitsItem = unitsSequence.first else {
            return nil
        }
        
        guard let units = parseCodedConcept(from: unitsItem.dataSet) else {
            return nil
        }
        
        let measurementUnits = RealWorldValueUnits(
            codeValue: units.codeValue,
            codingSchemeDesignator: units.codingSchemeDesignator,
            codeMeaning: units.codeMeaning
        )
        
        // Quantity Definition Sequence (0040,9220) - optional
        let quantityDefinition: DICOMCore.CodedConcept?
        if let quantitySequence = dataSet.sequence(for: Tag(group: 0x0040, element: 0x9220)),
           let quantityItem = quantitySequence.first {
            quantityDefinition = parseCodedConcept(from: quantityItem.dataSet)
        } else {
            quantityDefinition = nil
        }
        
        // Parse transformation (linear or LUT)
        let transformation: RealWorldValueLUT.Transformation
        
        // Try linear transformation first (Real World Value Slope/Intercept)
        if let slope = dataSet.float64s(for: Tag(group: 0x0040, element: 0x9225))?.first,
           let intercept = dataSet.float64s(for: Tag(group: 0x0040, element: 0x9224))?.first {
            transformation = .linear(slope: slope, intercept: intercept)
        }
        // Try LUT Data
        else if let firstValueMapped = dataSet.float64s(for: Tag(group: 0x0040, element: 0x9212))?.first,
                let lastValueMapped = dataSet.float64s(for: Tag(group: 0x0040, element: 0x9213))?.first,
                let lutData = dataSet.float64s(for: Tag(group: 0x0040, element: 0x9216)) {
            let descriptor = RealWorldValueLUT.LUTDescriptor(
                firstValueMapped: firstValueMapped,
                lastValueMapped: lastValueMapped
            )
            transformation = .lut(descriptor, data: lutData)
        } else {
            return nil
        }
        
        return RealWorldValueLUT(
            label: label,
            explanation: explanation,
            measurementUnits: measurementUnits,
            quantityDefinition: quantityDefinition,
            transformation: transformation
        )
    }
    
    // MARK: - Modality LUT Parsing (Legacy)
    
    /// Parse Modality LUT (Rescale Slope/Intercept)
    ///
    /// - Parameter dataSet: The DICOM data set
    /// - Returns: RealWorldValueLUT, or nil if not present
    private static func parseModalityLUT(from dataSet: DataSet) -> RealWorldValueLUT? {
        // Rescale Slope (0028,1053) and Rescale Intercept (0028,1052)
        guard let slope = dataSet.float64(for: Tag.rescaleSlope),
              let intercept = dataSet.float64(for: Tag.rescaleIntercept) else {
            return nil
        }
        
        // Rescale Type (0028,1054) - optional, describes the units
        let rescaleType = dataSet.string(for: Tag.rescaleType)
        
        // Determine units based on rescale type
        let units: RealWorldValueUnits
        let quantity: DICOMCore.CodedConcept?
        
        switch rescaleType?.uppercased() {
        case "HU":
            units = .hounsfield
            quantity = .hounsfield
            
        case "US":
            // Unspecified - use ratio
            units = .ratio
            quantity = nil
            
        case "OD":
            // Optical density
            units = RealWorldValueUnits(codeValue: "{od}", codeMeaning: "optical density")
            quantity = nil
            
        default:
            // Default to ratio for unknown types
            units = .ratio
            quantity = nil
        }
        
        return RealWorldValueLUT(
            label: rescaleType,
            explanation: rescaleType != nil ? "Modality LUT: \(rescaleType!)" : "Modality LUT",
            measurementUnits: units,
            quantityDefinition: quantity,
            transformation: .linear(slope: slope, intercept: intercept)
        )
    }
    
    // MARK: - Helper Methods
    
    /// Parse a coded concept from a data set
    ///
    /// - Parameter dataSet: Data set containing Code Value, Coding Scheme Designator, Code Meaning
    /// - Returns: CodedConcept, or nil if required fields are missing
    private static func parseCodedConcept(from dataSet: DataSet) -> DICOMCore.CodedConcept? {
        guard let codeValue = dataSet.string(for: Tag.codeValue),
              let codingScheme = dataSet.string(for: Tag.codingSchemeDesignator),
              let codeMeaning = dataSet.string(for: Tag.codeMeaning) else {
            return nil
        }
        
        return DICOMCore.CodedConcept(
            codeValue: codeValue,
            codingSchemeDesignator: codingScheme,
            codeMeaning: codeMeaning
        )
    }
}

// MARK: - Tag Extensions

extension Tag {
    /// Shared Functional Groups Sequence (5200,9229)
    static let sharedFunctionalGroupsSequence = Tag(group: 0x5200, element: 0x9229)
    
    /// Per-Frame Functional Groups Sequence (5200,9230)
    static let perFrameFunctionalGroupsSequence = Tag(group: 0x5200, element: 0x9230)
}
