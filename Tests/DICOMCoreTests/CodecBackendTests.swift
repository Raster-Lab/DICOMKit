// CodecBackendTests.swift
// DICOMCoreTests — Phase 5: Hardware Acceleration

import Foundation
import Testing
@testable import DICOMCore

@Suite("CodecBackend Tests")
struct CodecBackendTests {

    // MARK: - CodecBackend enum

    @Test("All backend cases have distinct rawValues")
    func test_allCases_haveDistinctRawValues() {
        let raws = CodecBackend.allCases.map(\.rawValue)
        #expect(Set(raws).count == CodecBackend.allCases.count)
    }

    @Test("scalar backend is always available")
    func test_scalarBackend_alwaysAvailable() {
        #expect(CodecBackendProbe.isAvailable(.scalar))
    }

    @Test("CodecBackend.allCases contains metal, accelerate, scalar")
    func test_allCases_containsExpectedBackends() {
        let cases = CodecBackend.allCases
        #expect(cases.contains(.metal))
        #expect(cases.contains(.accelerate))
        #expect(cases.contains(.scalar))
    }

    @Test("displayName is non-empty for all backends")
    func test_displayName_nonEmpty() {
        for backend in CodecBackend.allCases {
            #expect(!backend.displayName.isEmpty)
        }
    }

    @Test("description matches rawValue")
    func test_description_matchesRawValue() {
        for backend in CodecBackend.allCases {
            #expect(backend.description == backend.rawValue)
        }
    }

    // MARK: - CodecBackendProbe

    @Test("bestAvailable is one of the known backends")
    func test_bestAvailable_isKnownBackend() {
        let best = CodecBackendProbe.bestAvailable
        #expect(CodecBackend.allCases.contains(best))
    }

    @Test("bestAvailable backend is actually available")
    func test_bestAvailable_isAvailable() {
        let best = CodecBackendProbe.bestAvailable
        #expect(CodecBackendProbe.isAvailable(best))
    }

    @Test("availableBackends contains at least scalar")
    func test_availableBackends_atLeastScalar() {
        let avail = CodecBackendProbe.availableBackends
        #expect(!avail.isEmpty)
        #expect(avail.contains(.scalar))
    }

    @Test("availableBackends first element equals bestAvailable")
    func test_availableBackends_firstMatchesBest() {
        let avail = CodecBackendProbe.availableBackends
        let best = CodecBackendProbe.bestAvailable
        #expect(avail.first == best)
    }

    @Test("bestAvailable returns consistently across multiple calls")
    func test_bestAvailable_isStable() {
        let first = CodecBackendProbe.bestAvailable
        let second = CodecBackendProbe.bestAvailable
        #expect(first == second)
    }

    // MARK: - CodecBackendPreference

    @Test("auto preference resolves to bestAvailable")
    func test_autoPreference_resolvesBestAvailable() {
        let pref = CodecBackendPreference.auto
        #expect(pref.effective == CodecBackendProbe.bestAvailable)
    }

    @Test("scalar preference always resolves to scalar")
    func test_scalarPreference_resolvesScalar() {
        let pref = CodecBackendPreference.scalar
        #expect(pref.effective == .scalar)
    }

    @Test("preference with nil forced resolves to bestAvailable")
    func test_nilForced_resolvesBestAvailable() {
        let pref = CodecBackendPreference(forced: nil)
        #expect(pref.effective == CodecBackendProbe.bestAvailable)
    }

    @Test("preference with unavailable forced backend falls back to bestAvailable")
    func test_unavailableForced_fallsBackToBestAvailable() {
        // On any platform, if Metal is unavailable and we force .metal, we
        // expect fallback to bestAvailable (which won't be .metal).
        if !CodecBackendProbe.isAvailable(.metal) {
            let pref = CodecBackendPreference(forced: .metal)
            #expect(pref.effective != .metal)
            #expect(pref.effective == CodecBackendProbe.bestAvailable)
        }
    }

    @Test("static factory properties produce matching forced values")
    func test_staticFactoryProperties() {
        #expect(CodecBackendPreference.metal.forced == .metal)
        #expect(CodecBackendPreference.accelerate.forced == .accelerate)
        #expect(CodecBackendPreference.scalar.forced == .scalar)
        #expect(CodecBackendPreference.auto.forced == nil)
    }

    // MARK: - CodecRegistry extension

