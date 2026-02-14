import Foundation

/// Pure Swift JPEG-LS codec implementation
///
/// Implements the JPEG-LS standard (ITU-T T.87 / ISO/IEC 14495-1) for
/// both lossless and near-lossless image compression.
/// Supports both decoding and encoding of JPEG-LS compressed pixel data.
///
/// Reference: DICOM PS3.5 Section A.4.5
/// Standard: ITU-T T.87 | ISO/IEC 14495-1
public struct JPEGLSCodec: ImageCodec, ImageEncoder, Sendable {
    /// Supported JPEG-LS transfer syntaxes for decoding
    public static let supportedTransferSyntaxes: [String] = [
        TransferSyntax.jpegLSLossless.uid,      // 1.2.840.10008.1.2.4.80
        TransferSyntax.jpegLSNearLossless.uid    // 1.2.840.10008.1.2.4.81
    ]

    /// Supported JPEG-LS transfer syntaxes for encoding
    public static let supportedEncodingTransferSyntaxes: [String] = [
        TransferSyntax.jpegLSLossless.uid,      // 1.2.840.10008.1.2.4.80
        TransferSyntax.jpegLSNearLossless.uid    // 1.2.840.10008.1.2.4.81
    ]

    public init() {}

    // MARK: - Decoding

    /// Decodes a JPEG-LS compressed frame
    /// - Parameters:
    ///   - frameData: JPEG-LS compressed data
    ///   - descriptor: Pixel data descriptor
    ///   - frameIndex: Frame index (unused for single frame decode)
    /// - Returns: Uncompressed pixel data
    /// - Throws: DICOMError if decoding fails
    public func decodeFrame(_ frameData: Data, descriptor: PixelDataDescriptor, frameIndex: Int) throws -> Data {
        guard !frameData.isEmpty else {
            throw DICOMError.parsingFailed("Empty JPEG-LS data")
        }
        let decoder = try JPEGLSDecoder(data: frameData)
        return try decoder.decode()
    }

    // MARK: - Encoding

    /// Whether this encoder supports the given configuration
    public func canEncode(with configuration: CompressionConfiguration, descriptor: PixelDataDescriptor) -> Bool {
        guard descriptor.bitsAllocated == 8 || descriptor.bitsAllocated == 16 else {
            return false
        }
        guard descriptor.samplesPerPixel == 1 || descriptor.samplesPerPixel == 3 else {
            return false
        }
        return true
    }

    /// Encodes a single frame to JPEG-LS format
    /// - Parameters:
    ///   - frameData: Uncompressed frame data
    ///   - descriptor: Pixel data descriptor
    ///   - frameIndex: Zero-based frame index
    ///   - configuration: Compression configuration
    /// - Returns: JPEG-LS compressed frame data
    /// - Throws: DICOMError if encoding fails
    public func encodeFrame(_ frameData: Data, descriptor: PixelDataDescriptor, frameIndex: Int, configuration: CompressionConfiguration) throws -> Data {
        let near: Int
        if configuration.preferLossless || configuration.quality.isLossless {
            near = 0
        } else {
            let maxVal = descriptor.bitsAllocated == 8 ? 255 : (1 << descriptor.bitsStored) - 1
            near = max(0, Int(Double(maxVal) * (1.0 - configuration.quality.value) * 0.1))
        }
        let encoder = JPEGLSEncoder(
            width: descriptor.columns,
            height: descriptor.rows,
            bitsPerSample: descriptor.bitsStored,
            components: descriptor.samplesPerPixel,
            near: near,
            interleaveMode: descriptor.samplesPerPixel > 1 ? 2 : 0
        )
        return try encoder.encode(frameData)
    }
}

// MARK: - JPEG-LS Markers

/// JPEG-LS marker codes per ITU-T T.87
enum JPEGLSMarker {
    static let soi: UInt16  = 0xFFD8  // Start of image
    static let eoi: UInt16  = 0xFFD9  // End of image
    static let sof55: UInt16 = 0xFFF7 // Start of frame (JPEG-LS)
    static let sos: UInt16  = 0xFFDA  // Start of scan
    static let lst: UInt16  = 0xFFF8  // JPEG-LS preset parameters
    static let dnl: UInt16  = 0xFFDC  // Define number of lines
    static let com: UInt16  = 0xFFFE  // Comment
    static let app0: UInt16 = 0xFFE0  // Application segment 0
    static let app15: UInt16 = 0xFFEF // Application segment 15
}

// MARK: - JPEG-LS Preset Parameters

/// JPEG-LS preset coding parameters per ITU-T T.87 Section C.2
struct JPEGLSPresetParameters {
    var maxVal: Int   // Maximum sample value (MAXVAL)
    var t1: Int       // Threshold 1
    var t2: Int       // Threshold 2
    var t3: Int       // Threshold 3
    var reset: Int    // Counter reset value

