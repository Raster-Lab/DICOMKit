import Testing
@testable import DICOMDictionary
@testable import DICOMCore

/// Regression test for M4 (see BUG_REVIEW.md): dictionary rows whose Name field
/// is empty were dropped because `split(separator:)` omitted empty subsequences,
/// collapsing the 6-column row to 5 and failing the field-count guard.
@Suite("Empty-Name Dictionary Entry Regression Tests")
struct EmptyNameEntryRegressionTests {

    @Test("Tags with an empty Name field are still present in the dictionary")
    func testEmptyNameEntriesArePresent() {
        // These three standard elements have an empty Name in the source
        // dictionary and were silently dropped before the fix.
        let cases: [(UInt16, UInt16, VR)] = [
            (0x0018, 0x0061, .DS),
            (0x0400, 0x0315, .FL),
            (0x300A, 0x0782, .US),
        ]

        for (group, element, expectedVR) in cases {
            let entry = DataElementDictionary.lookup(tag: Tag(group: group, element: element))
            #expect(entry != nil, "expected (\(String(group, radix: 16)),\(String(element, radix: 16))) to be present")
            #expect(entry?.vr.contains(expectedVR) == true)
        }
    }
}
