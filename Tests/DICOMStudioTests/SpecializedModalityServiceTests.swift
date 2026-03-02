// SpecializedModalityServiceTests.swift
// DICOMStudioTests

import Testing
@testable import DICOMStudio
import Foundation

@Suite("Specialized Modality Service Tests")
struct SpecializedModalityServiceTests {

    // MARK: - RT: ROIs

    @Test("setROIs and getROIs round-trips")
    func testSetAndGetROIs() {
        let service = SpecializedModalityService()
        let rois = [RTStructureSetROI(id: 1, name: "PTV", roiType: .ptv, color: .red)]
        service.setROIs(rois)
        #expect(service.getROIs().count == 1)
        #expect(service.getROIs().first?.name == "PTV")
    }

    @Test("setROIVisibility toggles visibility")
    func testSetROIVisibility() {
        let service = SpecializedModalityService()
        let roi = RTStructureSetROI(id: 1, name: "PTV", roiType: .ptv, color: .red, isVisible: true)
        service.setROIs([roi])
        service.setROIVisibility(roiID: 1, visible: false)
        #expect(service.getROIs().first?.isVisible == false)
    }

    // MARK: - RT: Isodose Levels

    @Test("setIsodoseLevels and getIsodoseLevels round-trips")
    func testSetAndGetIsodoseLevels() {
        let service = SpecializedModalityService()
        let levels = RTHelpers.isodoseLevels(for: 60.0)
        service.setIsodoseLevels(levels)
        #expect(service.getIsodoseLevels().count == 7)
    }

    // MARK: - RT: DVH Curves

    @Test("addDVHCurve and getDVHCurves accumulate")
    func testAddAndGetDVHCurves() {
        let service = SpecializedModalityService()
        let curve = DVHCurve(roiName: "PTV", structureColor: .red, points: [])
        service.addDVHCurve(curve)
        service.addDVHCurve(curve)
        #expect(service.getDVHCurves().count == 2)
    }

    // MARK: - RT: Beams

    @Test("setBeams and getBeams round-trips")
    func testSetAndGetBeams() {
        let service = SpecializedModalityService()
        let beams = [RTBeam(beamID: 1, radiationType: .photon,
                            gantryAngle: 0, collimatorAngle: 0, couchAngle: 0,
                            numberOfControlPoints: 2)]
        service.setBeams(beams)
        #expect(service.getBeams().count == 1)
    }

    // MARK: - RT: Fraction Groups

    @Test("setFractionGroups and getFractionGroups round-trips")
    func testSetAndGetFractionGroups() {
        let service = SpecializedModalityService()
        let group = RTFractionGroup(fractionGroupID: 1, numberOfFractions: 25,
                                    beamDoses: [(beamID: 1, dose: 2.0)])
        service.setFractionGroups([group])
        #expect(service.getFractionGroups().count == 1)
    }

    // MARK: - Segmentation

    @Test("updateSegmentOverlayState and getSegmentOverlayState round-trips")
    func testUpdateAndGetSegmentOverlayState() {
        let service = SpecializedModalityService()
        let overlays = SegmentationHelpers.buildOverlays(segmentCount: 3)
        let state = SegmentOverlayState(overlays: overlays)
        service.updateSegmentOverlayState(state)
        #expect(service.getSegmentOverlayState().overlays.count == 3)
    }

    @Test("setSegmentVisibility toggles specific segment")
    func testSetSegmentVisibility() {
        let service = SpecializedModalityService()
        let overlays = SegmentationHelpers.buildOverlays(segmentCount: 2)
        service.updateSegmentOverlayState(SegmentOverlayState(overlays: overlays))
        service.setSegmentVisibility(segmentNumber: 1, visible: false)
        let updated = service.getSegmentOverlayState().overlays
        #expect(updated.first(where: { $0.segmentNumber == 1 })?.isVisible == false)
        #expect(updated.first(where: { $0.segmentNumber == 2 })?.isVisible == true)
    }

