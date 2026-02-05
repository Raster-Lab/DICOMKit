/// Private Tag Definition
///
/// Defines a known private tag with its name, VR, and description.
/// Used in vendor-specific dictionaries to interpret private data elements.
public struct PrivateTagDefinition: Sendable, Hashable {
    /// Private tag
    public let tag: Tag
    
    /// Tag name
    public let name: String
    
    /// Value representation
    public let vr: VR
    
    /// Description
    public let description: String?
    
    /// Creates a private tag definition
    /// - Parameters:
    ///   - tag: Private tag
    ///   - name: Tag name
    ///   - vr: Value representation
    ///   - description: Optional description
    public init(tag: Tag, name: String, vr: VR, description: String? = nil) {
        self.tag = tag
        self.name = name
        self.vr = vr
        self.description = description
    }
}

/// Private Tag Dictionary
///
/// Dictionary of known private tags for vendor-specific data elements.
/// Maps private creator IDs to their tag definitions.
///
/// Reference: DICOM PS3.5 Section 7.8 - Private Data Elements
public struct PrivateTagDictionary: Sendable {
    /// Private tag definitions indexed by creator ID
    private let definitions: [String: [Tag: PrivateTagDefinition]]
    
    /// Creates an empty private tag dictionary
    public init() {
        self.definitions = [:]
    }
    
    /// Creates a private tag dictionary with definitions
    /// - Parameter definitions: Dictionary of creator ID to tag definitions
    public init(definitions: [String: [Tag: PrivateTagDefinition]]) {
        self.definitions = definitions
    }
    
    /// Looks up a private tag definition
    /// - Parameters:
    ///   - tag: Private tag to look up
    ///   - creatorID: Private creator ID
    /// - Returns: Private tag definition if found
    public func definition(for tag: Tag, creatorID: String) -> PrivateTagDefinition? {
        return definitions[creatorID]?[tag]
    }
    
    /// Looks up the VR for a private tag
    /// - Parameters:
    ///   - tag: Private tag to look up
    ///   - creatorID: Private creator ID
    /// - Returns: Value representation if known
    public func vr(for tag: Tag, creatorID: String) -> VR? {
        return definition(for: tag, creatorID: creatorID)?.vr
    }
    
    /// Looks up the name for a private tag
    /// - Parameters:
    ///   - tag: Private tag to look up
    ///   - creatorID: Private creator ID
    /// - Returns: Tag name if known
    public func name(for tag: Tag, creatorID: String) -> String? {
        return definition(for: tag, creatorID: creatorID)?.name
    }
}

// MARK: - Well-Known Private Tag Dictionaries
extension PrivateTagDictionary {
    /// Siemens CSA Header private tags
    public static let siemensCSA: PrivateTagDictionary = {
        var defs: [Tag: PrivateTagDefinition] = [:]
        
        // Common Siemens CSA tags (group 0x0029, block 0x10)
        defs[Tag(group: 0x0029, element: 0x1008)] = PrivateTagDefinition(
            tag: Tag(group: 0x0029, element: 0x1008),
            name: "CSA Image Header Type",
            vr: .CS,
            description: "Type of CSA header"
        )
        
        defs[Tag(group: 0x0029, element: 0x1009)] = PrivateTagDefinition(
            tag: Tag(group: 0x0029, element: 0x1009),
            name: "CSA Image Header Version",
            vr: .CS,
            description: "Version of CSA header format"
        )
        
        defs[Tag(group: 0x0029, element: 0x1010)] = PrivateTagDefinition(
            tag: Tag(group: 0x0029, element: 0x1010),
            name: "CSA Image Header Info",
            vr: .OB,
            description: "CSA image header data"
        )
        
        defs[Tag(group: 0x0029, element: 0x1018)] = PrivateTagDefinition(
            tag: Tag(group: 0x0029, element: 0x1018),
            name: "CSA Series Header Type",
            vr: .CS,
            description: "Type of series CSA header"
        )
        
        defs[Tag(group: 0x0029, element: 0x1019)] = PrivateTagDefinition(
            tag: Tag(group: 0x0029, element: 0x1019),
            name: "CSA Series Header Version",
            vr: .CS,
            description: "Version of series CSA header"
        )
        
        defs[Tag(group: 0x0029, element: 0x1020)] = PrivateTagDefinition(
            tag: Tag(group: 0x0029, element: 0x1020),
            name: "CSA Series Header Info",
            vr: .OB,
            description: "CSA series header data"
        )
        
        return PrivateTagDictionary(definitions: ["SIEMENS CSA HEADER": defs])
    }()
    
