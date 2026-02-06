import Testing
import Foundation
@testable import DICOMWeb
@testable import DICOMKit
@testable import DICOMCore

// MARK: - Server Cache Middleware Tests

@Suite("Server Cache Middleware Tests")
struct ServerCacheMiddlewareTests {

    // MARK: - Basic Configuration

    @Test("Cache disabled returns nil for cached response")
    func testCacheDisabled() async throws {
        let middleware = ServerCacheMiddleware(configuration: .disabled)

        let request = DICOMwebRequest(
            method: .get,
            path: "/dicom-web/studies",
            headers: [:]
        )

        let cached = await middleware.cachedResponse(for: request)
        #expect(cached == nil)
    }

    @Test("Cache enabled returns nil on first request (cache miss)")
    func testCacheMissOnFirstRequest() async throws {
        let middleware = ServerCacheMiddleware(configuration: .default)

        let request = DICOMwebRequest(
            method: .get,
            path: "/dicom-web/studies",
            headers: [:]
        )

        let cached = await middleware.cachedResponse(for: request)
        #expect(cached == nil)
    }

    @Test("POST requests are not cached")
    func testPostNotCached() async throws {
        let middleware = ServerCacheMiddleware(configuration: .default)

        let request = DICOMwebRequest(
            method: .post,
            path: "/dicom-web/studies",
            headers: [:]
        )

        let cached = await middleware.cachedResponse(for: request)
        #expect(cached == nil)
    }

    // MARK: - Cache Hit/Miss Flow

    @Test("Cache stores and returns responses for GET requests")
    func testCacheStoreAndRetrieve() async throws {
        let middleware = ServerCacheMiddleware(configuration: .default)

        let request = DICOMwebRequest(
            method: .get,
            path: "/dicom-web/studies",
            headers: [:]
        )

        let responseBody = "[{\"test\": \"data\"}]".data(using: .utf8)!
        let originalResponse = DICOMwebResponse.ok(
            json: responseBody
        )

        // Cache the response
        let cachedResponse = await middleware.cacheResponse(originalResponse, for: request)
        #expect(cachedResponse.statusCode == 200)
        #expect(cachedResponse.headers["ETag"] != nil)
        #expect(cachedResponse.headers["Cache-Control"] != nil)
        #expect(cachedResponse.headers["X-Cache"] == "MISS")

        // Second request should hit cache
        let cachedResult = await middleware.cachedResponse(for: request)
        #expect(cachedResult != nil)
        #expect(cachedResult?.statusCode == 200)
        #expect(cachedResult?.headers["X-Cache"] == "HIT")
        #expect(cachedResult?.body == responseBody)
    }

    @Test("Cache key includes query parameters")
    func testCacheKeyWithQueryParams() async throws {
        let middleware = ServerCacheMiddleware(configuration: .default)

        let request1 = DICOMwebRequest(
            method: .get,
            path: "/dicom-web/studies",
            queryParameters: ["PatientName": "Smith"]
        )
        let request2 = DICOMwebRequest(
            method: .get,
            path: "/dicom-web/studies",
            queryParameters: ["PatientName": "Jones"]
        )

        let body = "[{\"test\": \"data\"}]".data(using: .utf8)!
        let response = DICOMwebResponse.ok(json: body)

        // Cache response for request1
        _ = await middleware.cacheResponse(response, for: request1)

        // request2 should miss (different query params)
        let cached2 = await middleware.cachedResponse(for: request2)
        #expect(cached2 == nil)

        // request1 should hit
        let cached1 = await middleware.cachedResponse(for: request1)
        #expect(cached1 != nil)
    }

    @Test("Cache key includes Accept header")
    func testCacheKeyWithAcceptHeader() async throws {
        let middleware = ServerCacheMiddleware(configuration: .default)

        let request1 = DICOMwebRequest(
            method: .get,
            path: "/dicom-web/studies/1.2.3/metadata",
            headers: ["Accept": "application/dicom+json"]
        )
        let request2 = DICOMwebRequest(
            method: .get,
            path: "/dicom-web/studies/1.2.3/metadata",
            headers: ["Accept": "application/dicom+xml"]
        )

        let body = "[{\"test\": \"data\"}]".data(using: .utf8)!
        let response = DICOMwebResponse.ok(json: body)

        // Cache response for request1
        _ = await middleware.cacheResponse(response, for: request1)

        // request2 should miss (different Accept header)
        let cached2 = await middleware.cachedResponse(for: request2)
        #expect(cached2 == nil)
    }

