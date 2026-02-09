//
// VideoTests.swift
// DICOMKit
//
// Created by DICOMKit on 2026-02-09.
// Copyright © 2026 DICOMKit. All rights reserved.
//

import XCTest
@testable import DICOMKit
@testable import DICOMCore

final class VideoTests: XCTestCase {

    // MARK: - VideoType Tests

    func test_videoType_endoscopic_fromSOPClassUID() {
        let type = VideoType(sopClassUID: "1.2.840.10008.5.1.4.1.1.77.1.1.1")
        XCTAssertEqual(type, .endoscopic)
        XCTAssertEqual(type.sopClassUID, "1.2.840.10008.5.1.4.1.1.77.1.1.1")
        XCTAssertEqual(type.defaultModality, "ES")
        XCTAssertEqual(type.displayName, "Video Endoscopic")
    }

    func test_videoType_microscopic_fromSOPClassUID() {
        let type = VideoType(sopClassUID: "1.2.840.10008.5.1.4.1.1.77.1.2.1")
        XCTAssertEqual(type, .microscopic)
        XCTAssertEqual(type.sopClassUID, "1.2.840.10008.5.1.4.1.1.77.1.2.1")
        XCTAssertEqual(type.defaultModality, "GM")
        XCTAssertEqual(type.displayName, "Video Microscopic")
    }

    func test_videoType_photographic_fromSOPClassUID() {
        let type = VideoType(sopClassUID: "1.2.840.10008.5.1.4.1.1.77.1.4.1")
        XCTAssertEqual(type, .photographic)
        XCTAssertEqual(type.sopClassUID, "1.2.840.10008.5.1.4.1.1.77.1.4.1")
        XCTAssertEqual(type.defaultModality, "XC")
        XCTAssertEqual(type.displayName, "Video Photographic")
    }

    func test_videoType_unknown_fromInvalidSOPClassUID() {
        let type = VideoType(sopClassUID: "1.2.3.4.5")
        XCTAssertEqual(type, .unknown)
        XCTAssertEqual(type.sopClassUID, "")
        XCTAssertEqual(type.defaultModality, "OT")
        XCTAssertEqual(type.displayName, "Unknown Video")
    }

    // MARK: - VideoCodec Tests

    func test_videoCodec_mpeg2_fromTransferSyntax() {
        let codec = VideoCodec(transferSyntaxUID: "1.2.840.10008.1.2.4.100")
        XCTAssertEqual(codec, .mpeg2)
        XCTAssertEqual(codec.compressionMethod, "ISO_13818_2")
        XCTAssertEqual(codec.displayName, "MPEG-2")
    }

    func test_videoCodec_mpeg2HighLevel_fromTransferSyntax() {
        let codec = VideoCodec(transferSyntaxUID: "1.2.840.10008.1.2.4.101")
        XCTAssertEqual(codec, .mpeg2)
    }

    func test_videoCodec_h264_fromTransferSyntax() {
        let codec = VideoCodec(transferSyntaxUID: "1.2.840.10008.1.2.4.102")
        XCTAssertEqual(codec, .h264)
        XCTAssertEqual(codec.compressionMethod, "ISO_14496_10")
        XCTAssertEqual(codec.displayName, "H.264/AVC")
    }

    func test_videoCodec_h264BD_fromTransferSyntax() {
        let codec = VideoCodec(transferSyntaxUID: "1.2.840.10008.1.2.4.103")
        XCTAssertEqual(codec, .h264)
    }

    func test_videoCodec_h265_fromTransferSyntax() {
        let codec = VideoCodec(transferSyntaxUID: "1.2.840.10008.1.2.4.107")
        XCTAssertEqual(codec, .h265)
        XCTAssertEqual(codec.compressionMethod, "ISO_23008_2")
        XCTAssertEqual(codec.displayName, "H.265/HEVC")
    }

    func test_videoCodec_h265Main10_fromTransferSyntax() {
        let codec = VideoCodec(transferSyntaxUID: "1.2.840.10008.1.2.4.108")
        XCTAssertEqual(codec, .h265)
    }

    func test_videoCodec_unknown_fromInvalidTransferSyntax() {
        let codec = VideoCodec(transferSyntaxUID: "1.2.840.10008.1.2")
        XCTAssertEqual(codec, .unknown)
        XCTAssertEqual(codec.compressionMethod, "")
        XCTAssertEqual(codec.displayName, "Unknown")
    }

    // MARK: - Video SOP Class UID Constants

