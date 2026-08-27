// SavedViewGroupTests.swift
// DICOMStudioTests
//
// How the series pane's PR list groups what it is handed.
//
// The list used to be per-image, which meant a view saved across a 33-slice
// series produced 33 identical rows and buried the one view that was actually
// on a single image. Grouping by view is what fixed that, and the collapse rule
// — "this reaches the whole series, so say it once" — is a claim about the
// study, so it is tested here rather than left to the eye.

import Testing
@testable import DICOMStudio
import Foundation

@Suite("Saved View Group Tests")
struct SavedViewGroupTests {

    /// One state of `label` on image `image` of the series, in PR series
    /// `stateSeries`.
    private func reference(
        _ label: String,
        image: Int,
        stateSeries: Int? = 9001,
        isColour: Bool = false
    ) -> SavedViewReference {
        SavedViewReference(
            sopInstanceUID: "1.2.9.\(label).\(image)",
            label: label,
            imageSeriesInstanceUID: "1.2.3",
            imageSOPInstanceUID: "1.2.4.\(image)",
            imageInstanceNumber: image,
            imageSeriesNumber: 3,
            stateSeriesNumber: stateSeries,
            stateInstanceNumber: image,
            isColour: isColour)
    }

    // MARK: - Grouping

    @Test("States of one view group together however many images they are on")
    func testGroupsByLabel() {
        let references = (1...33).map { reference("PR2", image: $0) }
        let groups = SavedViewGroup.grouped(references)

        // The whole point: thirty-three objects, one group.
        #expect(groups.count == 1)
        #expect(groups[0].label == "PR2")
        #expect(groups[0].imageCount == 33)
        #expect(groups[0].references.count == 33)
    }

    @Test("Groups keep the order their first state arrived in")
    func testGroupOrderFollowsArrival() {
        // Image order, which is how the view model hands them over: image 1
        // carries GSPS_PR and PR2, image 6 adds PR1.
        let references = [
            reference("GSPS_PR", image: 1),
            reference("PR2", image: 1),
            reference("PR2", image: 2),
            reference("PR1", image: 6),
            reference("PR2", image: 6),
        ]
        let groups = SavedViewGroup.grouped(references)

        #expect(groups.map(\.label) == ["GSPS_PR", "PR2", "PR1"])
        // And each group keeps its own states in the order they came, which is
        // image order — the list reads down the slices, not around them.
        #expect(groups[1].references.map(\.imageInstanceNumber) == [1, 2, 6])
    }

    @Test("Several states on one image count as one image, not several")
    func testImageCountIsOverDistinctImages() {
        // A multi-frame image can carry more than one state of the same view.
        // Counting objects would claim the view reaches two slices.
        let group = SavedViewGroup(label: "PR2", references: [
            reference("PR2", image: 1),
            reference("PR2", image: 1),
        ])
        #expect(group.references.count == 2)
        #expect(group.imageCount == 1)
    }

    @Test("An empty group answers rather than trapping")
    func testEmptyGroup() {
        let group = SavedViewGroup(label: "PR2", references: [])
        #expect(group.imageCount == 0)
        #expect(!group.isColour)
        #expect(group.commonStateSeriesNumber == nil)
        #expect(!group.coversWholeSeries(ofImageCount: 33))
    }

    // MARK: - The collapse rule

    @Test("A view on every image of the series collapses to one line")
    func testCoversWholeSeries() {
        let group = SavedViewGroup(
            label: "PR2", references: (1...33).map { reference("PR2", image: $0) })
        #expect(group.coversWholeSeries(ofImageCount: 33))
    }

    @Test("A view on some of the series does not collapse")
    func testPartialCoverageDoesNotCollapse() {
        // One slice short is still "some images": the reader has to be told
        // which, because the one it misses is the one they will look for.
        let group = SavedViewGroup(
            label: "PR2", references: (1...32).map { reference("PR2", image: $0) })
        #expect(!group.coversWholeSeries(ofImageCount: 33))

        let single = SavedViewGroup(
            label: "GSPS_PR", references: [reference("GSPS_PR", image: 1)])
        #expect(!single.coversWholeSeries(ofImageCount: 33))
    }

