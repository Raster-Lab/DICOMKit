// StudyBrowserHelpersTests.swift
// DICOMStudioTests
//
// Tests for StudyBrowserHelpers

import Testing
@testable import DICOMStudio
import Foundation

@Suite("StudyBrowserHelpers Tests")
struct StudyBrowserHelpersTests {

    // MARK: - Test Data Helpers

    private func makeStudy(
        uid: String = UUID().uuidString,
        patientName: String? = "DOE^JOHN",
        studyDate: Date? = Date(),
        modality: String = "CT",
        studyDescription: String? = "CT CHEST",
        patientID: String? = "P001",
        institutionName: String? = "Hospital A"
    ) -> StudyModel {
        StudyModel(
            studyInstanceUID: uid,
            studyID: "S1",
            studyDate: studyDate,
            studyDescription: studyDescription,
            patientName: patientName,
            patientID: patientID,
            institutionName: institutionName,
            modalitiesInStudy: [modality]
        )
    }

    // MARK: - Filtering Tests

    @Test("No filter returns all studies")
    func testNoFilter() {
        let studies = [makeStudy(), makeStudy()]
        let filtered = StudyBrowserHelpers.filter(studies: studies, with: .none)
        #expect(filtered.count == 2)
    }

    @Test("Filter by modality")
    func testFilterByModality() {
        let studies = [
            makeStudy(modality: "CT"),
            makeStudy(modality: "MR"),
            makeStudy(modality: "US"),
        ]
        let filter = LibraryFilter(modalities: ["CT"])
        let filtered = StudyBrowserHelpers.filter(studies: studies, with: filter)
        #expect(filtered.count == 1)
        #expect(filtered[0].modalitiesInStudy.contains("CT"))
    }

    @Test("Filter by multiple modalities")
    func testFilterByMultipleModalities() {
        let studies = [
            makeStudy(modality: "CT"),
            makeStudy(modality: "MR"),
            makeStudy(modality: "US"),
        ]
        let filter = LibraryFilter(modalities: ["CT", "MR"])
        let filtered = StudyBrowserHelpers.filter(studies: studies, with: filter)
        #expect(filtered.count == 2)
    }

    @Test("Filter by patient name")
    func testFilterByPatientName() {
        let studies = [
            makeStudy(patientName: "DOE^JOHN"),
            makeStudy(patientName: "SMITH^JANE"),
        ]
        let filter = LibraryFilter(patientName: "DOE")
        let filtered = StudyBrowserHelpers.filter(studies: studies, with: filter)
        #expect(filtered.count == 1)
    }

    @Test("Filter by patient name is case-insensitive")
    func testFilterPatientNameCaseInsensitive() {
        let studies = [makeStudy(patientName: "DOE^JOHN")]
        let filter = LibraryFilter(patientName: "doe")
        let filtered = StudyBrowserHelpers.filter(studies: studies, with: filter)
        #expect(filtered.count == 1)
    }

    @Test("Filter by date range")
    func testFilterByDateRange() {
        let cal = Calendar.current
        let today = Date()
        let yesterday = cal.date(byAdding: .day, value: -1, to: today)!
        let lastWeek = cal.date(byAdding: .day, value: -7, to: today)!

        let studies = [
            makeStudy(studyDate: today),
            makeStudy(studyDate: yesterday),
            makeStudy(studyDate: lastWeek),
        ]
        let filter = LibraryFilter(dateFrom: cal.date(byAdding: .day, value: -2, to: today)!)
        let filtered = StudyBrowserHelpers.filter(studies: studies, with: filter)
        #expect(filtered.count == 2)
    }

    @Test("Full-text search across metadata")
    func testSearchText() {
        let studies = [
            makeStudy(patientName: "DOE^JOHN", studyDescription: "CT CHEST"),
            makeStudy(patientName: "SMITH^JANE", studyDescription: "MR BRAIN"),
        ]
        let filter = LibraryFilter(searchText: "CHEST")
        let filtered = StudyBrowserHelpers.filter(studies: studies, with: filter)
        #expect(filtered.count == 1)
    }

