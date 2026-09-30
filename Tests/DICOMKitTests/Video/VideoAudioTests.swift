//
// VideoAudioTests.swift
// DICOMKit
//
// Copyright © 2026 DICOMKit. All rights reserved.
//

import XCTest
@testable import DICOMKit
import DICOMCore

/// Audio in DICOM video: the probe reads the audio tracks of MP4 and MPEG-TS
/// inputs, `VideoConformanceValidator.validateAudio` checks them against PS3.5
/// 2026a 8.2.5 (MPEG2) and 8.2.12 / Table 8.2.12-1 (H.264, HEVC), and the Cine
/// Module's Multiplexed Audio Channels Description Code Sequence (003A,0300) is
/// written and read back per PS3.3 Table C.7-13 (D46).
///
/// Fixtures are assembled from the box and packet layouts of ISO/IEC 14496-12,
/// 14496-14, 13818-1, 13818-7, 11172-3 and ETSI TS 102 366, like the other video
/// suites, so the expected values follow from those specifications.
final class VideoAudioTests: XCTestCase {

    // MARK: - ISO-BMFF Fixtures

    private func box(_ type: String, _ payload: Data) -> Data {
        var data = Data()
        data.append(uint32: UInt32(payload.count + 8))
        data.append(contentsOf: Array(type.utf8))
        data.append(payload)
        return data
    }

    private func fullBox(_ type: String, _ payload: Data) -> Data {
        box(type, Data([0, 0, 0, 0]) + payload)
    }

    private func ftyp() -> Data {
        var payload = Data("isom".utf8)
        payload.append(uint32: 512)
        for brand in ["isom", "mp41", "avc1"] { payload.append(contentsOf: Array(brand.utf8)) }
        return box("ftyp", payload)
    }

    private func mdhd(timescale: UInt32, duration: UInt32) -> Data {
        var payload = Data()
        payload.append(uint32: 0)
        payload.append(uint32: 0)
        payload.append(uint32: 0)
        payload.append(uint32: timescale)
        payload.append(uint32: duration)
        payload.append(uint16: 0x55C4)
        payload.append(uint16: 0)
        return box("mdhd", payload)
    }

    private func hdlr(_ handler: String) -> Data {
        var payload = Data()
        payload.append(uint32: 0)
        payload.append(uint32: 0)
        payload.append(contentsOf: Array(handler.utf8))
        payload.append(Data(repeating: 0, count: 12))
        payload.append(contentsOf: Array("Handler\0".utf8))
        return box("hdlr", payload)
    }

    private static let spsH264Unit = Data([
        0x67,
        0x64, 0x00, 0x29, 0xAC, 0xB4, 0x03, 0xC0, 0x11, 0x3F, 0x2C, 0x20,
        0x00, 0x00, 0x03, 0x00, 0x20, 0x00, 0x00, 0x07, 0x98,
    ])

    private func avc1Entry() -> Data {
        var avcC = Data([0x01, 0x64, 0x00, 0x29, 0xFF, 0xE1])
        avcC.append(uint16: UInt16(Self.spsH264Unit.count))
        avcC.append(Self.spsH264Unit)
        avcC.append(0x01)
        avcC.append(uint16: 3)
        avcC.append(contentsOf: [0xEE, 0x3C, 0xB0])

        var payload = Data(repeating: 0, count: 6)
        payload.append(uint16: 1)
        payload.append(Data(repeating: 0, count: 16))
        payload.append(uint16: 1920)
        payload.append(uint16: 1080)
        payload.append(uint32: 0x0048_0000)
        payload.append(uint32: 0x0048_0000)
        payload.append(uint32: 0)
        payload.append(uint16: 1)
        payload.append(Data(repeating: 0, count: 32))
        payload.append(uint16: 24)
        payload.append(uint16: 0xFFFF)
        payload.append(box("avcC", avcC))
        return box("avc1", payload)
    }

    /// An AudioSampleEntry (ISO/IEC 14496-12 12.2.3): 28 bytes, then its boxes.
    private func audioEntry(
        _ format: String, channels: UInt16, sampleSize: UInt16, rate: UInt32, children: Data = Data()
    ) -> Data {
        var payload = Data(repeating: 0, count: 6)
        payload.append(uint16: 1)                  // data_reference_index
        payload.append(Data(repeating: 0, count: 8))
        payload.append(uint16: channels)
        payload.append(uint16: sampleSize)
        payload.append(uint16: 0)
        payload.append(uint16: 0)
        payload.append(uint32: rate << 16)
        XCTAssertEqual(payload.count, 28)
        payload.append(children)
        return box(format, payload)
    }

    /// An ESDBox with a DecoderConfigDescriptor (ISO/IEC 14496-1 7.2.6).
    private func esds(objectType: UInt8, maxBitrate: UInt32, avgBitrate: UInt32, dsi: [UInt8]) -> Data {
        func descriptor(_ tag: UInt8, _ body: Data) -> Data {
            Data([tag, UInt8(body.count)]) + body
        }
        var config = Data([objectType, 0x15, 0x00, 0x00, 0x00])
        config.append(uint32: maxBitrate)
        config.append(uint32: avgBitrate)
        config.append(descriptor(0x05, Data(dsi)))
        let es = Data([0x00, 0x01, 0x00]) + descriptor(0x04, config) + descriptor(0x06, Data([0x02]))
        return fullBox("esds", descriptor(0x03, es))
    }

    private func track(handler: String, entry: Data, samples: UInt32, chunkOffset: UInt32? = nil) -> Data {
        var stsd = Data()
        stsd.append(uint32: 0)
        stsd.append(uint32: 1)
        stsd.append(entry)
        var stsz = Data()
        stsz.append(uint32: 0)
        stsz.append(uint32: 100)
        stsz.append(uint32: samples)
        var stbl = box("stsd", stsd) + box("stsz", stsz)
        if let chunkOffset {
            var stco = Data()
            stco.append(uint32: 0)
            stco.append(uint32: 1)
            stco.append(uint32: chunkOffset)
            stbl += box("stco", stco)
        }
        let mdia = box("mdia", mdhd(timescale: 30000, duration: 300_000) + hdlr(handler)
                       + box("minf", box("stbl", stbl)))
        return box("trak", mdia)
    }

