import Foundation
import DICOMCore

// MARK: - Query/Retrieve SOP Class UIDs

/// Patient Root Query/Retrieve Information Model - FIND
///
/// Reference: PS3.4 Annex C.6.1
public let patientRootQueryRetrieveFindSOPClassUID = "1.2.840.10008.5.1.4.1.2.1.1"

/// Study Root Query/Retrieve Information Model - FIND
///
/// Reference: PS3.4 Annex C.6.2
public let studyRootQueryRetrieveFindSOPClassUID = "1.2.840.10008.5.1.4.1.2.2.1"

/// Patient/Study Only Query/Retrieve Information Model - FIND (Retired)
///
/// Reference: PS3.4 Annex C.6.3
public let patientStudyOnlyQueryRetrieveFindSOPClassUID = "1.2.840.10008.5.1.4.1.2.3.1"

// MARK: - Query/Retrieve Information Model

/// Query/Retrieve Information Model type
///
/// Defines which information model to use for queries.
///
/// Reference: PS3.4 Section C.6 - Query/Retrieve Service Class
public enum QueryRetrieveInformationModel: Sendable, Hashable {
    /// Patient Root Information Model
    ///
    /// The patient is at the top of the hierarchy.
    /// Supports PATIENT, STUDY, SERIES, and IMAGE query levels.
    case patientRoot
    
    /// Study Root Information Model
    ///
    /// The study is at the top of the hierarchy.
    /// Supports STUDY, SERIES, and IMAGE query levels (not PATIENT).
    case studyRoot
    
    /// The SOP Class UID for C-FIND
    public var findSOPClassUID: String {
        switch self {
        case .patientRoot:
            return patientRootQueryRetrieveFindSOPClassUID
        case .studyRoot:
            return studyRootQueryRetrieveFindSOPClassUID
        }
    }
    
    /// The supported query levels for this information model
    public var supportedLevels: [QueryLevel] {
        switch self {
        case .patientRoot:
            return [.patient, .study, .series, .image]
        case .studyRoot:
            return [.study, .series, .image]
        }
    }
    
    /// Whether a query level is supported by this information model
    public func supportsLevel(_ level: QueryLevel) -> Bool {
        supportedLevels.contains(level)
    }
}

// MARK: - CustomStringConvertible

extension QueryRetrieveInformationModel: CustomStringConvertible {
    public var description: String {
        switch self {
        case .patientRoot:
            return "Patient Root"
        case .studyRoot:
            return "Study Root"
        }
    }
}
