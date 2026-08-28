// ViewerContentKind.swift
// DICOMStudio
//
// DICOM Studio — what kind of thing an instance is, from the viewer's point of view.
//
// A study is not only pictures. Reports, encapsulated documents, key object
// selections and presentation states all sit in the same study and the same
// series pane, and until the viewer can name them it treats each one as a
// picture it failed to decode — which is how a perfectly valid SR ends up
// reported as an "unsupported transfer syntax".

import Foundation
import DICOMKit

/// The kind of content an instance holds.
public enum ViewerContentKind: String, Sendable, Equatable, Hashable, CaseIterable {
    case image
    case waveform
    case report
    case keyObjectSelection
    case document
    case presentationState
    case rawData
    case other

    /// Classifies an instance by its SOP Class UID (0008,0016).
    ///
    /// Prefix matching rather than an exhaustive table: the storage classes are
    /// organised by family, and a new member of a family — another SR flavour,
    /// another encapsulated document type — should land in the right branch
    /// without this list having to be revised first.
    public static func kind(forSOPClassUID uid: String?) -> ViewerContentKind {
        guard let uid, !uid.isEmpty else { return .image }
        switch uid {
        case Self.keyObjectSelectionUID:
            return .keyObjectSelection
        case Self.rawDataUID:
            return .rawData
        default:
            break
        }
        if uid.hasPrefix(Self.structuredReportPrefix)   { return .report }
        if uid.hasPrefix(Self.encapsulatedPrefix)       { return .document }
        if uid.hasPrefix(Self.presentationStatePrefix)  { return .presentationState }
        if uid.hasPrefix(Self.waveformPrefix)           { return .waveform }
        return .image
    }

    /// Whether this kind is displayed as pixels.
    public var isImage: Bool { self == .image }

    /// Why this content cannot be displayed, when it cannot be.
    ///
    /// Raw Data Storage holds a vendor's own acquisition data — k-space,
    /// projections, calibration — in a private format with no image and no
    /// standard way to render one. Saying so plainly is the only honest thing
    /// the viewer can do with it.
    public var cannotDisplayReason: String? {
        switch self {
        case .rawData:
            return "Raw Data objects hold vendor-private acquisition data, "
                + "not an image, and cannot be displayed in the viewer."
        default:
            return nil
        }
    }

    /// Name for the series pane and the viewer's placeholder.
    public var displayName: String {
        switch self {
        case .image:              return "Images"
        case .waveform:           return "Waveform"
        case .report:             return "Structured Report"
        case .keyObjectSelection: return "Key Object Selection"
        case .document:           return "Document"
        case .presentationState:  return "Presentation State"
        case .rawData:            return "Raw Data"
        case .other:              return "Other"
        }
    }

    /// SF Symbol standing in for the content where no picture can be drawn.
    public var symbolName: String {
        switch self {
        case .image:              return "photo"
        case .waveform:           return "waveform.path.ecg"
        case .report:             return "doc.text"
        case .keyObjectSelection: return "star.square"
        case .document:           return "doc.richtext"
        case .presentationState:  return "slider.horizontal.below.rectangle"
        case .rawData:            return "exclamationmark.octagon"
        case .other:              return "doc"
        }
    }

    // Storage class families. Reference: PS3.4 B.5 (Standard SOP Classes).
    static let structuredReportPrefix = "1.2.840.10008.5.1.4.1.1.88"
    static let keyObjectSelectionUID = "1.2.840.10008.5.1.4.1.1.88.59"
    static let encapsulatedPrefix = "1.2.840.10008.5.1.4.1.1.104"
    static let presentationStatePrefix = "1.2.840.10008.5.1.4.1.1.11"
    /// Raw Data Storage — vendor-private acquisition data with no image in it.
    static let rawDataUID = "1.2.840.10008.5.1.4.1.1.66"
    static let waveformPrefix = "1.2.840.10008.5.1.4.1.1.9"
}