    /// An H.264 High@4.1 clip with one audio track. `mdat` precedes `moov`, so
    /// the audio's first chunk offset is known when `stco` is written.
    private func mp4(audioEntry entry: Data, mdat: Data = Data(repeating: 0, count: 16)) -> Data {
        let head = ftyp()
        let mdatBox = box("mdat", mdat)
        let video = track(handler: "vide", entry: avc1Entry(), samples: 300)
        let audio = track(handler: "soun", entry: entry, samples: 400,
                          chunkOffset: UInt32(head.count + 8))
        return head + mdatBox + box("moov", video + audio)
    }

    // MARK: - Transport Stream Fixtures

    private struct TSStream {
        let streamType: UInt8
        let pid: Int
        let streamID: UInt8
        let descriptors: Data
        let payload: Data
    }

    /// PAT, PMT and one PES packet per stream (ISO/IEC 13818-1 2.4.3, 2.4.4).
    private func transportStream(_ streams: [TSStream], programInfo: Data = Data()) -> Data {
        let pmtPID = 0x1000
        func packet(pid: Int, start: Bool, payload: Data) -> Data {
            var data = Data([0x47, UInt8((start ? 0x40 : 0) | (pid >> 8) & 0x1F), UInt8(pid & 0xFF), 0x10])
            let body = payload.prefix(184)
            data.append(body)
            data.append(Data(repeating: 0xFF, count: 184 - body.count))
            return data
        }
        func section(_ tableID: UInt8, _ body: Data) -> Data {
            let length = body.count + 4
            var data = Data([0x00, tableID, UInt8(0xB0 | ((length >> 8) & 0x0F)), UInt8(length & 0xFF)])
            data.append(body)
            data.append(Data(repeating: 0, count: 4))
            return data
        }
        var pat = Data([0x00, 0x01, 0xC1, 0x00, 0x00, 0x00, 0x01])
        pat.append(contentsOf: [UInt8(0xE0 | (pmtPID >> 8)), UInt8(pmtPID & 0xFF)])

        var pmt = Data([0x00, 0x01, 0xC1, 0x00, 0x00, 0xE1, 0x00])
        pmt.append(contentsOf: [UInt8(0xF0 | (programInfo.count >> 8)), UInt8(programInfo.count & 0xFF)])
        pmt.append(programInfo)
        for stream in streams {
            pmt.append(stream.streamType)
            pmt.append(contentsOf: [UInt8(0xE0 | (stream.pid >> 8)), UInt8(stream.pid & 0xFF)])
            pmt.append(contentsOf: [UInt8(0xF0 | (stream.descriptors.count >> 8)),
                                    UInt8(stream.descriptors.count & 0xFF)])
            pmt.append(stream.descriptors)
        }

        var ts = packet(pid: 0, start: true, payload: section(0x00, pat))
        ts += packet(pid: pmtPID, start: true, payload: section(0x02, pmt))
        for stream in streams {
            var pes = Data([0x00, 0x00, 0x01, stream.streamID, 0x00, 0x00, 0x80, 0x00, 0x00])
            pes.append(stream.payload)
            ts += packet(pid: stream.pid, start: true, payload: pes)
        }
        for _ in 0..<3 {
            ts += packet(pid: streams[0].pid, start: false, payload: Data())
        }
        return ts
    }

    private func h264Video() -> TSStream {
        TSStream(streamType: 0x1B, pid: 0x0100, streamID: 0xE0, descriptors: Data(),
                 payload: Data([0, 0, 0, 1]) + Self.spsH264Unit)
    }

    /// An MPEG-2 MP@ML sequence header, 720x576 at 25 fps.
    private func mpeg2Video() -> TSStream {
        TSStream(streamType: 0x02, pid: 0x0100, streamID: 0xE0, descriptors: Data(), payload: Data([
            0x00, 0x00, 0x01, 0xB3, 0x2D, 0x02, 0x40, 0x33, 0x13, 0x88, 0x23, 0x80,
            0x80, 0x00, 0x00, 0x01, 0xB5, 0x14, 0x8A, 0x00, 0x01, 0x00, 0x00, 0x80,
        ]))
    }

    /// An AC-3 syncframe header (ETSI TS 102 366 4.3): 48 kHz (fscod 0),
    /// frmsizecod 20 (192 kbit/s), bsid 8, acmod 2 (2/0) with dsurmod, lfeon 0.
    private static let ac3Stereo192: [UInt8] = [0x0B, 0x77, 0x00, 0x00, 0x14, 0x40, 0x40, 0x00]
    /// acmod 7 (3/2) with cmixlev and surmixlev, lfeon 1: 5.1.
    private static let ac3FivePointOne: [UInt8] = [0x0B, 0x77, 0x00, 0x00, 0x14, 0x40, 0xE1, 0x00]
    /// MPEG-1 Layer III, 128 kbit/s, 44.1 kHz, joint stereo (ISO/IEC 11172-3 2.4.1.3).
    private static let mp3Header: [UInt8] = [0xFF, 0xFB, 0x90, 0x64]

    /// Two ADTS frames of 20 bytes: AAC LC, 48 kHz, channel configuration 2.
    private static var adtsFrames: [UInt8] {
        let header: [UInt8] = [0xFF, 0xF1, 0x4C, 0x80, 0x02, 0x9F, 0xFC]
        let frame = header + [UInt8](repeating: 0, count: 13)
        return frame + frame
    }

    // MARK: - Constraint Table (PS3.5 2026a 8.2.12, Table 8.2.12-1)

