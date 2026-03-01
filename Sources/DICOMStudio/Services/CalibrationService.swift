// CalibrationService.swift
// DICOMStudio
//
// DICOM Studio — Service for managing pixel-to-physical calibration

import Foundation

/// Service for managing pixel-to-physical space calibration.
///
/// Extracts calibration from DICOM headers and supports manual overrides.
public final class CalibrationService: @unchecked Sendable {

    /// Lock for thread-safe access.
    private let lock = NSLock()

    /// Calibrations by SOP Instance UID.
    private var calibrationsByImage: [String: CalibrationModel]

    /// Creates a new calibration service.
    public init() {
        self.calibrationsByImage = [:]
    }

    // MARK: - Calibration Management

    /// Retrieves the calibration for a given image.
    ///
    /// - Parameter sopInstanceUID: SOP Instance UID.
    /// - Returns: The calibration model, or uncalibrated if none set.
    public func calibration(for sopInstanceUID: String) -> CalibrationModel {
        lock.lock()
        defer { lock.unlock() }
        return calibrationsByImage[sopInstanceUID] ?? .uncalibrated
    }

    /// Sets the calibration for an image.
    ///
    /// - Parameters:
    ///   - calibration: The calibration model.
    ///   - sopInstanceUID: SOP Instance UID.
    public func setCalibration(_ calibration: CalibrationModel, for sopInstanceUID: String) {
        lock.lock()
        defer { lock.unlock() }
        calibrationsByImage[sopInstanceUID] = calibration
    }

    /// Extracts and stores calibration from DICOM header values.
    ///
    /// - Parameters:
    ///   - sopInstanceUID: SOP Instance UID.
    ///   - pixelSpacing: Pixel Spacing (0028,0030) string, if available.
    ///   - imagerPixelSpacing: Imager Pixel Spacing (0018,1164), if available.
    ///   - nominalScannedPixelSpacing: Nominal Scanned Pixel Spacing (0018,2010), if available.
    /// - Returns: The resolved calibration.
    @discardableResult
    public func extractCalibration(
        for sopInstanceUID: String,
        pixelSpacing: String?,
        imagerPixelSpacing: String?,
        nominalScannedPixelSpacing: String?
    ) -> CalibrationModel {
        let calibration = CalibrationHelpers.resolveCalibration(
            pixelSpacing: pixelSpacing,
            imagerPixelSpacing: imagerPixelSpacing,
            nominalScannedPixelSpacing: nominalScannedPixelSpacing
        )
        setCalibration(calibration, for: sopInstanceUID)
        return calibration
    }

    /// Sets a manual calibration for an image.
    ///
    /// - Parameters:
    ///   - sopInstanceUID: SOP Instance UID.
    ///   - pixelDistance: Known distance in pixels.
    ///   - knownDistanceMM: Known physical distance in mm.
    /// - Returns: The manual calibration, or uncalibrated if invalid.
    @discardableResult
    public func setManualCalibration(
        for sopInstanceUID: String,
        pixelDistance: Double,
        knownDistanceMM: Double
    ) -> CalibrationModel {
        let calibration = CalibrationHelpers.calibrationFromManual(
            pixelDistance: pixelDistance,
            knownDistanceMM: knownDistanceMM
        )
        setCalibration(calibration, for: sopInstanceUID)
        return calibration
    }

    /// Removes calibration for an image (resets to uncalibrated).
    ///
    /// - Parameter sopInstanceUID: SOP Instance UID.
    public func removeCalibration(for sopInstanceUID: String) {
        lock.lock()
        defer { lock.unlock() }
        calibrationsByImage.removeValue(forKey: sopInstanceUID)
    }

    /// Returns all calibrated SOP Instance UIDs.
    ///
    /// - Returns: Array of SOP Instance UID strings.
    public func calibratedImages() -> [String] {
        lock.lock()
        defer { lock.unlock() }
        return calibrationsByImage
            .filter { $0.value.isCalibrated }
            .map { $0.key }
    }

    /// Clears all calibrations.
    public func clearAll() {
        lock.lock()
        defer { lock.unlock() }
        calibrationsByImage.removeAll()
    }
}
