//
//  DownloadManagerTests.swift
//  DICOMViewer macOS Tests
//
//  Created by DICOMKit Team on 2026-02-06.
//  Copyright © 2026 Raster Lab. All rights reserved.
//

import XCTest
@testable import DICOMViewer

final class DownloadManagerTests: XCTestCase {
    var manager: DownloadManager!
    
    override func setUp() async throws {
        manager = DownloadManager()
    }
    
    func testEnqueueItem() async {
        let id = await manager.enqueue(
            serverName: "Test PACS",
            studyDescription: "CT Chest",
            patientName: "Doe^John",
            studyInstanceUID: "1.2.3.4.5"
        )
        
        let items = await manager.allItems
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.id, id)
        XCTAssertEqual(items.first?.status, .queued)
        XCTAssertEqual(items.first?.patientName, "Doe^John")
    }
    
    func testMarkStarted() async {
        let id = await manager.enqueue(
            serverName: "Test",
            studyDescription: "Study",
            patientName: "Patient",
            studyInstanceUID: "1.2.3"
        )
        
        await manager.markStarted(id: id)
        
        let items = await manager.allItems
        XCTAssertEqual(items.first?.status, .downloading)
        XCTAssertNotNil(items.first?.startTime)
    }
    
    func testMarkCompleted() async {
        let id = await manager.enqueue(
            serverName: "Test",
            studyDescription: "Study",
            patientName: "Patient",
            studyInstanceUID: "1.2.3"
        )
        
        await manager.markStarted(id: id)
        await manager.markCompleted(id: id)
        
        let items = await manager.allItems
        XCTAssertEqual(items.first?.status, .completed)
        XCTAssertEqual(items.first?.progress, 1.0)
        XCTAssertNotNil(items.first?.endTime)
    }
    
    func testMarkFailed() async {
        let id = await manager.enqueue(
            serverName: "Test",
            studyDescription: "Study",
            patientName: "Patient",
            studyInstanceUID: "1.2.3"
        )
        
        await manager.markStarted(id: id)
        await manager.markFailed(id: id, error: "Connection timeout")
        
        let items = await manager.allItems
        XCTAssertEqual(items.first?.status, .failed)
        XCTAssertEqual(items.first?.error, "Connection timeout")
    }
    
    func testCancelDownload() async {
        let id = await manager.enqueue(
            serverName: "Test",
            studyDescription: "Study",
            patientName: "Patient",
            studyInstanceUID: "1.2.3"
        )
        
        await manager.markStarted(id: id)
        await manager.cancel(id: id)
        
        let items = await manager.allItems
        XCTAssertEqual(items.first?.status, .cancelled)
    }
    
    func testUpdateProgress() async {
        let id = await manager.enqueue(
            serverName: "Test",
            studyDescription: "Study",
            patientName: "Patient",
            studyInstanceUID: "1.2.3"
        )
        
        await manager.updateProgress(id: id, progress: 0.5, completed: 50, total: 100)
        
        let items = await manager.allItems
        XCTAssertEqual(items.first?.progress, 0.5)
        XCTAssertEqual(items.first?.completedInstances, 50)
        XCTAssertEqual(items.first?.totalInstances, 100)
    }
    
    func testClearFinished() async {
        let id1 = await manager.enqueue(serverName: "T", studyDescription: "S", patientName: "P1", studyInstanceUID: "1")
        let _ = await manager.enqueue(serverName: "T", studyDescription: "S", patientName: "P2", studyInstanceUID: "2")
        
        await manager.markStarted(id: id1)
        await manager.markCompleted(id: id1)
        
        await manager.clearFinished()
        
        let items = await manager.allItems
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.patientName, "P2")
    }
    
    func testRemoveItem() async {
        let id = await manager.enqueue(serverName: "T", studyDescription: "S", patientName: "P", studyInstanceUID: "1")
        
        await manager.remove(id: id)
        
        let items = await manager.allItems
        XCTAssertTrue(items.isEmpty)
    }
    
    func testMultipleItems() async {
        await manager.enqueue(serverName: "T1", studyDescription: "S1", patientName: "P1", studyInstanceUID: "1")
        await manager.enqueue(serverName: "T2", studyDescription: "S2", patientName: "P2", studyInstanceUID: "2")
        await manager.enqueue(serverName: "T3", studyDescription: "S3", patientName: "P3", studyInstanceUID: "3")
        
        let count = await manager.totalCount
        XCTAssertEqual(count, 3)
    }
    
    func testActiveCount() async {
        let id1 = await manager.enqueue(serverName: "T", studyDescription: "S", patientName: "P1", studyInstanceUID: "1")
        let id2 = await manager.enqueue(serverName: "T", studyDescription: "S", patientName: "P2", studyInstanceUID: "2")
        await manager.enqueue(serverName: "T", studyDescription: "S", patientName: "P3", studyInstanceUID: "3")
        
        await manager.markStarted(id: id1)
        await manager.markStarted(id: id2)
        
        let activeCount = await manager.activeCount
        XCTAssertEqual(activeCount, 2)
    }
    
    func testCanStartMore() async {
        let id1 = await manager.enqueue(serverName: "T", studyDescription: "S", patientName: "P1", studyInstanceUID: "1")
        let id2 = await manager.enqueue(serverName: "T", studyDescription: "S", patientName: "P2", studyInstanceUID: "2")
        
        await manager.markStarted(id: id1)
        var canStart = await manager.canStartMore
        XCTAssertTrue(canStart)
        
        await manager.markStarted(id: id2)
        canStart = await manager.canStartMore
        XCTAssertFalse(canStart)
    }
    
    func testEnqueueWithSeriesUID() async {
        let id = await manager.enqueue(
            serverName: "Test",
            studyDescription: "CT",
            patientName: "Patient",
            studyInstanceUID: "1.2.3",
            seriesInstanceUID: "1.2.3.4"
        )
        
        let items = await manager.allItems
        XCTAssertEqual(items.first?.seriesInstanceUID, "1.2.3.4")
    }
    
    func testDownloadItemElapsedTime() {
        var item = DownloadManager.DownloadItem(
            serverName: "Test",
            studyDescription: "CT",
            patientName: "Patient",
            studyInstanceUID: "1.2.3"
        )
        
        // No start time = no elapsed time
        XCTAssertNil(item.elapsedTime)
        
        // With start time
        item.startTime = Date().addingTimeInterval(-60)
        let elapsed = item.elapsedTime
        XCTAssertNotNil(elapsed)
        XCTAssertGreaterThan(elapsed ?? 0, 50)
    }
    
    func testQueuedItemCounts() async {
        let id1 = await manager.enqueue(serverName: "T", studyDescription: "S", patientName: "P1", studyInstanceUID: "1")
        let id2 = await manager.enqueue(serverName: "T", studyDescription: "S", patientName: "P2", studyInstanceUID: "2")
        await manager.enqueue(serverName: "T", studyDescription: "S", patientName: "P3", studyInstanceUID: "3")
        
        await manager.markStarted(id: id1)
        await manager.markCompleted(id: id1)
        await manager.markStarted(id: id2)
        await manager.markFailed(id: id2, error: "Error")
        
        let completedCount = await manager.completedCount
        let failedCount = await manager.failedCount
        let queuedCount = await manager.queuedCount
        
        XCTAssertEqual(completedCount, 1)
        XCTAssertEqual(failedCount, 1)
        XCTAssertEqual(queuedCount, 1)
    }
}