    func test_audioConstraints_matchTable8_2_12_1() {
        let table = VideoConformanceValidator.audioConstraints(for: .mpeg4AVCHP41)
        XCTAssertEqual(table.map(\.format), [.lpcm, .ac3, .aac, .mp3, .mpeg1LayerII])
        XCTAssertTrue(table.allSatisfy { $0.section == "PS3.5 8.2.12" })

        let byFormat = Dictionary(uniqueKeysWithValues: table.map { ($0.format, $0) })
        XCTAssertEqual(byFormat[.lpcm]?.maximumBitRate, 4_608_000)
        XCTAssertEqual(byFormat[.lpcm]?.samplingFrequencies, [48000, 96000])
        XCTAssertEqual(byFormat[.lpcm]?.permittedBitsPerSample, [16, 20, 24])
        XCTAssertEqual(byFormat[.lpcm]?.permittedChannelCounts, [2])
        XCTAssertEqual(byFormat[.ac3]?.maximumBitRate, 640_000)
        XCTAssertEqual(byFormat[.ac3]?.samplingFrequencies, [48000])
        XCTAssertEqual(byFormat[.ac3]?.permittedBitsPerSample, [16])
        XCTAssertEqual(byFormat[.ac3]?.permittedChannelCounts, [2, 6])
        XCTAssertEqual(byFormat[.aac]?.maximumBitRate, 640_000)
        XCTAssertEqual(byFormat[.aac]?.samplingFrequencies, [48000])
        XCTAssertEqual(byFormat[.aac]?.permittedBitsPerSample, [16, 20, 24])
        XCTAssertEqual(byFormat[.mp3]?.maximumBitRate, 320_000)
        XCTAssertEqual(byFormat[.mp3]?.samplingFrequencies, [32000, 44100, 48000])
        XCTAssertEqual(byFormat[.mp3]?.maximumBitsPerSample, 24)
        XCTAssertNil(byFormat[.mp3]?.permittedChannelCounts)
        XCTAssertEqual(byFormat[.mp3]?.requiresConstantBitRate, true)
        XCTAssertEqual(byFormat[.mpeg1LayerII]?.maximumBitRate, 384_000)
        XCTAssertEqual(byFormat[.mpeg1LayerII]?.permittedChannelCounts, [2])

        // Table 8.2.12-1: LPCM and AC-3 only in MPEG-2 TS; the rest in both.
        XCTAssertEqual(table.filter { !$0.permittedInMP4 }.map(\.format), [.lpcm, .ac3])
        XCTAssertTrue(table.allSatisfy(\.permittedInMPEG2TS))

        // Every H.264/HEVC syntax, fragmentable variants included, applies 8.2.12.
        for syntax in [TransferSyntax.hevcH265MainProfile, .hevcH265Main10Profile,
                       .mpeg4AVCHP42For2DVideo, .mpeg4AVCStereoHP42] {
            XCTAssertEqual(VideoConformanceValidator.audioConstraints(for: syntax), table)
        }
        XCTAssertTrue(VideoConformanceValidator.audioConstraints(for: .explicitVRLittleEndian).isEmpty)
    }

    /// PS3.5 8.2.5 (and 8.2.6 by reference): CBR MP3 only, up to 24 bits, 32,
    /// 44.1 or 48 kHz for the main channel; no bit rate or container limit.
    func test_audioConstraints_mpeg2AllowsOnlyCBRMP3() {
        for syntax in [TransferSyntax.mpeg2MainProfile, .mpeg2MainProfileHighLevel] {
            let table = VideoConformanceValidator.audioConstraints(for: syntax)
            XCTAssertEqual(table.count, 1)
            XCTAssertEqual(table.first?.format, .mp3)
            XCTAssertEqual(table.first?.section, "PS3.5 8.2.5")
            XCTAssertNil(table.first?.maximumBitRate)
            XCTAssertEqual(table.first?.samplingFrequencies, [32000, 44100, 48000])
            XCTAssertEqual(table.first?.requiresConstantBitRate, true)
            XCTAssertEqual(table.first?.permittedInMP4, true)
        }
    }

    // MARK: - MP4

    private func aacEntry(rate: UInt32, dsi: [UInt8]) -> Data {
        audioEntry("mp4a", channels: 2, sampleSize: 16, rate: rate,
                   children: esds(objectType: 0x40, maxBitrate: 192_000, avgBitrate: 128_000, dsi: dsi))
    }

    /// AudioSpecificConfig AAC LC (2), 48 kHz (index 3), channelConfiguration 2.
    private static let ascLC48Stereo: [UInt8] = [0x11, 0x90]
    /// AudioSpecificConfig AAC LC, 44.1 kHz (index 4), channelConfiguration 2.
    private static let ascLC44Stereo: [UInt8] = [0x12, 0x10]

    func test_mp4_aac48kStereo_meetsTable8_2_12_1() throws {
        let input = mp4(audioEntry: aacEntry(rate: 48000, dsi: Self.ascLC48Stereo))
        let probe = try VideoProbe.probe(input)
        XCTAssertEqual(probe.audioTrackCount, 1)
        let track = try XCTUnwrap(probe.audioTracks.first)
        XCTAssertEqual(track.format, .aac)
        XCTAssertEqual(track.codecTag, "mp4a")
        XCTAssertEqual(track.samplingFrequency, 48000)
        XCTAssertEqual(track.channelCount, 2)
        XCTAssertEqual(track.bitsPerSample, 16)
        XCTAssertEqual(track.maximumBitRate, 192_000)
        XCTAssertEqual(track.averageBitRate, 128_000)

        let result = VideoConformanceValidator.validateAudio(
            tracks: probe.audioTracks, container: .mp4, transferSyntax: .mpeg4AVCHP41)
        XCTAssertTrue(result.hasNoKnownViolations)
        XCTAssertEqual(result.tracks.first?.notChecked, [])

        let outcome = try VideoWorkflow.convert(
            bitstream: input, type: .endoscopic, typeWasExplicit: true, dryRun: true)
        XCTAssertEqual(outcome.output, """
            note: audio track 1 (AAC, 48 kHz, 2 channels, 16-bit, max 192 kbit/s) meets PS3.5 8.2.12.
            note: Multiplexed Audio Channels Description Code Sequence (003A,0300) has no Items: \
            each Item needs a Channel Source code (PS3.16 CID 3000) that the container does not record.
            """)

        let report = try VideoWorkflow.probe(bitstream: input)
        XCTAssertTrue(report.output.contains("Audio tracks:     1 (carried in the bit stream)\n"
            + "Audio track 1:    AAC, 48 kHz, 2 channels, 16-bit, max 192 kbit/s"), report.output)
        XCTAssertEqual(report.exitCode, .success)
    }

