import Foundation
import DICOMCore
import DICOMKit

// MARK: - DataSet Helper Extension

extension DataSet {
    /// Convenience method to set a string value for a tag
    mutating func set(string value: String, for tag: Tag) {
        // For UI (UID) tags
        if tag == .studyInstanceUID || tag == .seriesInstanceUID || 
           tag == .sopInstanceUID || tag == .sopClassUID {
            let paddedValue = value.padding(toLength: (value.count % 2 == 0) ? value.count : value.count + 1, withPad: "\0", startingAt: 0)
            let data = paddedValue.data(using: .utf8) ?? Data()
            let element = DataElement(tag: tag, vr: .UI, length: UInt32(data.count), valueData: data)
            self[tag] = element
            return
        }
        
        // Determine VR for other tags
        let vr: VR
        switch tag {
        case .patientID, .patientName, .studyID, .accessionNumber,
             .studyDescription, .seriesDescription, .modality:
            vr = .CS // Code String for most identifiers
        case .studyDate, .seriesDate, .contentDate:
            vr = .DA // Date
        case .studyTime, .seriesTime, .contentTime:
            vr = .TM // Time
        case .instanceNumber, .seriesNumber:
            vr = .IS // Integer String
        default:
            vr = .LO // Long String as fallback
        }
        
        // For other strings, pad to even length with space
        let paddedValue = value.padding(toLength: (value.count % 2 == 0) ? value.count : value.count + 1, withPad: " ", startingAt: 0)
        let data = paddedValue.data(using: .utf8) ?? Data()
        let element = DataElement(tag: tag, vr: vr, length: UInt32(data.count), valueData: data)
        self[tag] = element
    }
}
