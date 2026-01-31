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
    
    @Test("TransferSyntax from UID - Compressed transfer syntax returns nil")
    func testFromUIDCompressed() {
        // JPEG Baseline (Process 1) - this is a compressed transfer syntax
        let ts = TransferSyntax.from(uid: "1.2.840.10008.1.2.4.50")
        
        #expect(ts == nil)
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