    func test_mp4_aac44k_violatesSamplingFrequency() throws {
        let input = mp4(audioEntry: aacEntry(rate: 44100, dsi: Self.ascLC44Stereo))
        let probe = try VideoProbe.probe(input)
        XCTAssertEqual(probe.audioTracks.first?.samplingFrequency, 44100)

        let result = VideoConformanceValidator.validateAudio(
            tracks: probe.audioTracks, container: .mp4, transferSyntax: .mpeg4AVCHP41)
        XCTAssertEqual(result.violations.map(\.constraint), [.samplingFrequency])
        XCTAssertEqual(result.violations.first?.message,
                       "sampling frequency 44.1 kHz is not permitted for AAC; PS3.5 8.2.12 allows 48 kHz")

        // A warning, not a rejection: the object is still written, audio intact.
        let outcome = try VideoWorkflow.convert(bitstream: input, type: .endoscopic, typeWasExplicit: true)
        XCTAssertTrue(outcome.output.hasPrefix("""
            warning: audio track 1 (AAC, 44.1 kHz, 2 channels, 16-bit, max 192 kbit/s): \
            sampling frequency 44.1 kHz is not permitted for AAC; PS3.5 8.2.12 allows 48 kHz; \
            the audio is kept unchanged.
            """), outcome.output)
        let fragment = try XCTUnwrap(outcome.video?.toDataSet()[.pixelData]?.encapsulatedFragments?.first)
        XCTAssertEqual(fragment.prefix(input.count), input)
    }

    func test_mp4_lpcm_violatesContainerRuleOfTable8_2_12_1() throws {
        let input = mp4(audioEntry: audioEntry("sowt", channels: 2, sampleSize: 16, rate: 48000))
        let track = try XCTUnwrap(VideoProbe.probe(input).audioTracks.first)
        XCTAssertEqual(track.format, .lpcm)
        XCTAssertEqual(track.maximumBitRate, 1_536_000)

        let result = VideoConformanceValidator.validateAudio(
            tracks: [track], container: .mp4, transferSyntax: .hevcH265MainProfile)
        XCTAssertEqual(result.violations.map(\.constraint), [.container])
        XCTAssertEqual(result.violations.first?.message,
                       "LPCM is permitted only in an MPEG-2 TS container, not MP4 (PS3.5 Table 8.2.12-1)")
        // The same track is fine in a transport stream.
        XCTAssertTrue(VideoConformanceValidator.validateAudio(
            tracks: [track], container: .mpegTS, transferSyntax: .hevcH265MainProfile).hasNoKnownViolations)
    }

    func test_mp4_ac3_readsDac3_andViolatesContainerRule() throws {
        // dac3: fscod 0, bsid 8, bsmod 0, acmod 7, lfeon 1, bit_rate_code 18 (640 kbit/s).
        let dac3 = box("dac3", Data([0x10, 0x3E, 0x40]))
        let input = mp4(audioEntry: audioEntry("ac-3", channels: 6, sampleSize: 16, rate: 48000, children: dac3))
        let track = try XCTUnwrap(VideoProbe.probe(input).audioTracks.first)
        XCTAssertEqual(track.format, .ac3)
        XCTAssertEqual(track.samplingFrequency, 48000)
        XCTAssertEqual(track.channelCount, 6)
        XCTAssertEqual(track.hasLFE, true)
        XCTAssertEqual(track.maximumBitRate, 640_000)
        XCTAssertEqual(track.summary, "AC-3, 48 kHz, 5.1 channels, 16-bit, max 640 kbit/s")

        let result = VideoConformanceValidator.validateAudio(
            tracks: [track], container: .mp4, transferSyntax: .mpeg4AVCHP41)
        XCTAssertEqual(result.violations.map(\.constraint), [.container])
    }

    func test_mp4_mp3_readsFirstFrameHeader() throws {
        let entry = audioEntry(".mp3", channels: 2, sampleSize: 16, rate: 44100)
        // Two 417-byte frames (144 * 128000 / 44100), so the header is confirmed.
        let frame = Data(Self.mp3Header) + Data(repeating: 0, count: 413)
        let input = mp4(audioEntry: entry, mdat: frame + frame)
        let track = try XCTUnwrap(VideoProbe.probe(input).audioTracks.first)
        XCTAssertEqual(track.format, .mp3)
        XCTAssertEqual(track.samplingFrequency, 44100)
        XCTAssertEqual(track.frameBitRate, 128_000)

        let result = VideoConformanceValidator.validateAudio(
            tracks: [track], container: .mp4, transferSyntax: .mpeg4AVCHP41)
        XCTAssertTrue(result.hasNoKnownViolations)
        // CBR would need every frame read; no Layer III bit rate exceeds 320 kbit/s.
        XCTAssertEqual(result.tracks.first?.notChecked, [.constantBitRate])
    }

    /// An `mp4a` entry without `esds` names no format: nothing is claimed, and
    /// the D34 wording is kept.
    func test_mp4_unidentifiedAudio_keepsTheGenericWarning() throws {
        let input = mp4(audioEntry: audioEntry("mp4a", channels: 2, sampleSize: 16, rate: 48000))
        let probe = try VideoProbe.probe(input)
        XCTAssertNil(probe.audioTracks.first?.format)
        let outcome = try VideoWorkflow.convert(
            bitstream: input, type: .endoscopic, typeWasExplicit: true, dryRun: true)
        XCTAssertEqual(outcome.output, VideoConsole.audioCarriedLine(trackCount: 1))
    }

    // MARK: - MPEG-TS

