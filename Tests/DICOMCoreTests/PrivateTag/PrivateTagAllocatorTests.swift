import XCTest
@testable import DICOMCore

final class PrivateTagAllocatorTests: XCTestCase {
    // MARK: - Basic Allocation
    
    func test_allocateBlock_allocatesFirstBlock() async throws {
        let allocator = PrivateTagAllocator()
        
        let creator = try await allocator.allocateBlock(creatorID: "TEST", in: 0x0009)
        
        XCTAssertNotNil(creator)
        XCTAssertEqual(creator?.creatorID, "TEST")
        XCTAssertEqual(creator?.group, 0x0009)
        XCTAssertEqual(creator?.element, 0x0010)
        XCTAssertEqual(creator?.blockNumber, 0x00)
    }
    
    func test_allocateBlock_allocatesMultipleBlocks() async throws {
        let allocator = PrivateTagAllocator()
        
        let creator1 = try await allocator.allocateBlock(creatorID: "TEST1", in: 0x0009)
        let creator2 = try await allocator.allocateBlock(creatorID: "TEST2", in: 0x0009)
        
        XCTAssertEqual(creator1?.element, 0x0010)
        XCTAssertEqual(creator2?.element, 0x0011)
    }
    
    func test_allocateBlock_returnsExistingForSameCreator() async throws {
        let allocator = PrivateTagAllocator()
        
        let creator1 = try await allocator.allocateBlock(creatorID: "TEST", in: 0x0009)
        let creator2 = try await allocator.allocateBlock(creatorID: "TEST", in: 0x0009)
        
        XCTAssertEqual(creator1?.element, creator2?.element)
    }
    
    func test_allocateBlock_throwsForEvenGroup() async {
        let allocator = PrivateTagAllocator()
        
        do {
            _ = try await allocator.allocateBlock(creatorID: "TEST", in: 0x0008)
            XCTFail("Expected error for even group")
        } catch let error as PrivateTagError {
            if case .invalidGroup(let group) = error {
                XCTAssertEqual(group, 0x0008)
            } else {
                XCTFail("Wrong error type")
            }
        } catch {
            XCTFail("Wrong error type")
        }
    }
    
    func test_allocateBlock_returnsNilWhenFull() async throws {
        let allocator = PrivateTagAllocator()
        
        // Allocate all 240 blocks (0x0010-0x00FF)
        for i in 0..<240 {
            _ = try await allocator.allocateBlock(creatorID: "TEST\(i)", in: 0x0009)
        }
        
        // Try to allocate one more
        let creator = try await allocator.allocateBlock(creatorID: "OVERFLOW", in: 0x0009)
        XCTAssertNil(creator)
    }
    
    // MARK: - Get or Allocate
    
    func test_getOrAllocateBlock_returnsExisting() async throws {
        let allocator = PrivateTagAllocator()
        
        _ = try await allocator.allocateBlock(creatorID: "TEST", in: 0x0009)
        let creator = try await allocator.getOrAllocateBlock(creatorID: "TEST", in: 0x0009)
        
        XCTAssertEqual(creator.element, 0x0010)
    }
    
    func test_getOrAllocateBlock_allocatesNew() async throws {
        let allocator = PrivateTagAllocator()
        
        let creator = try await allocator.getOrAllocateBlock(creatorID: "TEST", in: 0x0009)
        
        XCTAssertEqual(creator.element, 0x0010)
    }
    
    func test_getOrAllocateBlock_throwsWhenFull() async throws {
        let allocator = PrivateTagAllocator()
        
        // Fill all blocks
        for i in 0..<240 {
            _ = try await allocator.allocateBlock(creatorID: "TEST\(i)", in: 0x0009)
        }
        
        do {
            _ = try await allocator.getOrAllocateBlock(creatorID: "OVERFLOW", in: 0x0009)
            XCTFail("Expected error when no blocks available")
        } catch let error as PrivateTagError {
            if case .noBlocksAvailable(let group) = error {
                XCTAssertEqual(group, 0x0009)
            } else {
                XCTFail("Wrong error type")
            }
        }
    }
    
