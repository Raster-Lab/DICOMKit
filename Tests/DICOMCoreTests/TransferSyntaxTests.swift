import Testing
@testable import DICOMCore

@Suite("TransferSyntax Tests")
struct TransferSyntaxTests {
    
    @Test("Implicit VR Little Endian transfer syntax properties")
    func testImplicitVRLittleEndian() {
        let ts = TransferSyntax.implicitVRLittleEndian
        
        #expect(ts.uid == "1.2.840.10008.1.2")
        #expect(ts.isExplicitVR == false)
        #expect(ts.byteOrder == .littleEndian)
        #expect(ts.isEncapsulated == false)
        #expect(ts.isDeflated == false)
    }
    
    @Test("Explicit VR Little Endian transfer syntax properties")
    func testExplicitVRLittleEndian() {
        let ts = TransferSyntax.explicitVRLittleEndian
        
        #expect(ts.uid == "1.2.840.10008.1.2.1")
        #expect(ts.isExplicitVR == true)
        #expect(ts.byteOrder == .littleEndian)
        #expect(ts.isEncapsulated == false)
        #expect(ts.isDeflated == false)
    }
    
    @Test("Deflated Explicit VR Little Endian transfer syntax properties")
    func testDeflatedExplicitVRLittleEndian() {
        let ts = TransferSyntax.deflatedExplicitVRLittleEndian
        
        #expect(ts.uid == "1.2.840.10008.1.2.1.99")
        #expect(ts.isExplicitVR == true)
        #expect(ts.byteOrder == .littleEndian)
        #expect(ts.isEncapsulated == false)
        #expect(ts.isDeflated == true)
    }
    
    @Test("Explicit VR Big Endian transfer syntax properties")
    func testExplicitVRBigEndian() {
        let ts = TransferSyntax.explicitVRBigEndian
        
        #expect(ts.uid == "1.2.840.10008.1.2.2")
        #expect(ts.isExplicitVR == true)
        #expect(ts.byteOrder == .bigEndian)
        #expect(ts.isEncapsulated == false)
        #expect(ts.isDeflated == false)
    }
    
    @Test("TransferSyntax from UID - Implicit VR Little Endian")
    func testFromUIDImplicitVR() {
        let ts = TransferSyntax.from(uid: "1.2.840.10008.1.2")
        
        #expect(ts != nil)
        #expect(ts?.uid == TransferSyntax.implicitVRLittleEndian.uid)
        #expect(ts?.isExplicitVR == false)
        #expect(ts?.byteOrder == .littleEndian)
        #expect(ts?.isDeflated == false)
    }
    
    @Test("TransferSyntax from UID - Explicit VR Little Endian")
    func testFromUIDExplicitVRLittleEndian() {
        let ts = TransferSyntax.from(uid: "1.2.840.10008.1.2.1")
        
        #expect(ts != nil)
        #expect(ts?.uid == TransferSyntax.explicitVRLittleEndian.uid)
        #expect(ts?.isExplicitVR == true)
        #expect(ts?.byteOrder == .littleEndian)
        #expect(ts?.isDeflated == false)
    }
    
    @Test("TransferSyntax from UID - Deflated Explicit VR Little Endian")
    func testFromUIDDeflatedExplicitVRLittleEndian() {
        let ts = TransferSyntax.from(uid: "1.2.840.10008.1.2.1.99")
        
        #expect(ts != nil)
        #expect(ts?.uid == TransferSyntax.deflatedExplicitVRLittleEndian.uid)
        #expect(ts?.isExplicitVR == true)
        #expect(ts?.byteOrder == .littleEndian)
        #expect(ts?.isDeflated == true)
    }
    
    @Test("TransferSyntax from UID - Explicit VR Big Endian")
    func testFromUIDExplicitVRBigEndian() {
        let ts = TransferSyntax.from(uid: "1.2.840.10008.1.2.2")
        
        #expect(ts != nil)
        #expect(ts?.uid == TransferSyntax.explicitVRBigEndian.uid)
        #expect(ts?.isExplicitVR == true)
        #expect(ts?.byteOrder == .bigEndian)
        #expect(ts?.isDeflated == false)
    }
    