    func test_ts_ac3_isCountedAndAllowed() throws {
        let ac3 = TSStream(streamType: 0x81, pid: 0x0101, streamID: 0xBD, descriptors: Data(),
                           payload: Data(Self.ac3Stereo192))
        let probe = try VideoProbe.probe(transportStream([h264Video(), ac3]), trustInput: true)
        XCTAssertEqual(probe.audioTrackCount, 1, "audio in MPEG-TS is now counted")
        let track = try XCTUnwrap(probe.audioTracks.first)
        XCTAssertEqual(track.format, .ac3)
        XCTAssertEqual(track.pid, 0x0101)
        XCTAssertEqual(track.codecTag, "stream_type 0x81")
        XCTAssertEqual(track.samplingFrequency, 48000)
        XCTAssertEqual(track.channelCount, 2)
        XCTAssertEqual(track.maximumBitRate, 192_000)

        let result = VideoConformanceValidator.validateAudio(
            tracks: probe.audioTracks, container: .mpegTS, transferSyntax: .mpeg4AVCHP41)
        XCTAssertTrue(result.hasNoKnownViolations)
        XCTAssertEqual(result.tracks.first?.notChecked, [.bitsPerSample])

        let outcome = try VideoWorkflow.convert(
            bitstream: transportStream([h264Video(), ac3]), type: .endoscopic, typeWasExplicit: true,
            explicitTransferSyntax: TransferSyntax.mpeg4AVCHP41.uid, trustInput: true, dryRun: true)
        XCTAssertTrue(outcome.output.hasPrefix(
            "note: audio track 1 (AC-3, 48 kHz, 2 channels, max 192 kbit/s): "
            + "not checked against PS3.5 8.2.12: bits per sample."), outcome.output)
    }

    func test_ts_ac3FivePointOne_andDVBDescriptor() throws {
        // stream_type 0x06 with a DVB AC-3 descriptor (tag 0x6A).
        let ac3 = TSStream(streamType: 0x06, pid: 0x0102, streamID: 0xBD,
                           descriptors: Data([0x6A, 0x01, 0x00]), payload: Data(Self.ac3FivePointOne))
        let track = try XCTUnwrap(TransportStreamScanner.audioTracks(transportStream([h264Video(), ac3])).first)
        XCTAssertEqual(track.format, .ac3)
        XCTAssertEqual(track.channelCount, 6)
        XCTAssertEqual(track.hasLFE, true)
    }

    func test_ts_adtsAAC_isRead() throws {
        let aac = TSStream(streamType: 0x0F, pid: 0x0101, streamID: 0xC0, descriptors: Data(),
                           payload: Data(Self.adtsFrames))
        let tracks = TransportStreamScanner.audioTracks(transportStream([h264Video(), aac]))
        XCTAssertEqual(tracks.count, 1)
        XCTAssertEqual(tracks.first?.format, .aac)
        XCTAssertEqual(tracks.first?.samplingFrequency, 48000)
        XCTAssertEqual(tracks.first?.channelCount, 2)
    }

    func test_ts_hdmvLPCM_requiresTheHDMVRegistration() throws {
        // LPCM header: channel_assignment 3 (stereo), sampling_frequency 1 (48 kHz),
        // bits_per_sample 1 (16).
        let lpcm = TSStream(streamType: 0x80, pid: 0x1100, streamID: 0xBD, descriptors: Data(),
                            payload: Data([0x01, 0xE0, 0x31, 0x40]))
        let hdmv = Data([0x05, 0x04]) + Data("HDMV".utf8)
        let tracks = TransportStreamScanner.audioTracks(
            transportStream([h264Video(), lpcm], programInfo: hdmv))
        let track = try XCTUnwrap(tracks.first)
        XCTAssertEqual(track.format, .lpcm)
        XCTAssertEqual(track.samplingFrequency, 48000)
        XCTAssertEqual(track.channelCount, 2)
        XCTAssertEqual(track.bitsPerSample, 16)
        XCTAssertTrue(VideoConformanceValidator.validateAudio(
            tracks: tracks, container: .mpegTS, transferSyntax: .mpeg4AVCHP41).hasNoKnownViolations)

        // Without it, 0x80 is User Private (ATSC uses it for video): not audio.
        XCTAssertTrue(TransportStreamScanner.audioTracks(transportStream([h264Video(), lpcm])).isEmpty)
    }

    /// PS3.5 8.2.5: an MPEG2 stream's audio shall be CBR MP3.
    func test_mpeg2_mp3InTS_meets8_2_5_andAACDoesNot() throws {
        let mp3 = TSStream(streamType: 0x03, pid: 0x0101, streamID: 0xC0, descriptors: Data(),
                           payload: Data(Self.mp3Header))
        let ts = transportStream([mpeg2Video(), mp3])
        let track = try XCTUnwrap(VideoProbe.probe(ts, trustInput: true).audioTracks.first)
        XCTAssertEqual(track.format, .mp3)
        XCTAssertEqual(track.samplingFrequency, 44100)
        XCTAssertEqual(track.channelCount, 2)

        let result = VideoConformanceValidator.validateAudio(
            tracks: [track], container: .mpegTS, transferSyntax: .mpeg2MainProfile)
        XCTAssertEqual(result.section, "PS3.5 8.2.5")
        XCTAssertTrue(result.hasNoKnownViolations)
        XCTAssertEqual(result.tracks.first?.notChecked, [.bitsPerSample, .constantBitRate])

        let outcome = try VideoWorkflow.convert(
            bitstream: ts, type: .endoscopic, typeWasExplicit: true,
            explicitTransferSyntax: TransferSyntax.mpeg2MainProfile.uid, trustInput: true, dryRun: true)
        XCTAssertTrue(outcome.output.hasPrefix(
            "note: audio track 1 (MP3, 44.1 kHz, 2 channels, 128 kbit/s): not checked against "
            + "PS3.5 8.2.5: bits per sample, constant bit rate."), outcome.output)

        let aac = VideoAudioTrack(format: .aac, codecTag: "stream_type 0x0F",
                                  samplingFrequency: 48000, channelCount: 2)
        let rejected = VideoConformanceValidator.validateAudio(
            tracks: [aac], container: .mpegTS, transferSyntax: .mpeg2MainProfileHighLevel)
        XCTAssertEqual(rejected.violations.first?.message,
                       "AAC is not a permitted audio format; PS3.5 8.2.5 allows only CBR MPEG-1 Layer III (MP3)")
    }