    func test_video_sopClassUIDs() {
        XCTAssertEqual(Video.videoEndoscopicImageStorageUID, "1.2.840.10008.5.1.4.1.1.77.1.1.1")
        XCTAssertEqual(Video.videoMicroscopicImageStorageUID, "1.2.840.10008.5.1.4.1.1.77.1.2.1")
        XCTAssertEqual(Video.videoPhotographicImageStorageUID, "1.2.840.10008.5.1.4.1.1.77.1.4.1")
    }

    // MARK: - Video Property Tests

    func test_video_isEndoscopic_returnsTrue() {
        let video = makeVideo(sopClassUID: Video.videoEndoscopicImageStorageUID)
        XCTAssertTrue(video.isEndoscopic)
        XCTAssertFalse(video.isMicroscopic)
        XCTAssertFalse(video.isPhotographic)
        XCTAssertEqual(video.videoType, .endoscopic)
    }

    func test_video_isMicroscopic_returnsTrue() {
        let video = makeVideo(sopClassUID: Video.videoMicroscopicImageStorageUID)
        XCTAssertFalse(video.isEndoscopic)
        XCTAssertTrue(video.isMicroscopic)
        XCTAssertFalse(video.isPhotographic)
        XCTAssertEqual(video.videoType, .microscopic)
    }

    func test_video_isPhotographic_returnsTrue() {
        let video = makeVideo(sopClassUID: Video.videoPhotographicImageStorageUID)
        XCTAssertFalse(video.isEndoscopic)
        XCTAssertFalse(video.isMicroscopic)
        XCTAssertTrue(video.isPhotographic)
        XCTAssertEqual(video.videoType, .photographic)
    }

    func test_video_resolution() {
        let video = makeVideo(rows: 1080, columns: 1920)
        XCTAssertEqual(video.resolution, "1920x1080")
    }

    func test_video_effectiveFrameRate_fromRecommendedDisplayRate() {
        let video = makeVideo(recommendedDisplayFrameRate: 25)
        XCTAssertEqual(video.effectiveFrameRate, 25.0)
    }

    func test_video_effectiveFrameRate_fromCineRate() {
        let video = makeVideo(cineRate: 30)
        XCTAssertEqual(video.effectiveFrameRate, 30.0)
    }

    func test_video_effectiveFrameRate_fromFrameTime() {
        let video = makeVideo(frameTime: 33.33)
        XCTAssertEqual(video.effectiveFrameRate, 1000.0 / 33.33, accuracy: 0.1)
    }

    func test_video_effectiveFrameRate_default30fps() {
        let video = makeVideo()
        XCTAssertEqual(video.effectiveFrameRate, 30.0)
    }

    func test_video_duration() {
        let video = makeVideo(numberOfFrames: 900, recommendedDisplayFrameRate: 30)
        XCTAssertEqual(video.duration, 30.0, accuracy: 0.001)
    }

    func test_video_duration_withFrameTime() {
        let video = makeVideo(numberOfFrames: 300, frameTime: 40.0)
        XCTAssertEqual(video.duration, 12.0, accuracy: 0.001)
    }

    // MARK: - VideoBuilder Tests

    func test_builder_build_endoscopic() throws {
        let video = try VideoBuilder(
            videoType: .endoscopic,
            rows: 480,
            columns: 640,
            numberOfFrames: 300,
            studyInstanceUID: "1.2.3.4.5",
            seriesInstanceUID: "1.2.3.4.5.6"
        )
        .setPatientName("Smith^John")
        .setPatientID("12345")
        .setFrameRate(30)
        .build()

        XCTAssertEqual(video.sopClassUID, Video.videoEndoscopicImageStorageUID)
        XCTAssertEqual(video.rows, 480)
        XCTAssertEqual(video.columns, 640)
        XCTAssertEqual(video.numberOfFrames, 300)
        XCTAssertEqual(video.patientName, "Smith^John")
        XCTAssertEqual(video.patientID, "12345")
        XCTAssertEqual(video.cineRate, 30)
        XCTAssertEqual(video.recommendedDisplayFrameRate, 30)
        XCTAssertEqual(video.modality, "ES")
        XCTAssertFalse(video.sopInstanceUID.isEmpty)
    }

    func test_builder_build_microscopic() throws {
        let video = try VideoBuilder(
            videoType: .microscopic,
            rows: 720,
            columns: 1280,
            numberOfFrames: 600,
            studyInstanceUID: "1.2.3.4.5",
            seriesInstanceUID: "1.2.3.4.5.6"
        )
        .build()

        XCTAssertEqual(video.sopClassUID, Video.videoMicroscopicImageStorageUID)
        XCTAssertEqual(video.modality, "GM")
    }