    @Test("TransferSyntax from UID - Unknown UID returns nil")
    func testFromUIDUnknown() {
        let ts = TransferSyntax.from(uid: "1.2.840.10008.1.2.999")
        
        #expect(ts == nil)
    }
    
    @Test("TransferSyntax from UID - Compressed transfer syntax returns valid syntax")
    func testFromUIDCompressed() {
        // JPEG Baseline (Process 1) - now supported
        let ts = TransferSyntax.from(uid: "1.2.840.10008.1.2.4.50")
        
        #expect(ts != nil)
        #expect(ts?.isEncapsulated == true)
        #expect(ts?.isExplicitVR == true)
        #expect(ts?.byteOrder == .littleEndian)
    }
    
    @Test("TransferSyntax from UID - Unknown transfer syntax returns nil")
    func testFromUIDUnsupported() {
        let ts = TransferSyntax.from(uid: "1.2.840.10008.1.2.4.999")
        
        #expect(ts == nil)
    }

    @Test("Extended JPEG 2000 families are recognized")
    func testExtendedJPEG2000Families() {
        let part2Lossless = TransferSyntax.jpeg2000Part2Lossless
        #expect(TransferSyntax.from(uid: part2Lossless.uid) == .jpeg2000Part2Lossless)
        #expect(part2Lossless.isJPEG2000)
        #expect(part2Lossless.isJPEG2000Part2)
        #expect(part2Lossless.isLossless)

        let htLossless = TransferSyntax.htj2kLossless
        #expect(TransferSyntax.from(uid: htLossless.uid) == .htj2kLossless)
        #expect(htLossless.isJPEG2000)
        #expect(htLossless.isHTJ2K)
        #expect(htLossless.isLossless)

        let htRPCL = TransferSyntax.htj2kRPCLLossless
        #expect(TransferSyntax.from(uid: htRPCL.uid) == .htj2kRPCLLossless)
        #expect(htRPCL.isHTJ2K)
        #expect(htRPCL.isLossless)

        let htLossy = TransferSyntax.htj2kLossy
        #expect(TransferSyntax.from(uid: htLossy.uid) == .htj2kLossy)
        #expect(htLossy.isHTJ2K)
        #expect(htLossy.isLossless == false)
    }

    @Test("TransferSyntax parse recognizes CLI aliases and UIDs")
    func testParseAliases() {
        #expect(TransferSyntax.parse("explicit-vr-le") == .explicitVRLittleEndian)
        #expect(TransferSyntax.parse("implicit-vr-le") == .implicitVRLittleEndian)
        // `parse` is CONSERVATIVE (UID-only, no intent): bare `…-lossless` keeps the
        // reversible-only UID; `…-lossless-only` is an explicit synonym. The lossless-INTO-
        // general split lives in `parseEncoding` (see testParseEncodingIntentAliases).
        #expect(TransferSyntax.parse("jpeg2000-lossless") == .jpeg2000Lossless)      // .90
        #expect(TransferSyntax.parse("jpeg2000-lossless-only") == .jpeg2000Lossless) // .90
        #expect(TransferSyntax.parse("htj2k-lossless") == .htj2kLossless)           // .201
        #expect(TransferSyntax.parse("htj2k-lossless-only") == .htj2kLossless)      // .201
        #expect(TransferSyntax.parse("htj2k-rpcl-lossless-only") == .htj2kRPCLLossless) // .202
        #expect(TransferSyntax.parse("htj2k-rpcl") == .htj2kRPCLLossless)           // deprecated alias
        #expect(TransferSyntax.parse("htj2k") == .htj2kLossy)                       // .203 general
        #expect(TransferSyntax.parse("1.2.840.10008.1.2.4.201") == .htj2kLossless)
        #expect(TransferSyntax.parse("not-a-syntax") == nil)
    }
    
