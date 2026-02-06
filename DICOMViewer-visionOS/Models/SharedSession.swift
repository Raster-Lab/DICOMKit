// SharedSession.swift
// DICOMViewer visionOS - SharePlay Collaborative Session
//
// Copyright 2024 DICOMKit. All rights reserved.
// SPDX-License-Identifier: MIT

import Foundation
import GroupActivities

/// SharePlay collaborative viewing session
@Observable
final class SharedSession: Identifiable, Sendable {
    let id: UUID
    let groupSession: GroupSession<DICOMViewingActivity>?
    var participants: [UserPresence]
    var isActive: Bool
    var currentStudyID: UUID?
    var synchronizedState: SessionState
    let createdAt: Date
    
    struct SessionState: Codable, Sendable {
        var studyInstanceUID: String?
        var seriesInstanceUID: String?
        var currentFrameIndex: Int
        var windowCenter: Double
        var windowWidth: Double
        var immersiveMode: Bool
        var volumeTransform: Transform3D?
    }
    
    struct Transform3D: Codable, Sendable {
        var position: [Float]  // 3 values
        var rotation: [Float]  // 4 values (quaternion)
        var scale: [Float]     // 3 values
    }
    
    init(
        id: UUID = UUID(),
        groupSession: GroupSession<DICOMViewingActivity>? = nil,
        participants: [UserPresence] = [],
        isActive: Bool = false,
        currentStudyID: UUID? = nil,
        synchronizedState: SessionState = SessionState(currentFrameIndex: 0, windowCenter: 0, windowWidth: 0, immersiveMode: false),
        createdAt: Date = Date()
    ) {
        self.id = id
        self.groupSession = groupSession
        self.participants = participants
        self.isActive = isActive
        self.currentStudyID = currentStudyID
        self.synchronizedState = synchronizedState
        self.createdAt = createdAt
    }
}

/// GroupActivity for SharePlay
struct DICOMViewingActivity: GroupActivity {
    static let activityIdentifier = "com.dicomkit.viewer.visionos.viewing"
    
    var metadata: GroupActivityMetadata {
        var metadata = GroupActivityMetadata()
        metadata.title = "DICOM Viewing Session"
        metadata.type = .generic
        return metadata
    }
}
