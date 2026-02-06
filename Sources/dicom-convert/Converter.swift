import Foundation
import DICOMCore
import DICOMKit

/// Helper for converting between transfer syntaxes
struct TransferSyntaxConverter {
    /// Convert a dataset to a different transfer syntax
    func convert(
        dataSet: DataSet,
        to targetSyntax: TransferSyntax,
        preservePixelData: Bool = true
    ) throws -> Data {
        // Create file meta information for target transfer syntax
        var fileMeta = DataSet()
        
        // File Meta Information Version
        let versionTag = Tag.fileMetaInformationVersion
        fileMeta[versionTag] = DataElement(
            tag: versionTag,
            vr: .OB,
            length: 2,
            valueData: Data([0x00, 0x01])
        )
        
        // Media Storage SOP Class UID (copy from dataset if available)
        if let sopClassUID = dataSet.string(for: .sopClassUID),
           let data = sopClassUID.data(using: .ascii) {
            let sopClassTag = Tag.mediaStorageSOPClassUID
            fileMeta[sopClassTag] = DataElement(
                tag: sopClassTag,
                vr: .UI,
                length: UInt32(data.count),
                valueData: data
            )
        }
        
        // Media Storage SOP Instance UID (copy from dataset if available)
        if let sopInstanceUID = dataSet.string(for: .sopInstanceUID),
           let data = sopInstanceUID.data(using: .ascii) {
            let sopInstanceTag = Tag.mediaStorageSOPInstanceUID
            fileMeta[sopInstanceTag] = DataElement(
                tag: sopInstanceTag,
                vr: .UI,
                length: UInt32(data.count),
                valueData: data
            )
        }
        
        // Transfer Syntax UID
        if let tsData = targetSyntax.uid.data(using: .ascii) {
            let tsTag = Tag.transferSyntaxUID
            fileMeta[tsTag] = DataElement(
                tag: tsTag,
                vr: .UI,
                length: UInt32(tsData.count),
                valueData: tsData
            )
        }
        
        // Implementation Class UID
        if let implData = "1.2.826.0.1.3680043.10.1".data(using: .ascii) {
            let implTag = Tag.implementationClassUID
            fileMeta[implTag] = DataElement(
                tag: implTag,
                vr: .UI,
                length: UInt32(implData.count),
                valueData: implData
            )
        }
        
        // Implementation Version Name
        if let versionData = "DICOMKIT_1_0".data(using: .ascii) {
            let versionTag = Tag.implementationVersionName
            fileMeta[versionTag] = DataElement(
                tag: versionTag,
                vr: .SH,
                length: UInt32(versionData.count),
                valueData: versionData
            )
        }
        
        // Write file
        var output = Data()
        
        // Write preamble and DICM prefix
        output.append(Data(repeating: 0, count: 128))
        output.append(contentsOf: "DICM".utf8)
        
        // Write file meta information (always Explicit VR Little Endian)
        let metaWriter = DICOMWriter(byteOrder: .littleEndian, explicitVR: true)
        let metaData = try writeDataSet(fileMeta, writer: metaWriter)
        
        // File Meta Information Group Length
        let lengthData = metaWriter.serializeUInt32(UInt32(metaData.count))
        let groupLengthElement = DataElement(
            tag: .fileMetaInformationGroupLength,
            vr: .UL,
            length: UInt32(lengthData.count),
            valueData: lengthData
        )
        
        output.append(try writeElement(groupLengthElement, writer: metaWriter))
        output.append(metaData)
        
        // Write main dataset with target transfer syntax
        let dataWriter = createWriter(for: targetSyntax)
        let dataSetData = try writeDataSet(dataSet, writer: dataWriter)
        output.append(dataSetData)
        
        return output
    }
    
    private func createWriter(for transferSyntax: TransferSyntax) -> DICOMWriter {
        let byteOrder: ByteOrder = transferSyntax.byteOrder
        let explicitVR = transferSyntax.isExplicitVR
        return DICOMWriter(byteOrder: byteOrder, explicitVR: explicitVR)
    }
    
    private func writeDataSet(_ dataSet: DataSet, writer: DICOMWriter) throws -> Data {
        var output = Data()
        
        for tag in dataSet.tags.sorted() {
            guard let element = dataSet[tag] else { continue }
            output.append(try writeElement(element, writer: writer))
        }
        
        return output
    }
    
    private func writeElement(_ element: DataElement, writer: DICOMWriter) throws -> Data {
        var output = Data()
        
        // Write tag
        output.append(writer.serializeUInt16(element.tag.group))
        output.append(writer.serializeUInt16(element.tag.element))
        
        let vr = element.vr
        let valueData = element.valueData
        
        if writer.explicitVR {
            // Write VR
            output.append(contentsOf: vr.rawValue.utf8)
            
            // Check if VR uses 2-byte or 4-byte length field
            if vr.uses32BitLength {
                // Reserved bytes
                output.append(contentsOf: [0x00, 0x00])
                // 4-byte length
                output.append(writer.serializeUInt32(UInt32(valueData.count)))
            } else {
                // 2-byte length
                let length = min(valueData.count, 0xFFFF)
                output.append(writer.serializeUInt16(UInt16(length)))
            }
        } else {
            // Implicit VR: just 4-byte length
            output.append(writer.serializeUInt32(UInt32(valueData.count)))
        }
        
        // Write value
        output.append(valueData)
        
        return output
    }
}

extension VR {
    /// VRs that use 32-bit length field in Explicit VR encoding
    var uses32BitLength: Bool {
        switch self {
        case .OB, .OD, .OF, .OL, .OW, .SQ, .UC, .UN, .UR, .UT:
            return true
        default:
            return false
        }
    }
}

extension TransferSyntax {
    var byteOrder: ByteOrder {
        switch self {
        case .explicitVRBigEndian:
            return .bigEndian
        default:
            return .littleEndian
        }
    }
    
    var isExplicitVR: Bool {
        switch self {
        case .implicitVRLittleEndian:
            return false
        default:
            return true
        }
    }
}
