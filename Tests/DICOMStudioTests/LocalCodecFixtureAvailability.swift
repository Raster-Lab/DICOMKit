import Foundation

enum LocalCodecFixtureAvailability {
    private static let sampleStudiesRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("SampleStudies", isDirectory: true)

    static var hasSampleStudies: Bool {
        let paths = [
            "ct/study_001/instance_000001.dcm",
            "dx/study_001/instance_000001.dcm",
            "mg/study_001/instance_000001.dcm",
            "mr/study_003/instance_000001.dcm",
            "px/study_003/instance_000001.dcm",
            "xa/study_001/instance_000001.dcm"
        ]
        return paths.allSatisfy { FileManager.default.fileExists(atPath: sampleStudiesRoot.appendingPathComponent($0).path) }
    }
}