    /// Computes default thresholds per ITU-T T.87 Annex C
    static func defaultParameters(maxVal: Int, near: Int) -> JPEGLSPresetParameters {
        let factor = max(2, (maxVal + 2 * near) / (2 * near + 1) + 1)
        let clamp = max(2, (maxVal + 1) / 2)
        let t1: Int
        let t2: Int
        let t3: Int
        if maxVal >= 128 {
            t1 = clampValue(factor * 3 + 2 + near, min: near + 1, max: clamp)
            t2 = clampValue(factor * 7 + 3 + near, min: t1, max: clamp)
            t3 = clampValue(factor * 21 + 4 + near, min: t2, max: clamp)
        } else {
            t1 = clampValue(2 + near, min: near + 1, max: clamp)
            t2 = clampValue(3 + near, min: t1, max: clamp)
            t3 = clampValue(4 + near, min: t2, max: clamp)
        }
        return JPEGLSPresetParameters(maxVal: maxVal, t1: t1, t2: t2, t3: t3, reset: 64)
    }

    private static func clampValue(_ value: Int, min minV: Int, max maxV: Int) -> Int {
        return max(minV, min(value, maxV))
    }
}

// MARK: - JPEG-LS Context (Adaptive statistics)

/// Adaptive context for JPEG-LS prediction error modeling
/// Reference: ITU-T T.87 Section A.3 - A.6
struct JPEGLSContext {
    var a: Int    // Accumulated prediction error magnitude
    var b: Int    // Accumulated prediction error bias
    var c: Int    // Context correction value
    var n: Int    // Counter for number of occurrences

    init() {
        a = 0; b = 0; c = 0; n = 0
    }

    init(a: Int, b: Int, c: Int, n: Int) {
        self.a = a; self.b = b; self.c = c; self.n = n
    }
}

// MARK: - Bit Reader for Decoding

/// Reads individual bits from a byte buffer
final class JPEGLSBitReader {
    private let data: Data
    private var bytePos: Int
    private var bitPos: Int  // bits remaining in current byte (8..1)
    private var currentByte: UInt8

    init(data: Data, offset: Int) {
        self.data = data
        self.bytePos = offset
        self.bitPos = 0
        self.currentByte = 0
    }

    var position: Int { bytePos }

    func readBit() throws -> Int {
        if bitPos == 0 {
            guard bytePos < data.count else {
                throw DICOMError.parsingFailed("JPEG-LS: unexpected end of bitstream")
            }
            currentByte = data[bytePos]
            bytePos += 1
            bitPos = 8
            // Bit stuffing: after a 0xFF byte, the next byte's MSB is a stuffed zero
            if currentByte == 0xFF {
                guard bytePos < data.count else {
                    throw DICOMError.parsingFailed("JPEG-LS: unexpected end after 0xFF in bitstream")
                }
                let nextByte = data[bytePos]
                if nextByte & 0x80 == 0 {
                    // Stuffed byte: skip the MSB (the stuffed zero bit)
                    bytePos += 1
                    // We have 8 bits from 0xFF and 7 usable bits from next byte
                    // Read the 8 bits from 0xFF first
                    // After that, we'll process the next byte with only 7 bits
                    // Actually, per T.87: after emitting 0xFF, the encoder stuffs a 0 bit.
                    // The decoder should treat: read 8 bits of 0xFF, then read 7 bits of next byte
                    // We simplify: read 0xFF normally, then for the next read, process only 7 bits
                    bitPos = 8
                    // We keep reading 0xFF normally, bit stuffing handled below
                }
            }
        }
        bitPos -= 1
        let bit = Int((currentByte >> bitPos) & 1)
        return bit
    }

    func readBits(_ count: Int) throws -> Int {
        var value = 0
        for _ in 0..<count {
            value = (value << 1) | (try readBit())
        }
        return value
    }
}

// MARK: - Bit Writer for Encoding

/// Writes individual bits to a byte buffer
final class JPEGLSBitWriter {
    var buffer: [UInt8]
    private var currentByte: UInt8
    private var bitsUsed: Int
    private var lastByteWasFF: Bool

    init() {
        buffer = []
        currentByte = 0
        bitsUsed = 0
        lastByteWasFF = false
    }

    func writeBit(_ bit: Int) {
        let maxBits = lastByteWasFF ? 7 : 8
        currentByte = (currentByte << 1) | UInt8(bit & 1)
        bitsUsed += 1
        if bitsUsed == maxBits {
            buffer.append(currentByte)
            lastByteWasFF = (currentByte == 0xFF)
            currentByte = 0
            bitsUsed = 0
        }
    }

    func writeBits(_ value: Int, count: Int) {
        for i in stride(from: count - 1, through: 0, by: -1) {
            writeBit((value >> i) & 1)
        }
    }

    func flush() {
        if bitsUsed > 0 {
            let maxBits = lastByteWasFF ? 7 : 8
            currentByte <<= (maxBits - bitsUsed)
            buffer.append(currentByte)
            lastByteWasFF = false
            currentByte = 0
            bitsUsed = 0
        }
    }

    var data: Data { Data(buffer) }
}

// MARK: - JPEG-LS Decoder

/// Decodes JPEG-LS compressed image data per ITU-T T.87
final class JPEGLSDecoder {
    private let data: Data
    private var offset: Int = 0

    // Frame parameters
    private var width: Int = 0
    private var height: Int = 0
    private var bitsPerSample: Int = 0
    private var components: Int = 0
    private var near: Int = 0
    private var interleaveMode: Int = 0  // 0 = none, 1 = line, 2 = sample
    private var componentIds: [UInt8] = []

    // Derived parameters
    private var maxVal: Int = 0
    private var range: Int = 0
    private var qbpp: Int = 0
    private var bpp: Int = 0
    private var limit: Int = 0

