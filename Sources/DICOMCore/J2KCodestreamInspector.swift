import Foundation

/// Read-only inspection of a JPEG 2000 codestream's headers.
///
/// DICOMKit uses this to answer questions the pinned J2KSwift decoder cannot
/// answer for itself. J2KSwift's marker loop (`J2KDecoderPipeline`) dispatches on
/// SIZ/COD/QCD/COM/SOT/EOC and *skips every other marker segment*, so a codestream
/// carrying JPEG 2000 Part 2 extensions decodes as though those extensions were
/// absent — silently, and with wrong pixels. Scanning the headers ourselves lets the
/// codec refuse such a frame instead of returning a plausible-looking image.
public enum J2KCodestreamInspector {

    // MARK: - Marker codes

    // ISO/IEC 15444-1 (Part 1) delimiting / header markers.
    private static let soc: UInt16 = 0xFF4F  // Start of codestream
    private static let sot: UInt16 = 0xFF90  // Start of tile-part
    private static let sod: UInt16 = 0xFF93  // Start of data
    private static let eoc: UInt16 = 0xFFD9  // End of codestream
    private static let siz: UInt16 = 0xFF51  // Image and tile size
    private static let cod: UInt16 = 0xFF52  // Coding style default
    private static let coc: UInt16 = 0xFF53  // Coding style component

    /// ISO/IEC 15444-2 (Part 2) multi-component transform marker segments.
    ///
    /// Values are the **standard** ones, cross-checked against the OpenJPEG
    /// reference implementation (`j2k.h`: `J2K_MS_MCT 0xff74`, `J2K_MS_MCC 0xff75`,
    /// `J2K_MS_MCO 0xff77`). Note that J2KSwift's own `J2KMarker` enum assigns these
    /// three names to different codes (`mct = 0xFF75`, `mco = 0xFF76`,
    /// `mcc = 0xFF77`); that mapping is unused by its pipelines and must **not** be
    /// mirrored here — this scanner exists to recognise codestreams produced by
    /// conformant third-party encoders (Kakadu, OpenJPEG, …).
    public enum Part2MultiComponentMarker: UInt16, CaseIterable, Sendable {
        /// Multiple component transformation — defines a transform array.
        case mct = 0xFF74
        /// Multiple component collection — groups the components a transform covers.
        case mcc = 0xFF75
        /// Multiple component transform ordering — the order transforms are applied.
        case mco = 0xFF77

        public var name: String {
            switch self {
            case .mct: return "MCT"
            case .mcc: return "MCC"
            case .mco: return "MCO"
            }
        }
    }

    // MARK: - Public API

    /// The Part 2 multi-component transform markers present in `data`'s headers, in
    /// the order first encountered (de-duplicated). Empty when the codestream is
    /// plain Part 1 / HTJ2K, when it carries no such markers, or when `data` is not
    /// a codestream this scanner recognises.
    ///
    /// Scanning is confined to the main header and each tile-part header; packet
    /// bodies are skipped via `Psot`. A conformant encoder only writes MCT/MCC/MCO
    /// when a multi-component transform is actually in force, so presence is
    /// sufficient grounds to treat the frame as un-decodable here.
    ///
    /// This never throws: a malformed or truncated codestream simply yields whatever
    /// was found before the scan ran out of well-formed input. Rejecting malformed
    /// input is the decoder's job, not this scanner's.
    public static func part2MultiComponentMarkers(in data: Data) -> [Part2MultiComponentMarker] {
        guard let codestream = locateCodestream(in: data) else { return [] }
        return scanHeaders(codestream)
    }

    /// Whether `data` carries a Part 2 multi-component transform the pinned decoder
    /// would ignore rather than invert.
    public static func containsPart2MultiComponentTransform(in data: Data) -> Bool {
        !part2MultiComponentMarkers(in: data).isEmpty
    }