    // MARK: - Conditional Requests (If-None-Match)

    @Test("If-None-Match returns 304 when ETag matches")
    func testIfNoneMatchReturns304() async throws {
        let middleware = ServerCacheMiddleware(configuration: .default)

        let request = DICOMwebRequest(
            method: .get,
            path: "/dicom-web/studies",
            headers: [:]
        )

        let body = "[{\"test\": \"data\"}]".data(using: .utf8)!
        let response = DICOMwebResponse.ok(json: body)

        // Cache the response and get the ETag
        let cachedResponse = await middleware.cacheResponse(response, for: request)
        let etag = cachedResponse.headers["ETag"]!

        // Send conditional request with matching ETag
        let conditionalRequest = DICOMwebRequest(
            method: .get,
            path: "/dicom-web/studies",
            headers: ["If-None-Match": etag]
        )

        let result = await middleware.cachedResponse(for: conditionalRequest)
        #expect(result != nil)
        #expect(result?.statusCode == 304)
        #expect(result?.body == nil)
        #expect(result?.headers["ETag"] != nil)
    }

    @Test("If-None-Match with non-matching ETag returns cached response")
    func testIfNoneMatchMismatch() async throws {
        let middleware = ServerCacheMiddleware(configuration: .default)

        let request = DICOMwebRequest(
            method: .get,
            path: "/dicom-web/studies",
            headers: [:]
        )

        let body = "[{\"test\": \"data\"}]".data(using: .utf8)!
        let response = DICOMwebResponse.ok(json: body)

        // Cache the response
        _ = await middleware.cacheResponse(response, for: request)

        // Send conditional request with non-matching ETag
        let conditionalRequest = DICOMwebRequest(
            method: .get,
            path: "/dicom-web/studies",
            headers: ["If-None-Match": "W/\"invalid_etag\""]
        )

        let result = await middleware.cachedResponse(for: conditionalRequest)
        #expect(result != nil)
        #expect(result?.statusCode == 200)
        #expect(result?.body == body)
    }

    @Test("If-None-Match with wildcard returns 304 for any cached response")
    func testIfNoneMatchWildcard() async throws {
        let middleware = ServerCacheMiddleware(configuration: .default)

        let request = DICOMwebRequest(
            method: .get,
            path: "/dicom-web/studies",
            headers: [:]
        )

        let body = "[{\"test\": \"data\"}]".data(using: .utf8)!
        let response = DICOMwebResponse.ok(json: body)

        // Cache the response
        _ = await middleware.cacheResponse(response, for: request)

        // Send conditional request with wildcard ETag
        let conditionalRequest = DICOMwebRequest(
            method: .get,
            path: "/dicom-web/studies",
            headers: ["If-None-Match": "*"]
        )

        let result = await middleware.cachedResponse(for: conditionalRequest)
        #expect(result != nil)
        #expect(result?.statusCode == 304)
    }

    // MARK: - Cache Invalidation

    @Test("Invalidate all clears cache")
    func testInvalidateAll() async throws {
        let middleware = ServerCacheMiddleware(configuration: .default)

        let request = DICOMwebRequest(
            method: .get,
            path: "/dicom-web/studies",
            headers: [:]
        )

        let body = "[{\"test\": \"data\"}]".data(using: .utf8)!
        let response = DICOMwebResponse.ok(json: body)

        _ = await middleware.cacheResponse(response, for: request)

        // Verify cached
        let cached = await middleware.cachedResponse(for: request)
        #expect(cached != nil)

        // Invalidate all
        await middleware.invalidateAll()

        // Should miss now
        let afterInvalidate = await middleware.cachedResponse(for: request)
        #expect(afterInvalidate == nil)
    }

    @Test("Invalidate by study UID clears cache")
    func testInvalidateByStudyUID() async throws {
        let middleware = ServerCacheMiddleware(configuration: .default)

        let request = DICOMwebRequest(
            method: .get,
            path: "/dicom-web/studies/1.2.3",
            headers: [:]
        )

        let body = "[{\"test\": \"data\"}]".data(using: .utf8)!
        let response = DICOMwebResponse.ok(json: body)

        _ = await middleware.cacheResponse(response, for: request)

        // Invalidate by study UID
        await middleware.invalidate(studyUID: "1.2.3")

        // Should miss now
        let afterInvalidate = await middleware.cachedResponse(for: request)
        #expect(afterInvalidate == nil)
    }