    @Test("setGlobalOpacity updates opacity")
    func testSetGlobalOpacity() {
        let service = SpecializedModalityService()
        service.setGlobalOpacity(0.3)
        #expect(abs(service.getSegmentOverlayState().globalOpacity - 0.3) < 0.001)
    }

    // MARK: - Parametric Map

    @Test("updateParametricMapDisplayState and getParametricMapDisplayState round-trips")
    func testUpdateAndGetParametricMapDisplayState() {
        let service = SpecializedModalityService()
        let state = ParametricMapDisplayState(mapType: .suvMap, colormapName: .jet,
                                              minValue: 0, maxValue: 20)
        service.updateParametricMapDisplayState(state)
        #expect(service.getParametricMapDisplayState().mapType == .suvMap)
        #expect(service.getParametricMapDisplayState().colormapName == .jet)
    }

    @Test("setSUVParameters and getSUVParameters round-trips")
    func testSetAndGetSUVParameters() {
        let service = SpecializedModalityService()
        let params = SUVInputParameters(patientWeightKg: 70, injectedDoseBq: 3.7e8,
                                         injectionDateTime: Date())
        service.setSUVParameters(params)
        #expect(service.getSUVParameters() != nil)
        service.setSUVParameters(nil)
        #expect(service.getSUVParameters() == nil)
    }

    // MARK: - Waveform

    @Test("updateWaveformSettings and getWaveformSettings round-trips")
    func testUpdateAndGetWaveformSettings() {
        let service = SpecializedModalityService()
        let settings = WaveformDisplaySettings(paperSpeedMmPerSec: 50.0)
        service.updateWaveformSettings(settings)
        #expect(service.getWaveformSettings().paperSpeedMmPerSec == 50.0)
    }

    @Test("setWaveformChannels and getWaveformChannels round-trips")
    func testSetAndGetWaveformChannels() {
        let service = SpecializedModalityService()
        let channels = WaveformHelpers.standardECGLeadLabels().enumerated().map { (i, label) in
            WaveformDisplayChannel(channelIndex: i, label: label)
        }
        service.setWaveformChannels(channels)
        #expect(service.getWaveformChannels().count == 12)
    }

    @Test("addCaliperMeasurement and getCaliperMeasurements accumulate")
    func testAddAndGetCaliperMeasurements() {
        let service = SpecializedModalityService()
        let m = WaveformCaliperMeasurement(startSampleIndex: 0, endSampleIndex: 250,
                                           samplingFrequency: 250.0)
        service.addCaliperMeasurement(m)
        service.addCaliperMeasurement(m)
        #expect(service.getCaliperMeasurements().count == 2)
    }

    @Test("clearCaliperMeasurements empties the list")
    func testClearCaliperMeasurements() {
        let service = SpecializedModalityService()
        let m = WaveformCaliperMeasurement(startSampleIndex: 0, endSampleIndex: 100,
                                           samplingFrequency: 250.0)
        service.addCaliperMeasurement(m)
        service.clearCaliperMeasurements()
        #expect(service.getCaliperMeasurements().isEmpty)
    }

    // MARK: - Video

    @Test("setVideoDisplayState and getVideoDisplayState round-trips")
    func testSetAndGetVideoDisplayState() {
        let service = SpecializedModalityService()
        let state = VideoDisplayState(totalFrames: 120, frameRate: 25.0)
        service.setVideoDisplayState(state)
        #expect(service.getVideoDisplayState() != nil)
        #expect(service.getVideoDisplayState()?.totalFrames == 120)
    }

    @Test("updatePlaybackState toggles isPlaying")
    func testUpdatePlaybackState() {
        let service = SpecializedModalityService()
        service.setVideoDisplayState(VideoDisplayState(totalFrames: 100, frameRate: 25.0))
        service.updatePlaybackState(isPlaying: true)
        #expect(service.getVideoDisplayState()?.isPlaying == true)
    }

