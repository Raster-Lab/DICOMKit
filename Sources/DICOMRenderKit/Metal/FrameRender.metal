// FrameRender.metal
// DICOMRenderKit — GPU_RENDERING_PLAN.md milestones M3 (monochrome) and M4 (colour)
//
// Every kernel here does integer and byte-fetch work only. There is deliberately
// no floating-point arithmetic anywhere in this file.
//
// That is design pillar 1 of the plan, and it is not a style preference: this
// project's core invariant is that the CLIs and the app make one shared render
// decision, asserted byte-for-byte by ExportWindowParityTests. A shader that
// recomputed window/level in `float` could not reproduce the CPU's `Double`
// arithmetic bit-for-bit, and the divergence would break that contract.
//
// So every value-mapping decision — bit shift, stored-bit mask, sign extension,
// the VOI window, MONOCHROME1 inversion, the colour normalise, the palette
// lookup — is evaluated on the CPU, in Double, over the at-most-65,536 possible
// inputs, and handed to the GPU as a byte table. The shader's whole job is:
// assemble the sample, index the table, write the byte. That makes GPU output
// bit-identical to CPU output by construction rather than by tolerance.
//
// Buffers, not textures, for both input and output:
//   - Input: DICOM packing is irregular (12 bits stored in 16 allocated, planar
//     configuration 0 vs 1) and maps onto no native MTLPixelFormat. A buffer is
//     also what lets the input be wrapped `bytesNoCopy` over the decoded frame
//     the CPU already holds.
//   - Output: a plain byte buffer keeps the row stride exactly `width` (or
//     `width * 4`), which is what CGImage wants, and avoids the float
//     quantisation an `r8Unorm` texture write would introduce. The plan proposed
//     a texture view for the output; a buffer is simpler and strictly more exact,
//     and M5 can add a view when it needs one for display.

#include <metal_stdlib>
using namespace metal;

// MARK: - Parameters
//
// Layouts must match the Swift structs in MetalFrameRenderer.swift exactly. All
// fields are uint (4 bytes) so the two agree without any padding subtleties.

struct MonochromeParams {
    uint width;
    uint height;
    uint frameByteOffset;    // where this frame starts in the wrapped buffer
    uint bytesPerSample;     // 1 → one byte per sample, else two are assembled
    uint availablePixels;    // pixels actually backed by bytes; the rest stay 0
};

struct ColorParams {
    uint width;
    uint height;
    uint frameByteOffset;
    uint bytesPerSample;
    uint planarConfiguration; // 0 = R1G1B1R2G2B2…, 1 = R1R2…G1G2…B1B2…
    uint frameByteCount;      // bounds for this frame's bytes
    uint planeSizeBytes;      // pixels * bytesPerSample, for planar config 1
};

struct PaletteParams {
    uint width;
    uint height;
    uint frameByteOffset;
    uint bytesPerSample;
    uint availablePixels;
};

// MARK: - Sample assembly
//
// The one place frame bytes become a number. Mirrors the CPU renderer's
// assembly: one byte, or little-endian low|high<<8 for anything wider. Note
// nothing is shifted, masked or sign-extended here — the tables were built over
// the *raw* assembled value, so those steps have already happened.

static inline uint assembleSample(device const uchar* bytes,
                                  uint offset,
                                  uint bytesPerSample)
{
    if (bytesPerSample == 1) {
        return uint(bytes[offset]);
    }
    return uint(bytes[offset]) | (uint(bytes[offset + 1]) << 8);
}

// MARK: - Monochrome

kernel void render_monochrome(
    device   const uchar*      frameBytes [[buffer(0)]],
    constant MonochromeParams& p          [[buffer(1)]],
    device   const uchar*      lut        [[buffer(2)]],   // 256 or 65536 entries
    device   uchar*            out        [[buffer(3)]],
    uint2 gid [[thread_position_in_grid]])
{
    if (gid.x >= p.width || gid.y >= p.height) { return; }

    uint index = gid.y * p.width + gid.x;

    // Samples past the end of a short frame stay black, matching the bounds check
    // the CPU loop broke out on.
    if (index >= p.availablePixels) {
        out[index] = 0;
        return;
    }

    uint offset = p.frameByteOffset + index * p.bytesPerSample;
    out[index] = lut[assembleSample(frameBytes, offset, p.bytesPerSample)];
}

// MARK: - Colour (RGB)
//
// YBR variants are NOT handled here and are routed to the CPU — see
// MetalFrameRenderer.swift for why. This kernel is for photometric
// interpretations whose samples map to output bytes one at a time.

