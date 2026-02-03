import Testing
import Foundation
@testable import DICOMWeb

@Suite("DICOMwebError Tests")
struct DICOMwebErrorTests {
    
    // MARK: - HTTP Status Code Factory Tests
    
    @Test("fromHTTPStatus creates correct errors for 4xx codes")
    func testClientErrors() {
        #expect(DICOMwebError.fromHTTPStatus(400) == .badRequest(message: nil))
        #expect(DICOMwebError.fromHTTPStatus(401) == .unauthorized(message: nil))
        #expect(DICOMwebError.fromHTTPStatus(403) == .forbidden(message: nil))
        #expect(DICOMwebError.fromHTTPStatus(404) == .notFound(resource: nil))
        #expect(DICOMwebError.fromHTTPStatus(429) == .tooManyRequests(retryAfter: nil))
    }
    
    @Test("fromHTTPStatus creates correct errors for 5xx codes")
    func testServerErrors() {
        #expect(DICOMwebError.fromHTTPStatus(500) == .internalServerError(message: nil))
        #expect(DICOMwebError.fromHTTPStatus(501) == .notImplemented(message: nil))
        #expect(DICOMwebError.fromHTTPStatus(502) == .badGateway(message: nil))
        #expect(DICOMwebError.fromHTTPStatus(503) == .serviceUnavailable(retryAfter: nil))
        #expect(DICOMwebError.fromHTTPStatus(504) == .gatewayTimeout(message: nil))
    }
    
    @Test("fromHTTPStatus with message")
    func testWithMessage() {
        let error = DICOMwebError.fromHTTPStatus(400, message: "Invalid query")
        if case .badRequest(let msg) = error {
            #expect(msg == "Invalid query")
        } else {
            #expect(Bool(false), "Expected badRequest error")
        }
    }
    
    @Test("fromHTTPStatus with retry-after header")
    func testWithRetryAfterHeader() {
        let error = DICOMwebError.fromHTTPStatus(
            429,
            message: nil,
            headers: ["Retry-After": "60"]
        )
        if case .tooManyRequests(let retryAfter) = error {
            #expect(retryAfter == 60)
        } else {
            #expect(Bool(false), "Expected tooManyRequests error")
        }
    }
    
    @Test("Unknown status code returns httpError")
    func testUnknownStatusCode() {
        let error = DICOMwebError.fromHTTPStatus(418)
        if case .httpError(let statusCode, _) = error {
            #expect(statusCode == 418)
        } else {
            #expect(Bool(false), "Expected httpError")
        }
    }
    
    // MARK: - Error Categories Tests
    
    @Test("isTransient identifies transient errors")
    func testIsTransient() {
        #expect(DICOMwebError.timeout(operation: nil).isTransient)
        #expect(DICOMwebError.connectionFailed(underlying: nil).isTransient)
        #expect(DICOMwebError.serviceUnavailable(retryAfter: nil).isTransient)
        #expect(DICOMwebError.tooManyRequests(retryAfter: nil).isTransient)
        
        #expect(!DICOMwebError.badRequest(message: nil).isTransient)
        #expect(!DICOMwebError.notFound(resource: nil).isTransient)
        #expect(!DICOMwebError.invalidJSON(reason: nil).isTransient)
    }
    
    @Test("isClientError identifies client errors")
    func testIsClientError() {
        #expect(DICOMwebError.badRequest(message: nil).isClientError)
        #expect(DICOMwebError.unauthorized(message: nil).isClientError)
        #expect(DICOMwebError.forbidden(message: nil).isClientError)
        #expect(DICOMwebError.notFound(resource: nil).isClientError)
        
        #expect(!DICOMwebError.internalServerError(message: nil).isClientError)
        #expect(!DICOMwebError.timeout(operation: nil).isClientError)
    }
    
    @Test("isServerError identifies server errors")
    func testIsServerError() {
        #expect(DICOMwebError.internalServerError(message: nil).isServerError)
        #expect(DICOMwebError.serviceUnavailable(retryAfter: nil).isServerError)
        #expect(DICOMwebError.gatewayTimeout(message: nil).isServerError)
        
        #expect(!DICOMwebError.badRequest(message: nil).isServerError)
        #expect(!DICOMwebError.timeout(operation: nil).isServerError)
    }
    
    @Test("retryAfter returns correct value")
    func testRetryAfter() {
        #expect(DICOMwebError.tooManyRequests(retryAfter: 30).retryAfter == 30)
        #expect(DICOMwebError.serviceUnavailable(retryAfter: 60).retryAfter == 60)
        #expect(DICOMwebError.badRequest(message: nil).retryAfter == nil)
    }
    
    // MARK: - Error Description Tests
    
    @Test("Error descriptions are meaningful")
    func testErrorDescriptions() {
        #expect(DICOMwebError.badRequest(message: nil).errorDescription == "Bad Request")
        #expect(DICOMwebError.badRequest(message: "Invalid UID").errorDescription == "Bad Request: Invalid UID")
        #expect(DICOMwebError.notFound(resource: "Study").errorDescription == "Not Found: Study")
        #expect(DICOMwebError.timeout(operation: "retrieve").errorDescription == "Timeout during retrieve")
        #expect(DICOMwebError.missingRequiredField(field: "vr").errorDescription == "Missing required field: vr")
        #expect(DICOMwebError.invalidFrameNumber(frame: 5, maxFrame: 3).errorDescription == "Invalid frame number 5. Maximum: 3")
    }
}

// MARK: - Equatable for testing

extension DICOMwebError: Equatable {
    public static func == (lhs: DICOMwebError, rhs: DICOMwebError) -> Bool {
        switch (lhs, rhs) {
        case (.badRequest(let l), .badRequest(let r)): return l == r
        case (.unauthorized(let l), .unauthorized(let r)): return l == r
        case (.forbidden(let l), .forbidden(let r)): return l == r
        case (.notFound(let l), .notFound(let r)): return l == r
        case (.conflict(let l), .conflict(let r)): return l == r
        case (.internalServerError(let l), .internalServerError(let r)): return l == r
        case (.notImplemented(let l), .notImplemented(let r)): return l == r
        case (.badGateway(let l), .badGateway(let r)): return l == r
        case (.gatewayTimeout(let l), .gatewayTimeout(let r)): return l == r
        case (.tooManyRequests(let l), .tooManyRequests(let r)): return l == r
        case (.serviceUnavailable(let l), .serviceUnavailable(let r)): return l == r
        case (.httpError(let lc, let lm), .httpError(let rc, let rm)): return lc == rc && lm == rm
        case (.notAcceptable, .notAcceptable): return true
        case (.payloadTooLarge, .payloadTooLarge): return true
        case (.unsupportedMediaType, .unsupportedMediaType): return true
        case (.unprocessableEntity, .unprocessableEntity): return true
        default: return false
        }
    }
}