    func test_builder_build_photographic() throws {
        let video = try VideoBuilder(
            videoType: .photographic,
            rows: 1080,
            columns: 1920,
            numberOfFrames: 1800,
            studyInstanceUID: "1.2.3.4.5",
            seriesInstanceUID: "1.2.3.4.5.6"
        )
        .build()

        XCTAssertEqual(video.sopClassUID, Video.videoPhotographicImageStorageUID)
        XCTAssertEqual(video.modality, "XC")
    }

    func test_builder_build_withAllMetadata() throws {
        let video = try VideoBuilder(
            videoType: .endoscopic,
            rows: 1080,
            columns: 1920,
            numberOfFrames: 900,
            studyInstanceUID: "1.2.3.4.5",
            seriesInstanceUID: "1.2.3.4.5.6"
        )
        .setSOPInstanceUID("1.2.3.4.5.6.7")
        .setInstanceNumber(1)
        .setPatientName("Doe^Jane")
        .setPatientID("67890")
        .setModality("ES")
        .setSeriesDescription("Upper GI Endoscopy")
        .setSeriesNumber(1)
        .setSamplesPerPixel(3)
        .setPhotometricInterpretation("YBR_FULL_422")
        .setBitDepth(allocated: 8, stored: 8, highBit: 7)
        .setPixelRepresentation(0)
        .setPlanarConfiguration(0)
        .setFrameRate(30)
        .setFrameDelay(0.0)
        .setActualFrameDuration(33)
        .setStartTrim(10)
        .setStopTrim(890)
        .setLossyCompression(codec: .h264, ratio: 15.0)
        .build()

        XCTAssertEqual(video.sopInstanceUID, "1.2.3.4.5.6.7")
        XCTAssertEqual(video.instanceNumber, 1)
        XCTAssertEqual(video.seriesDescription, "Upper GI Endoscopy")
        XCTAssertEqual(video.seriesNumber, 1)
        XCTAssertEqual(video.planarConfiguration, 0)
        XCTAssertEqual(video.startTrim, 10)
        XCTAssertEqual(video.stopTrim, 890)
        XCTAssertEqual(video.lossyImageCompression, "01")
        XCTAssertEqual(video.lossyImageCompressionRatio, 15.0)
        XCTAssertEqual(video.lossyImageCompressionMethod, "ISO_14496_10")
    }

    func test_builder_build_withPixelData() throws {
        let pixelData = Data(repeating: 0xFF, count: 1024)

        let video = try VideoBuilder(
            videoType: .endoscopic,
            rows: 480,
            columns: 640,
            numberOfFrames: 1,
            studyInstanceUID: "1.2.3.4.5",
            seriesInstanceUID: "1.2.3.4.5.6"
        )
        .setPixelData(pixelData)
        .build()

        XCTAssertEqual(video.pixelData?.count, 1024)
    }

    func test_builder_build_failsWithZeroRows() {
        XCTAssertThrowsError(try VideoBuilder(
            videoType: .endoscopic,
            rows: 0,
            columns: 640,
            numberOfFrames: 300,
            studyInstanceUID: "1.2.3.4.5",
            seriesInstanceUID: "1.2.3.4.5.6"
        ).build())
    }

    func test_builder_build_failsWithZeroColumns() {
        XCTAssertThrowsError(try VideoBuilder(
            videoType: .endoscopic,
            rows: 480,
            columns: 0,
            numberOfFrames: 300,
            studyInstanceUID: "1.2.3.4.5",
            seriesInstanceUID: "1.2.3.4.5.6"
        ).build())
    }

    func test_builder_build_failsWithZeroFrames() {
        XCTAssertThrowsError(try VideoBuilder(
            videoType: .endoscopic,
            rows: 480,
            columns: 640,
            numberOfFrames: 0,
            studyInstanceUID: "1.2.3.4.5",
            seriesInstanceUID: "1.2.3.4.5.6"
        ).build())
    }

    func test_builder_build_failsWithUnknownType() {
        XCTAssertThrowsError(try VideoBuilder(
            videoType: .unknown,
            rows: 480,
            columns: 640,
            numberOfFrames: 300,
            studyInstanceUID: "1.2.3.4.5",
            seriesInstanceUID: "1.2.3.4.5.6"
        ).build())
    }

