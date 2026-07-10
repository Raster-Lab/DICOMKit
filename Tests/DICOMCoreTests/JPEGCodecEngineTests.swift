import Testing
import Foundation
@testable import DICOMCore

/// Verifies `CodecRegistry.encoder(for:engine:)` routes JPEG **Baseline** to either
/// JLICodec or the native ImageIO codec, while every other transfer syntax — the
/// three other JPEG syntaxes included — resolves identically no matter what engine
/// is asked for. ImageIO has no SOF1/SOF3 encoder, which is why Baseline is the
/// only syntax with a second engine.
@Suite("JPEGCodecEngine — registry encoder routing")
struct JPEGCodecEngineTests {

    private let baseline = TransferSyntax.jpegBaseline.uid       // .50
    private let extended = TransferSyntax.jpegExtended.uid       // .51
    private let lossless = TransferSyntax.jpegLossless.uid       // .57
    private let losslessSV1 = TransferSyntax.jpegLosslessSV1.uid // .70

    /// Syntaxes that must ignore the engine parameter entirely.
    private var engineAgnosticUIDs: [String] {
        [extended, lossless, losslessSV1,
         TransferSyntax.jpeg2000.uid,
         TransferSyntax.jpegLSLossless.uid,
         TransferSyntax.rleLossless.uid]
    }

    // MARK: - The selectable syntax

    @Test("jpegEngineSelectableUID is JPEG Baseline")
    func testSelectableUID() {
        #expect(CodecRegistry.jpegEngineSelectableUID == baseline)
    }

    @Test("Default engine (.jli) leaves Baseline on JLICodec")
    func testBaselineDefaultEngineIsJLI() throws {
        let encoder = try #require(CodecRegistry.shared.encoder(for: baseline, engine: .jli))
        #expect(encoder is JLICodec)
    }

    @Test("Omitting the engine matches .jli exactly")
    func testEngineDefaultMatchesPlainLookup() throws {
        let plain = try #require(CodecRegistry.shared.encoder(for: baseline))
        let jli = try #require(CodecRegistry.shared.encoder(for: baseline, engine: .jli))
        #expect(type(of: plain) == type(of: jli))
    }

    #if canImport(ImageIO)
    @Test("Native engine swaps Baseline to NativeJPEGCodec")
    func testBaselineNativeEngine() throws {
        let encoder = try #require(CodecRegistry.shared.encoder(for: baseline, engine: .native))
        #expect(encoder is NativeJPEGCodec)
    }

    @Test("NativeJPEGCodec advertises Baseline as its only encoding syntax")
    func testNativeEncodesBaselineOnly() {
        #expect(NativeJPEGCodec.supportedEncodingTransferSyntaxes == [baseline])
    }
    #endif

    // MARK: - Every other syntax ignores the engine

    @Test("Non-Baseline syntaxes resolve identically for .jli and .native")
    func testOtherSyntaxesIgnoreEngine() throws {
        for uid in engineAgnosticUIDs {
            let jli = try #require(CodecRegistry.shared.encoder(for: uid, engine: .jli),
                                   "no encoder for \(uid)")
            let native = try #require(CodecRegistry.shared.encoder(for: uid, engine: .native),
                                      "no encoder for \(uid)")
            #expect(type(of: jli) == type(of: native), "engine changed encoder for \(uid)")
        }
    }

    @Test("The other three JPEG syntaxes stay on JLICodec under .native")
    func testOtherJPEGSyntaxesStayJLI() throws {
        for uid in [extended, lossless, losslessSV1] {
            let encoder = try #require(CodecRegistry.shared.encoder(for: uid, engine: .native))
            #expect(encoder is JLICodec, "\(uid) was diverted off JLICodec")
        }
    }

    @Test("An unknown transfer syntax stays nil under either engine")
    func testUnknownSyntaxIsNil() {
        let bogus = "1.2.840.10008.1.2.4.99999"
        #expect(CodecRegistry.shared.encoder(for: bogus, engine: .jli) == nil)
        #expect(CodecRegistry.shared.encoder(for: bogus, engine: .native) == nil)
    }

    // MARK: - Enum surface

    @Test("Engine raw values are stable (they are persisted in the Workshop form)")
    func testRawValues() {
        #expect(JPEGCodecEngine.jli.rawValue == "jli")
        #expect(JPEGCodecEngine.native.rawValue == "native")
        #expect(JPEGCodecEngine.allCases.map { $0.rawValue } == ["jli", "native"])
    }
}