    @Test("Search by patient ID")
    func testSearchByPatientID() {
        let studies = [
            makeStudy(patientID: "MRN12345"),
            makeStudy(patientID: "MRN99999"),
        ]
        let filter = LibraryFilter(searchText: "12345")
        let filtered = StudyBrowserHelpers.filter(studies: studies, with: filter)
        #expect(filtered.count == 1)
    }

    @Test("Search is case-insensitive")
    func testSearchCaseInsensitive() {
        let studies = [makeStudy(studyDescription: "CT ABDOMEN")]
        let filter = LibraryFilter(searchText: "abdomen")
        let filtered = StudyBrowserHelpers.filter(studies: studies, with: filter)
        #expect(filtered.count == 1)
    }

    @Test("Empty search returns all studies")
    func testEmptySearch() {
        let studies = [makeStudy(), makeStudy()]
        let filter = LibraryFilter(searchText: "")
        let filtered = StudyBrowserHelpers.filter(studies: studies, with: filter)
        #expect(filtered.count == 2)
    }

    // MARK: - Sorting Tests

    @Test("Sort by date ascending")
    func testSortByDateAscending() {
        let cal = Calendar.current
        let today = Date()
        let yesterday = cal.date(byAdding: .day, value: -1, to: today)!
        let studies = [
            makeStudy(uid: "today", studyDate: today),
            makeStudy(uid: "yesterday", studyDate: yesterday),
        ]
        let sorted = StudyBrowserHelpers.sort(studies: studies, by: .date, direction: .ascending)
        #expect(sorted[0].studyDate! < sorted[1].studyDate!)
    }

    @Test("Sort by date descending")
    func testSortByDateDescending() {
        let cal = Calendar.current
        let today = Date()
        let yesterday = cal.date(byAdding: .day, value: -1, to: today)!
        let studies = [
            makeStudy(uid: "yesterday", studyDate: yesterday),
            makeStudy(uid: "today", studyDate: today),
        ]
        let sorted = StudyBrowserHelpers.sort(studies: studies, by: .date, direction: .descending)
        #expect(sorted[0].studyDate! > sorted[1].studyDate!)
    }

    @Test("Sort by patient name ascending")
    func testSortByPatientNameAscending() {
        let studies = [
            makeStudy(uid: "1", patientName: "SMITH^JOHN"),
            makeStudy(uid: "2", patientName: "DOE^JANE"),
        ]
        let sorted = StudyBrowserHelpers.sort(studies: studies, by: .patientName, direction: .ascending)
        #expect(sorted[0].patientName == "DOE^JANE")
    }

    @Test("Sort by modality")
    func testSortByModality() {
        let studies = [
            makeStudy(uid: "1", modality: "MR"),
            makeStudy(uid: "2", modality: "CT"),
        ]
        let sorted = StudyBrowserHelpers.sort(studies: studies, by: .modality, direction: .ascending)
        #expect(sorted[0].displayModalities == "CT")
    }

    @Test("Sort by study description")
    func testSortByDescription() {
        let studies = [
            makeStudy(uid: "1", studyDescription: "MR Brain"),
            makeStudy(uid: "2", studyDescription: "CT Chest"),
        ]
        let sorted = StudyBrowserHelpers.sort(studies: studies, by: .studyDescription, direction: .ascending)
        #expect(sorted[0].studyDescription == "CT Chest")
    }

    @Test("Sort handles nil dates")
    func testSortHandlesNilDates() {
        let studies = [
            makeStudy(uid: "1", studyDate: nil),
            makeStudy(uid: "2", studyDate: Date()),
        ]
        let sorted = StudyBrowserHelpers.sort(studies: studies, by: .date, direction: .ascending)
        #expect(sorted[0].studyDate == nil)
    }

    // MARK: - Search Match Tests

