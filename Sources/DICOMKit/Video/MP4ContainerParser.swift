//
// MP4ContainerParser.swift
// DICOMKit
//
// Copyright © 2026 DICOMKit. All rights reserved.
//

import Foundation

/// The container a video payload arrives in.
///
/// PS3.5 Sections 8.2.7, 8.2.10 and 8.2.11 each state that "the container format
/// for the video bit stream shall be MPEG-2 Transport Stream, a.k.a. MPEG-TS … or
/// MPEG-4, a.k.a. MP4 container", so the encapsulated payload *retains* its
/// container rather than being demuxed to an elementary stream.
public enum VideoContainer: Sendable, Hashable {
    /// ISO Base Media File Format with an MP4-compatible brand.
    case mp4
    /// QuickTime movie. Structurally an ISO-BMFF file, but not an MP4 brand, so it
    /// must be remuxed before encapsulation.
    case quickTime
    /// MPEG-2 Transport Stream.
    case mpegTS
    /// A raw Annex B / MPEG-2 elementary stream with no container at all.
    case elementaryStream
    /// Something this toolkit does not recognize.
    case unknown

    /// Whether DICOM permits this container as an encapsulated payload.
    public var isPermittedByDICOM: Bool {
        switch self {
        case .mp4, .mpegTS: return true
        case .quickTime, .elementaryStream, .unknown: return false
        }
    }

    /// A human-readable name for error messages.
    public var displayName: String {
        switch self {
        case .mp4: return "MP4"
        case .quickTime: return "QuickTime (MOV)"
        case .mpegTS: return "MPEG-2 Transport Stream"
        case .elementaryStream: return "raw elementary stream"
        case .unknown: return "unrecognized container"
        }
    }
}

/// Parses the parts of an ISO Base Media File Format file this toolkit needs.
///
/// This is a *reader*, not a muxer: it walks the box tree to identify the codec,
/// recover the parameter sets from `avcC` / `hvcC`, and read the exact frame count
/// from the sample table. Everything here is plain byte handling, so it works on
/// every platform — rewriting a container is the part that needs AVFoundation.
///
/// Reference: ISO/IEC 14496-12 (ISO Base Media File Format),
/// ISO/IEC 14496-14 (MP4), ISO/IEC 14496-15 (AVC/HEVC file format)
public enum MP4ContainerParser {

    // MARK: - Box

    /// One box in the ISO-BMFF tree.
    public struct Box: Sendable, Hashable {
        /// The four-character type, e.g. "moov" or "avcC".
        public let type: String
        /// Offset of the box header within the file.
        public let offset: Int
        /// Total size of the box, header included.
        public let size: Int
        /// Offset of the box's payload, i.e. past its header.
        public let payloadOffset: Int
        /// Size of the box's payload.
        public var payloadSize: Int { size - (payloadOffset - offset) }
    }

    /// What an MP4's video track says about itself.
    public struct TrackInfo: Sendable {
        /// The codec, from the sample entry's four-character code.
        public let codec: VideoCodec
        /// Width in pixels, from the sample description.
        public let width: Int
        /// Height in pixels, from the sample description.
        public let height: Int
        /// Exact frame count from the sample table, which is cheaper and more
        /// reliable than counting access units in the bit stream.
        public let frameCount: Int
        /// Sequence Parameter Sets from `avcC` / `hvcC`, without NAL headers for
        /// AVC and with them for HEVC, as each box stores them.
        public let parameterSets: [Data]
        /// Frame rate derived from the media timescale and sample durations.
        public let frameRate: Double?
    }

    /// A summary of an MP4 file's structure.
    public struct FileInfo: Sendable {
        /// The detected container.
        public let container: VideoContainer
        /// Brands from the `ftyp` box: the major brand first, then compatible ones.
        public let brands: [String]
        /// Video tracks found, in file order.
        public let videoTracks: [TrackInfo]
        /// The number of audio tracks, which DICOM video IODs cannot carry.
        public let audioTrackCount: Int
    }

    // MARK: - Container Detection