    /// Unknown values are "not checked", never violations.
    func test_unknownValues_areNotChecked() {
        let result = VideoConformanceValidator.validateAudio(
            tracks: [VideoAudioTrack(format: .aac, codecTag: "x"), .unidentified],
            container: .mp4, transferSyntax: .mpeg4AVCHP41)
        XCTAssertTrue(result.hasNoKnownViolations)
        XCTAssertEqual(result.tracks[0].notChecked,
                       [.maximumBitRate, .samplingFrequency, .bitsPerSample, .channels])
        XCTAssertEqual(result.tracks[1].notChecked, VideoAudioViolation.Constraint.allCases)
    }

    func test_otherLimits_bitRateChannelsBitsAndFormat() {
        func messages(_ track: VideoAudioTrack, _ container: VideoContainer = .mpegTS) -> [String] {
            VideoConformanceValidator.validateAudio(
                tracks: [track], container: container, transferSyntax: .mpeg4AVCHP41).violations.map(\.message)
        }
        XCTAssertEqual(messages(VideoAudioTrack(
            format: .aac, codecTag: "x", samplingFrequency: 48000, channelCount: 1,
            bitsPerSample: 16, maximumBitRate: 700_000)), [
            "bit rate 700 kbit/s exceeds the PS3.5 8.2.12 maximum of 640 kbit/s for AAC",
            "1 channel is not permitted for AAC; PS3.5 8.2.12 allows 2 or 5.1 channels",
        ])
        XCTAssertEqual(messages(VideoAudioTrack(
            format: .ac3, codecTag: "x", samplingFrequency: 48000, channelCount: 2, bitsPerSample: 24,
            maximumBitRate: 192_000)),
            ["24 bits per sample is not permitted for AC-3; PS3.5 8.2.12 allows 16 bits"])
        XCTAssertEqual(messages(VideoAudioTrack(
            format: .lpcm, codecTag: "x", samplingFrequency: 96000, channelCount: 2, bitsPerSample: 24,
            maximumBitRate: 4_608_000)), [], "96 kHz / 24-bit stereo LPCM is exactly the limit")
        XCTAssertEqual(messages(VideoAudioTrack(format: .trueHD, codecTag: "x")), [
            "Dolby TrueHD is not a permitted audio format; PS3.5 8.2.12 allows "
            + "LPCM, AC-3, AAC, MP3 or MPEG-1 Layer II",
        ])
        XCTAssertEqual(messages(VideoAudioTrack(
            format: .mp3, codecTag: "x", samplingFrequency: 22050, channelCount: 2, frameBitRate: 64000)),
            ["sampling frequency 22.05 kHz is not permitted for MP3; PS3.5 8.2.12 allows "
             + "32 kHz, 44.1 kHz or 48 kHz for the main channel"])
    }

    /// D59: PS3.5 2026a 8.2.12 "AC-3 is standardized in" ETSI TS 102 366, which the
    /// PS3.5 bibliography titles "Audio Compression (AC-3, Enhanced AC-3)
    /// Standard", so E-AC-3 is judged by the AC-3 row of Table 8.2.12-1.
    func test_eac3_withinAC3Limits_isPermitted() {
        let track = VideoAudioTrack(
            format: .eac3, codecTag: "stream_type 0x87", pid: 0x101, samplingFrequency: 48000,
            channelCount: 6, hasLFE: true, bitsPerSample: 16, maximumBitRate: 640_000)
        let result = VideoConformanceValidator.validateAudio(
            tracks: [track], container: .mpegTS, transferSyntax: .mpeg4AVCHP41)
        XCTAssertEqual(result.violations.map(\.message), [])
        XCTAssertTrue(result.hasNoKnownViolations)
    }

    func test_eac3_beyondAC3Limits_reportsEachViolation() {
        let track = VideoAudioTrack(
            format: .eac3, codecTag: "ec-3", samplingFrequency: 44100, channelCount: 8,
            bitsPerSample: 24, maximumBitRate: 1_024_000)
        let messages = VideoConformanceValidator.validateAudio(
            tracks: [track], container: .mp4, transferSyntax: .hevcH265MainProfile).violations.map(\.message)
        XCTAssertEqual(messages, [
            "E-AC-3 is permitted only in an MPEG-2 TS container, not MP4 (PS3.5 Table 8.2.12-1)",
            "bit rate 1024 kbit/s exceeds the PS3.5 8.2.12 maximum of 640 kbit/s for E-AC-3",
            "sampling frequency 44.1 kHz is not permitted for E-AC-3; PS3.5 8.2.12 allows 48 kHz",
            "24 bits per sample is not permitted for E-AC-3; PS3.5 8.2.12 allows 16 bits",
            "8 channels is not permitted for E-AC-3; PS3.5 8.2.12 allows 2 or 5.1 channels",
        ])
        // 8.2.5 (MPEG2) permits only MP3, so E-AC-3 still fails the format check there.
        let mpeg2 = VideoConformanceValidator.validateAudio(
            tracks: [track], container: .mpegTS, transferSyntax: .mpeg2MainProfile).violations.map(\.message)
        XCTAssertEqual(mpeg2, [
            "E-AC-3 is not a permitted audio format; PS3.5 8.2.5 allows only CBR MPEG-1 Layer III (MP3)",
        ])
    }

    // MARK: - Header Parsers

