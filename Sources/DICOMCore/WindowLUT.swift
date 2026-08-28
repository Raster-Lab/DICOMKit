import Foundation

/// A precomputed grayscale display table: raw stored sample → final 8-bit display byte.
///
/// The monochrome render inner loop is a pure function of exactly one variable — the
/// raw sample assembled from the frame bytes. Everything downstream of it (bit shift,
/// stored-bit mask, sign extension, ``WindowSettings/apply(to:)``, MONOCHROME1
/// inversion, clamp to `UInt8`) depends on nothing else, so it can be evaluated once
/// per *possible* input (256 or 65,536 values) instead of once per pixel. A 3000×4000
/// mammogram goes from 12 million window evaluations to 65,536.
///
/// The table is built by calling the same `WindowSettings.apply` the scalar loop
/// called, in the same order, so its values are identical by construction — every
/// consumer of the table (the CPU renderer today, the Metal kernel later) stays
/// bit-exact with the historical output. See `GPU_RENDERING_PLAN.md`, design pillar 1.
///
/// This lives in `DICOMCore` rather than a render-specific target because the CLI
/// export path, the print film burn and the on-screen viewer must all window through
/// the identical table.
public struct WindowLUT: Sendable, Equatable {
    /// Display bytes indexed by raw sample value.
    ///
    /// 256 entries when samples occupy one byte, 65,536 otherwise — matching the
    /// 1-byte / 2-byte assembly the renderer performs on the frame bytes.
    public let table: [UInt8]

    /// Number of entries in the table (256 or 65,536).
    @inlinable
    public var count: Int { table.count }

    /// Wraps an already-built table.
    public init(table: [UInt8]) {
        self.table = table
    }

    /// The display byte for a raw sample value.
    ///
    /// - Precondition: `rawValue` is within `0..<count`, which holds for any value the
    ///   renderer assembles from 1 or 2 frame bytes.
    @inlinable
    public subscript(rawValue: Int) -> UInt8 {
        table[rawValue]
    }
}

// MARK: - Building

extension WindowLUT {
    /// Returns a cached grayscale table for a descriptor + window pair, building it on
    /// a miss.
    ///
    /// Repeated renders at one window — a cine loop, a re-layout, every tile in a
    /// series — reuse the cached table. An interactive window drag changes the window
    /// on every mouse delta and therefore rebuilds, which costs 65,536 `apply` calls
    /// regardless of image size.
    public static func grayscale(
        descriptor: PixelDataDescriptor,
        window: WindowSettings
    ) -> WindowLUT {
        WindowLUTCache.shared.lut(for: Parameters(descriptor: descriptor, window: window))
    }

    /// Builds the table unconditionally, bypassing the cache.
    public static func makeGrayscale(
        descriptor: PixelDataDescriptor,
        window: WindowSettings
    ) -> WindowLUT {
        Parameters(descriptor: descriptor, window: window).build()
    }

    /// Everything a grayscale table's contents depend on, and nothing else.
    ///
    /// Deliberately *not* the whole descriptor: rows, columns and frame count do not
    /// change a single table entry, and including them would miss the cache on every
    /// differently-sized image in a study.
    struct Parameters: Hashable {
        let entries: Int
        let bitShift: Int
        let storedBitMask: Int
        let isSigned: Bool
        let bitsStored: Int
        let isMonochrome1: Bool
        let center: Double
        let width: Double
        let function: VOILUTFunction

        init(descriptor: PixelDataDescriptor, window: WindowSettings) {
            self.entries = descriptor.bytesPerSample == 1 ? 256 : 65_536
            self.bitShift = descriptor.bitShift
            self.storedBitMask = descriptor.storedBitMask
            self.isSigned = descriptor.isSigned
            self.bitsStored = descriptor.bitsStored
            self.isMonochrome1 = descriptor.photometricInterpretation == .monochrome1
            // Only the three fields the transform reads — `explanation` is a label and
            // must not split the cache.
            self.center = window.center
            self.width = window.width
            self.function = window.function
        }

        /// A transcription of the historical per-pixel chain in
        /// `PixelDataRenderer.renderMonochromeFrame`, hoisted over its single input.
        ///
        /// Keep the operations — and their order — identical to that loop. The
        /// equality of the two is the whole contract this type exists to provide.
        func build() -> WindowLUT {
            let window = WindowSettings(center: center, width: width, function: function)
            var table = [UInt8](repeating: 0, count: entries)
            table.withUnsafeMutableBufferPointer { out in
                for rawValue in 0..<entries {
                    // Apply bit masking
                    let shiftedValue = rawValue >> bitShift
                    var maskedValue = shiftedValue & storedBitMask

                    // Apply sign extension if needed
                    if isSigned {
                        let signBit = 1 << (bitsStored - 1)
                        if maskedValue & signBit != 0 {
                            maskedValue = maskedValue - (1 << bitsStored)
                        }
                    }

                    // Apply window transform
                    var normalized = window.apply(to: Double(maskedValue))

                    // For MONOCHROME1, invert the output (white = minimum)
                    if isMonochrome1 {
                        normalized = 1.0 - normalized
                    }

                    // Clamp and convert to 8-bit
                    out[rawValue] = UInt8(max(0, min(255, normalized * 255.0)))
                }
            }
            return WindowLUT(table: table)
        }
    }
}

// MARK: - Cache

/// A tiny most-recently-used cache of built tables.
///
/// Capacity is deliberately small: the tables are 64 KB each, and the access pattern
/// that matters (one window across a whole series, then a new window) has a working
/// set of one. The extra slots cover a viewer showing a handful of series at once.
final class WindowLUTCache: @unchecked Sendable {
    static let shared = WindowLUTCache()

    private let lock = NSLock()
    private var entries: [(parameters: WindowLUT.Parameters, lut: WindowLUT)] = []
    private let capacity = 4

    func lut(for parameters: WindowLUT.Parameters) -> WindowLUT {
        lock.lock()
        if let index = entries.firstIndex(where: { $0.parameters == parameters }) {
            let hit = entries.remove(at: index)
            entries.insert(hit, at: 0)
            lock.unlock()
            return hit.lut
        }
        lock.unlock()

        // Build outside the lock — a 65,536-entry sigmoid table is not something to
        // hold a global lock across, and a duplicate build under contention is
        // harmless because the two tables are equal.
        let built = parameters.build()

        lock.lock()
        if !entries.contains(where: { $0.parameters == parameters }) {
            entries.insert((parameters, built), at: 0)
            if entries.count > capacity {
                entries.removeLast()
            }
        }
        lock.unlock()
        return built
    }

    /// Drops every cached table. Test support only.
    func removeAll() {
        lock.lock()
        entries.removeAll()
        lock.unlock()
    }
}
