// PatientOverlayText.swift
// DICOMStudio
//
// DICOM Studio — the identification text burned over an image.
//
// One definition of what the overlay says, used by the viewer's tiles and by the
// film preview's cells. Two of them would be two answers to "who is this
// patient", and the film would eventually disagree with the screen it was
// composed on.

import Foundation
import DICOMCore
import DICOMKit

/// Patient and study identification, as two lines of overlay text.
public struct PatientOverlayText: Sendable, Equatable, Hashable {

    /// Patient name, ID and study date, comma separated.
    public let primaryLine: String

    /// Study description, on its own line.
    public let secondaryLine: String

    public init(primaryLine: String, secondaryLine: String) {
        self.primaryLine = primaryLine
        self.secondaryLine = secondaryLine
    }

    /// Whether there is anything to draw.
    public var isEmpty: Bool { primaryLine.isEmpty && secondaryLine.isEmpty }

    /// Reads the overlay text from a data set.
    ///
    /// Missing values are dropped rather than shown as blanks, so a
    /// de-identified file does not print a line of stray commas.
    public static func make(from dataSet: DataSet) -> PatientOverlayText {
        func string(_ group: UInt16, _ element: UInt16) -> String? {
            guard let value = dataSet.string(for: Tag(group: group, element: element))?
                .trimmingCharacters(in: .whitespacesAndNewlines),
                  !value.isEmpty else { return nil }
            return value
        }

        let name = string(0x0010, 0x0010).map { DICOMValueParser.formatPersonName($0) }
        let patientID = string(0x0010, 0x0020)
        let studyDate = string(0x0008, 0x0020).map { DICOMValueParser.formatDate($0) }

        return PatientOverlayText(
            primaryLine: [name, patientID, studyDate].compactMap { $0 }.joined(separator: ", "),
            secondaryLine: string(0x0008, 0x1030) ?? "")
    }
}
