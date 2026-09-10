//
// TransportStreamScanner.swift
// DICOMKit
//
// Copyright © 2026 DICOMKit. All rights reserved.
//

import Foundation

/// Recovers the leading elementary-stream bytes from an MPEG-2 Transport Stream.
///
/// This is deliberately **not** a demuxer. It reassembles just enough of the
/// first video PID to reach a sequence or parameter set header, because the
/// alternative — encapsulating a stream whose geometry is entirely unknown —
/// produces a DICOM object with Rows and Columns of zero, which no reader can
/// display. Frame counts, timing and audio still require real demuxing.
///
/// Reference: ISO/IEC 13818-1 Sections 2.4.3.2 (packet layer), 2.4.3.6 (PES)
public enum TransportStreamScanner {

    /// The fixed TS packet length. The 192- and 204-byte variants carry the same
    /// 188-byte packet with extra framing, which `packetStride` detects.
    private static let packetSize = 188

    /// How many bytes of elementary stream to gather before giving up. A sequence
    /// header sits near the start of the first GOP, so a small budget suffices and
    /// keeps a large file from being walked in full.
    private static let payloadBudget = 512 * 1024

    /// Stream type values that identify a video PID in the PMT, mapped to the
    /// codec each denotes.
    ///
    /// The PMT is the authority on codec here. Sniffing the payload instead would
    /// misidentify it: MPEG-2 start codes share the Annex B prefix, so an MPEG-2
    /// sequence header can parse as a plausible — and wrong — H.264 SPS.
    ///
    /// Reference: ISO/IEC 13818-1 Table 2-34
    private static let videoStreamTypes: [UInt8: VideoCodec] = [
        0x01: .mpeg2,  // MPEG-1 video, which the MPEG-2 parser also reads
        0x02: .mpeg2,
        0x1B: .h264,
        0x24: .h265,
    ]

    /// The first video PID's leading elementary-stream bytes and declared codec.
    public struct VideoPayload: Sendable {
        /// Concatenated PES payload, starting at a PES boundary.
        public let data: Data
        /// The codec the PMT declares for this PID.
        public let codec: VideoCodec
    }

    /// The leading elementary-stream bytes of the first video PID.
    ///
    /// - Parameter data: The transport stream.
    /// - Returns: The payload and its declared codec, or nil when no video PID is
    ///   found or it carries nothing readable.
    public static func firstVideoPayload(_ data: Data) -> VideoPayload? {
        guard let layout = packetLayout(data) else { return nil }
        guard let track = videoPID(data, layout: layout) else { return nil }
        guard let payload = payload(data, layout: layout, pid: track.pid) else { return nil }
        return VideoPayload(data: payload, codec: track.codec)
    }

    // MARK: - Packet Layout

    /// Where the first packet starts and how far apart packets are.
    private struct Layout {
        let start: Int
        let stride: Int
    }

    /// Determines the packet alignment, tolerating a leading partial packet and
    /// the 192-byte (timestamped) and 204-byte (error-corrected) framings.
    private static func packetLayout(_ data: Data) -> Layout? {
        for stride in [packetSize, 192, 204] {
            let searchLimit = min(stride, max(data.count - stride * 3, 0))
            guard searchLimit > 0 else { continue }
            for start in 0..<searchLimit {
                guard byte(data, at: start) == 0x47 else { continue }
                // Three further syncs at the same spacing rule out a stray 0x47.
                let confirmed = (1...3).allSatisfy { index in
                    byte(data, at: start + stride * index) == 0x47
                }
                if confirmed { return Layout(start: start, stride: stride) }
            }
        }
        return nil
    }

    // MARK: - PID Discovery

    /// Finds the first video PID by reading the PAT, then the PMT it points to.
    ///
    /// Falls back to nil rather than guessing: encapsulating the wrong PID would
    /// describe the object with another track's geometry.
    private static func videoPID(_ data: Data, layout: Layout) -> (pid: Int, codec: VideoCodec)? {
        let pat = section(data, layout: layout, pid: 0x0000, tableID: 0x00)
        guard !pat.isEmpty else { return nil }

        // PAT entries are program_number (2) + PMT PID (2), after an 8-byte header
        // and before the 4-byte CRC.
        var pmtPIDs: [Int] = []
        var offset = 8
        while offset + 4 <= pat.count - 4 {
            let programNumber = (Int(pat[offset]) << 8) | Int(pat[offset + 1])
            let pid = ((Int(pat[offset + 2]) & 0x1F) << 8) | Int(pat[offset + 3])
            // Program 0 designates the NIT, which carries no elementary streams.
            if programNumber != 0 { pmtPIDs.append(pid) }
            offset += 4
        }

        for pmtPID in pmtPIDs {
            let pmt = section(data, layout: layout, pid: pmtPID, tableID: 0x02)
            guard !pmt.isEmpty else { continue }
            // Skip the 12-byte header, then the program_info descriptors.
            guard pmt.count > 12 else { continue }
            let programInfoLength = ((Int(pmt[10]) & 0x0F) << 8) | Int(pmt[11])
            var entry = 12 + programInfoLength
            while entry + 5 <= pmt.count - 4 {
                let streamType = pmt[entry]
                let pid = ((Int(pmt[entry + 1]) & 0x1F) << 8) | Int(pmt[entry + 2])
                let esInfoLength = ((Int(pmt[entry + 3]) & 0x0F) << 8) | Int(pmt[entry + 4])
                if let codec = videoStreamTypes[streamType] { return (pid, codec) }
                entry += 5 + esInfoLength
            }
        }
        return nil
    }

