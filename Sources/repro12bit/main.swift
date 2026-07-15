import Foundation
import DICOMCore
import DICOMKit

let path = "/Users/raster/Desktop/DICOM_Output/12bit_Implicit.dcm"
guard let fileData = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
    print("cannot read file")
    exit(1)
}

let file: DICOMFile
if let parsed = try? DICOMFile.read(from: fileData) {
    file = parsed
} else if let forced = try? DICOMFile.read(from: fileData, force: true) {
    file = forced
} else {
    print("not a readable DICOM file")
    exit(1)
}

guard let pixelData = file.pixelData() else {
    print("no pixel data")
    exit(1)
}
guard let frame = pixelData.frameData(at: 0) else {
    print("frame 0 not accessible")
    exit(1)
}
let descriptor = pixelData.descriptor

print("rows=\(descriptor.rows) cols=\(descriptor.columns) frames=\(descriptor.numberOfFrames)")
print("bitsAllocated=\(descriptor.bitsAllocated) bitsStored=\(descriptor.bitsStored) highBit=\(descriptor.highBit) isSigned=\(descriptor.isSigned)")
print("samplesPerPixel=\(descriptor.samplesPerPixel) photometric=\(descriptor.photometricInterpretation) planarConfig=\(descriptor.planarConfiguration)")
print("frame bytes=\(frame.count) expectedBytesPerFrame=\(descriptor.bytesPerFrame)")

let transferSyntax = file.dataSet.string(for: .transferSyntaxUID) ?? "unknown"
print("source transfer syntax = \(transferSyntax)")

let config = CompressionConfiguration(quality: .maximum, speed: .balanced, progressive: false, preferLossless: true)

func runMatrix(uid: String, label: String, decModes: [J2KSwiftDecodeMode], frame: Data, descriptor: PixelDataDescriptor) {
    for mode: J2KSwiftEncodeMode in [.cpu, .gpu] {
        let encResult = J2KSwiftCodec.benchEncode(frame, descriptor: descriptor, transferSyntaxUID: uid, configuration: config, mode: mode, warmups: 0, runs: 1)
        guard let codestream = encResult.data else {
            print("[\(label) \(mode)] ENCODE FAILED: \(encResult.error ?? "?")")
            continue
        }
        print("[\(label) \(mode)] encoded \(codestream.count) bytes (raw \(frame.count))")

        for decMode in decModes {
            let decResult = J2KSwiftCodec.benchDecode(codestream, descriptor: descriptor, mode: decMode, warmups: 0, runs: 1)
            guard let decoded = decResult.data else {
                print("  [\(label) \(mode) encode -> \(decMode) decode] DECODE FAILED: \(decResult.error ?? "?")")
                continue
            }
            let match = decoded == frame
            if match {
                print("  [\(label) \(mode) encode -> \(decMode) decode] BIT-EXACT MATCH")
            } else {
                var diffCount = 0
                var firstDiffIdx = -1
                var maxAbsDiff: Int = 0
                decoded.withUnsafeBytes { d in
                    frame.withUnsafeBytes { o in
                        let dp = d.bindMemory(to: UInt8.self)
                        let op = o.bindMemory(to: UInt8.self)
                        for i in 0..<min(dp.count, op.count) where dp[i] != op[i] {
                            diffCount += 1
                            if firstDiffIdx < 0 { firstDiffIdx = i }
                            let diff = abs(Int(dp[i]) - Int(op[i]))
                            if diff > maxAbsDiff { maxAbsDiff = diff }
                        }
                    }
                }
                print("  [\(label) \(mode) encode -> \(decMode) decode] MISMATCH: \(diffCount) bytes differ (first at \(firstDiffIdx), maxAbsByteDiff=\(maxAbsDiff)), decoded.count=\(decoded.count) frame.count=\(frame.count)")
            }
        }
    }
}

runMatrix(uid: "1.2.840.10008.1.2.4.90", label: "J2K-Part1", decModes: [.cpu, .decodeGPU], frame: frame, descriptor: descriptor)
runMatrix(uid: "1.2.840.10008.1.2.4.201", label: "HTJ2K", decModes: [.cpu, .decodeGPU, .decodeWithGPUHT], frame: frame, descriptor: descriptor)