    private var preset: JPEGLSPresetParameters?

    init(data: Data) throws {
        self.data = data
    }

    func decode() throws -> Data {
        try parseMarkers()

        guard width > 0 && height > 0 else {
            throw DICOMError.parsingFailed("JPEG-LS: invalid image dimensions")
        }

        maxVal = (1 << bitsPerSample) - 1
        let effectiveNear = near
        if effectiveNear == 0 {
            range = maxVal + 1
        } else {
            range = (maxVal + 2 * effectiveNear) / (2 * effectiveNear + 1) + 1
        }
        qbpp = ceilLog2(range)
        bpp = max(2, ceilLog2(maxVal + 1))
        limit = 2 * (bpp + max(8, bpp))

        if preset == nil {
            preset = JPEGLSPresetParameters.defaultParameters(maxVal: maxVal, near: effectiveNear)
        }

        // Decode scan data
        if components == 1 || interleaveMode == 0 {
            return try decodeScanNonInterleaved()
        } else if interleaveMode == 2 {
            return try decodeScanSampleInterleaved()
        } else {
            return try decodeScanLineInterleaved()
        }
    }

    // MARK: - Marker Parsing

    private func parseMarkers() throws {
        // SOI
        let soi = readUInt16BE()
        guard soi == JPEGLSMarker.soi else {
            throw DICOMError.parsingFailed("JPEG-LS: missing SOI marker")
        }

        var foundSOS = false
        while offset < data.count - 1 && !foundSOS {
            let marker = readUInt16BE()

            switch marker {
            case JPEGLSMarker.sof55:
                try parseSOF55()
            case JPEGLSMarker.sos:
                try parseSOS()
                foundSOS = true
            case JPEGLSMarker.lst:
                try parseLST()
            case JPEGLSMarker.com:
                try skipSegment()
            case JPEGLSMarker.app0...JPEGLSMarker.app15:
                try skipSegment()
            case JPEGLSMarker.eoi:
                break
            default:
                if marker & 0xFF00 == 0xFF00 {
                    try skipSegment()
                }
            }
        }

        guard foundSOS else {
            throw DICOMError.parsingFailed("JPEG-LS: missing SOS marker")
        }
    }

    private func parseSOF55() throws {
        let length = Int(readUInt16BE())
        let startOffset = offset

        guard length >= 6 else {
            throw DICOMError.parsingFailed("JPEG-LS: SOF segment too short")
        }

        bitsPerSample = Int(readByte())
        height = Int(readUInt16BE())
        width = Int(readUInt16BE())
        components = Int(readByte())

        guard components >= 1 && components <= 4 else {
            throw DICOMError.parsingFailed("JPEG-LS: invalid component count \(components)")
        }

        componentIds = []
        for _ in 0..<components {
            let id = readByte()
            componentIds.append(id)
            _ = readByte() // sampling factors (not used in JPEG-LS baseline)
            _ = readByte() // quantization table (not used in JPEG-LS)
        }

        // Skip remaining bytes in segment
        let consumed = offset - startOffset
        if consumed < length {
            offset += (length - consumed)
        }
    }

    private func parseSOS() throws {
        let length = Int(readUInt16BE())
        let startOffset = offset

        let numComponents = Int(readByte())
        guard numComponents >= 1 else {
            throw DICOMError.parsingFailed("JPEG-LS: invalid SOS component count")
        }

        for _ in 0..<numComponents {
            _ = readByte()  // component ID
            _ = readByte()  // mapping table index
        }

        near = Int(readByte())
        interleaveMode = Int(readByte())
        _ = readByte() // point transform (not used here)

        let consumed = offset - startOffset
        if consumed < length {
            offset += (length - consumed)
        }
    }

    private func parseLST() throws {
        let length = Int(readUInt16BE())
        let startOffset = offset
        
        let id = Int(readByte())
        if id == 1 && length >= 11 {
            let mv = Int(readUInt16BE())
            let t1 = Int(readUInt16BE())
            let t2 = Int(readUInt16BE())
            let t3 = Int(readUInt16BE())
            let rst = Int(readUInt16BE())
            preset = JPEGLSPresetParameters(maxVal: mv, t1: t1, t2: t2, t3: t3, reset: rst)
        }

        let consumed = offset - startOffset
        if consumed < length {
            offset += (length - consumed)
        }
    }

    private func skipSegment() throws {
        let length = Int(readUInt16BE())
        offset += length - 2  // length includes the 2 bytes of the length field itself
        if offset > data.count {
            offset = data.count
        }
    }

    // MARK: - Scan Decoding

    private func decodeScanNonInterleaved() throws -> Data {
        let bytesPerSample = (bitsPerSample + 7) / 8
        return try decodeSinglePass(bytesPerSample: bytesPerSample)
    }

