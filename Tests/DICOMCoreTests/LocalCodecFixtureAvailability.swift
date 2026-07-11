import Foundation

enum LocalCodecFixtureAvailability {
    private static let repositoryRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    private static let medicalRoot = repositoryRoot
        .appendingPathComponent("LocalDatasets/medical-dicom-organized", isDirectory: true)

    private static func containsDICOM(_ relativeDirectory: String) -> Bool {
        let directory = medicalRoot.appendingPathComponent(relativeDirectory, isDirectory: true)
        guard let enumerator = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: nil) else {
            return false
        }
        return enumerator.contains { item in
            (item as? URL)?.pathExtension.lowercased() == "dcm"
        }
    }

    static var hasMR: Bool { containsDICOM("mr") }
    static var hasMRAndPX: Bool { hasMR && containsDICOM("px") }
    static var hasMRorPX: Bool { hasMR || containsDICOM("px") }

    static var hasCTVolume: Bool {
        let directory = medicalRoot.appendingPathComponent("ct/study_002", isDirectory: true)
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.fileSizeKey]
        ) else { return false }
        return files.filter { url in
            guard url.pathExtension.lowercased() == "dcm",
                  let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize else { return false }
            return size >= 400_000
        }.count >= 16
    }

    static var hasCompressionReportCorpus: Bool {
        let paths = [
            "ct/study_001/instance_000001.dcm",
            "ct/study_003/instance_000050.dcm",
            "dx/study_001/instance_000001.dcm",
            "dx/study_002/instance_000001.dcm",
            "mg/study_001/instance_000001.dcm",
            "mg/study_002/instance_000001.dcm",
            "mr/study_001/instance_000001.dcm",
            "mr/study_002/instance_000100.dcm",
            "px/study_001/instance_000001.dcm",
            "xa/study_001/instance_000001.dcm"
        ]
        return paths.allSatisfy { FileManager.default.fileExists(atPath: medicalRoot.appendingPathComponent($0).path) }
    }
}
