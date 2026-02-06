// SharePlayManager.swift
// DICOMViewer visionOS - SharePlay Management Service
//
// Copyright 2024 DICOMKit. All rights reserved.
// SPDX-License-Identifier: MIT

import Foundation
import GroupActivities

/// Manager for SharePlay collaborative sessions
@MainActor
final class SharePlayManager: ObservableObject {
    @Published var session: SharedSession?
    @Published var isActive = false
    
    /// Start a new SharePlay session
    func startSession() async throws {
        let activity = DICOMViewingActivity()
        
        // Placeholder: Would actually start GroupActivity session
        let newSession = SharedSession(isActive: true)
        session = newSession
        isActive = true
    }
    
    /// End the current session
    func endSession() {
        session = nil
        isActive = false
    }
    
    /// Broadcast state update to all participants
    func broadcastState(_ state: SharedSession.SessionState) {
        session?.synchronizedState = state
    }
    
    /// Handle participant joining
    func handleParticipantJoined(_ participant: UserPresence) {
        session?.participants.append(participant)
    }
    
    /// Handle participant leaving
    func handleParticipantLeft(_ participantID: UUID) {
        session?.participants.removeAll { $0.id == participantID }
    }
}