    @Test("advanceFrame increments currentFrameIndex")
    func testAdvanceFrame() {
        let service = SpecializedModalityService()
        service.setVideoDisplayState(VideoDisplayState(totalFrames: 100, frameRate: 25.0))
        service.advanceFrame()
        #expect(service.getVideoDisplayState()?.currentFrameIndex == 1)
    }

    // MARK: - Document

    @Test("setDocumentDisplayState and getDocumentDisplayState round-trips")
    func testSetAndGetDocumentDisplayState() {
        let service = SpecializedModalityService()
        let state = EncapsulatedDocumentDisplayState(documentType: .pdf, isLoaded: true,
                                                      pageCount: 5, title: "Test")
        service.setDocumentDisplayState(state)
        #expect(service.getDocumentDisplayState()?.documentType == .pdf)
    }

    @Test("nextPage increments currentPage")
    func testNextPage() {
        let service = SpecializedModalityService()
        let state = EncapsulatedDocumentDisplayState(documentType: .pdf, isLoaded: true,
                                                      pageCount: 5, currentPage: 0)
        service.setDocumentDisplayState(state)
        service.nextPage()
        #expect(service.getDocumentDisplayState()?.currentPage == 1)
    }

    @Test("previousPage decrements currentPage")
    func testPreviousPage() {
        let service = SpecializedModalityService()
        let state = EncapsulatedDocumentDisplayState(documentType: .pdf, isLoaded: true,
                                                      pageCount: 5, currentPage: 3)
        service.setDocumentDisplayState(state)
        service.previousPage()
        #expect(service.getDocumentDisplayState()?.currentPage == 2)
    }

    @Test("nextPage does not exceed pageCount")
    func testNextPageDoesNotExceedMax() {
        let service = SpecializedModalityService()
        let state = EncapsulatedDocumentDisplayState(documentType: .pdf, isLoaded: true,
                                                      pageCount: 3, currentPage: 2)
        service.setDocumentDisplayState(state)
        service.nextPage()
        #expect(service.getDocumentDisplayState()?.currentPage == 2)
    }

    // MARK: - WSI

    @Test("updateWSIDisplayState and getWSIDisplayState round-trips")
    func testUpdateAndGetWSIDisplayState() {
        let service = SpecializedModalityService()
        let state = WSIDisplayState(zoomFactor: 2.5, visibleOpticalPaths: ["1", "2"])
        service.updateWSIDisplayState(state)
        #expect(abs(service.getWSIDisplayState().zoomFactor - 2.5) < 0.001)
    }

    @Test("setTileLevels and getTileLevels round-trips")
    func testSetAndGetTileLevels() {
        let service = SpecializedModalityService()
        let levels = [WSITileLevel(level: 0, width: 8192, height: 8192,
                                   tileWidth: 256, tileHeight: 256)]
        service.setTileLevels(levels)
        #expect(service.getTileLevels().count == 1)
    }

    @Test("setOpticalPaths and getOpticalPaths round-trips")
    func testSetAndGetOpticalPaths() {
        let service = SpecializedModalityService()
        let paths = [WSIOpticalPath(opticalPathID: "1", illuminationColor: .white)]
        service.setOpticalPaths(paths)
        #expect(service.getOpticalPaths().count == 1)
    }

    @Test("toggleOpticalPath flips visibility")
    func testToggleOpticalPath() {
        let service = SpecializedModalityService()
        let paths = [WSIOpticalPath(opticalPathID: "1", illuminationColor: .white, isVisible: true)]
        service.setOpticalPaths(paths)
        service.toggleOpticalPath(id: "1")
        #expect(service.getOpticalPaths().first?.isVisible == false)
    }

    // MARK: - Reset

    @Test("resetAll clears all state")
    func testResetAll() {
        let service = SpecializedModalityService()
        service.setROIs([RTStructureSetROI(id: 1, name: "PTV", roiType: .ptv, color: .red)])
        service.setVideoDisplayState(VideoDisplayState(totalFrames: 100, frameRate: 25.0))
        service.resetAll()
        #expect(service.getROIs().isEmpty)
        #expect(service.getVideoDisplayState() == nil)
    }
}
