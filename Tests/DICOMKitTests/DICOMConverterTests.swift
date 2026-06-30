import Testing
import Foundation
@testable import DICOMKit
import DICOMCore

/// Contract tests for the shared ``DICOMConverter`` API — the single source of truth
/// the `dicom-convert` CLI and the DICOMStudio CLI Workshop both use for the convert
/// target list, transfer-syntax parsing, and the conversion pipeline.
@Suite("DICOMConverter Shared API")
struct DICOMConverterTests {

    @Test("every catalog token (cliToken / aliasToken / UID) round-trips through parseTarget")
    func tokensRoundTrip() {
        for t in DICOMConverter.targets {
            #expect(DICOMConverter.parseTarget(t.cliToken)?.uid == t.syntax.uid, "cliToken \(t.cliToken)")
            #expect(DICOMConverter.parseTarget(t.aliasToken)?.uid == t.syntax.uid, "aliasToken \(t.aliasToken)")
            #expect(DICOMConverter.parseTarget(t.syntax.uid)?.uid == t.syntax.uid, "uid \(t.syntax.uid)")
            for alias in t.extraAliases {
                #expect(DICOMConverter.parseTarget(alias)?.uid == t.syntax.uid, "extra alias \(alias)")
            }
        }
    }

    @Test("the picker token lists are the catalog and can never offer a value parseTarget rejects")
    func pickerTokensAlwaysParse() {
        #expect(DICOMConverter.cliTokens.count == DICOMConverter.targets.count)
        #expect(DICOMConverter.aliasTokens.count == DICOMConverter.targets.count)
        for token in DICOMConverter.cliTokens + DICOMConverter.aliasTokens {
            #expect(DICOMConverter.parseTarget(token) != nil, "picker token \(token) must parse")
        }
    }

    @Test("catalog covers the DICOMCore-encodable convert set incl. Part 2, HTJ2K, JPEG XL")
    func catalogCoverage() {
        let uids = Set(DICOMConverter.targetSyntaxes.map(\.uid))
        let expected: [TransferSyntax] = [
            .explicitVRLittleEndian, .implicitVRLittleEndian, .explicitVRBigEndian, .deflatedExplicitVRLittleEndian,
            .jpegBaseline, .jpegExtended, .jpegLossless, .jpegLosslessSV1,
            .jpeg2000Lossless, .jpeg2000, .jpeg2000Part2Lossless, .jpeg2000Part2,
            .htj2kLossless, .htj2kRPCLLossless, .htj2kLossy,
            .jpegLSLossless, .jpegLSNearLossless, .jpegXLLossless, .rleLossless,
        ]
        for s in expected { #expect(uids.contains(s.uid), "missing target \(s.displayName)") }
        // Non-encodable / out-of-scope syntaxes must NOT be offered as convert targets.
        for s: TransferSyntax in [.mpeg2MainProfile, .jpipReferenced, .jp3dLossless, .jpegXL, .jpegXLRecompression] {
            #expect(!uids.contains(s.uid), "\(s.displayName) must not be a convert target")
            #expect(DICOMConverter.parseTarget(s.uid) == nil, "\(s.displayName) UID must not parse as a target")
        }
    }

    @Test("JPEG XL and JPEG-LS generic aliases resolve to the lossless-only encode target")
    func losslessOnlyAliases() {
        // JPEG XL encode is lossless-only — the generic names fold to .jpegXLLossless.
        #expect(DICOMConverter.parseTarget("jpeg-xl")?.uid == TransferSyntax.jpegXLLossless.uid)
        #expect(DICOMConverter.parseTarget("jxl")?.uid == TransferSyntax.jpegXLLossless.uid)
        #expect(DICOMConverter.parseTarget("jpegxl")?.uid == TransferSyntax.jpegXLLossless.uid)
        // Bare "jpegls" historically meant LOSSLESS for dicom-convert (not near-lossless).
        #expect(DICOMConverter.parseTarget("jpegls")?.uid == TransferSyntax.jpegLSLossless.uid)
    }

    @Test("legacy short aliases preserved (CLI ↔ app parity)")
    func legacyAliases() {
        #expect(DICOMConverter.parseTarget("evle")?.uid == TransferSyntax.explicitVRLittleEndian.uid)
        #expect(DICOMConverter.parseTarget("ivle")?.uid == TransferSyntax.implicitVRLittleEndian.uid)
        #expect(DICOMConverter.parseTarget("evbe")?.uid == TransferSyntax.explicitVRBigEndian.uid)
        #expect(DICOMConverter.parseTarget("j2k")?.uid == TransferSyntax.jpeg2000.uid)
        #expect(DICOMConverter.parseTarget("rle")?.uid == TransferSyntax.rleLossless.uid)
        #expect(DICOMConverter.parseTarget("deflate")?.uid == TransferSyntax.deflatedExplicitVRLittleEndian.uid)
        // Case-insensitive CamelCase from the CLI is accepted too.
        #expect(DICOMConverter.parseTarget("ExplicitVRLittleEndian")?.uid == TransferSyntax.explicitVRLittleEndian.uid)
    }

    @Test("unknown token returns nil and the error message names it and lists targets")
    func unknownToken() {
        #expect(DICOMConverter.parseTarget("Bogus") == nil)
        #expect(DICOMConverter.parseTarget("") == nil)
        #expect(DICOMConverter.parseTarget("   ") == nil)
        let msg = DICOMConverter.unknownTargetMessage("Bogus")
        #expect(msg.contains("Bogus"))
        #expect(msg.contains("HTJ2KLossless"))
        #expect(msg.contains("JPEGXLLossless"))
    }

    @Test("convertToDICOM transcodes explicit → implicit and renders a valid Part-10 file")
    func convertRoundTrip() throws {
        var ds = DataSet()
        ds.setString("1.2.840.10008.5.1.4.1.1.7", for: .sopClassUID, vr: .UI)
        ds.setString("1.2.3.4.5.6.7.8.9", for: .sopInstanceUID, vr: .UI)
        ds.setString("TEST^PATIENT", for: .patientName, vr: .PN)
        let file = DICOMFile.create(
            dataSet: ds,
            sopClassUID: "1.2.840.10008.5.1.4.1.1.7",
            sopInstanceUID: "1.2.3.4.5.6.7.8.9",
            transferSyntaxUID: TransferSyntax.explicitVRLittleEndian.uid
        )

        let outcome = try DICOMConverter.convertToDICOM(
            dicomFile: file, to: .implicitVRLittleEndian, stripPrivate: false
        )
        #expect(outcome.sourceSyntax.uid == TransferSyntax.explicitVRLittleEndian.uid)
        #expect(outcome.targetSyntax.uid == TransferSyntax.implicitVRLittleEndian.uid)
        #expect(outcome.wasTranscoded)
        #expect(outcome.isLossless)
        #expect(outcome.strippedPrivateTagCount == 0)

        // The output is a real DICOM file encoded in the target transfer syntax.
        let reread = try DICOMFile.read(from: outcome.data)
        #expect(reread.transferSyntaxUID == TransferSyntax.implicitVRLittleEndian.uid)
        #expect(reread.dataSet.string(for: .patientName)?
            .trimmingCharacters(in: CharacterSet(charactersIn: "\0 ")) == "TEST^PATIENT")
    }