    func test_builder_build_customModality() throws {
        let video = try VideoBuilder(
            videoType: .endoscopic,
            rows: 480,
            columns: 640,
            numberOfFrames: 300,
            studyInstanceUID: "1.2.3.4.5",
            seriesInstanceUID: "1.2.3.4.5.6"
        )
        .setModality("OT")
        .build()

        XCTAssertEqual(video.modality, "OT")
    }

    func test_builder_build_lossyCompression_manual() throws {
        let video = try VideoBuilder(
            videoType: .endoscopic,
            rows: 480,
            columns: 640,
            numberOfFrames: 300,
            studyInstanceUID: "1.2.3.4.5",
            seriesInstanceUID: "1.2.3.4.5.6"
        )
        .setLossyCompression(ratio: 20.0, method: "ISO_23008_2")
        .build()

        XCTAssertEqual(video.lossyImageCompression, "01")
        XCTAssertEqual(video.lossyImageCompressionRatio, 20.0)
        XCTAssertEqual(video.lossyImageCompressionMethod, "ISO_23008_2")
    }

    // MARK: - VideoBuilder DataSet Tests

    func test_builder_buildDataSet() throws {
        let dataSet = try VideoBuilder(
            videoType: .endoscopic,
            rows: 1080,
            columns: 1920,
            numberOfFrames: 900,
            studyInstanceUID: "1.2.3.4.5",
            seriesInstanceUID: "1.2.3.4.5.6"
        )
        .setPatientName("Smith^John")
        .setPatientID("12345")
        .setFrameRate(30)
        .buildDataSet()

        XCTAssertEqual(dataSet.string(for: .sopClassUID), Video.videoEndoscopicImageStorageUID)
        XCTAssertNotNil(dataSet.string(for: .sopInstanceUID))
        XCTAssertEqual(dataSet.string(for: .studyInstanceUID), "1.2.3.4.5")
        XCTAssertEqual(dataSet.string(for: .seriesInstanceUID), "1.2.3.4.5.6")
        XCTAssertEqual(dataSet.string(for: .patientName), "Smith^John")
        XCTAssertEqual(dataSet.string(for: .patientID), "12345")
        XCTAssertEqual(dataSet[.rows]?.uint16Value, 1080)
        XCTAssertEqual(dataSet[.columns]?.uint16Value, 1920)
        XCTAssertEqual(dataSet[.samplesPerPixel]?.uint16Value, 3)
        XCTAssertEqual(dataSet.string(for: .photometricInterpretation), "YBR_FULL_422")
        XCTAssertEqual(dataSet.string(for: .modality), "ES")
    }

    func test_builder_buildDataSet_withCineModule() throws {
        let dataSet = try VideoBuilder(
            videoType: .endoscopic,
            rows: 480,
            columns: 640,
            numberOfFrames: 300,
            studyInstanceUID: "1.2.3.4.5",
            seriesInstanceUID: "1.2.3.4.5.6"
        )
        .setFrameRate(25)
        .setStartTrim(5)
        .setStopTrim(295)
        .buildDataSet()

        XCTAssertNotNil(dataSet[.frameTime])
        XCTAssertNotNil(dataSet[.cineRate])
        XCTAssertNotNil(dataSet[.recommendedDisplayFrameRate])
        XCTAssertNotNil(dataSet[.startTrim])
        XCTAssertNotNil(dataSet[.stopTrim])
    }

    // MARK: - Video.toDataSet() Tests

    func test_video_toDataSet_roundTrip() throws {
        let originalVideo = try VideoBuilder(
            videoType: .endoscopic,
            rows: 720,
            columns: 1280,
            numberOfFrames: 600,
            studyInstanceUID: "1.2.3.4.5",
            seriesInstanceUID: "1.2.3.4.5.6"
        )
        .setPatientName("Test^Patient")
        .setPatientID("TEST001")
        .setSeriesDescription("Endoscopy Recording")
        .setFrameRate(30)
        .build()

        let dataSet = originalVideo.toDataSet()
        let parsedVideo = try VideoParser.parse(from: dataSet)

        XCTAssertEqual(parsedVideo.sopInstanceUID, originalVideo.sopInstanceUID)
        XCTAssertEqual(parsedVideo.sopClassUID, originalVideo.sopClassUID)
        XCTAssertEqual(parsedVideo.studyInstanceUID, originalVideo.studyInstanceUID)
        XCTAssertEqual(parsedVideo.seriesInstanceUID, originalVideo.seriesInstanceUID)
        XCTAssertEqual(parsedVideo.patientName, originalVideo.patientName)
        XCTAssertEqual(parsedVideo.patientID, originalVideo.patientID)
        XCTAssertEqual(parsedVideo.rows, originalVideo.rows)
        XCTAssertEqual(parsedVideo.columns, originalVideo.columns)
        XCTAssertEqual(parsedVideo.numberOfFrames, originalVideo.numberOfFrames)
        XCTAssertEqual(parsedVideo.modality, originalVideo.modality)
        XCTAssertEqual(parsedVideo.seriesDescription, originalVideo.seriesDescription)
    }