kernel void render_color(
    device   const uchar* frameBytes [[buffer(0)]],
    constant ColorParams& p          [[buffer(1)]],
    device   const uchar* lut        [[buffer(2)]],   // sample → 8-bit channel
    device   uchar*       out        [[buffer(3)]],   // RGBA, 4 bytes per pixel
    uint2 gid [[thread_position_in_grid]])
{
    if (gid.x >= p.width || gid.y >= p.height) { return; }

    uint index = gid.y * p.width + gid.x;
    uint totalPixels = p.width * p.height;

    // Out-of-bounds pixels resolve to sample 0 on all three channels, which is
    // what the CPU loop produces: it leaves r/g/b at their initial 0 and still
    // writes them.
    uint rawR = 0, rawG = 0, rawB = 0;

    if (p.planarConfiguration == 0) {
        uint base = index * 3 * p.bytesPerSample;
        // The comparisons are the CPU renderer's, transcribed including their
        // strictness: it used `<`, not `<=`.
        if (p.bytesPerSample == 1) {
            if (base + 2 < p.frameByteCount) {
                uint o = p.frameByteOffset + base;
                rawR = uint(frameBytes[o]);
                rawG = uint(frameBytes[o + 1]);
                rawB = uint(frameBytes[o + 2]);
            }
        } else {
            if (base + 5 < p.frameByteCount) {
                uint o = p.frameByteOffset + base;
                rawR = uint(frameBytes[o])     | (uint(frameBytes[o + 1]) << 8);
                rawG = uint(frameBytes[o + 2]) | (uint(frameBytes[o + 3]) << 8);
                rawB = uint(frameBytes[o + 4]) | (uint(frameBytes[o + 5]) << 8);
            }
        }
    } else {
        uint rOffset = index * p.bytesPerSample;
        uint gOffset = p.planeSizeBytes + rOffset;
        uint bOffset = 2 * p.planeSizeBytes + rOffset;
        if (p.bytesPerSample == 1) {
            if (bOffset < p.frameByteCount) {
                rawR = uint(frameBytes[p.frameByteOffset + rOffset]);
                rawG = uint(frameBytes[p.frameByteOffset + gOffset]);
                rawB = uint(frameBytes[p.frameByteOffset + bOffset]);
            }
        } else {
            if (bOffset + 1 < p.frameByteCount) {
                uint r0 = p.frameByteOffset + rOffset;
                uint g0 = p.frameByteOffset + gOffset;
                uint b0 = p.frameByteOffset + bOffset;
                rawR = uint(frameBytes[r0]) | (uint(frameBytes[r0 + 1]) << 8);
                rawG = uint(frameBytes[g0]) | (uint(frameBytes[g0 + 1]) << 8);
                rawB = uint(frameBytes[b0]) | (uint(frameBytes[b0 + 1]) << 8);
            }
        }
    }

    // Silence the unused-variable warning while keeping the value documented:
    // totalPixels is implied by width * height and the grid never exceeds it.
    (void)totalPixels;

    uint o = index * 4;
    out[o]     = lut[rawR];
    out[o + 1] = lut[rawG];
    out[o + 2] = lut[rawB];
    out[o + 3] = 255;
}

// MARK: - Palette colour

kernel void render_palette(
    device   const uchar*   frameBytes [[buffer(0)]],
    constant PaletteParams& p          [[buffer(1)]],
    device   const uchar*   redLUT     [[buffer(2)]],
    device   const uchar*   greenLUT   [[buffer(3)]],
    device   const uchar*   blueLUT    [[buffer(4)]],
    device   uchar*         out        [[buffer(5)]],
    uint2 gid [[thread_position_in_grid]])
{
    if (gid.x >= p.width || gid.y >= p.height) { return; }

    uint index = gid.y * p.width + gid.x;
    uint o = index * 4;

    // A short frame leaves the remaining pixels opaque black. The CPU loop broke
    // out with those bytes still at their initial 255, so alpha stays 255 and the
    // colour channels stay… 255 as well. Transcribed rather than tidied: the
    // equality test is the contract.
    if (index >= p.availablePixels) {
        out[o] = 255; out[o + 1] = 255; out[o + 2] = 255; out[o + 3] = 255;
        return;
    }

    uint offset = p.frameByteOffset + index * p.bytesPerSample;
    uint raw = assembleSample(frameBytes, offset, p.bytesPerSample);

    out[o]     = redLUT[raw];
    out[o + 1] = greenLUT[raw];
    out[o + 2] = blueLUT[raw];
    out[o + 3] = 255;
}