    func test_audioSpecificConfig_readsHEAACExtensionRate() throws {
        // AOT 5 (SBR), core 24 kHz, channelConfiguration 2, extension 48 kHz, core AOT 2.
        let config = try XCTUnwrap(AudioHeaderParser.audioSpecificConfig(Data([0x2B, 0x11, 0x88])))
        XCTAssertEqual(config.format, .aac)
        XCTAssertEqual(config.samplingFrequency, 48000)
        XCTAssertEqual(config.channelConfiguration, 2)
        XCTAssertEqual(AudioHeaderParser.audioSpecificConfig(Data(Self.ascLC44Stereo))?.samplingFrequency, 44100)
    }

    func test_mpegAudioHeader_fields() throws {
        let header = try XCTUnwrap(AudioHeaderParser.mpegAudioHeader(Self.mp3Header))
        XCTAssertEqual(header.layer, 3)
        XCTAssertEqual(header.version, 1)
        XCTAssertEqual(header.samplingFrequency, 44100)
        XCTAssertEqual(header.bitRate, 128_000)
        XCTAssertEqual(header.channelCount, 2)
        // MPEG-1 Layer II, 384 kbit/s (index 14), 48 kHz, single channel.
        let layer2 = try XCTUnwrap(AudioHeaderParser.mpegAudioHeader([0xFF, 0xFD, 0xE4, 0xC0]))
        XCTAssertEqual(layer2.format, .mpeg1LayerII)
        XCTAssertEqual(layer2.bitRate, 384_000)
        XCTAssertEqual(layer2.samplingFrequency, 48000)
        XCTAssertEqual(layer2.channelCount, 1)
    }

    // MARK: - (003A,0300) Items (PS3.3 Table C.7-13)

    func test_channels_derivedOnlyForMonoAndStereo() {
        let stereo = VideoAudioTrack(format: .aac, codecTag: "x", channelCount: 2)
        let mono = VideoAudioTrack(format: .mp3, codecTag: "x", channelCount: 1)
        XCTAssertEqual(VideoAudioChannel.channels(describing: [stereo, mono], source: .voice), [
            VideoAudioChannel(channelIdentificationCode: 1, mode: .stereo, source: .voice),
            VideoAudioChannel(channelIdentificationCode: 2, mode: .mono, source: .voice),
        ])
        let surround = VideoAudioTrack(format: .aac, codecTag: "x", channelCount: 6, hasLFE: true)
        let dual = VideoAudioTrack(format: .mp3, codecTag: "x", channelCount: 2, isDualMono: true)
        XCTAssertNil(VideoAudioChannel.channels(describing: [surround], source: .voice))
        XCTAssertNil(VideoAudioChannel.channels(describing: [dual], source: .voice))
        XCTAssertNil(VideoAudioChannel.channels(describing: [.unidentified], source: .voice))
        XCTAssertNil(VideoAudioChannel.channels(
            describing: Array(repeating: stereo, count: 10), source: .voice))
    }

    func test_multiplexedAudioChannels_roundTripThroughVideoParser() throws {
        let channels = [
            VideoAudioChannel(channelIdentificationCode: 1, mode: .stereo, source: .operatorsNarrative),
            VideoAudioChannel(channelIdentificationCode: 2, mode: .mono, source: .dopplerAudio),
        ]
        let video = try VideoBuilder(
            videoType: .endoscopic, rows: 1080, columns: 1920, numberOfFrames: 4,
            studyInstanceUID: "1.2.3.4.5", seriesInstanceUID: "1.2.3.4.5.6"
        ).setMultiplexedAudioChannels(channels).build()

        let parsed = try VideoParser.parse(from: video.toDataSet())
        XCTAssertEqual(parsed.multiplexedAudioChannels, channels)
        XCTAssertTrue(parsed.declaresMultiplexedAudio)
        XCTAssertEqual(parsed.toDataSet()[Tag(group: 0x003A, element: 0x0300)]?.sequenceItems?.count, 2)
    }

    func test_emptyAudioSequence_survivesARoundTrip() throws {
        var video = try VideoBuilder(
            videoType: .endoscopic, rows: 1080, columns: 1920, numberOfFrames: 4,
            studyInstanceUID: "1.2.3.4.5", seriesInstanceUID: "1.2.3.4.5.6"
        ).build()
        XCTAssertFalse(try VideoParser.parse(from: video.toDataSet()).declaresMultiplexedAudio)

        video.containsUndescribedMultiplexedAudio = true
        let parsed = try VideoParser.parse(from: video.toDataSet())
        XCTAssertTrue(parsed.multiplexedAudioChannels.isEmpty)
        XCTAssertTrue(parsed.declaresMultiplexedAudio)
        let sequence = try XCTUnwrap(parsed.toDataSet()[Tag(group: 0x003A, element: 0x0300)])
        XCTAssertEqual(sequence.sequenceItems?.count ?? 0, 0)
    }

