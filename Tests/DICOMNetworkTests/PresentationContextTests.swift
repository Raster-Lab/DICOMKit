import Testing
@testable import DICOMNetwork

@Suite("Presentation Context Tests")
struct PresentationContextTests {
    
    @Test("Valid Presentation Context creation")
    func testValidPresentationContext() throws {
        let context = try PresentationContext(
            id: 1,
            abstractSyntax: "1.2.840.10008.5.1.4.1.1.7",
            transferSyntaxes: ["1.2.840.10008.1.2.1"]
        )
        
        #expect(context.id == 1)
        #expect(context.abstractSyntax == "1.2.840.10008.5.1.4.1.1.7")
        #expect(context.transferSyntaxes.count == 1)
        #expect(context.transferSyntaxes[0] == "1.2.840.10008.1.2.1")
    }
    
    @Test("Presentation Context with multiple transfer syntaxes")
    func testMultipleTransferSyntaxes() throws {
        let context = try PresentationContext(
            id: 3,
            abstractSyntax: "1.2.840.10008.5.1.4.1.1.2",
            transferSyntaxes: [
                "1.2.840.10008.1.2.1",  // Explicit VR Little Endian
                "1.2.840.10008.1.2",     // Implicit VR Little Endian
                "1.2.840.10008.1.2.4.70" // JPEG Lossless
            ]
        )
        
        #expect(context.transferSyntaxes.count == 3)
    }
    
    @Test("Presentation Context ID must be odd")
    func testPresentationContextIDMustBeOdd() {
        #expect(throws: DICOMNetworkError.self) {
            _ = try PresentationContext(
                id: 2,  // Even - invalid
                abstractSyntax: "1.2.840.10008.5.1.4.1.1.7",
                transferSyntaxes: ["1.2.840.10008.1.2.1"]
            )
        }
    }
    
    @Test("Presentation Context requires abstract syntax")
    func testPresentationContextRequiresAbstractSyntax() {
        #expect(throws: DICOMNetworkError.self) {
            _ = try PresentationContext(
                id: 1,
                abstractSyntax: "",  // Empty - invalid
                transferSyntaxes: ["1.2.840.10008.1.2.1"]
            )
        }
    }
    
    @Test("Presentation Context requires at least one transfer syntax")
    func testPresentationContextRequiresTransferSyntax() {
        #expect(throws: DICOMNetworkError.self) {
            _ = try PresentationContext(
                id: 1,
                abstractSyntax: "1.2.840.10008.5.1.4.1.1.7",
                transferSyntaxes: []  // Empty - invalid
            )
        }
    }
    
    @Test("Presentation Context description")
    func testPresentationContextDescription() throws {
        let context = try PresentationContext(
            id: 1,
            abstractSyntax: "1.2.840.10008.5.1.4.1.1.7",
            transferSyntaxes: ["1.2.840.10008.1.2.1"]
        )
        
        #expect(context.description.contains("id=1"))
        #expect(context.description.contains("abstractSyntax"))
        #expect(context.description.contains("transferSyntaxes"))
    }
}

@Suite("Presentation Context Result Tests")
struct PresentationContextResultTests {
    
    @Test("Presentation Context Result raw values")
    func testResultRawValues() {
        #expect(PresentationContextResult.acceptance.rawValue == 0)
        #expect(PresentationContextResult.userRejection.rawValue == 1)
        #expect(PresentationContextResult.noReasonProviderRejection.rawValue == 2)
        #expect(PresentationContextResult.abstractSyntaxNotSupported.rawValue == 3)
        #expect(PresentationContextResult.transferSyntaxesNotSupported.rawValue == 4)
    }
    
    @Test("Presentation Context Result descriptions")
    func testResultDescriptions() {
        #expect(PresentationContextResult.acceptance.description == "Acceptance")
        #expect(PresentationContextResult.userRejection.description == "User Rejection")
        #expect(PresentationContextResult.abstractSyntaxNotSupported.description == "Abstract Syntax Not Supported")
    }
}

@Suite("Accepted Presentation Context Tests")
struct AcceptedPresentationContextTests {
    
    @Test("Accepted Presentation Context creation")
    func testAcceptedContextCreation() {
        let accepted = AcceptedPresentationContext(
            id: 1,
            result: .acceptance,
            transferSyntax: "1.2.840.10008.1.2.1"
        )
        
        #expect(accepted.id == 1)
        #expect(accepted.result == .acceptance)
        #expect(accepted.transferSyntax == "1.2.840.10008.1.2.1")
        #expect(accepted.isAccepted == true)
    }
    
    @Test("Rejected Presentation Context")
    func testRejectedContext() {
        let rejected = AcceptedPresentationContext(
            id: 3,
            result: .abstractSyntaxNotSupported,
            transferSyntax: nil
        )
        
        #expect(rejected.id == 3)
        #expect(rejected.result == .abstractSyntaxNotSupported)
        #expect(rejected.transferSyntax == nil)
        #expect(rejected.isAccepted == false)
    }
    
    @Test("Accepted context without transfer syntax is not accepted")
    func testAcceptedWithoutTransferSyntax() {
        let context = AcceptedPresentationContext(
            id: 1,
            result: .acceptance,
            transferSyntax: nil  // Missing transfer syntax
        )
        
        #expect(context.isAccepted == false)
    }
}
