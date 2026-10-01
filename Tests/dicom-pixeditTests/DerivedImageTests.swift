import XCTest
import DICOMCore
import DICOMKit
@testable import dicom_pixedit

/// dicom-pixedit against DICOM 2026a: the output of a pixel edit is a Derived Image
/// (PS3.3 C.7.6.1.1.2, General Reference Module Table C.12-10), the window is in
/// Modality LUT output units (C.11.2.1.2), the fill value stays inside Bits Stored
/// (C.7.6.3.1), and a crop moves Image Position (Patient) (C.7.6.2.1.1).
final class DerivedImageTests: XCTestCase {

    private let ctStorage = "1.2.840.10008.5.1.4.1.1.2"   // PS3.6 Table A-1 CT Image Storage
    private let sourceUID = "1.2.3.4.5"

    /// 10x8 CT image: Bits Allocated 16, Bits Stored 12, unsigned, Rescale −1024/1.
    private func ctFile() throws -> Data {
        var ds = DataSet()
        ds.setString(ctStorage, for: .sopClassUID, vr: .UI)
        ds.setString(sourceUID, for: .sopInstanceUID, vr: .UI)
        ds.setStrings(["ORIGINAL", "PRIMARY", "AXIAL"], for: .imageType, vr: .CS)
        ds.setInt(1, for: .samplesPerPixel, vr: .US)
        ds.setString("MONOCHROME2", for: .photometricInterpretation, vr: .CS)
        ds.setInt(8, for: .rows, vr: .US)
        ds.setInt(10, for: .columns, vr: .US)
        ds.setInt(16, for: .bitsAllocated, vr: .US)
        ds.setInt(12, for: .bitsStored, vr: .US)
        ds.setInt(11, for: .highBit, vr: .US)
        ds.setInt(0, for: .pixelRepresentation, vr: .US)
        ds.setString("-1024", for: .rescaleIntercept, vr: .DS)
        ds.setString("1", for: .rescaleSlope, vr: .DS)
        ds.setStrings(["-100", "-50", "20"], for: .imagePositionPatient, vr: .DS)
        ds.setStrings(["1", "0", "0", "0", "1", "0"], for: .imageOrientationPatient, vr: .DS)
        ds.setStrings(["0.5", "0.7"], for: .pixelSpacing, vr: .DS)
        ds.setInt(0, for: .smallestImagePixelValue, vr: .US)
        ds.setInt(3950, for: .largestImagePixelValue, vr: .US)
        ds.setString("01", for: .lossyImageCompression, vr: .CS)
        ds.setString("YES", for: .burnedInAnnotation, vr: .CS)
        var pixels = Data()
        for i in 0..<80 { let v = UInt16(i * 50); pixels.append(UInt8(v & 0xFF)); pixels.append(UInt8(v >> 8)) }
        ds[.pixelData] = DataElement.data(tag: .pixelData, vr: .OW, data: pixels)
        var file = DICOMFile.create(dataSet: ds, sopClassUID: ctStorage, sopInstanceUID: sourceUID,
                                    transferSyntaxUID: "1.2.840.10008.1.2.1")
        var meta = file.fileMetaInformation
        meta.setString("1.2.3.999", for: .implementationClassUID, vr: .UI)   // "another implementation"
        file = DICOMFile(fileMetaInformation: meta, dataSet: file.dataSet)
        return try file.write()
    }

    private func run(_ ops: [PixelOperation], described: [PixelOperation]? = nil) throws -> DICOMFile {
        let input = try ctFile()
        let (edited, _) = try PixelEditor(verbose: false).processData(input, operations: ops)
        let derived = DerivedImage.markDerived(edited: try DICOMFile.read(from: edited),
                                               source: try DICOMFile.read(from: input),
                                               operations: ops, described: described, newUID: "1.2.3.4.6")
        return try DICOMFile.read(from: derived.write())
    }