    // MARK: - Cache Statistics

    @Test("Cache statistics track hits and misses")
    func testCacheStatistics() async throws {
        let middleware = ServerCacheMiddleware(configuration: .default)

        let request = DICOMwebRequest(
            method: .get,
            path: "/dicom-web/studies",
            headers: [:]
        )

        // First access - miss
        _ = await middleware.cachedResponse(for: request)

        let body = "[{\"test\": \"data\"}]".data(using: .utf8)!
        let response = DICOMwebResponse.ok(json: body)
        _ = await middleware.cacheResponse(response, for: request)

        // Second access - hit
        _ = await middleware.cachedResponse(for: request)

        let stats = await middleware.statistics()
        #expect(stats.entryCount == 1)
        #expect(stats.hits >= 1)
        #expect(stats.misses >= 1)
    }

    // MARK: - Response Header Tests

    @Test("Cached response includes ETag header")
    func testCachedResponseHasETag() async throws {
        let middleware = ServerCacheMiddleware(configuration: .default)

        let request = DICOMwebRequest(method: .get, path: "/dicom-web/studies")

        let body = "[{\"study\": \"test\"}]".data(using: .utf8)!
        let response = DICOMwebResponse.ok(json: body)

        let result = await middleware.cacheResponse(response, for: request)
        #expect(result.headers["ETag"] != nil)
        #expect(result.headers["ETag"]!.hasPrefix("W/\""))
    }

    @Test("Cached response includes Cache-Control header")
    func testCachedResponseHasCacheControl() async throws {
        let config = CacheConfiguration(defaultTTL: 600)
        let middleware = ServerCacheMiddleware(configuration: config)

        let request = DICOMwebRequest(method: .get, path: "/dicom-web/studies")

        let body = "[{\"study\": \"test\"}]".data(using: .utf8)!
        let response = DICOMwebResponse.ok(json: body)

        let result = await middleware.cacheResponse(response, for: request)
        #expect(result.headers["Cache-Control"] == "public, max-age=600")
    }

    // MARK: - Non-cacheable Responses

    @Test("Non-200 responses are not cached")
    func testNon200NotCached() async throws {
        let middleware = ServerCacheMiddleware(configuration: .default)

        let request = DICOMwebRequest(method: .get, path: "/dicom-web/studies/1.2.3")

        let response = DICOMwebResponse.notFound(message: "Not found")
        let result = await middleware.cacheResponse(response, for: request)

        // Response should pass through unchanged
        #expect(result.statusCode == 404)
        #expect(result.headers["ETag"] == nil)

        // Should not be in cache
        let cached = await middleware.cachedResponse(for: request)
        #expect(cached == nil)
    }

    @Test("Responses without body are not cached")
    func testEmptyBodyNotCached() async throws {
        let middleware = ServerCacheMiddleware(configuration: .default)

        let request = DICOMwebRequest(method: .get, path: "/dicom-web/studies")

        let response = DICOMwebResponse.noContent()
        let result = await middleware.cacheResponse(response, for: request)

        #expect(result.headers["ETag"] == nil)
    }

    @Test("POST responses are not cached")
    func testPostResponseNotCached() async throws {
        let middleware = ServerCacheMiddleware(configuration: .default)

        let request = DICOMwebRequest(method: .post, path: "/dicom-web/studies")

        let body = "[{\"test\": \"data\"}]".data(using: .utf8)!
        let response = DICOMwebResponse(
            statusCode: 200,
            headers: ["Content-Type": "application/dicom+json"],
            body: body
        )

        let result = await middleware.cacheResponse(response, for: request)
        #expect(result.headers["ETag"] == nil)
    }
}

// MARK: - Server-Side Caching Integration Tests

@Suite("Server-Side Caching Integration Tests")
struct ServerCachingIntegrationTests {

    @Test("Server with caching enabled returns cached responses")
    func testServerCacheHit() async throws {
        let config = DICOMwebServerConfiguration(
            cacheConfiguration: .default
        )
        let storage = InMemoryStorageProvider()
        let server = DICOMwebServer(configuration: config, storage: storage)

        let request = DICOMwebRequest(
            method: .get,
            path: "/dicom-web/studies"
        )

        // First request - cache miss
        let response1 = await server.handleRequest(request)
        #expect(response1.statusCode == 200)
        #expect(response1.headers["X-Cache"] == "MISS")
        #expect(response1.headers["ETag"] != nil)

        // Second request - cache hit
        let response2 = await server.handleRequest(request)
        #expect(response2.statusCode == 200)
        #expect(response2.headers["X-Cache"] == "HIT")
    }