    /// Identifies a container by inspecting its bytes rather than its extension.
    ///
    /// A file's extension is a claim; its bytes are evidence. Endoscopy carts in
    /// particular produce `.mp4`-named files that are really QuickTime.
    public static func detectContainer(_ data: Data) -> VideoContainer {
        // ISO-BMFF: the first box is normally `ftyp`, whose brands decide whether
        // this is MP4 or QuickTime.
        if let ftyp = findBox(type: "ftyp", in: data, range: 0..<data.count) {
            let brands = readBrands(data, box: ftyp)
            if brands.contains(where: { $0.hasPrefix("qt") }) {
                return .quickTime
            }
            // isom, iso2, iso4-6, mp41/42, avc1, dash, and the M4V family are all
            // MP4-compatible brands.
            if brands.contains(where: { brand in
                brand.hasPrefix("iso") || brand.hasPrefix("mp4")
                    || brand == "avc1" || brand == "dash"
                    || brand.hasPrefix("M4V") || brand == "M4A "
            }) {
                return .mp4
            }
            // An ftyp with unfamiliar brands is still ISO-BMFF; treat it as MP4
            // only when it also has a moov box.
            if findBox(type: "moov", in: data, range: 0..<data.count) != nil {
                return .mp4
            }
            return .unknown
        }

        // QuickTime files may omit ftyp entirely and lead with moov or mdat.
        if findBox(type: "moov", in: data, range: 0..<data.count) != nil {
            return .quickTime
        }

        if isTransportStream(data) {
            return .mpegTS
        }

        if NALUnit.hasAnnexBStartCode(data) || hasMPEG2StartCode(data) {
            return .elementaryStream
        }

        return .unknown
    }

    /// Whether the data looks like an MPEG-2 Transport Stream.
    ///
    /// A TS is a run of 188-byte packets each beginning with the sync byte 0x47.
    /// Checking several consecutive packets avoids matching a stray 0x47.
    ///
    /// Reference: ISO/IEC 13818-1
    public static func isTransportStream(_ data: Data) -> Bool {
        let packetSize = 188
        let bytes = [UInt8](data.prefix(packetSize * 8))
        guard bytes.count >= packetSize * 2 else { return false }

        // Allow for a leading partial packet by trying each plausible start.
        for start in 0..<min(packetSize, bytes.count) {
            guard bytes[start] == 0x47 else { continue }
            var offset = start
            var matched = 0
            while offset < bytes.count {
                guard bytes[offset] == 0x47 else { break }
                matched += 1
                offset += packetSize
            }
            if matched >= 3 { return true }
        }
        return false
    }

    /// Whether the data begins with an MPEG-2 sequence or pack start code.
    private static func hasMPEG2StartCode(_ data: Data) -> Bool {
        let bytes = [UInt8](data.prefix(4))
        guard bytes.count >= 4 else { return false }
        guard bytes[0] == 0x00, bytes[1] == 0x00, bytes[2] == 0x01 else { return false }
        // B3 sequence header, BA pack header, or a picture start code.
        return bytes[3] == 0xB3 || bytes[3] == 0xBA || bytes[3] == 0x00
    }

    // MARK: - Box Walking

    /// Lists the boxes directly inside a byte range, without descending.
    public static func boxes(in data: Data, range: Range<Int>) -> [Box] {
        var result: [Box] = []
        var offset = range.lowerBound

        while offset + 8 <= range.upperBound {
            guard let size32 = readUInt32(data, at: offset),
                  let type = readFourCC(data, at: offset + 4)
            else { break }

            var size = Int(size32)
            var payloadOffset = offset + 8

            if size == 1 {
                // A 64-bit `largesize` follows the type.
                guard let large = readUInt64(data, at: offset + 8) else { break }
                guard large <= UInt64(Int.max) else { break }
                size = Int(large)
                payloadOffset = offset + 16
            } else if size == 0 {
                // Size 0 means the box runs to the end of the file.
                size = range.upperBound - offset
            }

            guard size >= payloadOffset - offset, offset + size <= range.upperBound else {
                break
            }

            result.append(Box(type: type, offset: offset, size: size, payloadOffset: payloadOffset))
            offset += size
        }

        return result
    }

    /// Finds the first box of a type directly inside a range.
    public static func findBox(type: String, in data: Data, range: Range<Int>) -> Box? {
        boxes(in: data, range: range).first { $0.type == type }
    }

    /// Follows a path of box types down the tree, e.g. `["moov", "trak", "mdia"]`.
    public static func findBox(path: [String], in data: Data) -> Box? {
        var range = 0..<data.count
        var found: Box?
        for type in path {
            guard let box = findBox(type: type, in: data, range: range) else { return nil }
            found = box
            range = box.payloadOffset..<(box.offset + box.size)
        }
        return found
    }

    // MARK: - File Inspection