    /// Reassembles one PSI section carrying the given table ID.
    ///
    /// Sections begin at the pointer_field offset of a packet flagged as a payload
    /// start, and may continue across packets.
    private static func section(
        _ data: Data,
        layout: Layout,
        pid targetPID: Int,
        tableID: UInt8
    ) -> [UInt8] {
        var section: [UInt8] = []
        var expected: Int?

        forEachPacket(data, layout: layout) { packet in
            guard pid(of: packet) == targetPID, let body = packetPayload(packet) else {
                return true
            }

            var bytes = body
            if payloadStarts(packet) {
                // A pointer_field leads the payload, giving the offset of the
                // first section byte.
                guard let pointer = bytes.first else { return true }
                let sectionStart = 1 + Int(pointer)
                guard sectionStart < bytes.count else { return true }
                bytes = Array(bytes[sectionStart...])
                guard bytes.first == tableID else { return true }
                section = []
                expected = nil
            } else if section.isEmpty {
                // Mid-section packet with no start seen yet: nothing to append to.
                return true
            }

            section += bytes
            if expected == nil, section.count >= 3 {
                // section_length counts the bytes after its own field.
                expected = (((Int(section[1]) & 0x0F) << 8) | Int(section[2])) + 3
            }
            if let total = expected, section.count >= total {
                section = Array(section.prefix(total))
                return false
            }
            return true
        }

        guard let total = expected, section.count >= total else { return [] }
        return section
    }

    // MARK: - Payload Assembly

    /// Concatenates the PES payloads of one PID, up to the byte budget.
    private static func payload(_ data: Data, layout: Layout, pid targetPID: Int) -> Data? {
        var payload = Data()

        forEachPacket(data, layout: layout) { packet in
            guard pid(of: packet) == targetPID, let body = packetPayload(packet) else {
                return true
            }

            var bytes = body
            if payloadStarts(packet) {
                // Strip the PES header so the elementary stream starts clean; a
                // packet without the start-code prefix is passed through as-is.
                if bytes.count >= 9, bytes[0] == 0x00, bytes[1] == 0x00, bytes[2] == 0x01 {
                    let headerLength = Int(bytes[8])
                    let elementaryStart = 9 + headerLength
                    guard elementaryStart <= bytes.count else { return true }
                    bytes = Array(bytes[elementaryStart...])
                }
            } else if payload.isEmpty {
                // Wait for a payload start, so the stream begins at a PES boundary.
                return true
            }

            payload.append(contentsOf: bytes)
            return payload.count < payloadBudget
        }

        return payload.isEmpty ? nil : payload
    }

    // MARK: - Packet Fields

    /// Walks packets in order, stopping when the body returns false.
    private static func forEachPacket(
        _ data: Data,
        layout: Layout,
        body: ([UInt8]) -> Bool
    ) {
        var offset = layout.start
        while offset + packetSize <= data.count {
            guard byte(data, at: offset) == 0x47 else {
                // Resynchronize rather than abandoning the rest of the file.
                offset += 1
                continue
            }
            let base = data.startIndex + offset
            let packet = [UInt8](data[base..<(base + packetSize)])
            if !body(packet) { return }
            offset += layout.stride
        }
    }

    /// The 13-bit PID from a packet header.
    private static func pid(of packet: [UInt8]) -> Int {
        ((Int(packet[1]) & 0x1F) << 8) | Int(packet[2])
    }

    /// Whether the packet begins a new PES packet or PSI section.
    private static func payloadStarts(_ packet: [UInt8]) -> Bool {
        packet[1] & 0x40 != 0
    }

    /// The packet's payload, with any adaptation field removed.
    ///
    /// Returns nil for a packet that carries no payload, or one that is scrambled
    /// and so cannot be read.
    private static func packetPayload(_ packet: [UInt8]) -> [UInt8]? {
        // transport_scrambling_control occupies the top two bits of byte 3.
        guard packet[3] & 0xC0 == 0 else { return nil }

        let adaptationControl = (packet[3] >> 4) & 0x03
        // 0 is reserved, 2 is adaptation field only: neither carries payload.
        guard adaptationControl == 1 || adaptationControl == 3 else { return nil }

        var start = 4
        if adaptationControl == 3 {
            let adaptationLength = Int(packet[4])
            start = 5 + adaptationLength
            guard start <= packet.count else { return nil }
        }
        guard start < packet.count else { return nil }
        return Array(packet[start...])
    }

    /// Reads one byte at a file offset, tolerating a non-zero start index.
    private static func byte(_ data: Data, at offset: Int) -> UInt8? {
        guard offset >= 0, offset < data.count else { return nil }
        return data[data.startIndex + offset]
    }
}