    @Test("Server without caching does not add cache headers")
    func testServerNoCaching() async throws {
        let config = DICOMwebServerConfiguration(
            cacheConfiguration: .disabled
        )
        let storage = InMemoryStorageProvider()
        let server = DICOMwebServer(configuration: config, storage: storage)

        let request = DICOMwebRequest(
            method: .get,
            path: "/dicom-web/studies"
        )

        let response = await server.handleRequest(request)
        #expect(response.statusCode == 200)
        #expect(response.headers["X-Cache"] == nil)
        #expect(response.headers["ETag"] == nil)
    }

    @Test("Server caching invalidated on POST")
    func testServerCacheInvalidatedOnPost() async throws {
        let config = DICOMwebServerConfiguration(
            cacheConfiguration: .default
        )
        let storage = InMemoryStorageProvider()
        let server = DICOMwebServer(configuration: config, storage: storage)

        // GET to populate cache
        let getRequest = DICOMwebRequest(
            method: .get,
            path: "/dicom-web/studies"
        )
        _ = await server.handleRequest(getRequest)

        // POST to invalidate cache (will fail since no body, but cache should still be invalidated)
        let postRequest = DICOMwebRequest(
            method: .post,
            path: "/dicom-web/studies",
            headers: ["Content-Type": "multipart/related; boundary=test"],
            body: Data()
        )
        _ = await server.handleRequest(postRequest)

        // GET again should be a miss
        let response = await server.handleRequest(getRequest)
        #expect(response.headers["X-Cache"] == "MISS")
    }

    @Test("Server handles If-None-Match conditional request")
    func testServerConditionalRequest() async throws {
        let config = DICOMwebServerConfiguration(
            cacheConfiguration: .default
        )
        let storage = InMemoryStorageProvider()
        let server = DICOMwebServer(configuration: config, storage: storage)

        // First GET to populate cache
        let request1 = DICOMwebRequest(
            method: .get,
            path: "/dicom-web/studies"
        )
        let response1 = await server.handleRequest(request1)
        let etag = response1.headers["ETag"]!

        // Conditional GET with matching ETag
        let request2 = DICOMwebRequest(
            method: .get,
            path: "/dicom-web/studies",
            headers: ["If-None-Match": etag]
        )
        let response2 = await server.handleRequest(request2)
        #expect(response2.statusCode == 304)
        #expect(response2.body == nil)
    }

    @Test("Server caching invalidated on DELETE")
    func testServerCacheInvalidatedOnDelete() async throws {
        let config = DICOMwebServerConfiguration(
            cacheConfiguration: .default
        )
        let storage = InMemoryStorageProvider()
        let server = DICOMwebServer(configuration: config, storage: storage)

        // GET to populate cache
        let getRequest = DICOMwebRequest(
            method: .get,
            path: "/dicom-web/studies"
        )
        _ = await server.handleRequest(getRequest)

        // Verify cache hit
        let response2 = await server.handleRequest(getRequest)
        #expect(response2.headers["X-Cache"] == "HIT")

        // DELETE to invalidate
        let deleteRequest = DICOMwebRequest(
            method: .delete,
            path: "/dicom-web/studies/1.2.3.4"
        )
        _ = await server.handleRequest(deleteRequest)

        // GET again should be a miss
        let response3 = await server.handleRequest(getRequest)
        #expect(response3.headers["X-Cache"] == "MISS")
    }
}

// MARK: - 304 Not Modified Response Tests

@Suite("304 Not Modified Response Tests")
struct NotModifiedResponseTests {

    @Test("304 Not Modified factory method")
    func testNotModifiedResponse() {
        let response = DICOMwebResponse.notModified(etag: "W/\"test123\"")

        #expect(response.statusCode == 304)
        #expect(response.headers["ETag"] == "W/\"test123\"")
        #expect(response.body == nil)
    }

    @Test("304 Not Modified without ETag")
    func testNotModifiedWithoutETag() {
        let response = DICOMwebResponse.notModified()

        #expect(response.statusCode == 304)
        #expect(response.headers["ETag"] == nil)
        #expect(response.body == nil)
    }
}