    @Test("JPEG transfer syntax properties")
    func testJPEGTransferSyntaxes() {
        // JPEG Baseline
        let jpegBaseline = TransferSyntax.jpegBaseline
        #expect(jpegBaseline.uid == "1.2.840.10008.1.2.4.50")
        #expect(jpegBaseline.isEncapsulated == true)
        #expect(jpegBaseline.isJPEG == true)
        #expect(jpegBaseline.isLossless == false)
        
        // JPEG Extended
        let jpegExtended = TransferSyntax.jpegExtended
        #expect(jpegExtended.uid == "1.2.840.10008.1.2.4.51")
        #expect(jpegExtended.isEncapsulated == true)
        #expect(jpegExtended.isJPEG == true)
        
        // JPEG Lossless
        let jpegLossless = TransferSyntax.jpegLossless
        #expect(jpegLossless.uid == "1.2.840.10008.1.2.4.57")
        #expect(jpegLossless.isEncapsulated == true)
        #expect(jpegLossless.isJPEG == true)
        #expect(jpegLossless.isLossless == true)
        
        // JPEG Lossless SV1
        let jpegLosslessSV1 = TransferSyntax.jpegLosslessSV1
        #expect(jpegLosslessSV1.uid == "1.2.840.10008.1.2.4.70")
        #expect(jpegLosslessSV1.isEncapsulated == true)
        #expect(jpegLosslessSV1.isJPEG == true)
        #expect(jpegLosslessSV1.isLossless == true)
    }
    
    @Test("JPEG 2000 transfer syntax properties")
    func testJPEG2000TransferSyntaxes() {
        // JPEG 2000 Lossless
        let j2kLossless = TransferSyntax.jpeg2000Lossless
        #expect(j2kLossless.uid == "1.2.840.10008.1.2.4.90")
        #expect(j2kLossless.isEncapsulated == true)
        #expect(j2kLossless.isJPEG2000 == true)
        #expect(j2kLossless.isLossless == true)
        
        // JPEG 2000 Lossy
        let j2k = TransferSyntax.jpeg2000
        #expect(j2k.uid == "1.2.840.10008.1.2.4.91")
        #expect(j2k.isEncapsulated == true)
        #expect(j2k.isJPEG2000 == true)
        #expect(j2k.isLossless == false)
    }
    
    @Test("RLE transfer syntax properties")
    func testRLETransferSyntax() {
        let rle = TransferSyntax.rleLossless
        #expect(rle.uid == "1.2.840.10008.1.2.5")
        #expect(rle.isEncapsulated == true)
        #expect(rle.isRLE == true)
        #expect(rle.isLossless == true)
    }
    
    @Test("TransferSyntax equality")
    func testEquality() {
        let ts1 = TransferSyntax.explicitVRLittleEndian
        let ts2 = TransferSyntax(
            uid: "1.2.840.10008.1.2.1",
            isExplicitVR: true,
            byteOrder: .littleEndian
        )
        
        #expect(ts1 == ts2)
    }
    
    @Test("TransferSyntax hashable")
    func testHashable() {
        var set: Set<TransferSyntax> = []
        set.insert(.implicitVRLittleEndian)
        set.insert(.explicitVRLittleEndian)
        set.insert(.deflatedExplicitVRLittleEndian)
        set.insert(.explicitVRBigEndian)
        
        #expect(set.count == 4)
        #expect(set.contains(.implicitVRLittleEndian))
        #expect(set.contains(.explicitVRLittleEndian))
        #expect(set.contains(.deflatedExplicitVRLittleEndian))
        #expect(set.contains(.explicitVRBigEndian))
    }
    
    @Test("TransferSyntax description")
    func testDescription() {
        let implicitDesc = TransferSyntax.implicitVRLittleEndian.description
        let explicitLEDesc = TransferSyntax.explicitVRLittleEndian.description
        let deflatedDesc = TransferSyntax.deflatedExplicitVRLittleEndian.description
        let explicitBEDesc = TransferSyntax.explicitVRBigEndian.description
        
        #expect(implicitDesc.contains("Implicit VR"))
        #expect(implicitDesc.contains("Little Endian"))
        #expect(implicitDesc.contains("1.2.840.10008.1.2"))
        
        #expect(explicitLEDesc.contains("Explicit VR"))
        #expect(explicitLEDesc.contains("Little Endian"))
        #expect(explicitLEDesc.contains("1.2.840.10008.1.2.1"))
        
        #expect(deflatedDesc.contains("Explicit VR"))
        #expect(deflatedDesc.contains("Little Endian"))
        #expect(deflatedDesc.contains("Deflated"))
        #expect(deflatedDesc.contains("1.2.840.10008.1.2.1.99"))
        
        #expect(explicitBEDesc.contains("Explicit VR"))
        #expect(explicitBEDesc.contains("Big Endian"))
        #expect(explicitBEDesc.contains("1.2.840.10008.1.2.2"))
    }
    
