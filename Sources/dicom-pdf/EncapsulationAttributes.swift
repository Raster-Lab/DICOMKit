// NEMA-verified: 2026a, checked 2026-10-01 — Encapsulated Document Length (0042,0015) UL, Type 3, "not including any trailing padding" (PS3.3 2026a Table C.24-2; VR per PS3.6 Table 6-1); Specific Character Set (0008,0005) Type 1C "Required if an expanded or replacement character set is used" (Table C.12-1), Defined Term ISO_IR 192 for UTF-8 (Table C.12-5); Conversion Type (0008,0064) 8 Defined Terms of Table C.8-24 (DV, DI, DF, WSD, SD, SI, DRW, SYN); Burned In Annotation (0028,0301) Type 1 YES/NO (Table C.24-2); HL7 Instance Identifier (0040,E001) Type 1C "Required if encapsulated document is a CDA document", "UID … concatenated with a caret (^) and Extension value" (Table C.24-2) — all dumped from the DocBook by script

import Foundation
import ArgumentParser
import DICOMKit
import DICOMCore

/// Attributes `dicom-pdf` adds around the shared `EncapsulatedDocumentBuilder` /
/// `EncapsulatedDocumentParser`, and the vocabularies of its encapsulation options.
enum PDFEncapsulation {

    /// Encapsulated Document Length (0042,0015), UL (PS3.3 Table C.24-2, Type 3).
    static let encapsulatedDocumentLength = Tag(group: 0x0042, element: 0x0015)

    /// PS3.3 2026a Table C.8-24 Conversion Type (0008,0064) Defined Terms, in table order.
    static let conversionTypes = ["DV", "DI", "DF", "WSD", "SD", "SI", "DRW", "SYN"]

    /// Default Conversion Type: the document was produced on a workstation.
    static let defaultConversionType = "WSD"

    /// Burned In Annotation (0028,0301) values (PS3.3 Table C.24-2).
    static let burnedInAnnotationValues = ["YES", "NO"]

    /// Specific Character Set Defined Term for UTF-8 (PS3.3 Table C.12-5).
    static let utf8CharacterSet = "ISO_IR 192"

    /// The VRs whose values Specific Character Set governs (PS3.5 6.1.2.2).
    private static let characterSetVRs: Set<VR> = [.SH, .LO, .ST, .LT, .UT, .PN, .UC]

    // MARK: - Option values

    /// Validates `--conversion-type` (case-insensitive) and returns the Defined Term.
    static func conversionType(_ raw: String) throws -> String {
        let value = raw.uppercased()
        guard conversionTypes.contains(value) else {
            throw ValidationError("--conversion-type \(raw) is not a Conversion Type (0008,0064) Defined Term of PS3.3 Table C.8-24: \(conversionTypes.joined(separator: ", "))")
        }
        return value
    }

    /// Validates `--burned-in-annotation` (case-insensitive): `true` for YES.
    static func burnedInAnnotation(_ raw: String) throws -> Bool {
        switch raw.uppercased() {
        case "YES": return true
        case "NO": return false
        default:
            throw ValidationError("--burned-in-annotation \(raw) is not YES or NO (Burned In Annotation (0028,0301), PS3.3 Table C.24-2)")
        }
    }

    /// The HL7 Instance Identifier of a CDA document: `root^extension` (or `root`)
    /// of the first `<id>` child of `<ClinicalDocument>`, as Table C.24-2 defines it.
    static func hl7InstanceIdentifier(fromCDA data: Data) -> String? {
        let finder = ClinicalDocumentIDFinder()
        let parser = XMLParser(data: data)
        parser.shouldProcessNamespaces = true
        parser.delegate = finder
        parser.parse()
        guard let root = finder.root, !root.isEmpty else { return nil }
        if let ext = finder.extensionValue, !ext.isEmpty { return "\(root)^\(ext)" }
        return root
    }

    // MARK: - Dataset completion and extraction

    /// Adds Encapsulated Document Length (0042,0015) with the unpadded byte count,
    /// and Specific Character Set (0008,0005) `ISO_IR 192` when a string value is
    /// not plain ASCII (the writer encodes strings as UTF-8).
    static func complete(_ dataSet: inout DataSet, documentByteCount: Int) {
        dataSet[encapsulatedDocumentLength] = DataElement.uint32(
            tag: encapsulatedDocumentLength, value: UInt32(documentByteCount))
        if dataSet[.specificCharacterSet] == nil, hasNonASCIIText(dataSet) {
            dataSet.setString(utf8CharacterSet, for: .specificCharacterSet, vr: .CS)
        }
    }

    /// Whether any top-level text value carries a byte outside ASCII.
    static func hasNonASCIIText(_ dataSet: DataSet) -> Bool {
        dataSet.allElements.contains { element in
            characterSetVRs.contains(element.vr) && element.valueData.contains { $0 > 0x7F }
        }
    }

    /// The document bytes without the trailing padding: the Encapsulated Document
    /// value cut to Encapsulated Document Length (0042,0015) when that is present
    /// and not longer than the value (PS3.3 Table C.24-2). Without it the value is
    /// returned as stored, since nothing says whether a last byte is padding.
    static func documentBytes(_ value: Data, in dataSet: DataSet) -> Data {
        guard let length = dataSet[encapsulatedDocumentLength]?.uint32Value,
              Int(length) <= value.count else { return value }
        return value.prefix(Int(length))
    }
}

/// Finds `/ClinicalDocument/id/@root` and `@extension` (HL7 CDA R2).
private final class ClinicalDocumentIDFinder: NSObject, XMLParserDelegate {
    var root: String?
    var extensionValue: String?
    private var depth = 0
    private var isClinicalDocument = false

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName: String?,
                attributes: [String: String] = [:]) {
        depth += 1
        if depth == 1 {
            isClinicalDocument = elementName == "ClinicalDocument"
            if !isClinicalDocument { parser.abortParsing() }
        }
        if depth == 2, isClinicalDocument, elementName == "id", root == nil {
            root = attributes["root"]
            extensionValue = attributes["extension"]
            parser.abortParsing()
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName: String?) {
        depth -= 1
    }
}