    /// CID 3000 is Extensible (PS3.16 2026a "Type: Extensible"; Table C.7-13
    /// "DCID 3000"), so an Item with another code is kept and written back (D57).
    func test_parser_keepsItemsOutsideCID3000() throws {
        let video = try VideoBuilder(
            videoType: .endoscopic, rows: 1080, columns: 1920, numberOfFrames: 4,
            studyInstanceUID: "1.2.3.4.5", seriesInstanceUID: "1.2.3.4.5.6"
        ).setMultiplexedAudioChannels([
            VideoAudioChannel(channelIdentificationCode: 1, mode: .stereo, source: .voice),
        ]).build()
        var dataSet = video.toDataSet()
        let tag = Tag(group: 0x003A, element: 0x0300)
        let source = SequenceItem(elements: [
            .string(tag: .codeValue, vr: .SH, value: "99999"),
            .string(tag: .codingSchemeDesignator, vr: .SH, value: "99LOCAL"),
            .string(tag: .codeMeaning, vr: .LO, value: "Local"),
        ])
        let item = SequenceItem(elements: [
            .string(tag: Tag(group: 0x003A, element: 0x0301), vr: .IS, value: "1"),
            .string(tag: Tag(group: 0x003A, element: 0x0302), vr: .CS, value: "MONO"),
            DataElement(tag: .channelSourceSequence, vr: .SQ, length: 0xFFFFFFFF,
                        valueData: Data(), sequenceItems: [source]),
        ])
        dataSet[tag] = DataElement(tag: tag, vr: .SQ, length: 0xFFFFFFFF,
                                   valueData: Data(), sequenceItems: [item])
        let parsed = try VideoParser.parse(from: dataSet)
        let local = VideoAudioChannel.Source(CodedConcept(
            codeValue: "99999", codingSchemeDesignator: "99LOCAL", codeMeaning: "Local"))
        XCTAssertEqual(parsed.multiplexedAudioChannels, [
            VideoAudioChannel(channelIdentificationCode: 1, mode: .mono, source: local),
        ])
        XCTAssertEqual(parsed.multiplexedAudioChannels.first?.source.codeMeaning, "Local")
        XCTAssertFalse(parsed.multiplexedAudioChannels.first?.source.isCID3000Member ?? true)
        XCTAssertTrue(parsed.declaresMultiplexedAudio)

        let written = try XCTUnwrap(parsed.toDataSet()[tag]?.sequenceItems)
        XCTAssertEqual(written.count, 1)
        let sourceItems = try XCTUnwrap(written[0][.channelSourceSequence]?.sequenceItems)
        XCTAssertEqual(sourceItems.count, 1, "Only a single Item shall be included")
        XCTAssertEqual(sourceItems[0].string(for: .codeValue), "99999")
        XCTAssertEqual(sourceItems[0].string(for: .codingSchemeDesignator), "99LOCAL")
        XCTAssertEqual(sourceItems[0].string(for: .codeMeaning), "Local")
    }

    /// A Channel Source Item with no code at all is still dropped (Type 1).
    func test_parser_dropsChannelSourceWithoutCode() throws {
        var dataSet = try VideoBuilder(
            videoType: .endoscopic, rows: 1080, columns: 1920, numberOfFrames: 4,
            studyInstanceUID: "1.2.3.4.5", seriesInstanceUID: "1.2.3.4.5.6"
        ).build().toDataSet()
        let tag = Tag(group: 0x003A, element: 0x0300)
        let source = SequenceItem(elements: [.string(tag: .codeMeaning, vr: .LO, value: "No code")])
        let item = SequenceItem(elements: [
            .string(tag: Tag(group: 0x003A, element: 0x0301), vr: .IS, value: "1"),
            .string(tag: Tag(group: 0x003A, element: 0x0302), vr: .CS, value: "MONO"),
            DataElement(tag: .channelSourceSequence, vr: .SQ, length: 0xFFFFFFFF,
                        valueData: Data(), sequenceItems: [source]),
        ])
        dataSet[tag] = DataElement(tag: tag, vr: .SQ, length: 0xFFFFFFFF,
                                   valueData: Data(), sequenceItems: [item])
        let parsed = try VideoParser.parse(from: dataSet)
        XCTAssertTrue(parsed.multiplexedAudioChannels.isEmpty)
        XCTAssertTrue(parsed.declaresMultiplexedAudio)
    }

    /// With a caller-named source and a stereo track, convert writes one Item
    /// and the written file parses back to it.
    func test_convert_withAudioChannelSource_writesItemsThatParseBack() throws {
        let input = mp4(audioEntry: aacEntry(rate: 48000, dsi: Self.ascLC48Stereo))
        let outcome = try VideoWorkflow.convert(
            bitstream: input, type: .endoscopic, typeWasExplicit: true,
            metadata: VideoWorkflow.Metadata(audioChannelSource: .operatorsNarrative))
        XCTAssertEqual(outcome.output,
                       "note: audio track 1 (AAC, 48 kHz, 2 channels, 16-bit, max 192 kbit/s) meets PS3.5 8.2.12.")

        let file = try DICOMFile.read(from: try XCTUnwrap(outcome.data))
        let items = try XCTUnwrap(file.dataSet[Tag(group: 0x003A, element: 0x0300)]?.sequenceItems)
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].string(for: Tag(group: 0x003A, element: 0x0301)), "1")
        XCTAssertEqual(items[0].string(for: Tag(group: 0x003A, element: 0x0302)), "STEREO")

        let parsed = try VideoParser.parse(from: file.dataSet)
        XCTAssertEqual(parsed.multiplexedAudioChannels, [
            VideoAudioChannel(channelIdentificationCode: 1, mode: .stereo, source: .operatorsNarrative),
        ])
    }

    func test_convert_withSourceButSurround_keepsTheSequenceEmpty() throws {
        let dsi: [UInt8] = [0x11, 0xB0]  // AAC LC, 48 kHz, channelConfiguration 6 (5.1)
        let input = mp4(audioEntry: aacEntry(rate: 48000, dsi: dsi))
        let outcome = try VideoWorkflow.convert(
            bitstream: input, type: .endoscopic, typeWasExplicit: true,
            metadata: VideoWorkflow.Metadata(audioChannelSource: .voice))
        XCTAssertTrue(outcome.output.hasSuffix(VideoConsole.audioChannelLayoutUndescribedLine), outcome.output)
        let sequence = try XCTUnwrap(outcome.video?.toDataSet()[Tag(group: 0x003A, element: 0x0300)])
        XCTAssertEqual(sequence.sequenceItems?.count ?? 0, 0)
    }

    // MARK: - API compatibility

    func test_countInitializer_stillWorks() {
        let stream = VideoStreamInfo(
            codec: .h264, width: 1920, height: 1080, profileIDC: 100, levelTimesTen: 41,
            chromaFormat: .yuv420, bitDepthLuma: 8, bitDepthChroma: 8, frameRate: 30, isProgressive: true)
        let result = VideoProbeResult(
            container: .mp4, stream: stream, frameCount: 1, frameCountSource: .sampleTable,
            audioTrackCount: 2, suggestedTransferSyntax: nil, frameRate: 30)
        XCTAssertEqual(result.audioTrackCount, 2)
        XCTAssertEqual(result.audioTracks, [.unidentified, .unidentified])
    }
}
