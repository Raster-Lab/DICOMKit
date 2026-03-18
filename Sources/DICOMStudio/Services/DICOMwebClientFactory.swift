// DICOMwebClientFactory.swift
// DICOMStudio
//
// DICOM Studio — Factory for creating DICOMwebClient instances from server profiles
// Reference: DICOM PS3.18 (Web Services)

import Foundation
import DICOMWeb

/// Creates `DICOMwebClient` instances from DICOMStudio `DICOMwebServerProfile` models.
///
/// Bridges the DICOMStudio display-layer profile configuration with the
/// DICOMWeb library's `DICOMwebConfiguration` and `DICOMwebClient` types.
public enum DICOMwebClientFactory: Sendable {

    /// Creates a `DICOMwebClient` from a server profile.
    ///
    /// - Parameter profile: The DICOMweb server profile containing URL, auth, and TLS settings.
    /// - Throws: `DICOMwebError.invalidURL` if the profile's base URL is malformed.
    /// - Returns: A configured `DICOMwebClient` ready for QIDO/WADO/STOW/UPS operations.
    public static func makeClient(from profile: DICOMwebServerProfile) throws -> DICOMwebClient {
        guard let baseURL = URL(string: profile.baseURL) else {
            throw DICOMwebError.invalidURL(url: profile.baseURL)
        }

        let authentication = mapAuthentication(profile)

        let configuration = DICOMwebConfiguration(
            baseURL: baseURL,
            authentication: authentication,
            maxConcurrentRequests: 4
        )

        return DICOMwebClient(configuration: configuration)
    }

    /// Maps a DICOMStudio auth method to the DICOMWeb library's `Authentication` type.
    private static func mapAuthentication(
        _ profile: DICOMwebServerProfile
    ) -> DICOMwebConfiguration.Authentication? {
        switch profile.authMethod {
        case .none:
            return nil
        case .bearer, .jwt:
            guard !profile.bearerToken.isEmpty else { return nil }
            return .bearer(token: profile.bearerToken)
        case .basic:
            guard !profile.username.isEmpty else { return nil }
            return .basic(username: profile.username, password: profile.password)
        case .oauth2PKCE:
            // OAuth2 PKCE requires a full OAuth2 flow; fall back to bearer if a token is present
            guard !profile.bearerToken.isEmpty else { return nil }
            return .bearer(token: profile.bearerToken)
        }
    }

    /// Builds a `QIDOQuery` from DICOMStudio `QIDOQueryParams`.
    public static func buildQIDOQuery(from params: QIDOQueryParams) -> QIDOQuery {
        var query = QIDOQuery()

        if !params.patientName.isEmpty {
            query = query.patientName(params.patientName)
        }
        if !params.patientID.isEmpty {
            query = query.patientID(params.patientID)
        }
        if !params.studyDateFrom.isEmpty, !params.studyDateTo.isEmpty {
            query = query.studyDate(from: params.studyDateFrom, to: params.studyDateTo)
        } else if !params.studyDateFrom.isEmpty {
            query = query.studyDate(params.studyDateFrom)
        }
        if !params.modality.isEmpty {
            query = query.modality(params.modality)
        }
        if !params.accessionNumber.isEmpty {
            query = query.accessionNumber(params.accessionNumber)
        }
        if !params.studyDescription.isEmpty {
            query = query.studyDescription(params.studyDescription)
        }
        if params.limit > 0 {
            query = query.limit(params.limit)
        }
        if params.offset > 0 {
            query = query.offset(params.offset)
        }

        return query
    }

    /// Converts `QIDOStudyResult` from the library to `QIDOResultItem` for display.
    public static func mapStudyResults(_ results: QIDOStudyResults) -> [QIDOResultItem] {
        results.results.map { study in
            QIDOResultItem(
                studyInstanceUID: study.studyInstanceUID ?? "",
                patientName: study.patientName ?? "",
                patientID: study.patientID ?? "",
                studyDate: study.studyDate ?? "",
                modality: study.modalitiesInStudy.joined(separator: ", "),
                studyDescription: study.studyDescription ?? "",
                numberOfSeries: study.numberOfStudyRelatedSeries,
                numberOfInstances: study.numberOfStudyRelatedInstances,
                queryLevel: .study
            )
        }
    }

    /// Converts `QIDOSeriesResult` from the library to `QIDOResultItem` for display.
    public static func mapSeriesResults(_ results: QIDOSeriesResults) -> [QIDOResultItem] {
        results.results.map { series in
            QIDOResultItem(
                studyInstanceUID: series.studyInstanceUID ?? "",
                seriesInstanceUID: series.seriesInstanceUID,
                patientName: "",
                patientID: "",
                studyDate: "",
                modality: series.modality ?? "",
                studyDescription: series.seriesDescription ?? "",
                numberOfInstances: series.numberOfSeriesRelatedInstances,
                queryLevel: .series
            )
        }
    }

    /// Converts `QIDOInstanceResult` from the library to `QIDOResultItem` for display.
    public static func mapInstanceResults(_ results: QIDOInstanceResults) -> [QIDOResultItem] {
        results.results.map { inst in
            QIDOResultItem(
                sopInstanceUID: inst.sopInstanceUID,
                patientName: "",
                patientID: "",
                studyDate: "",
                modality: "",
                studyDescription: "",
                queryLevel: .instance
            )
        }
    }
}