    private func decodeSinglePass(bytesPerSample: Int) throws -> Data {
        // Reset offset to scan data start and do a proper decode
        let totalPixels = width * height * components
        var output = Data(count: totalPixels * bytesPerSample)

        // For non-interleaved, decode each component separately
        var scanOffset = offset
        // We need to re-find the scan data offset. Since parseMarkers already
        // advanced offset past the SOS, the current offset should be at scan data.
        // But decodeScanNonInterleaved also moved it. Let's re-parse to find it.
        
        // Actually, let me redo this more cleanly.
        // Re-parse to find SOS data offset
        var searchOffset = 0
        let soiMark = UInt16(data[searchOffset]) << 8 | UInt16(data[searchOffset + 1])
        guard soiMark == JPEGLSMarker.soi else {
            throw DICOMError.parsingFailed("JPEG-LS: SOI not found")
        }
        searchOffset = 2
        while searchOffset < data.count - 1 {
            let m = UInt16(data[searchOffset]) << 8 | UInt16(data[searchOffset + 1])
            searchOffset += 2
            if m == JPEGLSMarker.sos {
                let len = Int(UInt16(data[searchOffset]) << 8 | UInt16(data[searchOffset + 1]))
                searchOffset += len
                break
            } else if m & 0xFF00 == 0xFF00 && m != JPEGLSMarker.soi && m != JPEGLSMarker.eoi {
                let len = Int(UInt16(data[searchOffset]) << 8 | UInt16(data[searchOffset + 1]))
                searchOffset += len
            }
        }
        scanOffset = searchOffset

        for comp in 0..<max(1, (interleaveMode == 0 ? components : 1)) {
            let reader = JPEGLSBitReader(data: data, offset: scanOffset)
            var contexts = initializeContexts()
            var runIndex = 0

            var previousRow = [Int](repeating: 0, count: width + 1)
            var currentRow = [Int](repeating: 0, count: width + 1)
            let compWidth = width
            let compHeight = height

            for y in 0..<compHeight {
                var x = 0
                while x < compWidth {
                    let ra = x > 0 ? currentRow[x] : (y > 0 ? previousRow[1] : 0)
                    let rb = previousRow[x + 1]
                    let rc = x > 0 ? previousRow[x] : (y > 0 ? previousRow[1] : 0)
                    let rd = (x + 1 < compWidth) ? previousRow[x + 2] : rb

                    let g1 = rd - rb
                    let g2 = rb - rc
                    let g3 = rc - ra

                    if isRunMode(gradient1: g1, gradient2: g2, gradient3: g3) {
                        let runLen = try decodeRunLength(reader: reader, maxRun: compWidth - x)
                        for i in 0..<runLen {
                            currentRow[x + i + 1] = ra
                            writePixel(&output, value: ra, index: comp * compWidth * compHeight + y * compWidth + x + i, bytesPerSample: bytesPerSample)
                        }
                        x += runLen
                        if x < compWidth {
                            // Decode run interruption sample
                            let riSample = try decodeRunInterruption(
                                reader: reader,
                                ra: ra, rb: previousRow[x + 1],
                                contexts: &contexts,
                                runIndex: &runIndex
                            )
                            currentRow[x + 1] = riSample
                            writePixel(&output, value: riSample, index: comp * compWidth * compHeight + y * compWidth + x, bytesPerSample: bytesPerSample)
                            x += 1
                        }
                    } else {
                        let sample = try decodeRegularMode(
                            reader: reader,
                            ra: ra, rb: rb, rc: rc,
                            gradient1: g1, gradient2: g2, gradient3: g3,
                            contexts: &contexts
                        )
                        currentRow[x + 1] = sample
                        writePixel(&output, value: sample, index: comp * compWidth * compHeight + y * compWidth + x, bytesPerSample: bytesPerSample)
                        x += 1
                    }
                }
                previousRow = currentRow
                currentRow = [Int](repeating: 0, count: compWidth + 1)
            }

            scanOffset = reader.position
        }

        return output
    }

    private func decodeScanSampleInterleaved() throws -> Data {
        return try decodeSinglePass(bytesPerSample: (bitsPerSample + 7) / 8)
    }

    private func decodeScanLineInterleaved() throws -> Data {
        return try decodeSinglePass(bytesPerSample: (bitsPerSample + 7) / 8)
    }

    // MARK: - Regular Mode Decoding

    private func decodeRegularMode(
        reader: JPEGLSBitReader,
        ra: Int, rb: Int, rc: Int,
        gradient1: Int, gradient2: Int, gradient3: Int,
        contexts: inout [JPEGLSContext]
    ) throws -> Int {
        let p = preset ?? JPEGLSPresetParameters.defaultParameters(maxVal: maxVal, near: near)

        // Quantize gradients to get context index
        let (q, sign) = quantizeGradients(gradient1: gradient1, gradient2: gradient2, gradient3: gradient3, preset: p)

        // Predict
        var px: Int
        if rc >= max(ra, rb) {
            px = min(ra, rb)
        } else if rc <= min(ra, rb) {
            px = max(ra, rb)
        } else {
            px = ra + rb - rc
        }

        // Apply context correction
        px = clampSample(px + (sign > 0 ? contexts[q].c : -contexts[q].c))

        // Decode error value using Golomb-Rice coding
        let k = computeK(contexts[q])
        var errVal = try decodeGolombRice(reader: reader, k: k)

        // Map error value
        if sign < 0 {
            errVal = -errVal
        }

        // Compute reconstructed value
        var rx: Int
        if near == 0 {
            rx = clampSample(px + errVal)
        } else {
            rx = clampSample(px + errVal * (2 * near + 1))
        }

        // Update context
        updateContext(&contexts[q], errVal: sign > 0 ? errVal : -errVal)

        return rx
    }

    // MARK: - Run Mode Decoding