    // MARK: - Create Tag
    
    func test_privateTag_createsCorrectTag() async throws {
        let creator = PrivateCreator(creatorID: "TEST", group: 0x0009, element: 0x0010)
        let allocator = PrivateTagAllocator()
        
        let tag = try await allocator.createTag(creator: creator, offset: 0x20)
        
        XCTAssertEqual(tag.group, 0x0009)
        XCTAssertEqual(tag.element, 0x1020) // block 0x10, offset 0x20
    }
    
    func test_createTag_throwsForInvalidOffset() async throws {
        let creator = PrivateCreator(creatorID: "TEST", group: 0x0009, element: 0x0010)
        let allocator = PrivateTagAllocator()
        
        // All offsets are now valid (0x00-0xFF)
        let tag = try await allocator.createTag(creator: creator, offset: 0x00)
        XCTAssertNotNil(tag)
    }
    
    // MARK: - Creator Lookup
    
    func test_creator_findsAllocatedCreator() async throws {
        let allocator = PrivateTagAllocator()
        
        let allocated = try await allocator.allocateBlock(creatorID: "TEST", in: 0x0009)
        let tag = allocated!.privateTag(offset: 0x20)!
        
        let found = await allocator.creator(for: tag)
        
        XCTAssertEqual(found?.creatorID, "TEST")
    }
    
    func test_creator_returnsNilForNonPrivateTag() async {
        let allocator = PrivateTagAllocator()
        let tag = Tag(group: 0x0008, element: 0x0020)
        
        let creator = await allocator.creator(for: tag)
        
        XCTAssertNil(creator)
    }
    
    func test_creator_returnsNilForUnallocatedTag() async {
        let allocator = PrivateTagAllocator()
        let tag = Tag(group: 0x0009, element: 0x1020) // block 0x10
        
        let creator = await allocator.creator(for: tag)
        
        XCTAssertNil(creator)
    }
    
    // MARK: - Reset
    
    func test_reset_clearsAllocations() async throws {
        let allocator = PrivateTagAllocator()
        
        _ = try await allocator.allocateBlock(creatorID: "TEST1", in: 0x0009)
        _ = try await allocator.allocateBlock(creatorID: "TEST2", in: 0x0009)
        
        await allocator.reset()
        
        let tag = Tag(group: 0x0009, element: 0x1020)
        let creator = await allocator.creator(for: tag)
        XCTAssertNil(creator)
    }
    
    func test_reset_allowsReallocation() async throws {
        let allocator = PrivateTagAllocator()
        
        _ = try await allocator.allocateBlock(creatorID: "TEST1", in: 0x0009)
        await allocator.reset()
        
        let creator = try await allocator.allocateBlock(creatorID: "TEST2", in: 0x0009)
        
        XCTAssertEqual(creator?.element, 0x0010)
        XCTAssertEqual(creator?.creatorID, "TEST2")
    }
    
    // MARK: - Creators in Group
    
    func test_creators_returnsAllInGroup() async throws {
        let allocator = PrivateTagAllocator()
        
        _ = try await allocator.allocateBlock(creatorID: "TEST1", in: 0x0009)
        _ = try await allocator.allocateBlock(creatorID: "TEST2", in: 0x0009)
        _ = try await allocator.allocateBlock(creatorID: "TEST3", in: 0x000B)
        
        let creators = await allocator.creators(in: 0x0009)
        
        XCTAssertEqual(creators.count, 2)
        XCTAssertTrue(creators.contains(where: { $0.creatorID == "TEST1" }))
        XCTAssertTrue(creators.contains(where: { $0.creatorID == "TEST2" }))
    }
    
    func test_creators_returnsEmptyForUnusedGroup() async {
        let allocator = PrivateTagAllocator()
        
        let creators = await allocator.creators(in: 0x0009)
        
        XCTAssertTrue(creators.isEmpty)
    }
}