    /// Reads an MP4 or MOV file's structure.
    ///
    /// - Returns: The file's structure, or nil when it is not ISO-BMFF at all.
    public static func inspect(_ data: Data) -> FileInfo? {
        let container = detectContainer(data)
        guard container == .mp4 || container == .quickTime else { return nil }

        var brands: [String] = []
        if let ftyp = findBox(type: "ftyp", in: data, range: 0..<data.count) {
            brands = readBrands(data, box: ftyp)
        }

        guard let moov = findBox(type: "moov", in: data, range: 0..<data.count) else {
            return FileInfo(container: container, brands: brands, videoTracks: [], audioTrackCount: 0)
        }

        var videoTracks: [TrackInfo] = []
        var audioTrackCount = 0

        let moovRange = moov.payloadOffset..<(moov.offset + moov.size)
        for trak in boxes(in: data, range: moovRange) where trak.type == "trak" {
            let trakRange = trak.payloadOffset..<(trak.offset + trak.size)
            guard let mdia = findBox(type: "mdia", in: data, range: trakRange) else { continue }
            let mdiaRange = mdia.payloadOffset..<(mdia.offset + mdia.size)

            // The handler type says what kind of track this is.
            guard let hdlr = findBox(type: "hdlr", in: data, range: mdiaRange),
                  let handler = readFourCC(data, at: hdlr.payloadOffset + 8)
            else { continue }

            if handler == "soun" {
                audioTrackCount += 1
                continue
            }
            guard handler == "vide" else { continue }

            if let track = parseVideoTrack(data, mdiaRange: mdiaRange) {
                videoTracks.append(track)
            }
        }

        return FileInfo(
            container: container,
            brands: brands,
            videoTracks: videoTracks,
            audioTrackCount: audioTrackCount
        )
    }

    // MARK: - Private

    /// Parses a video track from its `mdia` box.
    private static func parseVideoTrack(_ data: Data, mdiaRange: Range<Int>) -> TrackInfo? {
        // mdhd carries the timescale and duration, which give the frame rate.
        var timescale: UInt32 = 0
        var duration: UInt64 = 0
        if let mdhd = findBox(type: "mdhd", in: data, range: mdiaRange) {
            let versionOffset = mdhd.payloadOffset
            if let version = readUInt8(data, at: versionOffset) {
                if version == 1 {
                    timescale = readUInt32(data, at: versionOffset + 20) ?? 0
                    duration = readUInt64(data, at: versionOffset + 24) ?? 0
                } else {
                    timescale = readUInt32(data, at: versionOffset + 12) ?? 0
                    duration = UInt64(readUInt32(data, at: versionOffset + 16) ?? 0)
                }
            }
        }

        guard let minf = findBox(type: "minf", in: data, range: mdiaRange) else { return nil }
        let minfRange = minf.payloadOffset..<(minf.offset + minf.size)
        guard let stbl = findBox(type: "stbl", in: data, range: minfRange) else { return nil }
        let stblRange = stbl.payloadOffset..<(stbl.offset + stbl.size)

        // stsd holds the sample description: the codec and its parameter sets.
        guard let stsd = findBox(type: "stsd", in: data, range: stblRange) else { return nil }
        // stsd payload: version/flags (4) then entry_count (4), then the entries.
        let entriesStart = stsd.payloadOffset + 8
        let stsdEnd = stsd.offset + stsd.size
        guard entriesStart < stsdEnd else { return nil }

        guard let sampleEntry = boxes(in: data, range: entriesStart..<stsdEnd).first else {
            return nil
        }

        let codec: VideoCodec
        switch sampleEntry.type {
        case "avc1", "avc3", "avc2", "avc4":
            codec = .h264
        case "hvc1", "hev1", "hvc2", "hev2":
            codec = .h265
        case "mp4v", "m2v1", "mpeg", "mp2v":
            codec = .mpeg2
        default:
            codec = .unknown
        }

        // A visual sample entry is 78 bytes before its extension boxes; width and
        // height sit at offsets 24 and 26 within it.
        let width = Int(readUInt16(data, at: sampleEntry.payloadOffset + 24) ?? 0)
        let height = Int(readUInt16(data, at: sampleEntry.payloadOffset + 26) ?? 0)

        let extensionsStart = sampleEntry.payloadOffset + 78
        let sampleEntryEnd = sampleEntry.offset + sampleEntry.size
        var parameterSets: [Data] = []
        if extensionsStart < sampleEntryEnd {
            let extensionRange = extensionsStart..<sampleEntryEnd
            if let avcC = findBox(type: "avcC", in: data, range: extensionRange) {
                parameterSets = parseAVCC(data, box: avcC)
            } else if let hvcC = findBox(type: "hvcC", in: data, range: extensionRange) {
                parameterSets = parseHVCC(data, box: hvcC)
            }
        }

        // stsz gives the exact sample count — one sample is one coded picture.
        var frameCount = 0
        if let stsz = findBox(type: "stsz", in: data, range: stblRange) {
            frameCount = Int(readUInt32(data, at: stsz.payloadOffset + 8) ?? 0)
        } else if let stz2 = findBox(type: "stz2", in: data, range: stblRange) {
            frameCount = Int(readUInt32(data, at: stz2.payloadOffset + 8) ?? 0)
        }

        var frameRate: Double?
        if timescale > 0, duration > 0, frameCount > 0 {
            let seconds = Double(duration) / Double(timescale)
            if seconds > 0 {
                let rate = Double(frameCount) / seconds
                if rate.isFinite, rate > 0, rate < 1000 { frameRate = rate }
            }
        }

        return TrackInfo(
            codec: codec,
            width: width,
            height: height,
            frameCount: frameCount,
            parameterSets: parameterSets,
            frameRate: frameRate
        )
    }

