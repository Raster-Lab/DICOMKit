// CodecBackend.swift
// DICOMCore — Phase 5: Hardware Acceleration

import Foundation

#if canImport(J2KMetal)
import J2KMetal
#endif

#if canImport(J2KAccelerate)
import J2KAccelerate
#endif

// MARK: - CodecBackend

/// Identifies the hardware acceleration backend used by a DICOM codec.
///
/// The backends form a priority chain: `metal` is fastest on Apple platforms,
/// `accelerate` (Accelerate framework + ARM NEON / SSE) is next, and `scalar`
/// is the universal fallback.
///
/// ## Backend Selection
///
/// At runtime DICOMKit probes hardware availability and picks the best backend
/// automatically.  Use ``CodecBackendProbe/bestAvailable`` to query the result,
/// or instantiate a ``CodecBackendPreference`` to force a specific backend when
/// running benchmarks or diagnostic tools.
///
/// ```swift
/// // Query runtime best backend
/// let backend = CodecBackendProbe.bestAvailable
/// print(backend.displayName)   // e.g. "Metal (Apple Silicon)"
///
/// // Force scalar for benchmarking
/// let prefs = CodecBackendPreference(forced: .scalar)
/// ```
public enum CodecBackend: String, Sendable, CaseIterable, CustomStringConvertible {
    /// Apple Metal GPU compute — fastest on Apple Silicon / Intel + discrete GPU.
    case metal

    /// Apple Accelerate / ARM NEON / x86 SSE — CPU vectorised path.
    case accelerate

    /// Pure scalar Swift — universal fallback, no hardware dependency.
    case scalar

    /// Human-readable name, suitable for `--backend` CLI option display.
    public var description: String { rawValue }

    /// A more descriptive display string including detected sub-capabilities.
    public var displayName: String {
        switch self {
        case .metal:
            #if canImport(Metal)
            return J2KMetalDevice.isAvailable ? "Metal (GPU)" : "Metal (unavailable)"
            #else
            return "Metal (not supported on this platform)"
            #endif
        case .accelerate:
            #if canImport(J2KAccelerate)
            let simd = HTSIMDCapability.detect()
            switch simd.family {
            case .neon:   return "Accelerate (ARM NEON \(simd.vectorWidth * 32)-bit)"
            case .avx2:   return "Accelerate (x86 AVX2 \(simd.vectorWidth * 32)-bit)"
            case .sse42:  return "Accelerate (x86 SSE4.2 \(simd.vectorWidth * 32)-bit)"
            case .scalar: return "Accelerate (scalar fallback)"
            }
            #else
            return "Accelerate (not available)"
            #endif
        case .scalar:
            return "Scalar (pure Swift)"
        }
    }
}

// MARK: - CodecBackendProbe

/// Probes the current platform for the best available codec backend.
///
/// Results are cached on first access.  The probe runs once per process; it does
/// not respond to hardware changes (e.g., eGPU hot-plug) after startup.
public struct CodecBackendProbe: Sendable {

    /// The best codec backend available on the current platform.
    ///
    /// Priority: `metal` → `accelerate` → `scalar`.
    public static let bestAvailable: CodecBackend = {
        #if canImport(Metal)
        if J2KMetalDevice.isAvailable {
            return .metal
        }
        #endif
        #if canImport(Accelerate)
        return .accelerate
        #else
        return .scalar
        #endif
    }()

    /// Returns `true` if the given backend is available on this platform.
    public static func isAvailable(_ backend: CodecBackend) -> Bool {
        switch backend {
        case .metal:
            #if canImport(Metal)
            return J2KMetalDevice.isAvailable
            #else
            return false
            #endif
        case .accelerate:
            #if canImport(Accelerate)
            return true
            #else
            return false
            #endif
        case .scalar:
            return true
        }
    }

    /// Ranked list of available backends (best first).
    public static var availableBackends: [CodecBackend] {
        CodecBackend.allCases.filter { isAvailable($0) }
    }
}

// MARK: - CodecBackendPreference

/// Expresses a caller's preference for a specific codec backend.
///
/// When `forced` is non-nil the codec registry will attempt to honour it;
/// if the requested backend is unavailable the chain falls through to the
/// next available backend.  When `forced` is `nil` the best available
/// backend is used (default behaviour).
public struct CodecBackendPreference: Sendable {
    /// The backend preference.  `nil` means "auto" (best available).
    public var forced: CodecBackend?

    public init(forced: CodecBackend? = nil) {
        self.forced = forced
    }

    /// Auto: use the best available backend.
    public static let auto = CodecBackendPreference(forced: nil)

    /// Force Metal (falls back if unavailable).
    public static let metal = CodecBackendPreference(forced: .metal)

    /// Force Accelerate (falls back if unavailable).
    public static let accelerate = CodecBackendPreference(forced: .accelerate)

    /// Force scalar (always available).
    public static let scalar = CodecBackendPreference(forced: .scalar)

    /// Resolves the effective backend given the available options.
    ///
    /// If `forced` is set but unavailable, returns `bestAvailable`.
    public var effective: CodecBackend {
        guard let f = forced else { return CodecBackendProbe.bestAvailable }
        return CodecBackendProbe.isAvailable(f) ? f : CodecBackendProbe.bestAvailable
    }
}

// MARK: - CodecRegistry backend query extension

extension CodecRegistry {
    /// The best codec backend available on the current platform.
    public var activeBackend: CodecBackend {
        CodecBackendProbe.bestAvailable
    }

    /// Returns all backends available on this platform, best first.
    public var availableBackends: [CodecBackend] {
        CodecBackendProbe.availableBackends
    }

    /// Human-readable summary of the active hardware backend.
    public var backendDescription: String {
        activeBackend.displayName
    }
}
