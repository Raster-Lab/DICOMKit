// SyntheticFixtures.swift
//
// Deterministic, PHI-free DICOM Part-10 fixtures for the Tier-2 parity harness.
// Every field is a fixed constant (no Date(), no random UID, fixed pixel ramp)
// so regenerating produces byte-identical output — a prerequisite for committed
// goldens. Explicit VR Little Endian throughout.
//
// These are committed under Resources/CLIParity/synthetic/ (PHI-free), unlike
// the real, git-ignored fixtures/ corpus.

import Foundation

enum SyntheticFixtures {

    // MARK: - Explicit VR LE encoders

    private static func tagBytes(_ g: UInt16, _ e: UInt16) -> [UInt8] {
        [UInt8(g & 0xFF), UInt8(g >> 8), UInt8(e & 0xFF), UInt8(e >> 8)]
    }
    private static func u16(_ v: UInt16) -> [UInt8] { [UInt8(v & 0xFF), UInt8(v >> 8)] }
    private static func u32(_ v: UInt32) -> [UInt8] {
        [UInt8(v & 0xFF), UInt8((v >> 8) & 0xFF), UInt8((v >> 16) & 0xFF), UInt8((v >> 24) & 0xFF)]
    }

    /// Short-form element (2-byte length): most VRs.
    private static func elem(_ g: UInt16, _ e: UInt16, _ vr: String, _ value: [UInt8]) -> [UInt8] {
        var v = value
        if v.count % 2 == 1 { v.append(vr == "UI" ? 0x00 : 0x20) }   // pad odd
        return tagBytes(g, e) + Array(vr.utf8) + u16(UInt16(v.count)) + v
    }
    /// Long-form element (2 reserved + 4-byte length): OB/OW/etc.
    private static func elemLong(_ g: UInt16, _ e: UInt16, _ vr: String, _ value: [UInt8]) -> [UInt8] {
        var v = value
        if v.count % 2 == 1 { v.append(0x00) }
        return tagBytes(g, e) + Array(vr.utf8) + [0, 0] + u32(UInt32(v.count)) + v
    }
    private static func str(_ g: UInt16, _ e: UInt16, _ vr: String, _ s: String) -> [UInt8] {
        elem(g, e, vr, Array(s.utf8))
    }
    private static func us(_ g: UInt16, _ e: UInt16, _ v: UInt16) -> [UInt8] {
        elem(g, e, "US", u16(v))
    }

    // MARK: - Image builder

    /// Builds a valid Part-10 CT image (Explicit VR LE) with a deterministic
    /// pixel ramp. `frames > 1` emits NumberOfFrames + multiframe pixel data.
    static func image(sopInstanceUID: String, studyUID: String, seriesUID: String,
                      patientName: String, patientID: String, studyDescription: String,
                      seriesNumber: Int, instanceNumber: Int,
                      frames: Int = 1, rows: Int = 8, cols: Int = 8,
                      bits: Int = 16) -> Data {
        let ctSOP = "1.2.840.10008.5.1.4.1.1.2"
        let explicitLE = "1.2.840.10008.1.2.1"

        var main: [UInt8] = []
        main += str(0x0008, 0x0016, "UI", ctSOP)
        main += str(0x0008, 0x0018, "UI", sopInstanceUID)
        main += str(0x0008, 0x0020, "DA", "20200101")
        main += str(0x0008, 0x0030, "TM", "120000")
        main += str(0x0008, 0x0060, "CS", "CT")
        main += str(0x0008, 0x0070, "LO", "DICOMKit Parity")
        main += str(0x0008, 0x1030, "LO", studyDescription)
        main += str(0x0008, 0x103E, "LO", "PARITY SERIES")
        main += str(0x0010, 0x0010, "PN", patientName)
        main += str(0x0010, 0x0020, "LO", patientID)
        main += str(0x0010, 0x0030, "DA", "19800101")
        main += str(0x0010, 0x0040, "CS", "O")
        main += str(0x0020, 0x000D, "UI", studyUID)
        main += str(0x0020, 0x000E, "UI", seriesUID)
        main += str(0x0020, 0x0011, "IS", String(seriesNumber))
        main += str(0x0020, 0x0013, "IS", String(instanceNumber))
        main += us(0x0028, 0x0002, 1)                       // SamplesPerPixel
        main += str(0x0028, 0x0004, "CS", "MONOCHROME2")
        if frames > 1 { main += str(0x0028, 0x0008, "IS", String(frames)) }
        main += us(0x0028, 0x0010, UInt16(rows))            // Rows
        main += us(0x0028, 0x0011, UInt16(cols))            // Columns
        // 8-bit (jpeg-baseline-compatible) vs the default 12-bit-stored/16-bit CT.
        let eightBit = (bits == 8)
        main += us(0x0028, 0x0100, UInt16(eightBit ? 8 : 16))   // BitsAllocated
        main += us(0x0028, 0x0101, UInt16(eightBit ? 8 : 12))   // BitsStored
        main += us(0x0028, 0x0102, UInt16(eightBit ? 7 : 11))   // HighBit
        main += us(0x0028, 0x0103, 0)                           // PixelRepresentation (unsigned)

        // Deterministic pixel ramp: 1 byte/pixel (OB) at 8-bit, else 2 bytes/pixel (OW).
        let count = rows * cols * max(1, frames)
        var px: [UInt8] = []
        if eightBit {
            px.reserveCapacity(count)
            for i in 0..<count { px.append(UInt8(i % 256)) }
            main += elemLong(0x7FE0, 0x0010, "OB", px)
        } else {
            px.reserveCapacity(count * 2)
            for i in 0..<count { px += u16(UInt16(i % 4096)) }
            main += elemLong(0x7FE0, 0x0010, "OW", px)
        }

        // File meta (group 0002), Explicit VR LE.
        var meta: [UInt8] = []
        meta += str(0x0002, 0x0010, "UI", explicitLE)
        meta += str(0x0002, 0x0002, "UI", ctSOP)
        meta += str(0x0002, 0x0003, "UI", sopInstanceUID)
        meta += str(0x0002, 0x0012, "UI", "1.2.276.0.7230010.3.0.3.6.4")
        meta += str(0x0002, 0x0013, "SH", "DICOMKITPARITY")
        let metaFull = elem(0x0002, 0x0000, "UL", u32(UInt32(meta.count))) + meta

        var data = Data(count: 128)                         // preamble
        data.append(contentsOf: Array("DICM".utf8))
        data.append(contentsOf: metaFull)
        data.append(contentsOf: main)
        return data
    }

