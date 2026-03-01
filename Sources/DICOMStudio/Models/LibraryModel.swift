// LibraryModel.swift
// DICOMStudio
//
// DICOM Studio — Local file database model

import Foundation

/// Manages the local DICOM file library, providing study/series/instance organization.
///
/// The library maintains an in-memory index of imported DICOM files,
/// organized by the standard DICOM study–series–instance hierarchy.
public struct LibraryModel: Sendable {
    /// All studies in the library, keyed by Study Instance UID.
    public private(set) var studies: [String: StudyModel]

    /// All series in the library, keyed by Series Instance UID.
    public private(set) var series: [String: SeriesModel]

    /// All instances in the library, keyed by SOP Instance UID.
    public private(set) var instances: [String: InstanceModel]

    /// Mapping from Study Instance UID to its Series Instance UIDs.
    public private(set) var studySeries: [String: Set<String>]

    /// Mapping from Series Instance UID to its SOP Instance UIDs.
    public private(set) var seriesInstances: [String: Set<String>]

    /// Creates an empty library.
    public init() {
        self.studies = [:]
        self.series = [:]
        self.instances = [:]
        self.studySeries = [:]
        self.seriesInstances = [:]
    }

    /// Returns all studies sorted by study date (most recent first).
    public var sortedStudies: [StudyModel] {
        studies.values.sorted { lhs, rhs in
            switch (lhs.studyDate, rhs.studyDate) {
            case let (l?, r?): return l > r
            case (nil, _?): return false
            case (_?, nil): return true
            case (nil, nil): return lhs.studyInstanceUID < rhs.studyInstanceUID
            }
        }
    }

    /// Returns the series for a given study, sorted by series number.
    public func seriesForStudy(_ studyUID: String) -> [SeriesModel] {
        guard let seriesUIDs = studySeries[studyUID] else { return [] }
        return seriesUIDs.compactMap { series[$0] }
            .sorted { ($0.seriesNumber ?? 0) < ($1.seriesNumber ?? 0) }
    }

    /// Returns the instances for a given series, sorted by instance number.
    public func instancesForSeries(_ seriesUID: String) -> [InstanceModel] {
        guard let instanceUIDs = seriesInstances[seriesUID] else { return [] }
        return instanceUIDs.compactMap { instances[$0] }
            .sorted { ($0.instanceNumber ?? 0) < ($1.instanceNumber ?? 0) }
    }

    /// Total number of studies in the library.
    public var studyCount: Int { studies.count }

    /// Total number of series in the library.
    public var seriesCount: Int { series.count }

    /// Total number of instances in the library.
    public var instanceCount: Int { instances.count }

    /// Adds a study to the library.
    public mutating func addStudy(_ study: StudyModel) {
        studies[study.studyInstanceUID] = study
        if studySeries[study.studyInstanceUID] == nil {
            studySeries[study.studyInstanceUID] = []
        }
    }

    /// Adds a series to the library, linking it to its parent study.
    public mutating func addSeries(_ seriesModel: SeriesModel) {
        series[seriesModel.seriesInstanceUID] = seriesModel
        studySeries[seriesModel.studyInstanceUID, default: []].insert(seriesModel.seriesInstanceUID)
        if seriesInstances[seriesModel.seriesInstanceUID] == nil {
            seriesInstances[seriesModel.seriesInstanceUID] = []
        }
    }

    /// Adds an instance to the library, linking it to its parent series.
    public mutating func addInstance(_ instance: InstanceModel) {
        instances[instance.sopInstanceUID] = instance
        seriesInstances[instance.seriesInstanceUID, default: []].insert(instance.sopInstanceUID)
    }

    /// Removes a study and all its series and instances.
    public mutating func removeStudy(_ studyUID: String) {
        if let seriesUIDs = studySeries.removeValue(forKey: studyUID) {
            for seriesUID in seriesUIDs {
                if let instanceUIDs = seriesInstances.removeValue(forKey: seriesUID) {
                    for instanceUID in instanceUIDs {
                        instances.removeValue(forKey: instanceUID)
                    }
                }
                series.removeValue(forKey: seriesUID)
            }
        }
        studies.removeValue(forKey: studyUID)
    }

    /// Removes all data from the library.
    public mutating func clear() {
        studies.removeAll()
        series.removeAll()
        instances.removeAll()
        studySeries.removeAll()
        seriesInstances.removeAll()
    }
}
