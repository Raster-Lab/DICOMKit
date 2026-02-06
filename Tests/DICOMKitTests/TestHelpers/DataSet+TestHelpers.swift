//
// DataSet+TestHelpers.swift
// DICOMKit
//
// Created by DICOMKit on 2026-02-06.
// Copyright © 2026 DICOMKit. All rights reserved.
//

import Foundation
import DICOMCore
import DICOMDictionary
@testable import DICOMKit

/// Test helper extension for DataSet to simplify test data creation
extension DataSet {
    /// Convenience method to append string values to a DataSet
    /// - Parameters:
    ///   - tag: The tag to append
    ///   - value: The string value
    mutating func append(_ tag: Tag, _ value: String) {
        // Determine VR based on tag
        let vr: VR
        if let entry = DataElementDictionary.lookup(tag: tag) {
            vr = entry.vr
        } else {
            // Default to LO for unknown tags
            vr = .LO
        }
        self[tag] = DataElement.string(tag: tag, vr: vr, value: value)
    }
    
    /// Convenience method to append UInt16 values to a DataSet
    /// - Parameters:
    ///   - tag: The tag to append
    ///   - value: The UInt16 value
    mutating func append(_ tag: Tag, _ value: UInt16) {
        self[tag] = DataElement.uint16(tag: tag, value: value)
    }
    
    /// Convenience method to append Int values to a DataSet
    /// - Parameters:
    ///   - tag: The tag to append
    ///   - value: The Int value
    mutating func append(_ tag: Tag, _ value: Int) {
        // Convert Int to appropriate type based on tag
        // Most integer tags in DICOM are IS (Integer String) or SL/SS
        self[tag] = DataElement.int32(tag: tag, value: Int32(value))
    }
    
    /// Convenience method to append array of Int values to a DataSet
    /// - Parameters:
    ///   - tag: The tag to append
    ///   - values: Array of Int values
    mutating func append(_ tag: Tag, _ values: [Int]) {
        // Convert to Int32 array for DICOM
        let int32Values = values.map { Int32($0) }
        // Determine VR - for frame numbers and similar, use IS (Integer String)
        let vr: VR
        if let entry = DataElementDictionary.lookup(tag: tag) {
            vr = entry.vr
        } else {
            vr = .IS
        }
        // Use string representation for IS VR
        if vr == .IS {
            let stringValues = int32Values.map { String($0) }
            let combinedString = stringValues.joined(separator: "\\")
            self[tag] = DataElement.string(tag: tag, vr: .IS, value: combinedString)
        } else {
            // Use int32 array for SL VR
            let writer = DICOMWriter()
            let data = writer.serializeInt32s(int32Values)
            self[tag] = DataElement(tag: tag, vr: .SL, length: UInt32(data.count), valueData: data)
        }
    }
    
    /// Convenience method to append Double values to a DataSet
    /// - Parameters:
    ///   - tag: The tag to append
    ///   - value: The Double value
    mutating func append(_ tag: Tag, _ value: Double) {
        self[tag] = DataElement.float64(tag: tag, value: value)
    }
    
    /// Convenience method to append DICOMDate values to a DataSet
    /// - Parameters:
    ///   - tag: The tag to append
    ///   - value: The DICOMDate value
    mutating func append(_ tag: Tag, _ value: DICOMDate) {
        self[tag] = DataElement.string(tag: tag, vr: .DA, value: value.dicomString)
    }
    
    /// Convenience method to append DICOMTime values to a DataSet
    /// - Parameters:
    ///   - tag: The tag to append
    ///   - value: The DICOMTime value
    mutating func append(_ tag: Tag, _ value: DICOMTime) {
        self[tag] = DataElement.string(tag: tag, vr: .TM, value: value.dicomString)
    }
    
    /// Convenience method to append sequence items to a DataSet
    /// - Parameters:
    ///   - tag: The tag to append
    ///   - items: Array of DataSet items to append as a sequence
    mutating func appendSequence(_ tag: Tag, _ items: [DataSet]) {
        let sequenceItems = items.map { dataSet in
            SequenceItem(elements: dataSet.allElements)
        }
        let valueData = Data() // Empty for sequences
        self[tag] = DataElement(tag: tag, vr: .SQ, length: 0xFFFFFFFF, valueData: valueData, sequenceItems: sequenceItems)
    }
}