    /// Whether any COD or COC marker segment in the main header or a tile-part
    /// header selects the irreversible 9/7 wavelet (ISO/IEC 15444-1 Table A.20:
    /// SPcod/SPcoc transformation byte 0; 1 is the reversible 5/3 filter).
    ///
    /// A lossless-only DICOM transfer syntax (PS3.5 A.4.4 `…4.90`, A.4.6 `…4.201`
    /// / `…4.202`) promises exact reconstruction, which a 9/7 codestream cannot
    /// deliver, so the codec refuses such a frame instead of returning
    /// approximated samples. Rate truncation of a reversible codestream is not
    /// detectable from headers and is not claimed here.
    ///
    /// This never throws and returns `false` for malformed or truncated input;
    /// rejecting malformed input is the decoder's job.
    public static func usesIrreversibleWavelet(in data: Data) -> Bool {
        guard let codestream = locateCodestream(in: data) else { return false }
        var componentCount = 0
        var irreversible = false
        forEachHeaderSegment(in: codestream) { marker, offset, length in
            switch marker {
            case siz:
                // Lsiz(2) Rsiz(2) Xsiz…YTOsiz(8×4) Csiz(2): Csiz sits 38 bytes past the marker.
                if length >= 38, let csiz = readUInt16(codestream, at: offset + 38) {
                    componentCount = Int(csiz)
                }
            case cod:
                // Lcod(2) Scod(1) SGcod(4) SPcod: NL xcb ycb cbstyle transformation.
                if length >= 12, let transformation = readUInt8(codestream, at: offset + 13), transformation == 0 {
                    irreversible = true
                }
            case coc:
                // Lcoc(2) Ccoc(1 or 2, by Csiz) Scoc(1) SPcoc: NL xcb ycb cbstyle transformation.
                let componentIndexWidth = componentCount < 257 ? 1 : 2
                if length >= 8 + componentIndexWidth,
                   let transformation = readUInt8(codestream, at: offset + 9 + componentIndexWidth),
                   transformation == 0 {
                    irreversible = true
                }
            default:
                break
            }
        }
        return irreversible
    }

    // MARK: - Container handling

    /// Returns the raw codestream range, unwrapping a JP2 container if present.
    ///
    /// DICOM encapsulates a bare codestream (starting at SOC), but JP2-boxed pixel
    /// data appears in the wild, so both are handled.
    private static func locateCodestream(in data: Data) -> Data? {
        if readUInt16(data, at: 0) == soc { return data }
        return extractJP2Codestream(from: data)
    }

    /// Minimal JP2 (ISO/IEC 15444-1 Annex I) box walk to find the `jp2c` payload.
    private static func extractJP2Codestream(from data: Data) -> Data? {
        let jp2cType: UInt32 = 0x6A70_3263  // 'jp2c'
        var offset = 0

        while offset + 8 <= data.count {
            guard let lengthField = readUInt32(data, at: offset),
                  let boxType = readUInt32(data, at: offset + 4) else { return nil }

            // LBox semantics: 1 → 64-bit XLBox follows; 0 → box runs to end of file.
            let contentStart: Int
            let boxEnd: Int
            switch lengthField {
            case 1:
                guard let xlBox = readUInt64(data, at: offset + 8) else { return nil }
                contentStart = offset + 16
                guard let end = checkedEnd(start: offset, length: xlBox, limit: data.count) else { return nil }
                boxEnd = end
            case 0:
                contentStart = offset + 8
                boxEnd = data.count
            default:
                contentStart = offset + 8
                guard let end = checkedEnd(start: offset, length: UInt64(lengthField), limit: data.count) else { return nil }
                boxEnd = end
            }

            guard contentStart <= boxEnd, contentStart <= data.count else { return nil }

            if boxType == jp2cType {
                return data.subdata(in: absolute(data, contentStart)..<absolute(data, boxEnd))
            }

            // Guard against a zero/!advancing length pinning the loop.
            guard boxEnd > offset else { return nil }
            offset = boxEnd
        }
        return nil
    }

    /// Validates `start + length` against `limit`, returning the absolute end offset.
    private static func checkedEnd(start: Int, length: UInt64, limit: Int) -> Int? {
        guard length >= 8, length <= UInt64(limit) else { return nil }
        let end = start + Int(length)
        guard end <= limit else { return nil }
        return end
    }

    // MARK: - Marker scan

    private static func scanHeaders(_ data: Data) -> [Part2MultiComponentMarker] {
        var found: [Part2MultiComponentMarker] = []
        forEachHeaderSegment(in: data) { marker, _, _ in
            // Keep scanning after a hit: reporting every marker present makes the
            // eventual error message specific rather than naming whichever came first.
            if let part2 = Part2MultiComponentMarker(rawValue: marker), !found.contains(part2) {
                found.append(part2)
            }
        }
        return found
    }

