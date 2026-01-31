/// DICOMNetwork - DICOM Networking Support
///
/// This module provides DICOM networking capabilities for DICOMKit,
/// implementing the DICOM Upper Layer Protocol.
///
/// Reference: DICOM PS3.8 - Network Communication Support
///
/// ## Overview
///
/// DICOMNetwork provides types and protocols for DICOM network communication,
/// including Protocol Data Units (PDUs) for association management and data transfer.
///
/// ## Milestone 6.1 - Core Networking Infrastructure
///
/// This initial version includes:
/// - PDU type definitions for all DICOM Upper Layer Protocol messages
/// - Association PDUs: A-ASSOCIATE-RQ, A-ASSOCIATE-AC, A-ASSOCIATE-RJ
/// - Release PDUs: A-RELEASE-RQ, A-RELEASE-RP
/// - Data Transfer: P-DATA-TF
/// - Abort: A-ABORT
/// - Presentation Context structures for negotiation
/// - AE Title handling
/// - PDU encoding and decoding
/// - Error types for network operations
///
/// ## Usage
///
/// ```swift
/// import DICOMNetwork
///
/// // Create presentation contexts for negotiation
/// let context = try PresentationContext(
///     id: 1,
///     abstractSyntax: "1.2.840.10008.5.1.4.1.1.7",  // Secondary Capture
///     transferSyntaxes: ["1.2.840.10008.1.2.1"]      // Explicit VR LE
/// )
///
/// // Create an association request
/// let request = AssociateRequestPDU(
///     calledAETitle: try AETitle("PACS_SERVER"),
///     callingAETitle: try AETitle("MY_CLIENT"),
///     presentationContexts: [context],
///     implementationClassUID: "1.2.3.4.5.6.7.8.9"
/// )
///
/// // Encode for transmission
/// let data = try request.encode()
/// ```

// MARK: - PDU Types
@_exported import Foundation

// Re-export all public types
