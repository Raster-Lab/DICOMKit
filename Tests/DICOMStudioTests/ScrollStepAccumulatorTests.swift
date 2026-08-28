// ScrollStepAccumulatorTests.swift
// DICOMStudioTests
//
// Paging a stack with the wheel: one notch is one image.
//
// The bug this pins: a mouse wheel's delta is an acceleration curve, not a
// distance, so treating its magnitude as a number of images made a single notch
// jump several at once.

#if canImport(SwiftUI)
import Testing
@testable import DICOMStudio
import Foundation

@Suite("Scroll Step Accumulator Tests")
struct ScrollStepAccumulatorTests {

    @Test("One wheel notch is one image, however large the delta")
    func testNotchIsOneStep() {
        var accumulator = ScrollStepAccumulator()

        #expect(accumulator.steps(for: ScrollWheelDelta(y: 1, isPrecise: false)) == 1)
        #expect(accumulator.steps(for: ScrollWheelDelta(y: 3, isPrecise: false)) == 1)
        #expect(accumulator.steps(for: ScrollWheelDelta(y: 47, isPrecise: false)) == 1,
                "a hard spin pages faster by sending more events, not bigger ones")
        #expect(accumulator.steps(for: ScrollWheelDelta(y: -12, isPrecise: false)) == -1)
    }

    @Test("A zero delta is not a step")
    func testZeroIsNoStep() {
        var accumulator = ScrollStepAccumulator()
        #expect(accumulator.steps(for: ScrollWheelDelta(y: 0, isPrecise: false)) == 0)
        #expect(accumulator.steps(for: ScrollWheelDelta(y: 0, isPrecise: true)) == 0)
    }

    @Test("Trackpad deltas accumulate instead of stepping per event")
    func testPreciseDeltasAccumulate() {
        var accumulator = ScrollStepAccumulator()

        // Small increments on their own move nothing…
        #expect(accumulator.steps(for: ScrollWheelDelta(y: 4, isPrecise: true)) == 0)
        #expect(accumulator.steps(for: ScrollWheelDelta(y: 4, isPrecise: true)) == 0)
        // …until they add up to a step.
        #expect(accumulator.steps(for: ScrollWheelDelta(y: 4, isPrecise: true)) == 1)
        // And the remainder is kept rather than rounded away.
        #expect(accumulator.steps(for: ScrollWheelDelta(y: 12, isPrecise: true)) == 1)
    }

    @Test("A fast trackpad swipe pages by the distance actually swiped")
    func testPreciseSwipeStepsProportionally() {
        var accumulator = ScrollStepAccumulator()
        #expect(accumulator.steps(for: ScrollWheelDelta(y: -36, isPrecise: true)) == -3)
    }

    @Test("Direction changes do not carry a stale part-step")
    func testDirectionChangeAfterNotch() {
        var accumulator = ScrollStepAccumulator()
        #expect(accumulator.steps(for: ScrollWheelDelta(y: 8, isPrecise: true)) == 0)
        // A notch resets the running total: mixing devices mid-scroll must not
        // make the next notch worth two images.
        #expect(accumulator.steps(for: ScrollWheelDelta(y: 1, isPrecise: false)) == 1)
        #expect(accumulator.steps(for: ScrollWheelDelta(y: 8, isPrecise: true)) == 0)
    }

    @Test("Reset forgets a part-step")
    func testReset() {
        var accumulator = ScrollStepAccumulator()
        #expect(accumulator.steps(for: ScrollWheelDelta(y: 8, isPrecise: true)) == 0)
        accumulator.reset()
        #expect(accumulator.steps(for: ScrollWheelDelta(y: 8, isPrecise: true)) == 0)
    }
}
#endif