    @Test("Two views over the same half of a series are both partial")
    func testCoverageIsAgainstTheSeriesNotTheWidestGroup() {
        // Measured against the series' own count, not against whatever else is
        // present: calling both of these "the whole series" because neither is
        // beaten would be a plain misstatement of where they are.
        let references = (1...5).flatMap {
            [reference("Bone", image: $0), reference("Lung", image: $0)]
        }
        let groups = SavedViewGroup.grouped(references)
        #expect(groups.count == 2)
        for group in groups {
            #expect(group.imageCount == 5)
            #expect(!group.coversWholeSeries(ofImageCount: 10))
        }
    }

    @Test("A series of unknown size never collapses")
    func testUnknownSeriesSizeNeverCollapses() {
        // Zero is "the pane does not know", not "an empty series". Collapsing
        // there would claim a reach nothing established.
        let group = SavedViewGroup(
            label: "PR2", references: (1...3).map { reference("PR2", image: $0) })
        #expect(!group.coversWholeSeries(ofImageCount: 0))
    }

    @Test("A view reaching past the counted images still reads as whole-series")
    func testOverCoverageCollapses() {
        // The reference count comes from the states' Referenced Series
        // Sequence and the object count from the library's index; a state
        // naming an image the pane has not indexed must not leave the view
        // stuck at "34 images" on a 33-image series.
        let group = SavedViewGroup(
            label: "PR2", references: (1...34).map { reference("PR2", image: $0) })
        #expect(group.coversWholeSeries(ofImageCount: 33))
    }

    // MARK: - What the heading says

    @Test("A view saved in one pass names its PR series; one re-saved does not")
    func testCommonStateSeriesNumber() {
        let onePass = SavedViewGroup(
            label: "PR2", references: (1...3).map { reference("PR2", image: $0) })
        #expect(onePass.commonStateSeriesNumber == 9001)

        // Re-saved later: the objects live in two PR series, and naming one of
        // them would point the reader at a series that holds only part of it.
        let reSaved = SavedViewGroup(label: "PR2", references: [
            reference("PR2", image: 1, stateSeries: 9001),
            reference("PR2", image: 2, stateSeries: 9002),
        ])
        #expect(reSaved.commonStateSeriesNumber == nil)

        // Unnumbered states say nothing rather than inventing a number.
        let unnumbered = SavedViewGroup(
            label: "PR2", references: [reference("PR2", image: 1, stateSeries: nil)])
        #expect(unnumbered.commonStateSeriesNumber == nil)
    }

    @Test("A colour view is flagged as one")
    func testColourFlag() {
        let colour = SavedViewGroup(
            label: "Hot Iron",
            references: (1...3).map { reference("Hot Iron", image: $0, isColour: true) })
        #expect(colour.isColour)

        let grey = SavedViewGroup(
            label: "PR2", references: [reference("PR2", image: 1)])
        #expect(!grey.isColour)
    }

    // MARK: - The case from the screenshot

    @Test("The 35-states-on-33-images series lists three views, not thirty-three images")
    func testScreenshotCase() {
        // BRAIN PLAIN 5.00 ax: PR2 across every slice, GSPS_PR on image 1, PR1
        // on image 6. Thirty-five objects; three readings.
        var references: [SavedViewReference] = []
        for image in 1...33 {
            if image == 1 { references.append(reference("GSPS_PR", image: 1)) }
            if image == 6 { references.append(reference("PR1", image: 6)) }
            references.append(reference("PR2", image: image))
        }
        #expect(references.count == 35)

        let groups = SavedViewGroup.grouped(references)
        #expect(groups.count == 3)

        let byLabel = Dictionary(uniqueKeysWithValues: groups.map { ($0.label, $0) })
        // The series-wide one collapses; the two single-image ones do not, so
        // they are the rows that actually spend space — which is the inversion
        // this change is for.
        #expect(byLabel["PR2"]?.coversWholeSeries(ofImageCount: 33) == true)
        #expect(byLabel["GSPS_PR"]?.coversWholeSeries(ofImageCount: 33) == false)
        #expect(byLabel["GSPS_PR"]?.imageCount == 1)
        #expect(byLabel["PR1"]?.coversWholeSeries(ofImageCount: 33) == false)
        #expect(byLabel["PR1"]?.imageCount == 1)
    }
}