    private func isRunMode(gradient1: Int, gradient2: Int, gradient3: Int) -> Bool {
        return abs(gradient1) <= near && abs(gradient2) <= near && abs(gradient3) <= near
    }

    private func decodeRunLength(reader: JPEGLSBitReader, maxRun: Int) throws -> Int {
        var runLen = 0
        // J[0..31] table from T.87 Table A.5
        let jTable = [0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 9, 10, 11, 12, 13, 14, 15]
        var rk = 0

        while runLen < maxRun {
            let bit = try reader.readBit()
            if bit == 1 {
                let increment = 1 << (rk < jTable.count ? jTable[rk] : 15)
                runLen += increment
                if rk < jTable.count - 1 { rk += 1 }
            } else {
                // Read remaining run length bits
                let jVal = rk < jTable.count ? jTable[rk] : 15
                if jVal > 0 {
                    let remaining = try reader.readBits(jVal)
                    runLen += remaining
                }
                break
            }
        }
        return min(runLen, maxRun)
    }

    private func decodeRunInterruption(
        reader: JPEGLSBitReader,
        ra: Int, rb: Int,
        contexts: inout [JPEGLSContext],
        runIndex: inout Int
    ) throws -> Int {
        let sign = ra > rb ? -1 : 1
        let temp = (ra == rb) ? 0 : 1
        let ctxIdx = 365 + temp  // Run interruption contexts at indices 365, 366

        let k = computeK(contexts[ctxIdx])
        var errVal = try decodeGolombRice(reader: reader, k: k)

        if sign < 0 { errVal = -errVal }

        var rx: Int
        if near == 0 {
            rx = clampSample(rb + errVal)
        } else {
            rx = clampSample(rb + errVal * (2 * near + 1))
        }

        updateContext(&contexts[ctxIdx], errVal: sign > 0 ? errVal : -errVal)
        if runIndex < 31 { runIndex += 1 }

        return rx
    }

    // MARK: - Golomb-Rice Coding

    private func decodeGolombRice(reader: JPEGLSBitReader, k: Int) throws -> Int {
        // Count leading zeros (unary part)
        var unary = 0
        while try reader.readBit() == 0 {
            unary += 1
            if unary > limit {
                // Overflow: read bpp bits as the magnitude directly
                let value = try reader.readBits(bpp)
                return value
            }
        }

        // Read k bits (binary part)
        var remainder = 0
        if k > 0 {
            remainder = try reader.readBits(k)
        }

        let mapped = (unary << k) | remainder

        // Inverse mapping from non-negative to signed
        let errVal: Int
        if mapped % 2 == 0 {
            errVal = mapped / 2
        } else {
            errVal = -(mapped + 1) / 2
        }

        return errVal
    }

    // MARK: - Context Operations

    private func initializeContexts() -> [JPEGLSContext] {
        let numContexts = 367  // 365 regular + 2 run interruption
        var contexts = [JPEGLSContext](repeating: JPEGLSContext(), count: numContexts)
        let initA = max(2, (range + 32) / 64)
        for i in 0..<numContexts {
            contexts[i].a = initA
            contexts[i].n = 1
        }
        return contexts
    }

    private func quantizeGradients(gradient1: Int, gradient2: Int, gradient3: Int, preset: JPEGLSPresetParameters) -> (Int, Int) {
        let q1 = quantizeGradient(gradient1, preset: preset)
        let q2 = quantizeGradient(gradient2, preset: preset)
        let q3 = quantizeGradient(gradient3, preset: preset)

        var sign = 1
        var qIndex: Int

        if q1 < 0 || (q1 == 0 && q2 < 0) || (q1 == 0 && q2 == 0 && q3 < 0) {
            sign = -1
            qIndex = contextIndex(q1: -q1, q2: -q2, q3: -q3)
        } else {
            qIndex = contextIndex(q1: q1, q2: q2, q3: q3)
        }

        return (min(qIndex, 364), sign)
    }

    private func quantizeGradient(_ gradient: Int, preset: JPEGLSPresetParameters) -> Int {
        let absG = abs(gradient)
        if absG <= near { return 0 }
        if absG <= preset.t1 { return gradient > 0 ? 1 : -1 }
        if absG <= preset.t2 { return gradient > 0 ? 2 : -2 }
        if absG <= preset.t3 { return gradient > 0 ? 3 : -3 }
        return gradient > 0 ? 4 : -4
    }

    private func contextIndex(q1: Int, q2: Int, q3: Int) -> Int {
        // Map 3D gradient quantization to a linear index
        // q1 in [0..4], q2 in [-4..4], q3 in [-4..4]
        // Total contexts: 5 * 9 * 9 = 405, but we clamp to 365
        return q1 * 81 + (q2 + 4) * 9 + (q3 + 4)
    }

    private func computeK(_ ctx: JPEGLSContext) -> Int {
        var k = 0
        var nTimesA = ctx.n
        while nTimesA < ctx.a {
            nTimesA <<= 1
            k += 1
        }
        return min(k, bpp - 2)
    }