    // MARK: - Named fixtures (stable UIDs in a reserved test root)
    // Root 1.2.826.0.1.3680043.10.999.* is reserved for these test objects.

    static func singleFrameCT() -> Data {
        image(sopInstanceUID: "1.2.826.0.1.3680043.10.999.1.1.1",
              studyUID: "1.2.826.0.1.3680043.10.999.1.1",
              seriesUID: "1.2.826.0.1.3680043.10.999.1.2",
              patientName: "PARITY^SYNTH", patientID: "SYN-0001",
              studyDescription: "PARITY SYNTHETIC CT",
              seriesNumber: 1, instanceNumber: 1)
    }

    /// 8-bit unsigned MONOCHROME2 CT — the ONLY codec on the parity matrix that
    /// rejects the default 16-bit fixture is JPEG Baseline (8-bit only), so this
    /// gives `dicom-compress compress --codec jpeg/jpeg-baseline` a valid input.
    static func singleFrame8bitCT() -> Data {
        image(sopInstanceUID: "1.2.826.0.1.3680043.10.999.6.1.1",
              studyUID: "1.2.826.0.1.3680043.10.999.6.1",
              seriesUID: "1.2.826.0.1.3680043.10.999.6.2",
              patientName: "PARITY^SYNTH8", patientID: "SYN-0008",
              studyDescription: "PARITY SYNTHETIC CT 8BIT",
              seriesNumber: 6, instanceNumber: 1, bits: 8)
    }

    /// Same shape as `singleFrameCT` but different patient/UIDs/description — the
    /// second operand for `dicom-diff`.
    static func singleFrameCT2() -> Data {
        image(sopInstanceUID: "1.2.826.0.1.3680043.10.999.2.1.1",
              studyUID: "1.2.826.0.1.3680043.10.999.2.1",
              seriesUID: "1.2.826.0.1.3680043.10.999.2.2",
              patientName: "PARITY^SYNTH2", patientID: "SYN-0002",
              studyDescription: "PARITY SYNTHETIC CT TWO",
              seriesNumber: 2, instanceNumber: 1)
    }

    static func multiFrameCT(frames: Int = 4) -> Data {
        image(sopInstanceUID: "1.2.826.0.1.3680043.10.999.3.1.1",
              studyUID: "1.2.826.0.1.3680043.10.999.3.1",
              seriesUID: "1.2.826.0.1.3680043.10.999.3.2",
              patientName: "PARITY^MULTI", patientID: "SYN-0003",
              studyDescription: "PARITY SYNTHETIC MULTIFRAME",
              seriesNumber: 3, instanceNumber: 1, frames: frames)
    }

    /// A complete single-study directory: `series` series × `instances` instances
    /// (sequential InstanceNumbers). Returns (relative filename, bytes). Used by
    /// dicom-study summary/check/stats (one set) and compare (two distinct sets).
    static func studySet(studyIndex: Int, series: Int = 2, instances: Int = 2) -> [(name: String, data: Data)] {
        let root = "1.2.826.0.1.3680043.10.999.\(40 + studyIndex)"
        let studyUID = "\(root).1"
        var files: [(String, Data)] = []
        for s in 1...series {
            let seriesUID = "\(root).1.\(s)"
            for i in 1...instances {
                let sop = "\(root).1.\(s).\(i)"
                let data = image(sopInstanceUID: sop, studyUID: studyUID, seriesUID: seriesUID,
                                 patientName: "PARITY^STUDY\(studyIndex)", patientID: "SYN-STD-\(studyIndex)",
                                 studyDescription: "PARITY STUDY SET \(studyIndex)",
                                 seriesNumber: s, instanceNumber: i)
                files.append(("s\(s)i\(i).dcm", data))
            }
        }
        return files
    }
}