    @Test("ByteOrder cases")
    func testByteOrderCases() {
        let littleEndian = ByteOrder.littleEndian
        let bigEndian = ByteOrder.bigEndian
        
        #expect(littleEndian != bigEndian)
        #expect(littleEndian == .littleEndian)
        #expect(bigEndian == .bigEndian)
    }
    
    @Test("Custom TransferSyntax creation")
    func testCustomTransferSyntax() {
        // Test creating a custom encapsulated transfer syntax
        let customTS = TransferSyntax(
            uid: "1.2.840.10008.1.2.4.50",
            isExplicitVR: true,
            byteOrder: .littleEndian,
            isEncapsulated: true
        )
        
        #expect(customTS.uid == "1.2.840.10008.1.2.4.50")
        #expect(customTS.isExplicitVR == true)
        #expect(customTS.byteOrder == .littleEndian)
        #expect(customTS.isEncapsulated == true)
        #expect(customTS.isDeflated == false)
    }
    
    @Test("Custom deflated TransferSyntax creation")
    func testCustomDeflatedTransferSyntax() {
        // Test creating a custom deflated transfer syntax
        let customTS = TransferSyntax(
            uid: "1.2.840.10008.1.2.1.99",
            isExplicitVR: true,
            byteOrder: .littleEndian,
            isDeflated: true
        )
        
        #expect(customTS.uid == "1.2.840.10008.1.2.1.99")
        #expect(customTS.isExplicitVR == true)
        #expect(customTS.byteOrder == .littleEndian)
        #expect(customTS.isEncapsulated == false)
        #expect(customTS.isDeflated == true)
    }
}

// MARK: - Lossless Capability & Selectable Encodings

@Suite("TransferSyntax: J2K/HTJ2K lossless capability & selectable encodings")
struct TransferSyntaxCapabilityTests {

    @Test("Lossless-only J2K/HTJ2K UIDs report .losslessOnly")
    func testLosslessOnlyCapability() {
        #expect(TransferSyntax.jpeg2000Lossless.losslessCapability == .losslessOnly)        // .90
        #expect(TransferSyntax.jpeg2000Part2Lossless.losslessCapability == .losslessOnly)   // .92
        #expect(TransferSyntax.htj2kLossless.losslessCapability == .losslessOnly)            // .201
        #expect(TransferSyntax.htj2kRPCLLossless.losslessCapability == .losslessOnly)        // .202
    }

    @Test("General J2K/HTJ2K UIDs report .both (lossless or lossy)")
    func testBothCapability() {
        #expect(TransferSyntax.jpeg2000.losslessCapability == .both)       // .91
        #expect(TransferSyntax.jpeg2000Part2.losslessCapability == .both)  // .93
        #expect(TransferSyntax.htj2kLossy.losslessCapability == .both)     // .203
    }

    @Test("A purely-lossy JPEG UID reports .lossyOnly")
    func testLossyOnlyCapability() {
        #expect(TransferSyntax.jpegBaseline.losslessCapability == .lossyOnly)
    }

    @Test("selectableEncodings expands .91/.93/.203 into two rows each")
    func testDualEntriesForBothCapableUIDs() {
        let j2kEncodings = TransferSyntax.selectableEncodings.filter { $0.transferSyntax.isJPEG2000 }

        // .90/.92/.201/.202 → exactly one row each; .91/.93/.203 → two rows each.
        func rows(for uid: String) -> [SelectableEncoding] { j2kEncodings.filter { $0.uid == uid } }
        #expect(rows(for: "1.2.840.10008.1.2.4.90").count == 1)
        #expect(rows(for: "1.2.840.10008.1.2.4.91").count == 2)
        #expect(rows(for: "1.2.840.10008.1.2.4.92").count == 1)
        #expect(rows(for: "1.2.840.10008.1.2.4.93").count == 2)
        #expect(rows(for: "1.2.840.10008.1.2.4.201").count == 1)
        #expect(rows(for: "1.2.840.10008.1.2.4.202").count == 1)
        #expect(rows(for: "1.2.840.10008.1.2.4.203").count == 2)

        // The full J2K/HTJ2K list is 4 single + 3 doubled = 10 rows.
        #expect(j2kEncodings.count == 10)
    }