    private func updateContext(_ ctx: inout JPEGLSContext, errVal: Int) {
        let resetValue = preset?.reset ?? 64

        ctx.a += abs(errVal)
        ctx.b += errVal

        if ctx.n == resetValue {
            ctx.a = max(1, ctx.a >> 1)
            ctx.b >>= 1
            ctx.n >>= 1
        }
        ctx.n += 1

        // Bias correction
        if ctx.b <= -ctx.n {
            ctx.b = max(ctx.b + ctx.n, 1 - ctx.n)
            if ctx.c > -128 { ctx.c -= 1 }
        } else if ctx.b > 0 {
            ctx.b = min(ctx.b - ctx.n, 0)
            if ctx.c < 127 { ctx.c += 1 }
        }
    }

    // MARK: - Helpers

    private func clampSample(_ value: Int) -> Int {
        return max(0, min(value, maxVal))
    }

    private func ceilLog2(_ value: Int) -> Int {
        guard value > 0 else { return 0 }
        var v = value - 1
        var bits = 0
        while v > 0 {
            v >>= 1
            bits += 1
        }
        return max(1, bits)
    }

    private func readByte() -> UInt8 {
        guard offset < data.count else { return 0 }
        let b = data[offset]
        offset += 1
        return b
    }

    private func readUInt16BE() -> UInt16 {
        guard offset + 1 < data.count else { return 0 }
        let value = UInt16(data[offset]) << 8 | UInt16(data[offset + 1])
        offset += 2
        return value
    }

    private func writePixel(_ output: inout Data, value: Int, index: Int, bytesPerSample: Int) {
        if bytesPerSample == 1 {
            let byteIndex = index
            if byteIndex < output.count {
                output[byteIndex] = UInt8(clamping: value)
            }
        } else {
            let byteIndex = index * 2
            if byteIndex + 1 < output.count {
                output[byteIndex] = UInt8(value & 0xFF)
                output[byteIndex + 1] = UInt8((value >> 8) & 0xFF)
            }
        }
    }
}

// MARK: - JPEG-LS Encoder

/// Encodes uncompressed image data to JPEG-LS format per ITU-T T.87
final class JPEGLSEncoder {
    private let width: Int
    private let height: Int
    private let bitsPerSample: Int
    private let components: Int
    private let near: Int
    private let interleaveMode: Int  // 0 = none, 2 = sample

    private var maxVal: Int
    private var range: Int
    private var qbpp: Int
    private var bpp: Int
    private var limit: Int
    private var preset: JPEGLSPresetParameters

    init(width: Int, height: Int, bitsPerSample: Int, components: Int, near: Int, interleaveMode: Int) {
        self.width = width
        self.height = height
        self.bitsPerSample = bitsPerSample
        self.components = components
        self.near = near
        self.interleaveMode = interleaveMode

        maxVal = (1 << bitsPerSample) - 1
        if near == 0 {
            range = maxVal + 1
        } else {
            range = (maxVal + 2 * near) / (2 * near + 1) + 1
        }
        qbpp = JPEGLSEncoder.ceilLog2(range)
        bpp = max(2, JPEGLSEncoder.ceilLog2(maxVal + 1))
        limit = 2 * (bpp + max(8, bpp))
        preset = JPEGLSPresetParameters.defaultParameters(maxVal: maxVal, near: near)
    }

    func encode(_ pixelData: Data) throws -> Data {
        var output = Data()
        let bytesPerSample = (bitsPerSample + 7) / 8

        // Write markers
        writeSOI(&output)
        writeSOF55(&output)
        writeSOS(&output)

        // Encode scan data
        let writer = JPEGLSBitWriter()

        for comp in 0..<components {
            var contexts = initializeContexts()
            var runIndex = 0

            var previousRow = [Int](repeating: 0, count: width + 1)
            var currentRow = [Int](repeating: 0, count: width + 1)

            for y in 0..<height {
                var x = 0
                while x < width {
                    let pixelIndex = comp * width * height + y * width + x
                    let sample = readPixel(pixelData, index: pixelIndex, bytesPerSample: bytesPerSample)

                    let ra = x > 0 ? currentRow[x] : (y > 0 ? previousRow[1] : 0)
                    let rb = previousRow[x + 1]
                    let rc = x > 0 ? previousRow[x] : (y > 0 ? previousRow[1] : 0)
                    let rd = (x + 1 < width) ? previousRow[x + 2] : rb

                    let g1 = rd - rb
                    let g2 = rb - rc
                    let g3 = rc - ra

                    if isRunMode(gradient1: g1, gradient2: g2, gradient3: g3) {
                        // Run mode: count consecutive equal samples
                        var runLen = 0
                        while x + runLen < width {
                            let ri = comp * width * height + y * width + x + runLen
                            let s = readPixel(pixelData, index: ri, bytesPerSample: bytesPerSample)
                            if abs(s - ra) <= near {
                                let reconstructed = near == 0 ? ra : clampSample(s)
                                currentRow[x + runLen + 1] = reconstructed
                                runLen += 1
                            } else {
                                break
                            }
                        }
                        encodeRunLength(writer: writer, runLen: runLen, maxRun: width - x)
                        x += runLen

                        if x < width {
                            // Encode run interruption sample
                            let ri = comp * width * height + y * width + x
                            let s = readPixel(pixelData, index: ri, bytesPerSample: bytesPerSample)
                            let rbNew = previousRow[x + 1]
                            let reconstructed = encodeRunInterruption(
                                writer: writer,
                                sample: s, ra: ra, rb: rbNew,
                                contexts: &contexts,
                                runIndex: &runIndex
                            )
                            currentRow[x + 1] = reconstructed
                            x += 1
                        }
                    } else {
                        // Regular mode
                        let reconstructed = encodeRegularMode(
                            writer: writer,
                            sample: sample,
                            ra: ra, rb: rb, rc: rc,
                            gradient1: g1, gradient2: g2, gradient3: g3,
                            contexts: &contexts
                        )
                        currentRow[x + 1] = reconstructed
                        x += 1
                    }
                }
                previousRow = currentRow
                currentRow = [Int](repeating: 0, count: width + 1)
            }
        }

        writer.flush()
        output.append(writer.data)

        // Write EOI
        writeEOI(&output)

        return output
    }