    /// Siemens MR Header private tags
    public static let siemensMR: PrivateTagDictionary = {
        var defs: [Tag: PrivateTagDefinition] = [:]
        
        // Siemens MR specific tags (group 0x0019, block 0x10)
        defs[Tag(group: 0x0019, element: 0x100c)] = PrivateTagDefinition(
            tag: Tag(group: 0x0019, element: 0x100c),
            name: "B Value",
            vr: .IS,
            description: "Diffusion B value"
        )
        
        defs[Tag(group: 0x0019, element: 0x100d)] = PrivateTagDefinition(
            tag: Tag(group: 0x0019, element: 0x100d),
            name: "Diffusion Gradient Direction",
            vr: .FD,
            description: "Diffusion gradient direction vector"
        )
        
        defs[Tag(group: 0x0019, element: 0x100e)] = PrivateTagDefinition(
            tag: Tag(group: 0x0019, element: 0x100e),
            name: "Gradient Mode",
            vr: .CS,
            description: "Gradient mode"
        )
        
        return PrivateTagDictionary(definitions: ["SIEMENS MR HEADER": defs])
    }()
    
    /// GE Medical Systems private tags
    public static let geMedical: PrivateTagDictionary = {
        var defs: [Tag: PrivateTagDefinition] = [:]
        
        // GE Identification tags (group 0x0009, block 0x10)
        defs[Tag(group: 0x0009, element: 0x1001)] = PrivateTagDefinition(
            tag: Tag(group: 0x0009, element: 0x1001),
            name: "Full Fidelity",
            vr: .CS,
            description: "Full fidelity flag"
        )
        
        defs[Tag(group: 0x0009, element: 0x1002)] = PrivateTagDefinition(
            tag: Tag(group: 0x0009, element: 0x1002),
            name: "Suite ID",
            vr: .SH,
            description: "Suite identifier"
        )
        
        defs[Tag(group: 0x0009, element: 0x1004)] = PrivateTagDefinition(
            tag: Tag(group: 0x0009, element: 0x1004),
            name: "Product ID",
            vr: .SH,
            description: "Product identifier"
        )
        
        return PrivateTagDictionary(definitions: ["GEMS_IDEN_01": defs])
    }()
    
    /// GE Acquisition private tags
    public static let geAcquisition: PrivateTagDictionary = {
        var defs: [Tag: PrivateTagDefinition] = [:]
        
        // GE Acquisition tags (group 0x0019, block 0x10)
        defs[Tag(group: 0x0019, element: 0x100f)] = PrivateTagDefinition(
            tag: Tag(group: 0x0019, element: 0x100f),
            name: "Protocol Data Block",
            vr: .OB,
            description: "GE protocol data block"
        )
        
        return PrivateTagDictionary(definitions: ["GEMS_ACQU_01": defs])
    }()
    
    /// Philips Imaging private tags
    public static let philipsImaging: PrivateTagDictionary = {
        var defs: [Tag: PrivateTagDefinition] = [:]
        
        // Philips private tags (group 0x2001, block 0x10)
        defs[Tag(group: 0x2001, element: 0x1003)] = PrivateTagDefinition(
            tag: Tag(group: 0x2001, element: 0x1003),
            name: "Chemical Shift",
            vr: .FL,
            description: "Chemical shift value"
        )
        
        defs[Tag(group: 0x2001, element: 0x1008)] = PrivateTagDefinition(
            tag: Tag(group: 0x2001, element: 0x1008),
            name: "Stack Radial Angle",
            vr: .FL,
            description: "Stack radial angle"
        )
        
        return PrivateTagDictionary(definitions: ["Philips Imaging DD 001": defs])
    }()
    
    /// Combined dictionary with all well-known vendor tags
    public static let wellKnown: PrivateTagDictionary = {
        var combined: [String: [Tag: PrivateTagDefinition]] = [:]
        
        // Merge all vendor dictionaries
        for dict in [siemensCSA, siemensMR, geMedical, geAcquisition, philipsImaging] {
            for (creatorID, tags) in dict.definitions {
                if combined[creatorID] == nil {
                    combined[creatorID] = tags
                } else {
                    combined[creatorID]!.merge(tags) { _, new in new }
                }
            }
        }
        
        return PrivateTagDictionary(definitions: combined)
    }()
}