    @Test("Every negotiableImageSyntaxTokens token parses back to its paired syntax")
    func testNegotiableImageTokensRoundTrip() {
        // This is the source-of-truth contract the dicom-retrieve / dicom-qr pickers and CLI
        // help depend on: each canonical token must resolve, via the SAME parser the CLIs use,
        // to exactly the transfer syntax it is paired with. If this fails, a negotiation surface
        // is offering a token the CLI would reject with "Unknown transfer syntax".
        for entry in TransferSyntax.negotiableImageSyntaxTokens {
            #expect(TransferSyntax.parse(entry.token) == entry.syntax,
                    "token '\(entry.token)' must parse to \(entry.syntax.displayName)")
        }
        // Derived list stays in lockstep with the pairs.
        #expect(TransferSyntax.negotiableImageTokens == TransferSyntax.negotiableImageSyntaxTokens.map(\.token))
    }

    @Test("negotiableImageSyntaxTokens has no duplicate tokens or UIDs")
    func testNegotiableImageTokensAreUnique() {
        let tokens = TransferSyntax.negotiableImageTokens
        #expect(Set(tokens).count == tokens.count)
        let uids = TransferSyntax.negotiableImageSyntaxTokens.map { $0.syntax.uid }
        #expect(Set(uids).count == uids.count)
    }

    @Test("negotiableImageSyntaxTokens covers current codecs and omits non-retrievable ones")
    func testNegotiableImageTokensCoverage() {
        let tokens = Set(TransferSyntax.negotiableImageTokens)
        // The codecs added in the JPEG 2000 Part 2 / JPEG-LS / JPEG XL work must all appear —
        // this is the regression guard against the old hand-maintained list that stopped at RLE.
        for token in ["jpeg-ls-lossless", "jpeg-ls", "jpeg-xl-lossless", "jpeg-xl",
                      "jpeg2000-part2-lossless", "jpeg2000-part2", "jpeg-extended",
                      "explicit-vr-be", "deflate"] {
            #expect(tokens.contains(token), "negotiation list should offer '\(token)'")
        }
        // Non-decodable / non-retrievable syntaxes are intentionally excluded.
        let uids = Set(TransferSyntax.negotiableImageSyntaxTokens.map { $0.syntax.uid })
        for excluded in [TransferSyntax.mpeg2MainProfile, .hevcH265MainProfile,
                         .jpipReferenced, .jp3dLossless, .jpegXLRecompression] {
            #expect(!uids.contains(excluded.uid), "\(excluded.displayName) should not be negotiable")
        }
    }

    @Test("The two .91 rows carry distinct intent, id, and displayName")
    func testNinetyOneLosslessAndLossyRows() {
        let rows = TransferSyntax.selectableEncodings.filter { $0.uid == "1.2.840.10008.1.2.4.91" }
        let lossless = rows.first { $0.intent == .lossless }
        let lossy = rows.first { $0.intent == .lossy }

        #expect(lossless != nil)
        #expect(lossy != nil)
        #expect(lossless?.isLossless == true)
        #expect(lossy?.isLossless == false)
        #expect(lossless?.displayName == "JPEG 2000 Lossless")
        #expect(lossy?.displayName == "JPEG 2000 Lossy")
        // Distinct identity so pickers/result maps can key on them independently.
        #expect(lossless?.id != lossy?.id)
        #expect(lossless?.id == "1.2.840.10008.1.2.4.91#lossless")
    }

    @Test("Lossless-only rows use .notApplicable intent and their canonical name")
    func testLosslessOnlyRow() {
        let row = TransferSyntax.selectableEncodings.first { $0.uid == "1.2.840.10008.1.2.4.90" }
        #expect(row?.intent == .notApplicable)
        #expect(row?.isLossless == true)
        #expect(row?.displayName == "JPEG 2000 Lossless Only")
    }

    @Test("Canonical HTJ2K display names")
    func testHTJ2KDisplayNames() {
        #expect(TransferSyntax.htj2kLossless.displayName == "HTJ2K Lossless Only")
        #expect(TransferSyntax.htj2kRPCLLossless.displayName == "HTJ2K Lossless Only (RPCL)")
        #expect(TransferSyntax.htj2kLossy.displayName == "HTJ2K")
    }

    @Test("from(uid:) stays deterministic despite two rows sharing a UID")
    func testFromUIDDeterministic() {
        // Both .91 rows share the same underlying TransferSyntax; from(uid:) is single-valued.
        #expect(TransferSyntax.from(uid: "1.2.840.10008.1.2.4.91") == .jpeg2000)
        for enc in TransferSyntax.selectableEncodings {
            #expect(TransferSyntax.from(uid: enc.uid) == enc.transferSyntax)
        }
    }

    @Test("parseEncoding resolves intent aliases for the general UIDs")
    func testParseEncodingIntentAliases() {
        #expect(TransferSyntax.parseEncoding("j2k-91-lossless")?.uid == "1.2.840.10008.1.2.4.91")
        #expect(TransferSyntax.parseEncoding("j2k-91-lossless")?.isLossless == true)
        #expect(TransferSyntax.parseEncoding("j2k-91-lossy")?.isLossless == false)
        #expect(TransferSyntax.parseEncoding("htj2k-203-lossless")?.uid == "1.2.840.10008.1.2.4.203")
        #expect(TransferSyntax.parseEncoding("htj2k-203-lossless")?.isLossless == true)

        // Symmetric naming: bare `…-lossless` encodes reversibly INTO the general UID;
        // `…-lossless-only` selects the distinct reversible-only UID.
        #expect(TransferSyntax.parseEncoding("j2k-lossless")?.uid == "1.2.840.10008.1.2.4.91")
        #expect(TransferSyntax.parseEncoding("j2k-lossless")?.isLossless == true)
        #expect(TransferSyntax.parseEncoding("j2k-lossless-only")?.uid == "1.2.840.10008.1.2.4.90")
        #expect(TransferSyntax.parseEncoding("j2k-lossless-only")?.isLossless == true)
        // JPEG XL general .112 is now both-capable: -lossless/-lossy resolve into it.
        #expect(TransferSyntax.parseEncoding("jpeg-xl-lossless")?.uid == "1.2.840.10008.1.2.4.112")
        #expect(TransferSyntax.parseEncoding("jpeg-xl-lossless")?.isLossless == true)
        #expect(TransferSyntax.parseEncoding("jpeg-xl-lossless-only")?.uid == "1.2.840.10008.1.2.4.110")
        // A bare general alias defaults to the lossy mode.
        #expect(TransferSyntax.parseEncoding("j2k")?.intent == .lossy)
        #expect(TransferSyntax.parseEncoding("htj2k")?.intent == .lossy)
    }

    @Test("CLI HTJ2K target aliases map to the canonical UIDs (parse is conservative)")
    func testHTJ2KTargetAliases() {
        // `parse` (UID-only) keeps `htj2k-lossless` on the reversible-only .201; the
        // encode-intent split (`htj2k-lossless` → .203 reversible) is in `parseEncoding`.
        #expect(TransferSyntax.parse("htj2k-lossless") == .htj2kLossless)           // .201
        #expect(TransferSyntax.parse("htj2k-lossless-only") == .htj2kLossless)      // .201
        #expect(TransferSyntax.parse("htj2k-rpcl-lossless-only") == .htj2kRPCLLossless) // .202
        #expect(TransferSyntax.parse("htj2k-rpcl") == .htj2kRPCLLossless)           // deprecated alias
        #expect(TransferSyntax.parse("htj2k") == .htj2kLossy)                       // .203
        // parseEncoding carries the intent split:
        #expect(TransferSyntax.parseEncoding("htj2k-lossless")?.uid == "1.2.840.10008.1.2.4.203")
        #expect(TransferSyntax.parseEncoding("htj2k-lossless")?.isLossless == true)
    }
}