    // MARK: - VideoParser Tests

    func test_parser_missingSOPInstanceUID_throws() {
        var dataSet = DataSet()
        dataSet.setString(Video.videoEndoscopicImageStorageUID, for: .sopClassUID, vr: .UI)

        XCTAssertThrowsError(try VideoParser.parse(from: dataSet))
    }

    func test_parser_missingStudyInstanceUID_throws() {
        var dataSet = DataSet()
        dataSet.setString("1.2.3.4.5.6.7", for: .sopInstanceUID, vr: .UI)
        dataSet.setString(Video.videoEndoscopicImageStorageUID, for: .sopClassUID, vr: .UI)

        XCTAssertThrowsError(try VideoParser.parse(from: dataSet))
    }

    func test_parser_missingSeriesInstanceUID_throws() {
        var dataSet = DataSet()
        dataSet.setString("1.2.3.4.5.6.7", for: .sopInstanceUID, vr: .UI)
        dataSet.setString(Video.videoEndoscopicImageStorageUID, for: .sopClassUID, vr: .UI)
        dataSet.setString("1.2.3.4.5", for: .studyInstanceUID, vr: .UI)

        XCTAssertThrowsError(try VideoParser.parse(from: dataSet))
    }

    func test_parser_missingRows_throws() {
        var dataSet = makeMinimalDataSet()
        dataSet[.rows] = nil

        XCTAssertThrowsError(try VideoParser.parse(from: dataSet))
    }

    func test_parser_missingColumns_throws() {
        var dataSet = makeMinimalDataSet()
        dataSet[.columns] = nil

        XCTAssertThrowsError(try VideoParser.parse(from: dataSet))
    }

    func test_parser_missingNumberOfFrames_throws() {
        var dataSet = makeMinimalDataSet()
        dataSet[.numberOfFrames] = nil

        XCTAssertThrowsError(try VideoParser.parse(from: dataSet))
    }

    func test_parser_parsesMinimalDataSet() throws {
        let dataSet = makeMinimalDataSet()
        let video = try VideoParser.parse(from: dataSet)

        XCTAssertEqual(video.rows, 480)
        XCTAssertEqual(video.columns, 640)
        XCTAssertEqual(video.numberOfFrames, 300)
    }

    func test_parser_parsesCompressionInfo() throws {
        var dataSet = makeMinimalDataSet()
        dataSet.setString("01", for: .lossyImageCompression, vr: .CS)
        dataSet.setString("10.0", for: .lossyImageCompressionRatio, vr: .DS)
        dataSet.setString("ISO_14496_10", for: .lossyImageCompressionMethod, vr: .CS)

        let video = try VideoParser.parse(from: dataSet)

        XCTAssertEqual(video.lossyImageCompression, "01")
        XCTAssertEqual(video.lossyImageCompressionRatio ?? 0, 10.0, accuracy: 0.01)
        XCTAssertEqual(video.lossyImageCompressionMethod, "ISO_14496_10")
    }

    // MARK: - TransferSyntax Video Tests

    func test_transferSyntax_mpeg2MainProfile() {
        let ts = TransferSyntax.mpeg2MainProfile
        XCTAssertEqual(ts.uid, "1.2.840.10008.1.2.4.100")
        XCTAssertTrue(ts.isEncapsulated)
        XCTAssertTrue(ts.isExplicitVR)
        XCTAssertTrue(ts.isVideo)
        XCTAssertTrue(ts.isMPEG2)
        XCTAssertFalse(ts.isH264)
        XCTAssertFalse(ts.isH265)
        XCTAssertFalse(ts.isLossless)
    }

    func test_transferSyntax_mpeg2MainProfileHighLevel() {
        let ts = TransferSyntax.mpeg2MainProfileHighLevel
        XCTAssertEqual(ts.uid, "1.2.840.10008.1.2.4.101")
        XCTAssertTrue(ts.isVideo)
        XCTAssertTrue(ts.isMPEG2)
    }

