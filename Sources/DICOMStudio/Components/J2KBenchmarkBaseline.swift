// J2KBenchmarkBaseline.swift
// DICOMStudio
//
// DICOM Studio — embedded J2KSwift published-benchmark reference data.
//
// Source: J2KSwift/Documentation/Benchmarks/CROSS_HOST_M2_M4_inproc.md
// (J2KSwift 9.5.2, in-process, median of 7 timed runs after 2 warmups).
// These are the absolute reference the test bench measures against; per-cell
// comparison uses the nearest published fixture by modality and pixel count.

import Foundation

/// One row of J2KSwift's published cross-host in-process benchmark.
public struct J2KPublishedBenchmark: Sendable, Hashable {
    public let label: String
    public let modality: String
    public let pixelCount: Int
    /// Median ms — J2KSwift in-process, Apple M2.
    public let encodeMsM2: Double
    public let decodeMsM2: Double
    /// Median ms — J2KSwift in-process, Apple M4.
    public let encodeMsM4: Double
    public let decodeMsM4: Double
}

/// J2KSwift's published in-process benchmark, embedded as the bench's
/// absolute reference point.
public enum J2KBenchmarkBaseline {

    /// Provenance string shown next to the reference numbers.
    public static let sourceDescription =
        "J2KSwift 9.5.2 · CROSS_HOST_M2_M4_inproc · median-of-7"

    /// Representative per-fixture rows lifted from the published report,
    /// one per modality/size band.
    public static let published: [J2KPublishedBenchmark] = [
        J2KPublishedBenchmark(label: "MR 174×192",   modality: "MR", pixelCount: 174 * 192,
                              encodeMsM2: 0.55, decodeMsM2: 0.58, encodeMsM4: 0.38, decodeMsM4: 0.38),
        J2KPublishedBenchmark(label: "NM 256×256",   modality: "NM", pixelCount: 256 * 256,
                              encodeMsM2: 0.89, decodeMsM2: 0.95, encodeMsM4: 0.51, decodeMsM4: 0.57),
        J2KPublishedBenchmark(label: "CT 512×512",   modality: "CT", pixelCount: 512 * 512,
                              encodeMsM2: 2.13, decodeMsM2: 2.50, encodeMsM4: 1.28, decodeMsM4: 1.72),
        J2KPublishedBenchmark(label: "MR 512×512",   modality: "MR", pixelCount: 512 * 512,
                              encodeMsM2: 2.29, decodeMsM2: 2.57, encodeMsM4: 1.19, decodeMsM4: 1.86),
        J2KPublishedBenchmark(label: "CT 768×768",   modality: "CT", pixelCount: 768 * 768,
                              encodeMsM2: 3.96, decodeMsM2: 5.41, encodeMsM4: 2.13, decodeMsM4: 3.30),
        J2KPublishedBenchmark(label: "XA 1024×1024", modality: "XA", pixelCount: 1024 * 1024,
                              encodeMsM2: 4.94, decodeMsM2: 7.58, encodeMsM4: 3.18, decodeMsM4: 5.28),
        J2KPublishedBenchmark(label: "CT 1024×1024", modality: "CT", pixelCount: 1024 * 1024,
                              encodeMsM2: 5.91, decodeMsM2: 8.50, encodeMsM4: 3.81, decodeMsM4: 5.98),
        J2KPublishedBenchmark(label: "MR 1024×1024", modality: "MR", pixelCount: 1024 * 1024,
                              encodeMsM2: 7.10, decodeMsM2: 9.19, encodeMsM4: 3.84, decodeMsM4: 5.69),
        J2KPublishedBenchmark(label: "PX 2793×1316", modality: "PX", pixelCount: 2793 * 1316,
                              encodeMsM2: 16.57, decodeMsM2: 30.75, encodeMsM4: 9.52, decodeMsM4: 19.61),
        J2KPublishedBenchmark(label: "DX 2800×2288", modality: "DX", pixelCount: 2800 * 2288,
                              encodeMsM2: 34.43, decodeMsM2: 50.79, encodeMsM4: 19.05, decodeMsM4: 33.73),
        J2KPublishedBenchmark(label: "MG 3518×4784", modality: "MG", pixelCount: 3518 * 4784,
                              encodeMsM2: 64.05, decodeMsM2: 136.20, encodeMsM4: 38.76, decodeMsM4: 63.96),
    ]

    /// The closest published row for a fixture — same modality if one exists
    /// (nearest by pixel count), otherwise nearest pixel count across all rows.
    public static func nearest(modality: String, pixelCount: Int) -> J2KPublishedBenchmark? {
        let mod = modality.uppercased()
        let sameModality = published.filter { $0.modality == mod }
        let pool = sameModality.isEmpty ? published : sameModality
        return pool.min { lhs, rhs in
            abs(lhs.pixelCount - pixelCount) < abs(rhs.pixelCount - pixelCount)
        }
    }
}
