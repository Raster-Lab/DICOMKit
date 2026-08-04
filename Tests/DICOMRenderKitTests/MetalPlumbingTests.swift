import XCTest
@testable import DICOMRenderKit
import DICOMCore

#if canImport(Metal)
import Metal
#endif

/// Milestone M2 of `GPU_RENDERING_PLAN.md`: the target exists, the device comes up,
/// the shader library loads and every kernel compiles to a pipeline state.
///
/// The plan called out shader-library loading as the most likely thing to fail
/// silently, and it was right — just not in the way it expected. This toolchain's
/// SwiftPM ignores `.metal` files in a target's sources entirely, so the shader
/// ships as a resource and is compiled at first use. These tests are what would
/// catch that arrangement breaking.
final class MetalPlumbingTests: XCTestCase {

    #if canImport(Metal)

    /// Skips on machines with no GPU rather than failing: `.cpu` is always
    /// available and CI without a GPU is a supported configuration.
    private func requireDevice() throws -> MetalRenderDevice {
        try XCTSkipIf(MetalRenderDevice.shared == nil, "No Metal device on this machine")
        return MetalRenderDevice.shared!
    }

    func testDeviceAndLibraryLoad() throws {
        let device = try requireDevice()
        XCTAssertFalse(device.device.name.isEmpty)
        // Whichever path was taken, the library must actually contain our kernels —
        // an empty library that loads is the failure mode worth guarding.
        for kernel in MetalKernel.all {
            XCTAssertTrue(device.library.functionNames.contains(kernel),
                          "shader library is missing \(kernel)")
        }
    }

    /// Records which loading path is live. If a future toolchain starts emitting a
    /// metallib this test is where that becomes visible instead of silent.
    func testLibrarySourceIsKnown() throws {
        let device = try requireDevice()
        print("[M2] shader library source: \(device.librarySource.rawValue)")
        XCTAssertTrue(
            [.bundledMetallib, .runtimeCompiled].contains(device.librarySource))
    }

    func testEveryKernelBuildsAPipelineState() throws {
        let device = try requireDevice()
        for kernel in MetalKernel.all {
            XCTAssertNotNil(device.pipelineState(for: kernel),
                            "\(kernel) failed to build a compute pipeline state")
        }
    }

    /// The cache must hand back the same compiled object, not recompile per call.
    func testPipelineStateIsCached() throws {
        let device = try requireDevice()
        let first = try XCTUnwrap(device.pipelineState(for: MetalKernel.monochrome))
        let second = try XCTUnwrap(device.pipelineState(for: MetalKernel.monochrome))
        XCTAssertTrue(first === second)
    }

    func testUnknownKernelReturnsNil() throws {
        let device = try requireDevice()
        XCTAssertNil(device.pipelineState(for: "render_nonexistent"))
    }

    #endif

    // MARK: - Backend selection

    /// `.cpu` is the guarantee the whole fallback story rests on.
    func testCPUBackendIsAlwaysAvailable() {
        XCTAssertTrue(RenderBackend.cpu.isAvailable)
        XCTAssertTrue(RenderBackend.availableBackends.contains(.cpu))
    }

    /// Metal is chosen automatically only on unified-memory hardware — design
    /// pillar 2. On a discrete GPU the copies are unavoidable and the CPU renderer
    /// is the better answer, so `.metal` being *available* must not be enough.
    func testAutomaticSelectsMetalOnlyOnUnifiedMemory() throws {
        try XCTSkipIf(RenderBackend.environmentOverride != nil,
                      "DICOMKIT_RENDER_BACKEND pins the answer — covered by "
                      + "testEnvironmentOverrideOutranksForcedPreference instead")
        let automatic = RenderBackend.automatic()
        #if canImport(Metal)
        if let device = MetalRenderDevice.shared?.device {
            if device.hasUnifiedMemory {
                XCTAssertEqual(automatic, .metal)
            } else {
                XCTAssertEqual(automatic, .cpu,
                               "a discrete GPU must not be selected automatically")
            }
            return
        }
        #endif
        XCTAssertEqual(automatic, .cpu)
    }

    func testForcedPreferenceFallsBackToCPUWhenUnavailable() {
        XCTAssertEqual(RenderBackendPreference.cpu.effective, .cpu)
        let metal = RenderBackendPreference.metal.effective
        if let override = RenderBackend.environmentOverride {
            // The environment outranks a forced preference — see below.
            XCTAssertEqual(metal, override)
        } else {
            XCTAssertEqual(metal, RenderBackend.metal.isAvailable ? .metal : .cpu)
        }
    }

    /// `DICOMKIT_RENDER_BACKEND=cpu` must beat a hard-coded `.metal`, or the
    /// support instruction "run with the GPU off" would not actually do anything
    /// on the code paths that force a backend.
    ///
    /// CI runs the whole render suite a second time with that variable set, so this
    /// assertion has both branches exercised across the matrix.
    func testEnvironmentOverrideOutranksForcedPreference() throws {
        guard let override = RenderBackend.environmentOverride else {
            throw XCTSkip("DICOMKIT_RENDER_BACKEND is not set in this run")
        }
        XCTAssertEqual(RenderBackendPreference.metal.effective, override)
        XCTAssertEqual(RenderBackendPreference.cpu.effective, override)
        XCTAssertEqual(RenderBackend.automatic(), override)
        XCTAssertEqual(FrameRenderService(preference: .metal).activeBackend, override)
    }

    func testDisplayNamesAreDistinctAndNonEmpty() {
        let names = Set(RenderBackend.allCases.map(\.displayName))
        XCTAssertEqual(names.count, RenderBackend.allCases.count)
        XCTAssertFalse(names.contains(""))
    }

    /// An unrecognised `DICOMKIT_RENDER_BACKEND` must fall through to normal
    /// selection rather than disabling rendering — a typo in a support session
    /// should not leave someone with no images.
    func testEnvironmentOverrideParsing() {
        // The variable is not set in the test environment, so the parse is nil and
        // automatic selection is untouched.
        if ProcessInfo.processInfo.environment["DICOMKIT_RENDER_BACKEND"] == nil {
            XCTAssertNil(RenderBackend.environmentOverride)
        }
        XCTAssertEqual(RenderBackend(rawValue: "cpu"), .cpu)
        XCTAssertEqual(RenderBackend(rawValue: "metal"), .metal)
        XCTAssertNil(RenderBackend(rawValue: "gpu"))
    }
}