    func test_transferSyntax_mpeg4AVCHP41() {
        let ts = TransferSyntax.mpeg4AVCHP41
        XCTAssertEqual(ts.uid, "1.2.840.10008.1.2.4.102")
        XCTAssertTrue(ts.isEncapsulated)
        XCTAssertTrue(ts.isVideo)
        XCTAssertFalse(ts.isMPEG2)
        XCTAssertTrue(ts.isH264)
        XCTAssertFalse(ts.isH265)
        XCTAssertFalse(ts.isLossless)
    }

    func test_transferSyntax_mpeg4AVCHP41BD() {
        let ts = TransferSyntax.mpeg4AVCHP41BD
        XCTAssertEqual(ts.uid, "1.2.840.10008.1.2.4.103")
        XCTAssertTrue(ts.isVideo)
        XCTAssertTrue(ts.isH264)
    }

    func test_transferSyntax_hevcH265MainProfile() {
        let ts = TransferSyntax.hevcH265MainProfile
        XCTAssertEqual(ts.uid, "1.2.840.10008.1.2.4.107")
        XCTAssertTrue(ts.isEncapsulated)
        XCTAssertTrue(ts.isVideo)
        XCTAssertFalse(ts.isMPEG2)
        XCTAssertFalse(ts.isH264)
        XCTAssertTrue(ts.isH265)
        XCTAssertFalse(ts.isLossless)
    }

    func test_transferSyntax_hevcH265Main10Profile() {
        let ts = TransferSyntax.hevcH265Main10Profile
        XCTAssertEqual(ts.uid, "1.2.840.10008.1.2.4.108")
        XCTAssertTrue(ts.isVideo)
        XCTAssertTrue(ts.isH265)
    }

    func test_transferSyntax_fromUID_video() {
        XCTAssertNotNil(TransferSyntax.from(uid: "1.2.840.10008.1.2.4.100"))
        XCTAssertNotNil(TransferSyntax.from(uid: "1.2.840.10008.1.2.4.101"))
        XCTAssertNotNil(TransferSyntax.from(uid: "1.2.840.10008.1.2.4.102"))
        XCTAssertNotNil(TransferSyntax.from(uid: "1.2.840.10008.1.2.4.103"))
        XCTAssertNotNil(TransferSyntax.from(uid: "1.2.840.10008.1.2.4.107"))
        XCTAssertNotNil(TransferSyntax.from(uid: "1.2.840.10008.1.2.4.108"))
    }

    func test_transferSyntax_nonVideoIsNotVideo() {
        XCTAssertFalse(TransferSyntax.jpegBaseline.isVideo)
        XCTAssertFalse(TransferSyntax.jpeg2000.isVideo)
        XCTAssertFalse(TransferSyntax.rleLossless.isVideo)
        XCTAssertFalse(TransferSyntax.explicitVRLittleEndian.isVideo)
    }

    // MARK: - Helpers

    private func makeVideo(
        sopClassUID: String = Video.videoEndoscopicImageStorageUID,
        rows: Int = 480,
        columns: Int = 640,
        numberOfFrames: Int = 300,
        frameTime: Double? = nil,
        cineRate: Int? = nil,
        recommendedDisplayFrameRate: Int? = nil
    ) -> Video {
        return Video(
            sopInstanceUID: "1.2.3.4.5.6.7",
            sopClassUID: sopClassUID,
            studyInstanceUID: "1.2.3.4.5",
            seriesInstanceUID: "1.2.3.4.5.6",
            rows: rows,
            columns: columns,
            numberOfFrames: numberOfFrames,
            frameTime: frameTime,
            cineRate: cineRate,
            recommendedDisplayFrameRate: recommendedDisplayFrameRate
        )
    }

    private func makeMinimalDataSet() -> DataSet {
        var dataSet = DataSet()
        dataSet.setString("1.2.3.4.5.6.7", for: .sopInstanceUID, vr: .UI)
        dataSet.setString(Video.videoEndoscopicImageStorageUID, for: .sopClassUID, vr: .UI)
        dataSet.setString("1.2.3.4.5", for: .studyInstanceUID, vr: .UI)
        dataSet.setString("1.2.3.4.5.6", for: .seriesInstanceUID, vr: .UI)
        dataSet[.rows] = DataElement.uint16(tag: .rows, value: 480)
        dataSet[.columns] = DataElement.uint16(tag: .columns, value: 640)
        dataSet.setString("300", for: .numberOfFrames, vr: .IS)
        return dataSet
    }
}
