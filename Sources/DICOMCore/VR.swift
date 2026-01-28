/// Value Representation (VR) enumeration
///
/// Defines all 31 Value Representations from DICOM PS3.5 2025e Table 6.2-1.
/// Each VR specifies the data type and format of a DICOM data element value.
///
/// Reference: DICOM PS3.5 Section 6.2 - Value Representation (VR)
public enum VR: String, Sendable, Hashable, CaseIterable {
    // String VRs
    /// Application Entity (PS3.5 Section 6.2)
    case AE
    /// Age String (PS3.5 Section 6.2)
    case AS
    /// Code String (PS3.5 Section 6.2)
    case CS
    /// Date (PS3.5 Section 6.2)
    case DA
    /// Decimal String (PS3.5 Section 6.2)
    case DS
    /// Date Time (PS3.5 Section 6.2)
    case DT
    /// Integer String (PS3.5 Section 6.2)
    case IS
    /// Long String (PS3.5 Section 6.2)
    case LO
    /// Long Text (PS3.5 Section 6.2)
    case LT
    /// Person Name (PS3.5 Section 6.2)
    case PN
    /// Short String (PS3.5 Section 6.2)
    case SH
    /// Short Text (PS3.5 Section 6.2)
    case ST
    /// Time (PS3.5 Section 6.2)
    case TM
    /// Unlimited Characters (PS3.5 Section 6.2)
    case UC
    /// Unique Identifier (UID) (PS3.5 Section 6.2)
    case UI
    /// Unlimited Text (PS3.5 Section 6.2)
    case UT
    
    // Binary VRs
    /// Attribute Tag (PS3.5 Section 6.2)
    case AT
    /// Floating Point Single (PS3.5 Section 6.2)
    case FL
    /// Floating Point Double (PS3.5 Section 6.2)
    case FD
    /// Other Byte (PS3.5 Section 6.2)
    case OB
    /// Other Double (PS3.5 Section 6.2)
    case OD
    /// Other Float (PS3.5 Section 6.2)
    case OF
    /// Other Long (PS3.5 Section 6.2)
    case OL
    /// Other Word (PS3.5 Section 6.2)
    case OW
    /// Signed Long (PS3.5 Section 6.2)
    case SL
    /// Sequence of Items (PS3.5 Section 6.2)
    case SQ
    /// Signed Short (PS3.5 Section 6.2)
    case SS
    /// Unsigned Long (PS3.5 Section 6.2)
    case UL
    /// Unknown (PS3.5 Section 6.2)
    case UN
    /// Universal Resource Identifier or Universal Resource Locator (URI/URL) (PS3.5 Section 6.2)
    case UR
    /// Unsigned Short (PS3.5 Section 6.2)
    case US
    
    /// Indicates whether this VR uses a 32-bit length field in Explicit VR encoding
    ///
    /// Per PS3.5 Section 7.1.2, most VRs use a 16-bit length field, but certain VRs
    /// (OB, OD, OF, OL, OW, SQ, UC, UN, UR, UT) use a 32-bit length field.
    public var uses32BitLength: Bool {
        switch self {
        case .OB, .OD, .OF, .OL, .OW, .SQ, .UC, .UN, .UR, .UT:
            return true
        default:
            return false
        }
    }
    
    /// Character repertoire for string-based VRs
    ///
    /// Reference: PS3.5 Section 6.1.2 - Character Repertoires
    public var characterRepertoire: CharacterRepertoire? {
        switch self {
        case .AE, .AS, .CS, .DA, .DS, .DT, .IS, .TM, .UI, .UR:
            return .defaultRepertoire
        case .LO, .LT, .PN, .SH, .ST, .UC, .UT:
            return .extendedOrReplacement
        default:
            return nil
        }
    }
}

/// Character repertoire constraints for DICOM string VRs
///
/// Reference: PS3.5 Section 6.1.2
public enum CharacterRepertoire: Sendable, Hashable {
    /// Default Character Repertoire (ISO 646, basic ASCII subset)
    case defaultRepertoire
    /// Extended or Replacement Character Repertoires (controlled by Specific Character Set)
    case extendedOrReplacement
}