    /// Extracts SPS and PPS payloads from an `avcC` box.
    ///
    /// The AVCDecoderConfigurationRecord stores parameter sets **without** NAL
    /// headers and length-prefixed, not as Annex B.
    ///
    /// Reference: ISO/IEC 14496-15 Section 5.3.3.1
    public static func parseAVCC(_ data: Data, box: Box) -> [Data] {
        var offset = box.payloadOffset
        let end = box.offset + box.size
        // configurationVersion, AVCProfileIndication, profile_compatibility,
        // AVCLevelIndication, lengthSizeMinusOne, numOfSequenceParameterSets
        guard offset + 6 <= end else { return [] }
        guard let spsCountByte = readUInt8(data, at: offset + 5) else { return [] }
        let spsCount = Int(spsCountByte & 0x1F)
        offset += 6

        var sets: [Data] = []
        for _ in 0..<spsCount {
            guard offset + 2 <= end, let length = readUInt16(data, at: offset) else { break }
            offset += 2
            guard offset + Int(length) <= end else { break }
            sets.append(data.subdata(in: offset..<(offset + Int(length))))
            offset += Int(length)
        }
        return sets
    }

    /// Extracts parameter set payloads from an `hvcC` box.
    ///
    /// The HEVCDecoderConfigurationRecord groups its arrays by NAL type, and each
    /// stored unit **includes** its two-byte NAL header.
    ///
    /// Reference: ISO/IEC 14496-15 Section 8.3.3.1
    public static func parseHVCC(_ data: Data, box: Box) -> [Data] {
        var offset = box.payloadOffset
        let end = box.offset + box.size
        // The fixed portion of the record is 22 bytes, then numOfArrays.
        guard offset + 23 <= end else { return [] }
        guard let arrayCount = readUInt8(data, at: offset + 22) else { return [] }
        offset += 23

        var sets: [Data] = []
        for _ in 0..<Int(arrayCount) {
            guard offset + 3 <= end,
                  let nalCount = readUInt16(data, at: offset + 1)
            else { break }
            offset += 3

            for _ in 0..<Int(nalCount) {
                guard offset + 2 <= end, let length = readUInt16(data, at: offset) else { break }
                offset += 2
                guard offset + Int(length) <= end else { break }
                sets.append(data.subdata(in: offset..<(offset + Int(length))))
                offset += Int(length)
            }
        }
        return sets
    }

    /// Reads the major and compatible brands from an `ftyp` box.
    private static func readBrands(_ data: Data, box: Box) -> [String] {
        var brands: [String] = []
        if let major = readFourCC(data, at: box.payloadOffset) {
            brands.append(major)
        }
        // major_brand (4) + minor_version (4), then compatible brands.
        var offset = box.payloadOffset + 8
        let end = box.offset + box.size
        while offset + 4 <= end {
            if let brand = readFourCC(data, at: offset) {
                brands.append(brand)
            }
            offset += 4
        }
        return brands
    }

    // MARK: - Byte Readers

    private static func readUInt8(_ data: Data, at offset: Int) -> UInt8? {
        guard offset >= 0, offset < data.count else { return nil }
        return data[data.startIndex + offset]
    }

    private static func readUInt16(_ data: Data, at offset: Int) -> UInt16? {
        guard offset >= 0, offset + 2 <= data.count else { return nil }
        let base = data.startIndex + offset
        return (UInt16(data[base]) << 8) | UInt16(data[base + 1])
    }

    private static func readUInt32(_ data: Data, at offset: Int) -> UInt32? {
        guard offset >= 0, offset + 4 <= data.count else { return nil }
        let base = data.startIndex + offset
        return (UInt32(data[base]) << 24) | (UInt32(data[base + 1]) << 16)
            | (UInt32(data[base + 2]) << 8) | UInt32(data[base + 3])
    }

    private static func readUInt64(_ data: Data, at offset: Int) -> UInt64? {
        guard offset >= 0, offset + 8 <= data.count else { return nil }
        let base = data.startIndex + offset
        var value: UInt64 = 0
        for index in 0..<8 {
            value = (value << 8) | UInt64(data[base + index])
        }
        return value
    }

    private static func readFourCC(_ data: Data, at offset: Int) -> String? {
        guard offset >= 0, offset + 4 <= data.count else { return nil }
        let base = data.startIndex + offset
        let bytes = [data[base], data[base + 1], data[base + 2], data[base + 3]]
        // Box types are printable ASCII; anything else means we are misaligned.
        guard bytes.allSatisfy({ $0 >= 0x20 && $0 <= 0x7E }) else { return nil }
        return String(bytes: bytes, encoding: .ascii)
    }
}