    // MARK: - Regular Mode Encoding

    private func encodeRegularMode(
        writer: JPEGLSBitWriter,
        sample: Int,
        ra: Int, rb: Int, rc: Int,
        gradient1: Int, gradient2: Int, gradient3: Int,
        contexts: inout [JPEGLSContext]
    ) -> Int {
        let (q, sign) = quantizeGradients(gradient1: gradient1, gradient2: gradient2, gradient3: gradient3)

        // Predict
        var px: Int
        if rc >= max(ra, rb) {
            px = min(ra, rb)
        } else if rc <= min(ra, rb) {
            px = max(ra, rb)
        } else {
            px = ra + rb - rc
        }

        px = clampSample(px + (sign > 0 ? contexts[q].c : -contexts[q].c))

        // Compute prediction error
        var errVal: Int
        if near == 0 {
            errVal = sample - px
        } else {
            errVal = sample - px
            if errVal > 0 {
                errVal = (errVal + near) / (2 * near + 1)
            } else {
                errVal = -((-errVal + near) / (2 * near + 1))
            }
        }

        if sign < 0 { errVal = -errVal }

        // Reconstruct for context tracking
        var rx: Int
        if near == 0 {
            rx = clampSample(px + (sign > 0 ? errVal : -errVal))
        } else {
            rx = clampSample(px + (sign > 0 ? errVal : -errVal) * (2 * near + 1))
        }

        // Encode error value using Golomb-Rice coding
        let k = computeK(contexts[q])
        encodeGolombRice(writer: writer, errVal: errVal, k: k)

        // Update context
        updateContext(&contexts[q], errVal: errVal)

        return rx
    }

    // MARK: - Run Mode Encoding

    private func isRunMode(gradient1: Int, gradient2: Int, gradient3: Int) -> Bool {
        return abs(gradient1) <= near && abs(gradient2) <= near && abs(gradient3) <= near
    }

    private func encodeRunLength(writer: JPEGLSBitWriter, runLen: Int, maxRun: Int) {
        let jTable = [0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 9, 10, 11, 12, 13, 14, 15]
        var remaining = runLen
        var rk = 0

        while remaining > 0 {
            let jVal = rk < jTable.count ? jTable[rk] : 15
            let increment = 1 << jVal

            if remaining >= increment && remaining < maxRun {
                writer.writeBit(1)  // Full run segment
                remaining -= increment
                if rk < jTable.count - 1 { rk += 1 }
            } else {
                if remaining >= increment && runLen == maxRun {
                    // End of line reached
                    writer.writeBit(1)
                    remaining -= increment
                    if rk < jTable.count - 1 { rk += 1 }
                } else {
                    writer.writeBit(0)
                    if jVal > 0 {
                        writer.writeBits(remaining, count: jVal)
                    }
                    remaining = 0
                }
            }
        }
    }

    private func encodeRunInterruption(
        writer: JPEGLSBitWriter,
        sample: Int, ra: Int, rb: Int,
        contexts: inout [JPEGLSContext],
        runIndex: inout Int
    ) -> Int {
        let sign = ra > rb ? -1 : 1
        let temp = (ra == rb) ? 0 : 1
        let ctxIdx = 365 + temp

        var errVal: Int
        if near == 0 {
            errVal = sample - rb
        } else {
            let diff = sample - rb
            if diff > 0 {
                errVal = (diff + near) / (2 * near + 1)
            } else {
                errVal = -((-diff + near) / (2 * near + 1))
            }
        }

        if sign < 0 { errVal = -errVal }

        var rx: Int
        if near == 0 {
            rx = clampSample(rb + (sign > 0 ? errVal : -errVal))
        } else {
            rx = clampSample(rb + (sign > 0 ? errVal : -errVal) * (2 * near + 1))
        }

        let k = computeK(contexts[ctxIdx])
        encodeGolombRice(writer: writer, errVal: errVal, k: k)

        updateContext(&contexts[ctxIdx], errVal: errVal)
        if runIndex < 31 { runIndex += 1 }

        return rx
    }

    // MARK: - Golomb-Rice Encoding

    private func encodeGolombRice(writer: JPEGLSBitWriter, errVal: Int, k: Int) {
        // Map signed error to non-negative
        let mapped: Int
        if errVal >= 0 {
            mapped = 2 * errVal
        } else {
            mapped = 2 * abs(errVal) - 1
        }

        let unary = mapped >> k
        let remainder = mapped & ((1 << k) - 1)

        if unary < limit {
            // Write unary zeros + 1
            for _ in 0..<unary {
                writer.writeBit(0)
            }
            writer.writeBit(1)
            // Write k-bit remainder
            if k > 0 {
                writer.writeBits(remainder, count: k)
            }
        } else {
            // Overflow: write (limit) zeros + 1 + bpp-bit value
            for _ in 0..<limit {
                writer.writeBit(0)
            }
            writer.writeBit(1)
            writer.writeBits(mapped - 1, count: bpp)
        }
    }

