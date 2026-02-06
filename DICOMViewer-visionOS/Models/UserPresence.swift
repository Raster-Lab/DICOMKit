// UserPresence.swift
// DICOMViewer visionOS - Collaborative User Presence
//
// Copyright 2024 DICOMKit. All rights reserved.
// SPDX-License-Identifier: MIT

import Foundation
import simd

/// User presence in collaborative session
@Observable
final class UserPresence: Identifiable, Sendable {
    let id: UUID
    let userID: String
    let userName: String
    var avatarColor: String
    var handPositions: HandPositions?
    var gazeDirection: simd_float3?
    var isActive: Bool
    let joinedAt: Date
    
    struct HandPositions: Sendable {
        var leftHand: simd_float3?
        var rightHand: simd_float3?
    }
    
    init(
        id: UUID = UUID(),
        userID: String,
        userName: String,
        avatarColor: String = "#0000FF",
        handPositions: HandPositions? = nil,
        gazeDirection: simd_float3? = nil,
        isActive: Bool = true,
        joinedAt: Date = Date()
    ) {
        self.id = id
        self.userID = userID
        self.userName = userName
        self.avatarColor = avatarColor
        self.handPositions = handPositions
        self.gazeDirection = gazeDirection
        self.isActive = isActive
        self.joinedAt = joinedAt
    }
}
