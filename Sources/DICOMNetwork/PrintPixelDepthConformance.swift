// PrintPixelDepthConformance.swift
// DICOMNetwork
//
// The one place that knows what pixel depths a Basic Image Box may carry, and
// what to do about a sender that asks for something else.
//
// Print Management does not inherit the flexible depth of ordinary image
// storage. The Basic Grayscale Image Box (PS3.3 C.13.4) fixes Bits Stored at
// *8 or 12* — not 16 — with High Bit at 7 or 11 to match. Bits Allocated may be
// 8 or 16, which is the detail that misleads: 16 bits *allocated* is legal and
// ordinary (12-in-16 is how deep grayscale film is sent), while 16 bits
// *stored* is not a value the table enumerates. The Basic Color Image Box
// (PS3.3 C.13.5) is stricter still and permits only 8/8/7.
//
// These are Enumerated Values, so PS3.5 3.6.1 makes a value outside the list
// non-conformant rather than merely unusual, and an SCP would be within its
// rights to fail the N-SET.
//
// It does not, and that is deliberate. A 16-bit-stored image box is a sender
// that over-reached, not a corrupt one: every pixel it sent is meaningful, and
// the only thing wrong is that the top four bits have nowhere legal to go. A
// rejection turns that into no film at all, which is the worse outcome for the
// person waiting on it — so the depth is clamped to the nearest legal value
// below, the film is printed, and the log says plainly what was changed. The
// SCU learns about its bug from the log rather than from a failed job.
//
// Clamping *down* matters: 12 is chosen over 8 whenever the box can carry it,
// because dropping four bits of a grayscale ramp is a visible loss on film and
// dropping eight is a worse one.

import Foundation

/// Reconciles received pixel depth with what a Basic Image Box may legally
/// carry.
public enum PrintPixelDepthConformance: Sendable {

    /// Bits Stored values the Basic Grayscale Image Box enumerates (C.13.4).
    public static let grayscaleBitsStored: [UInt16] = [8, 12]

    /// The single Bits Stored value the Basic Color Image Box enumerates
    /// (C.13.5), which also fixes Bits Allocated at 8 and High Bit at 7.
    public static let colorBitsStored: UInt16 = 8

    /// The outcome of checking one image box's pixel depth.
    public struct Resolution: Sendable, Equatable {
        /// Bits Stored to use — the value received, or the clamped one.
        public var bitsStored: UInt16
        /// High Bit to match, always `bitsStored - 1`.
        public var highBit: UInt16
        /// One line per correction, empty when the sender was conformant.
        public var notes: [String]

        public init(bitsStored: UInt16, highBit: UInt16, notes: [String] = []) {
            self.bitsStored = bitsStored
            self.highBit = highBit
            self.notes = notes
        }
    }

    /// The largest legal Bits Stored not exceeding `requested`.
    ///
    /// A colour box has one legal value, so the question does not arise. A
    /// grayscale box takes 12 when the request reaches it and 8 otherwise —
    /// never a value above what was asked for, since inventing precision the
    /// sender did not supply would be its own kind of wrong.
    public static func clampedBitsStored(_ requested: UInt16, isColor: Bool) -> UInt16 {
        if isColor { return colorBitsStored }
        let legal = grayscaleBitsStored.sorted()
        return legal.last(where: { $0 <= requested }) ?? legal.first ?? 8
    }

    /// Checks a received depth and clamps it if the standard does not allow it.
    ///
    /// - Parameters:
    ///   - bitsStored: Bits Stored (0028,0101) as received.
    ///   - bitsAllocated: Bits Allocated (0028,0100) as received, which bounds
    ///     what Bits Stored can mean.
    ///   - isColor: Whether this is a Basic Color Image Box.
    /// - Returns: The depth to print at, and what to tell the log.
    public static func resolve(
        bitsStored: UInt16,
        bitsAllocated: UInt16,
        isColor: Bool
    ) -> Resolution {
        var notes: [String] = []
        var effective = bitsStored

        // Bits Stored can never exceed Bits Allocated — a box declaring 12-in-8
        // is malformed rather than merely over-deep, and the container wins.
        if effective > bitsAllocated {
            notes.append(
                "Bits Stored (0028,0101) is \(bitsStored) but Bits Allocated (0028,0100) "
                + "is \(bitsAllocated); Bits Stored cannot exceed the allocation, "
                + "so \(bitsAllocated) is used")
            effective = bitsAllocated
        }

        let allowed = isColor ? [colorBitsStored] : grayscaleBitsStored
        guard !allowed.contains(effective) else {
            return Resolution(bitsStored: effective, highBit: highBit(for: effective), notes: notes)
        }

        let clamped = clampedBitsStored(effective, isColor: isColor)
        let boxName = isColor ? "Basic Color Image Box" : "Basic Grayscale Image Box"
        let table = isColor ? "PS3.3 Table C.13-5" : "PS3.3 Table C.13-3"
        let legalText = allowed.map(String.init).joined(separator: " or ")

        notes.append(
            "Bits Stored (0028,0101) is \(effective), which the \(boxName) does not "
            + "allow — \(table) enumerates \(legalText). Printing at \(clamped)-bit "
            + "instead of failing the job; the sender should correct its Image Box.")

        return Resolution(
            bitsStored: clamped, highBit: highBit(for: clamped), notes: notes)
    }

    /// High Bit for a given Bits Stored, which the standard ties together:
    /// 8 → 7, 12 → 11.
    public static func highBit(for bitsStored: UInt16) -> UInt16 {
        bitsStored > 0 ? bitsStored - 1 : 0
    }
}