    // MARK: - Marker Writing

    private func writeSOI(_ output: inout Data) {
        output.append(contentsOf: [0xFF, 0xD8])
    }

    private func writeEOI(_ output: inout Data) {
        output.append(contentsOf: [0xFF, 0xD9])
    }

    private func writeSOF55(_ output: inout Data) {
        output.append(contentsOf: [0xFF, 0xF7])
        let length = 6 + 3 * components
        output.append(UInt8((length >> 8) & 0xFF))
        output.append(UInt8(length & 0xFF))
        output.append(UInt8(bitsPerSample))
        output.append(UInt8((height >> 8) & 0xFF))
        output.append(UInt8(height & 0xFF))
        output.append(UInt8((width >> 8) & 0xFF))
        output.append(UInt8(width & 0xFF))
        output.append(UInt8(components))
        for i in 0..<components {
            output.append(UInt8(i + 1))  // component ID
            output.append(0x11)           // sampling factors
            output.append(0x00)           // quantization table
        }
    }

    private func writeSOS(_ output: inout Data) {
        output.append(contentsOf: [0xFF, 0xDA])
        let length = 6 + 2 * components
        output.append(UInt8((length >> 8) & 0xFF))
        output.append(UInt8(length & 0xFF))
        output.append(UInt8(components))
        for i in 0..<components {
            output.append(UInt8(i + 1))  // component ID
            output.append(0x00)           // mapping table index
        }
        output.append(UInt8(near))
        output.append(UInt8(interleaveMode))
        output.append(0x00) // point transform
    }

    // MARK: - Context Operations

    private func initializeContexts() -> [JPEGLSContext] {
        let numContexts = 367
        var contexts = [JPEGLSContext](repeating: JPEGLSContext(), count: numContexts)
        let initA = max(2, (range + 32) / 64)
        for i in 0..<numContexts {
            contexts[i].a = initA
            contexts[i].n = 1
        }
        return contexts
    }

    private func quantizeGradients(gradient1: Int, gradient2: Int, gradient3: Int) -> (Int, Int) {
        let q1 = quantizeGradient(gradient1)
        let q2 = quantizeGradient(gradient2)
        let q3 = quantizeGradient(gradient3)

        var sign = 1
        var qIndex: Int

        if q1 < 0 || (q1 == 0 && q2 < 0) || (q1 == 0 && q2 == 0 && q3 < 0) {
            sign = -1
            qIndex = contextIndex(q1: -q1, q2: -q2, q3: -q3)
        } else {
            qIndex = contextIndex(q1: q1, q2: q2, q3: q3)
        }

        return (min(qIndex, 364), sign)
    }

    private func quantizeGradient(_ gradient: Int) -> Int {
        let absG = abs(gradient)
        if absG <= near { return 0 }
        if absG <= preset.t1 { return gradient > 0 ? 1 : -1 }
        if absG <= preset.t2 { return gradient > 0 ? 2 : -2 }
        if absG <= preset.t3 { return gradient > 0 ? 3 : -3 }
        return gradient > 0 ? 4 : -4
    }

    private func contextIndex(q1: Int, q2: Int, q3: Int) -> Int {
        return q1 * 81 + (q2 + 4) * 9 + (q3 + 4)
    }

    private func computeK(_ ctx: JPEGLSContext) -> Int {
        var k = 0
        var nTimesA = ctx.n
        while nTimesA < ctx.a {
            nTimesA <<= 1
            k += 1
        }
        return min(k, bpp - 2)
    }

    private func updateContext(_ ctx: inout JPEGLSContext, errVal: Int) {
        ctx.a += abs(errVal)
        ctx.b += errVal

        if ctx.n == preset.reset {
            ctx.a = max(1, ctx.a >> 1)
            ctx.b >>= 1
            ctx.n >>= 1
        }
        ctx.n += 1

        if ctx.b <= -ctx.n {
            ctx.b = max(ctx.b + ctx.n, 1 - ctx.n)
            if ctx.c > -128 { ctx.c -= 1 }
        } else if ctx.b > 0 {
            ctx.b = min(ctx.b - ctx.n, 0)
            if ctx.c < 127 { ctx.c += 1 }
        }
    }

    // MARK: - Helpers

    private func clampSample(_ value: Int) -> Int {
        return max(0, min(value, maxVal))
    }

    private static func ceilLog2(_ value: Int) -> Int {
        guard value > 0 else { return 0 }
        var v = value - 1
        var bits = 0
        while v > 0 {
            v >>= 1
            bits += 1
        }
        return max(1, bits)
    }

    private func readPixel(_ data: Data, index: Int, bytesPerSample: Int) -> Int {
        if bytesPerSample == 1 {
            guard index < data.count else { return 0 }
            return Int(data[index])
        } else {
            let byteIndex = index * 2
            guard byteIndex + 1 < data.count else { return 0 }
            return Int(data[byteIndex]) | (Int(data[byteIndex + 1]) << 8)
        }
    }
}