    /// Visits every marker segment of the main header and of each tile-part header
    /// as `(marker, offset of the marker, segment length field)`; packet bodies are
    /// skipped via `Psot`. SOT itself is visited; SOC, SOD and EOC are not.
    ///
    /// A well-formed header position always begins 0xFF..; anything else means the
    /// walk lost sync (truncated or malformed input) and it stops rather than guess.
    private static func forEachHeaderSegment(in data: Data, _ visit: (UInt16, Int, Int) -> Void) {
        var offset = 2  // Past SOC.

        while let marker = readUInt16(data, at: offset) {
            guard marker & 0xFF00 == 0xFF00 else { break }

            if marker == eoc || marker == sod { break }

            // Delimiting markers carry no length segment.
            if marker == soc {
                offset += 2
                continue
            }

            if marker == sot {
                // Walk the tile-part header (it may hold COD/COC/MCT… too), then hop
                // to the next tile-part via Psot.
                guard let next = walkTilePart(data, sotOffset: offset, visit) else { break }
                guard let next, next > offset else { break }
                offset = next
                continue
            }

            guard let segmentLength = readUInt16(data, at: offset + 2) else { break }
            // Lsiz-style length counts itself but not the 2-byte marker.
            guard segmentLength >= 2 else { break }
            visit(marker, offset, Int(segmentLength))
            offset += 2 + Int(segmentLength)
        }
    }

    /// Visits a single tile-part header and returns the offset of the next tile-part
    /// (`.some(nil)` when this tile-part runs to EOC, `nil` when SOT is malformed).
    private static func walkTilePart(
        _ data: Data,
        sotOffset: Int,
        _ visit: (UInt16, Int, Int) -> Void
    ) -> Int?? {
        // SOT: Lsot(2) Isot(2) Psot(4) TPsot(1) TNsot(1) — Psot spans SOT..tile end.
        guard let lsot = readUInt16(data, at: sotOffset + 2), lsot == 10,
              let psot = readUInt32(data, at: sotOffset + 6) else { return nil }
        visit(sot, sotOffset, Int(lsot))

        var offset = sotOffset + 2 + Int(lsot)

        // Walk the tile-part header up to SOD.
        while let marker = readUInt16(data, at: offset) {
            guard marker & 0xFF00 == 0xFF00 else { break }
            if marker == sod || marker == eoc { break }
            guard let segmentLength = readUInt16(data, at: offset + 2), segmentLength >= 2 else { break }
            visit(marker, offset, Int(segmentLength))
            offset += 2 + Int(segmentLength)
        }

        // Psot == 0 means the tile-part extends to EOC: nothing further to scan.
        guard psot != 0 else { return .some(nil) }
        let next = sotOffset + Int(psot)
        guard next <= data.count else { return .some(nil) }
        return .some(next)
    }

    // MARK: - Big-endian readers (offsets are relative to `data.startIndex`)

    private static func absolute(_ data: Data, _ offset: Int) -> Data.Index {
        data.index(data.startIndex, offsetBy: offset)
    }

    private static func readUInt8(_ data: Data, at offset: Int) -> UInt8? {
        guard offset >= 0, offset + 1 <= data.count else { return nil }
        return data[absolute(data, offset)]
    }

    private static func readUInt16(_ data: Data, at offset: Int) -> UInt16? {
        guard offset >= 0, offset + 2 <= data.count else { return nil }
        let i = absolute(data, offset)
        return UInt16(data[i]) << 8 | UInt16(data[data.index(after: i)])
    }

    private static func readUInt32(_ data: Data, at offset: Int) -> UInt32? {
        guard offset >= 0, offset + 4 <= data.count else { return nil }
        var value: UInt32 = 0
        for k in 0..<4 { value = value << 8 | UInt32(data[absolute(data, offset + k)]) }
        return value
    }

    private static func readUInt64(_ data: Data, at offset: Int) -> UInt64? {
        guard offset >= 0, offset + 8 <= data.count else { return nil }
        var value: UInt64 = 0
        for k in 0..<8 { value = value << 8 | UInt64(data[absolute(data, offset + k)]) }
        return value
    }
}
