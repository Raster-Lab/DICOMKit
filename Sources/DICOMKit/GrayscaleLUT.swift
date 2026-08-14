// GrayscaleLUT.swift
// DICOMKit
//
// Table-form grayscale LUTs: the Modality LUT Sequence (0028,3000) and the
// VOI LUT Sequence (0028,3010). Both share one wire structure — LUT Descriptor
// (three US/SS values) plus LUT Data (US or OW) — so both decode into this one
// type; what differs is how the entries are *used*, which the two apply
// methods make explicit.
//
// Before this existed, an image whose correct presentation requires a table
// LUT printed with the linear rescale or window instead — silently, and with
// the wrong contrast (SRS FR-004).
//
// Reference: PS3.3 C.11.1 (Modality LUT), C.11.2 (VOI LUT).

import Foundation
import DICOMCore

/// One decoded grayscale lookup table.
public struct GrayscaleLUT: Sendable, Equatable {

    /// The first input value the table maps. Inputs below clamp to the first
    /// entry, inputs past the end clamp to the last (PS3.3 C.11.1.1).
    public let firstMappedValue: Int

    /// Bits per entry as declared (8 or 16).
    public let bitsPerEntry: Int

    /// The table. Never empty.
    public let entries: [UInt16]

    /// LUT Explanation (0028,3003), when the file carries one.
    public let explanation: String?

    /// The smallest and largest entry, precomputed for normalization.
    public let entryRange: ClosedRange<Double>

    public init?(firstMappedValue: Int, bitsPerEntry: Int, entries: [UInt16],
                 explanation: String? = nil) {
        guard !entries.isEmpty else { return nil }
        self.firstMappedValue = firstMappedValue
        self.bitsPerEntry = bitsPerEntry
        self.entries = entries
        self.explanation = explanation
        var low = Double(entries[0]), high = Double(entries[0])
        for entry in entries {
            low = min(low, Double(entry))
            high = max(high, Double(entry))
        }
        self.entryRange = low...high
    }

    // MARK: Decoding

    /// Decodes one LUT sequence item.
    ///
    /// The classic failure points, handled here so no caller re-learns them:
    /// - Descriptor value 1 (number of entries) of **0 means 65536**, not zero.
    /// - Descriptor value 2 (first mapped value) is **signed** when the
    ///   image's Pixel Representation is 1.
    /// - LUT Data may be US or OW; 8-bit entries may be packed one per byte
    ///   or one per 16-bit word.
    public static func parse(item: SequenceItem, signedPixels: Bool) -> GrayscaleLUT? {
        guard let descriptorData = item[.lutDescriptor]?.valueData,
              descriptorData.count >= 6 else { return nil }

        let declaredEntries = Int(descriptorData.readUInt16LE(at: 0) ?? 0)
        let numberOfEntries = declaredEntries == 0 ? 65536 : declaredEntries
        let rawFirst = descriptorData.readUInt16LE(at: 2) ?? 0
        let firstMapped = signedPixels ? Int(Int16(bitPattern: rawFirst)) : Int(rawFirst)
        let bitsPerEntry = Int(descriptorData.readUInt16LE(at: 4) ?? 0)
        guard bitsPerEntry >= 8, bitsPerEntry <= 16 else { return nil }

        guard let lutData = item[.lutData]?.valueData else { return nil }

        var entries: [UInt16] = []
        entries.reserveCapacity(numberOfEntries)
        if bitsPerEntry == 8, lutData.count >= numberOfEntries,
           lutData.count < numberOfEntries * 2 {
            // One entry per byte.
            for index in 0..<numberOfEntries {
                entries.append(UInt16(lutData[lutData.startIndex + index]))
            }
        } else if lutData.count >= numberOfEntries * 2 {
            // One entry per little-endian 16-bit word (US or OW).
            for index in 0..<numberOfEntries {
                guard let value = lutData.readUInt16LE(at: index * 2) else { return nil }
                entries.append(value)
            }
        } else {
            return nil
        }

        return GrayscaleLUT(
            firstMappedValue: firstMapped,
            bitsPerEntry: bitsPerEntry,
            entries: entries,
            explanation: item.string(for: .lutExplanation)?
                .trimmingCharacters(in: .whitespacesAndNewlines))
    }

    // MARK: Lookup

    /// The entry a (possibly fractional) input value maps to, clamped to the
    /// table's ends per PS3.3 C.11.1.1.
    public func entry(for input: Double) -> UInt16 {
        let index = Int((input - Double(firstMappedValue)).rounded())
        return entries[max(0, min(entries.count - 1, index))]
    }

    /// A Modality LUT lookup: the raw entry value, in the manufacturer-defined
    /// output units the table's Modality LUT Type / Explanation describe.
    public func value(for input: Double) -> Double {
        Double(entry(for: input))
    }

    /// A VOI LUT lookup, normalized to 0…1 over the table's own entry range.
    ///
    /// Normalizing over the *actual* range rather than `2^bits − 1` is
    /// deliberate: 12-bit tables declared as 16 bits per entry are common, and
    /// dividing them by 65535 prints the whole film at a fifth of its
    /// dynamic range. A table that spans its declared depth divides by the
    /// same number either way.
    public func normalized(_ input: Double) -> Double {
        let span = entryRange.upperBound - entryRange.lowerBound
        guard span > 0 else { return 0 }
        return (Double(entry(for: input)) - entryRange.lowerBound) / span
    }
}

// MARK: - Tags

extension Tag {
    /// LUT Descriptor (0028,3002)
    static let lutDescriptor = Tag(group: 0x0028, element: 0x3002)
    /// LUT Explanation (0028,3003)
    static let lutExplanation = Tag(group: 0x0028, element: 0x3003)
    /// LUT Data (0028,3006)
    static let lutData = Tag(group: 0x0028, element: 0x3006)
}

// MARK: - Reading from a data set

public extension DataSet {

    /// The image's Modality LUT Sequence (0028,3000) table, when it has one.
    ///
    /// PS3.3 C.11.1: the sequence and Rescale Slope/Intercept are mutually
    /// exclusive — when this returns a table, the rescale pair **must not**
    /// also be applied.
    func modalityLUT() -> GrayscaleLUT? {
        guard let item = self[Tag(group: 0x0028, element: 0x3000)]?
            .sequenceItems?.first else { return nil }
        return GrayscaleLUT.parse(item: item, signedPixels: isSignedPixelData)
    }

    /// The image's first VOI LUT Sequence (0028,3010) table, when it has one.
    ///
    /// The first item is the default presentation, exactly as the first
    /// Window Center value is (PS3.3 C.11.2). Its input is the Modality LUT's
    /// output, so its first mapped value is signed whenever that output can be
    /// negative (C.11.2.1.1): a table-form Modality LUT never is, a rescale
    /// with a negative intercept (CT's −1024) always is, and bare stored
    /// pixels are when Pixel Representation says so.
    func voiLUT() -> GrayscaleLUT? {
        guard let item = self[Tag(group: 0x0028, element: 0x3010)]?
            .sequenceItems?.first else { return nil }
        let signed: Bool
        if modalityLUT() != nil {
            signed = false
        } else if rescaleSlope() != 1 || rescaleIntercept() != 0 {
            signed = rescaleIntercept() < 0 || (rescaleSlope() < 0)
                || isSignedPixelData
        } else {
            signed = isSignedPixelData
        }
        return GrayscaleLUT.parse(item: item, signedPixels: signed)
    }

    /// Whether Pixel Representation (0028,0103) declares signed pixels.
    private var isSignedPixelData: Bool {
        uint16(for: Tag(group: 0x0028, element: 0x0103)) == 1
    }
}