    @Test("Matches search on institution name")
    func testMatchesSearchInstitution() {
        let study = makeStudy(institutionName: "General Hospital")
        #expect(StudyBrowserHelpers.matchesSearch(study: study, text: "General"))
    }

    @Test("Does not match on unrelated text")
    func testDoesNotMatch() {
        let study = makeStudy(patientName: "DOE^JOHN", studyDescription: "CT CHEST")
        #expect(!StudyBrowserHelpers.matchesSearch(study: study, text: "XYZZY"))
    }

    // MARK: - Count Badge Tests

    @Test("Count badge singular")
    func testCountBadgeSingular() {
        let badge = StudyBrowserHelpers.countBadge(series: 1, instances: 1)
        #expect(badge == "1 series · 1 image")
    }

    @Test("Count badge plural")
    func testCountBadgePlural() {
        let badge = StudyBrowserHelpers.countBadge(series: 3, instances: 120)
        #expect(badge == "3 series · 120 images")
    }

    @Test("Count badge zero")
    func testCountBadgeZero() {
        let badge = StudyBrowserHelpers.countBadge(series: 0, instances: 0)
        #expect(badge == "0 series · 0 images")
    }

    // MARK: - Unique Modalities Tests

    @Test("Unique modalities from studies")
    func testUniqueModalities() {
        let studies = [
            makeStudy(modality: "CT"),
            makeStudy(modality: "MR"),
            makeStudy(modality: "CT"),
        ]
        let modalities = StudyBrowserHelpers.uniqueModalities(in: studies)
        #expect(modalities == ["CT", "MR"])
    }

    @Test("Unique modalities from empty list")
    func testUniqueModalitiesEmpty() {
        let modalities = StudyBrowserHelpers.uniqueModalities(in: [])
        #expect(modalities.isEmpty)
    }
}

@Suite("LibraryFilter Tests")
struct LibraryFilterTests {

    @Test("Default filter is not active")
    func testDefaultNotActive() {
        #expect(!LibraryFilter.none.isActive)
    }

    @Test("Filter with modality is active")
    func testModalityFilterActive() {
        let filter = LibraryFilter(modalities: ["CT"])
        #expect(filter.isActive)
    }

    @Test("Filter with search text is active")
    func testSearchFilterActive() {
        let filter = LibraryFilter(searchText: "test")
        #expect(filter.isActive)
    }

    @Test("Filter with patient name is active")
    func testPatientNameFilterActive() {
        let filter = LibraryFilter(patientName: "DOE")
        #expect(filter.isActive)
    }

    @Test("Filter with date from is active")
    func testDateFromFilterActive() {
        let filter = LibraryFilter(dateFrom: Date())
        #expect(filter.isActive)
    }

    @Test("Filter equality")
    func testFilterEquality() {
        let a = LibraryFilter(modalities: ["CT"], searchText: "test")
        let b = LibraryFilter(modalities: ["CT"], searchText: "test")
        #expect(a == b)
    }
}

@Suite("StudySortField Tests")
struct StudySortFieldTests {

    @Test("All sort fields have display names")
    func testDisplayNames() {
        for field in StudySortField.allCases {
            #expect(!field.displayName.isEmpty)
        }
    }

    @Test("Date display name")
    func testDateDisplayName() {
        #expect(StudySortField.date.displayName == "Study Date")
    }

    @Test("Sort direction toggle")
    func testToggle() {
        #expect(SortDirection.ascending.toggled == .descending)
        #expect(SortDirection.descending.toggled == .ascending)
    }
}

@Suite("BrowseDisplayMode Tests")
struct BrowseDisplayModeTests {

    @Test("All display modes have system images")
    func testSystemImages() {
        for mode in BrowseDisplayMode.allCases {
            #expect(!mode.systemImage.isEmpty)
        }
    }

    @Test("All display modes have accessibility labels")
    func testAccessibilityLabels() {
        for mode in BrowseDisplayMode.allCases {
            #expect(!mode.accessibilityLabel.isEmpty)
        }
    }
}