    func testEditedImageIsADerivedImageWithANewUID() throws {
        let out = try run([.invert])
        let ds = out.dataSet
        // C.7.6.1.1.2: different pixel data → SOP Instance UID different from the source.
        XCTAssertEqual(ds.string(for: .sopInstanceUID), "1.2.3.4.6")
        XCTAssertEqual(out.fileMetaInformation.string(for: .mediaStorageSOPInstanceUID), "1.2.3.4.6")
        XCTAssertEqual(out.fileMetaInformation.string(for: .implementationClassUID), DICOMFile.implementationClassUID)
        // Value 1 DERIVED, Values 2..n kept.
        XCTAssertEqual(ds.strings(for: .imageType), ["DERIVED", "PRIMARY", "AXIAL"])
        XCTAssertEqual(ds.string(for: .derivationDescription), "dicom-pixedit: pixel values inverted")
        // Table C.12-10 Source Image Sequence, Table 10-3 item, CID 7202 DCM 121322.
        let items = try XCTUnwrap(ds.sequence(for: .sourceImageSequence))
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0][.referencedSOPClassUID]?.stringValue, ctStorage)
        XCTAssertEqual(items[0][.referencedSOPInstanceUID]?.stringValue, sourceUID)
        let purpose = try XCTUnwrap(items[0][.purposeOfReferenceCodeSequence]?.sequenceItems?.first)
        XCTAssertEqual(purpose[.codeValue]?.stringValue, "121322")
        XCTAssertEqual(purpose[.codingSchemeDesignator]?.stringValue, "DCM")
        XCTAssertEqual(purpose[.codeMeaning]?.stringValue, "Source image for image processing operation")
        // Stale value range removed; lossy flag and burned-in flag left as they were.
        XCTAssertNil(ds[.smallestImagePixelValue])
        XCTAssertNil(ds[.largestImagePixelValue])
        XCTAssertEqual(ds.string(for: .lossyImageCompression), "01")
        XCTAssertEqual(ds.string(for: .burnedInAnnotation), "YES")
    }

    func testImageTypeAddedWhenAbsentAndDescriptionCapped() throws {
        var ds = DataSet()
        ds.setString(String(repeating: "x", count: 1020), for: .derivationDescription, vr: .ST)
        let file = DICOMFile(fileMetaInformation: DataSet(), dataSet: ds)
        let out = DerivedImage.markDerived(edited: file, source: file, operations: [.invert], newUID: "1.2.9")
        XCTAssertEqual(out.dataSet.strings(for: .imageType), ["DERIVED", "SECONDARY"])
        XCTAssertEqual(out.dataSet.string(for: .derivationDescription)?.count, DerivedImage.stMaximumLength)
    }

    func testCropMovesImagePositionPatient() throws {
        let out = try run([.crop(x: 2, y: 1, width: 5, height: 4)])
        // P = S + X·Δi·i + Y·Δj·j, Δi = Pixel Spacing Value 2 = 0.7, Δj = Value 1 = 0.5.
        let p = try XCTUnwrap(out.dataSet.decimalStrings(for: .imagePositionPatient)).map(\.value)
        XCTAssertEqual(p[0], -98.6, accuracy: 1e-9)
        XCTAssertEqual(p[1], -49.5, accuracy: 1e-9)
        XCTAssertEqual(p[2], 20, accuracy: 1e-9)
        XCTAssertEqual(out.dataSet.uint16(for: .rows), 4)
        XCTAssertEqual(out.dataSet.uint16(for: .columns), 5)
    }

    func testWindowIsTakenInModalityLUTOutputUnits() throws {
        // CT window 40/400 HU with Rescale Intercept −1024: stored center 1064, width 400.
        let w = DerivedImage.storedWindow(center: 40, width: 400, slope: 1, intercept: -1024)
        XCTAssertEqual(w.center, 1064, accuracy: 1e-9)
        XCTAssertEqual(w.width, 400, accuracy: 1e-9)
        // Slope 2: thresholds c − 0.5 ± (w − 1)/2 map exactly through y = 2x + b.
        let s = DerivedImage.storedWindow(center: 100.5, width: 201, slope: 2, intercept: 0)
        XCTAssertEqual(s.center - 0.5 - (s.width - 1) / 2, (100.5 - 0.5 - 100) / 2, accuracy: 1e-9)
        XCTAssertEqual(s.center - 0.5 + (s.width - 1) / 2, (100.5 - 0.5 + 100) / 2, accuracy: 1e-9)

        let out = try run([.windowLevel(center: w.center, width: w.width)],
                          described: [.windowLevel(center: 40, width: 400)])
        let px = try XCTUnwrap(out.dataSet[.pixelData]?.valueData)
        func sample(_ i: Int) -> Int { Int(px[2 * i]) | Int(px[2 * i + 1]) << 8 }
        // Stored 900 = −124 HU: (−124 − 39.5)/399 + 0.5 = 0.0902 of 4095 → 369.
        XCTAssertEqual(sample(18), 369)
        XCTAssertEqual(sample(0), 0)
        XCTAssertEqual(out.dataSet.string(for: .derivationDescription),
                       "dicom-pixedit: window center 40 width 400 baked into the stored values")
    }

    func testFillValueClampedToBitsStoredRange() {
        XCTAssertEqual(DerivedImage.storedRange(bitsStored: 12, signed: false), 0...4095)
        XCTAssertEqual(DerivedImage.storedRange(bitsStored: 12, signed: true), -2048...2047)
        XCTAssertEqual(DerivedImage.storedRange(bitsStored: 8, signed: false), 0...255)
        let high = DerivedImage.clampFill(9000, to: 0...4095)
        XCTAssertEqual(high.value, 4095)
        XCTAssertNotNil(high.warning)
        let ok = DerivedImage.clampFill(0, to: 0...4095)
        XCTAssertEqual(ok.value, 0)
        XCTAssertNil(ok.warning)
        XCTAssertEqual(DerivedImage.clampFill(-5000, to: -2048...2047).value, -2048)
    }

    func testSuccessiveEditsAppendSourceItemsAndDescriptions() throws {
        let first = try run([.invert])
        let second = DerivedImage.markDerived(edited: first, source: first, operations: [.invert], newUID: "1.2.3.4.7")
        let items = try XCTUnwrap(second.dataSet.sequence(for: .sourceImageSequence))
        XCTAssertEqual(items.map { $0[.referencedSOPInstanceUID]?.stringValue }, [sourceUID, "1.2.3.4.6"])
        XCTAssertEqual(second.dataSet.string(for: .derivationDescription),
                       "dicom-pixedit: pixel values inverted; dicom-pixedit: pixel values inverted")
    }
}