    @Test("CodecRegistry.shared.activeBackend matches probe bestAvailable")
    func test_codecRegistry_activeBackend_matchesProbe() {
        let registryBackend = CodecRegistry.shared.activeBackend
        let probeBackend = CodecBackendProbe.bestAvailable
        #expect(registryBackend == probeBackend)
    }

    @Test("CodecRegistry.shared.availableBackends is non-empty")
    func test_codecRegistry_availableBackends_nonEmpty() {
        #expect(!CodecRegistry.shared.availableBackends.isEmpty)
    }

    @Test("CodecRegistry.shared.backendDescription is non-empty")
    func test_codecRegistry_backendDescription_nonEmpty() {
        #expect(!CodecRegistry.shared.backendDescription.isEmpty)
    }

    @Test("CodecRegistry.shared.backendDescription matches activeBackend.displayName")
    func test_codecRegistry_backendDescription_matchesDisplayName() {
        let reg = CodecRegistry.shared
        #expect(reg.backendDescription == reg.activeBackend.displayName)
    }

    // MARK: - Metal availability on Apple platforms

    #if os(macOS) || os(iOS) || os(visionOS)
    @Test("Metal backend availability matches J2KMetalDevice.isAvailable")
    func test_metalBackend_matchesJ2KMetalDevice() {
        // On Apple platforms Metal is expected to be available (all modern hardware).
        // We just ensure our probe agrees with J2KMetal's own isAvailable flag.
        let isAvail = CodecBackendProbe.isAvailable(.metal)
        // We don't import J2KMetal directly in the test — rely on the probe.
        // The assertion: whatever the result, bestAvailable should be >= .metal if Metal is present.
        if isAvail {
            #expect(CodecBackendProbe.bestAvailable == .metal)
        }
    }
    #endif

    // MARK: - effectiveEncodeBackend (the backend actually dispatched to)

    @Test("auto dispatches to the GPU on Metal hardware (Phase 5)")
    func test_effectiveEncodeBackend_autoUsesMetalWhenAvailable() {
        // Phase 5: `auto` now selects the GPU for J2K encodes (any intent) when Metal
        // is available, and CPU otherwise.
        let pref = CodecBackendPreference.auto
        let expected: CodecBackend = CodecBackendProbe.isAvailable(.metal) ? .metal
            : (CodecBackendProbe.availableBackends.first { $0 != .metal } ?? .scalar)
        #expect(pref.effectiveEncodeBackend(isLossless: false, isJPEG2000Family: true) == expected)
        #expect(pref.effectiveEncodeBackend(isLossless: true, isJPEG2000Family: true) == expected)
        // Non-J2K stays CPU even under auto.
        #expect(pref.effectiveEncodeBackend(isLossless: false, isJPEG2000Family: false) != .metal)
    }

    @Test("explicit scalar stays scalar")
    func test_effectiveEncodeBackend_scalarStaysScalar() {
        #expect(CodecBackendPreference.scalar
            .effectiveEncodeBackend(isLossless: false, isJPEG2000Family: true) == .scalar)
    }

    @Test("metal + lossless J2K uses the GPU when Metal is available")
    func test_effectiveEncodeBackend_metalLosslessJ2K() {
        // Phase 2: the reversible GPU encode path is bit-exact (J2KSwift ≥ v11.0.1),
        // so a forced-Metal lossless J2K encode dispatches to the GPU just like lossy.
        let resolved = CodecBackendPreference.metal
            .effectiveEncodeBackend(isLossless: true, isJPEG2000Family: true)
        if CodecBackendProbe.isAvailable(.metal) {
            #expect(resolved == .metal)
        } else {
            #expect(resolved != .metal)
        }
    }

    @Test("metal + non-J2K codec is downgraded off the GPU")
    func test_effectiveEncodeBackend_metalNonJ2KDowngraded() {
        // Only JPEG 2000 / HTJ2K have a GPU encode path.
        #expect(CodecBackendPreference.metal
            .effectiveEncodeBackend(isLossless: false, isJPEG2000Family: false) != .metal)
    }

    @Test("metal + lossy J2K uses the GPU when Metal is available")
    func test_effectiveEncodeBackend_metalLossyJ2K() {
        let resolved = CodecBackendPreference.metal
            .effectiveEncodeBackend(isLossless: false, isJPEG2000Family: true)
        // Metal iff the platform has it; otherwise a CPU fallback (never Metal).
        if CodecBackendProbe.isAvailable(.metal) {
            #expect(resolved == .metal)
        } else {
            #expect(resolved != .metal)
        }
    }
}