    /// Builds a minimal Explicit VR LE source file for transcode round-trip tests.
    private func makeSource(patient: String = "TEST^PATIENT") -> DICOMFile {
        var ds = DataSet()
        ds.setString("1.2.840.10008.5.1.4.1.1.7", for: .sopClassUID, vr: .UI)
        ds.setString("1.2.3.4.5.6.7.8.9", for: .sopInstanceUID, vr: .UI)
        ds.setString(patient, for: .patientName, vr: .PN)
        return DICOMFile.create(
            dataSet: ds,
            sopClassUID: "1.2.840.10008.5.1.4.1.1.7",
            sopInstanceUID: "1.2.3.4.5.6.7.8.9",
            transferSyntaxUID: TransferSyntax.explicitVRLittleEndian.uid
        )
    }

    @Test("convertToDICOM produces a valid Deflated Explicit VR LE file that round-trips (FMI uncompressed)")
    func convertToDeflateRoundTrips() throws {
        // DEFLATE is a data-set-level deflate the DICOMCore transcoder rejects; convertToDICOM
        // handles it directly (serialize EVLE → deflate; File Meta Information stays uncompressed).
        let outcome = try DICOMConverter.convertToDICOM(
            dicomFile: makeSource(), to: .deflatedExplicitVRLittleEndian, stripPrivate: false
        )
        #expect(outcome.targetSyntax.uid == TransferSyntax.deflatedExplicitVRLittleEndian.uid)
        #expect(outcome.wasTranscoded)
        #expect(outcome.isLossless)

        let reread = try DICOMFile.read(from: outcome.data)
        #expect(reread.transferSyntaxUID == TransferSyntax.deflatedExplicitVRLittleEndian.uid)
        #expect(reread.dataSet.string(for: .patientName)?
            .trimmingCharacters(in: CharacterSet(charactersIn: "\0 ")) == "TEST^PATIENT")
    }

    @Test("convertToDICOM transcodes explicit LE → explicit BE and round-trips losslessly")
    func convertToBigEndianRoundTrips() throws {
        let outcome = try DICOMConverter.convertToDICOM(
            dicomFile: makeSource(), to: .explicitVRBigEndian, stripPrivate: false
        )
        #expect(outcome.targetSyntax.uid == TransferSyntax.explicitVRBigEndian.uid)
        #expect(outcome.wasTranscoded)
        #expect(outcome.isLossless)

        let reread = try DICOMFile.read(from: outcome.data)
        #expect(reread.transferSyntaxUID == TransferSyntax.explicitVRBigEndian.uid)
        #expect(reread.dataSet.string(for: .patientName)?
            .trimmingCharacters(in: CharacterSet(charactersIn: "\0 ")) == "TEST^PATIENT")
    }
}
