/// DICOM SR Template Validation
///
/// Provides validation of SR content against template definitions.
///
/// Reference: PS3.16 Section 5 - Template Specifications

import Foundation

// MARK: - Template Violation

/// Represents a violation of template constraints
public struct TemplateViolation: Sendable, Equatable {
    /// Severity of the violation
    public enum Severity: String, Sendable, Equatable, CaseIterable {
        /// Error - document is non-compliant
        case error
        /// Warning - potential issue but may be acceptable
        case warning
        /// Info - informational message
        case info
    }
    
    /// The severity of this violation
    public let severity: Severity
    
    /// The template row that was violated (if applicable)
    public let templateRowID: String?
    
    /// Path to the content item that caused the violation
    public let contentPath: String?
    
    /// Human-readable description of the violation
    public let message: String
    
    /// Additional details about the violation
    public let details: String?
    
    /// Creates a template violation
    public init(
        severity: Severity,
        templateRowID: String? = nil,
        contentPath: String? = nil,
        message: String,
        details: String? = nil
    ) {
        self.severity = severity
        self.templateRowID = templateRowID
        self.contentPath = contentPath
        self.message = message
        self.details = details
    }
    
    // MARK: - Factory Methods
    
    /// Creates a missing required content violation
    public static func missingRequired(
        rowID: String?,
        conceptName: CodedConcept?,
        path: String?
    ) -> TemplateViolation {
        let conceptDesc = conceptName?.codeMeaning ?? "content item"
        return TemplateViolation(
            severity: .error,
            templateRowID: rowID,
            contentPath: path,
            message: "Missing required \(conceptDesc)",
            details: conceptName.map { "Expected: \($0.codeValue) - \($0.codeMeaning)" }
        )
    }
    
    /// Creates a cardinality violation
    public static func cardinalityViolation(
        rowID: String?,
        expected: Cardinality,
        actual: Int,
        conceptName: CodedConcept?,
        path: String?
    ) -> TemplateViolation {
        let conceptDesc = conceptName?.codeMeaning ?? "content item"
        return TemplateViolation(
            severity: .error,
            templateRowID: rowID,
            contentPath: path,
            message: "Cardinality violation for \(conceptDesc): expected \(expected), found \(actual)",
            details: nil
        )
    }
    
    /// Creates a value type mismatch violation
    public static func valueTypeMismatch(
        rowID: String?,
        expected: ContentItemValueType,
        actual: ContentItemValueType,
        path: String?
    ) -> TemplateViolation {
        TemplateViolation(
            severity: .error,
            templateRowID: rowID,
            contentPath: path,
            message: "Value type mismatch: expected \(expected.rawValue), found \(actual.rawValue)",
            details: nil
        )
    }
    
    /// Creates a relationship type mismatch violation
    public static func relationshipMismatch(
        rowID: String?,
        expected: RelationshipType,
        actual: RelationshipType?,
        path: String?
    ) -> TemplateViolation {
        TemplateViolation(
            severity: .error,
            templateRowID: rowID,
            contentPath: path,
            message: "Relationship type mismatch: expected \(expected.rawValue), found \(actual?.rawValue ?? "none")",
            details: nil
        )
    }
    
    /// Creates an invalid concept violation
    public static func invalidConcept(
        rowID: String?,
        expected: ConceptNameConstraint,
        actual: CodedConcept?,
        path: String?
    ) -> TemplateViolation {
        let actualDesc = actual?.codeMeaning ?? "none"
        return TemplateViolation(
            severity: .error,
            templateRowID: rowID,
            contentPath: path,
            message: "Invalid concept name: found '\(actualDesc)'",
            details: "Expected: \(expected)"
        )
    }
    
    /// Creates an invalid value violation
    public static func invalidValue(
        rowID: String?,
        constraint: ValueConstraint,
        path: String?
    ) -> TemplateViolation {
        TemplateViolation(
            severity: .error,
            templateRowID: rowID,
            contentPath: path,
            message: "Value does not satisfy constraint",
            details: "Constraint: \(constraint)"
        )
    }
    
    /// Creates a warning for unexpected content
    public static func unexpectedContent(
        path: String?,
        message: String
    ) -> TemplateViolation {
        TemplateViolation(
            severity: .warning,
            templateRowID: nil,
            contentPath: path,
            message: message,
            details: nil
        )
    }
}

extension TemplateViolation: CustomStringConvertible {
    public var description: String {
        var result = "[\(severity.rawValue.uppercased())]"
        if let path = contentPath {
            result += " at \(path)"
        }
        if let rowID = templateRowID {
            result += " (row \(rowID))"
        }
        result += ": \(message)"
        if let details = details {
            result += " - \(details)"
        }
        return result
    }
}

// MARK: - Template Validation Result

/// Result of validating content against a template
public struct TemplateValidationResult: Sendable {
    /// The template that was validated against
    public let templateIdentifier: TemplateIdentifier
    
    /// All violations found during validation
    public let violations: [TemplateViolation]
    
    /// Whether the content is compliant (no errors)
    public var isCompliant: Bool {
        !violations.contains { $0.severity == .error }
    }
    
    /// Whether the content is fully compliant (no errors or warnings)
    public var isFullyCompliant: Bool {
        violations.isEmpty
    }
    
    /// All errors
    public var errors: [TemplateViolation] {
        violations.filter { $0.severity == .error }
    }
    
    /// All warnings
    public var warnings: [TemplateViolation] {
        violations.filter { $0.severity == .warning }
    }
    
    /// Number of errors
    public var errorCount: Int {
        errors.count
    }
    
    /// Number of warnings
    public var warningCount: Int {
        warnings.count
    }
    
    /// Creates a validation result
    public init(templateIdentifier: TemplateIdentifier, violations: [TemplateViolation]) {
        self.templateIdentifier = templateIdentifier
        self.violations = violations
    }
    
    /// Creates a successful validation result
    public static func success(for template: TemplateIdentifier) -> TemplateValidationResult {
        TemplateValidationResult(templateIdentifier: template, violations: [])
    }
}

// MARK: - Validation Mode

/// Mode for template validation
public enum TemplateValidationMode: Sendable, Equatable {
    /// Strict validation - all constraints must be satisfied
    case strict
    
    /// Lenient validation - only mandatory items are required
    case lenient
    
    /// Check only - report all issues but don't fail on warnings
    case checkOnly
}

// MARK: - Template Validator

/// Validates SR content against template definitions
///
/// Example:
/// ```swift
/// let validator = TemplateValidator()
/// let result = try validator.validate(document, against: .measurementReport)
/// if result.isCompliant {
///     print("Document is compliant with TID 1500")
/// } else {
///     for error in result.errors {
///         print(error)
///     }
/// }
/// ```
public struct TemplateValidator: Sendable {
    /// The validation mode
    public let mode: TemplateValidationMode
    
    /// Maximum depth to validate
    public let maxDepth: Int
    
    /// Creates a template validator
    /// - Parameters:
    ///   - mode: The validation mode (default: strict)
    ///   - maxDepth: Maximum nesting depth to validate (default: 50)
    public init(mode: TemplateValidationMode = .strict, maxDepth: Int = 50) {
        self.mode = mode
        self.maxDepth = maxDepth
    }
    
    /// Validates content items against a template
    /// - Parameters:
    ///   - contentItems: The content items to validate
    ///   - templateIdentifier: The template to validate against
    /// - Returns: The validation result
    public func validate(
        _ contentItems: [AnyContentItem],
        against templateIdentifier: TemplateIdentifier
    ) -> TemplateValidationResult {
        guard let templateType = TemplateRegistry.shared.template(for: templateIdentifier) else {
            return TemplateValidationResult(
                templateIdentifier: templateIdentifier,
                violations: [
                    TemplateViolation(
                        severity: .error,
                        message: "Unknown template: \(templateIdentifier)",
                        details: nil
                    )
                ]
            )
        }
        
        var violations: [TemplateViolation] = []
        validateAgainstTemplate(
            contentItems: contentItems,
            template: templateType,
            path: "/",
            depth: 0,
            violations: &violations
        )
        
        return TemplateValidationResult(
            templateIdentifier: templateIdentifier,
            violations: violations
        )
    }
    
    /// Validates a single content item against a template
    /// - Parameters:
    ///   - contentItem: The content item to validate
    ///   - templateIdentifier: The template to validate against
    /// - Returns: The validation result
    public func validate(
        _ contentItem: AnyContentItem,
        against templateIdentifier: TemplateIdentifier
    ) -> TemplateValidationResult {
        validate([contentItem], against: templateIdentifier)
    }
    
    // MARK: - Private Validation Methods
    
    private func validateAgainstTemplate(
        contentItems: [AnyContentItem],
        template: any SRTemplate.Type,
        path: String,
        depth: Int,
        violations: inout [TemplateViolation]
    ) {
        guard depth <= maxDepth else {
            violations.append(TemplateViolation(
                severity: .warning,
                contentPath: path,
                message: "Maximum validation depth exceeded",
                details: nil
            ))
            return
        }
        
        let rows = template.rows
        
        // Validate each template row
        for row in rows {
            validateRow(
                row: row,
                contentItems: contentItems,
                path: path,
                depth: depth,
                violations: &violations
            )
        }
        
        // In strict mode, check for unexpected content items
        if mode == .strict {
            checkForUnexpectedContent(
                contentItems: contentItems,
                rows: rows,
                path: path,
                violations: &violations
            )
        }
    }
    
    private func validateRow(
        row: TemplateRow,
        contentItems: [AnyContentItem],
        path: String,
        depth: Int,
        violations: inout [TemplateViolation]
    ) {
        // Find matching content items for this row
        let matchingItems = findMatchingItems(for: row, in: contentItems)
        let count = matchingItems.count
        
        // Check cardinality
        if !row.cardinality.isSatisfied(by: count) {
            // Check if this is a conditional row that doesn't apply
            if shouldSkipRow(row, in: contentItems) {
                return
            }
            
            // Only report error for mandatory items or if mode is strict
            if row.requirementLevel.isMandatory || mode == .strict {
                let conceptName = extractExpectedConcept(from: row.conceptName)
                
                if count < row.cardinality.minimum {
                    violations.append(.missingRequired(
                        rowID: row.rowID,
                        conceptName: conceptName,
                        path: path
                    ))
                } else if let max = row.cardinality.maximum, count > max {
                    violations.append(.cardinalityViolation(
                        rowID: row.rowID,
                        expected: row.cardinality,
                        actual: count,
                        conceptName: conceptName,
                        path: path
                    ))
                }
            }
        }
        
        // Validate each matching item
        for (index, item) in matchingItems.enumerated() {
            let itemPath = "\(path)/\(item.conceptName?.codeMeaning ?? item.valueType.rawValue)[\(index)]"
            
            // Validate value type
            if item.valueType != row.valueType {
                violations.append(.valueTypeMismatch(
                    rowID: row.rowID,
                    expected: row.valueType,
                    actual: item.valueType,
                    path: itemPath
                ))
            }
            
            // Validate relationship type
            if item.relationshipType != row.relationshipType {
                violations.append(.relationshipMismatch(
                    rowID: row.rowID,
                    expected: row.relationshipType,
                    actual: item.relationshipType,
                    path: itemPath
                ))
            }
            
            // Validate concept name if constrained
            validateConceptName(
                row: row,
                item: item,
                path: itemPath,
                violations: &violations
            )
            
            // Validate value constraint
            validateValueConstraint(
                row: row,
                item: item,
                path: itemPath,
                violations: &violations
            )
            
            // Recursively validate children if this is a container
            if let children = item.children, !children.isEmpty {
                // If there's an included template, validate against it
                if let includedTemplate = row.includedTemplate,
                   let includedTemplateType = TemplateRegistry.shared.template(for: includedTemplate) {
                    validateAgainstTemplate(
                        contentItems: children,
                        template: includedTemplateType,
                        path: itemPath,
                        depth: depth + 1,
                        violations: &violations
                    )
                }
            }
        }
    }
    
    private func findMatchingItems(for row: TemplateRow, in contentItems: [AnyContentItem]) -> [AnyContentItem] {
        contentItems.filter { item in
            // Match by value type
            if item.valueType != row.valueType {
                return false
            }
            
            // Match by relationship type if specified
            if let itemRelationship = item.relationshipType,
               itemRelationship != row.relationshipType {
                return false
            }
            
            // Match by concept name if constrained
            switch row.conceptName {
            case .any:
                return true
            case .exact(let concept):
                return item.conceptName == concept
            case .oneOf(let concepts):
                guard let itemConcept = item.conceptName else { return false }
                return concepts.contains(itemConcept)
            case .fromContextGroup, .baselineCID:
                // Would need context group validation - for now, accept
                return true
            }
        }
    }
    
    private func shouldSkipRow(_ row: TemplateRow, in contentItems: [AnyContentItem]) -> Bool {
        switch row.condition {
        case .none:
            return false
        case .ifPresent(let concept):
            // Skip if the required concept is not present
            return !contentItems.contains { $0.conceptName == concept }
        case .ifAbsent(let concept):
            // Skip if the concept is present
            return contentItems.contains { $0.conceptName == concept }
        case .ifEquals(let concept, _):
            // Skip if the concept doesn't have the required value
            let hasMatch = contentItems.contains { item in
                guard item.conceptName == concept else { return false }
                // For CODE items, check the value
                // This is a simplified check - real implementation would compare values
                return true
            }
            return !hasMatch
        case .anyOf(let conditions):
            // Skip if none of the conditions are met
            return !conditions.contains { !shouldSkipCondition($0, in: contentItems) }
        case .allOf(let conditions):
            // Skip if any condition is not met
            return conditions.contains { shouldSkipCondition($0, in: contentItems) }
        case .custom:
            // Custom conditions can't be evaluated automatically
            return false
        }
    }
    
    private func shouldSkipCondition(_ condition: TemplateRowCondition, in contentItems: [AnyContentItem]) -> Bool {
        switch condition {
        case .none:
            return false
        case .ifPresent(let concept):
            return !contentItems.contains { $0.conceptName == concept }
        case .ifAbsent(let concept):
            return contentItems.contains { $0.conceptName == concept }
        case .ifEquals:
            return false // Simplified
        case .anyOf(let conditions):
            return !conditions.contains { !shouldSkipCondition($0, in: contentItems) }
        case .allOf(let conditions):
            return conditions.contains { shouldSkipCondition($0, in: contentItems) }
        case .custom:
            return false
        }
    }
    
    private func validateConceptName(
        row: TemplateRow,
        item: AnyContentItem,
        path: String,
        violations: inout [TemplateViolation]
    ) {
        switch row.conceptName {
        case .any:
            break // Any concept is allowed
        case .exact(let expectedConcept):
            if item.conceptName != expectedConcept {
                violations.append(.invalidConcept(
                    rowID: row.rowID,
                    expected: row.conceptName,
                    actual: item.conceptName,
                    path: path
                ))
            }
        case .oneOf(let validConcepts):
            if let concept = item.conceptName, !validConcepts.contains(concept) {
                violations.append(.invalidConcept(
                    rowID: row.rowID,
                    expected: row.conceptName,
                    actual: item.conceptName,
                    path: path
                ))
            }
        case .fromContextGroup, .baselineCID:
            // Context group validation would require the context group registry
            // For now, we skip this validation
            break
        }
    }
    
    private func validateValueConstraint(
        row: TemplateRow,
        item: AnyContentItem,
        path: String,
        violations: inout [TemplateViolation]
    ) {
        switch row.valueConstraint {
        case .any:
            break // Any value is allowed
        case .exactCode, .oneOfCodes, .fromContextGroup:
            // Value validation for coded items
            // This would require accessing the actual value of the content item
            break
        case .numericUnits:
            // Unit validation for numeric items
            // This would require accessing the units of the numeric value
            break
        case .textPattern, .custom:
            // Pattern and custom validation
            break
        }
    }
    
    private func extractExpectedConcept(from constraint: ConceptNameConstraint) -> CodedConcept? {
        switch constraint {
        case .any:
            return nil
        case .exact(let concept):
            return concept
        case .oneOf(let concepts):
            return concepts.first
        case .fromContextGroup:
            return nil
        case .baselineCID(_, let baseline):
            return baseline
        }
    }
    
    private func checkForUnexpectedContent(
        contentItems: [AnyContentItem],
        rows: [TemplateRow],
        path: String,
        violations: inout [TemplateViolation]
    ) {
        for item in contentItems {
            let isExpected = rows.contains { row in
                // Check if this item matches any row
                if item.valueType != row.valueType {
                    return false
                }
                switch row.conceptName {
                case .any:
                    return true
                case .exact(let concept):
                    return item.conceptName == concept
                case .oneOf(let concepts):
                    guard let itemConcept = item.conceptName else { return false }
                    return concepts.contains(itemConcept)
                case .fromContextGroup, .baselineCID:
                    return true
                }
            }
            
            if !isExpected {
                violations.append(.unexpectedContent(
                    path: path,
                    message: "Unexpected content item: \(item.conceptName?.codeMeaning ?? item.valueType.rawValue)"
                ))
            }
        }
    }
}

// MARK: - Template Detection

/// Detects which template(s) might apply to a set of content items
public struct TemplateDetector: Sendable {
    /// Creates a template detector
    public init() {}
    
    /// Detects potential templates that match the given content
    /// - Parameter contentItems: The content items to analyze
    /// - Returns: Array of potential template identifiers with confidence scores
    public func detectTemplates(_ contentItems: [AnyContentItem]) -> [(template: TemplateIdentifier, confidence: Double)] {
        var results: [(template: TemplateIdentifier, confidence: Double)] = []
        
        for templateType in TemplateRegistry.shared.registeredTemplates {
            if let template = TemplateRegistry.shared.template(for: templateType) {
                let confidence = calculateConfidence(contentItems: contentItems, template: template)
                if confidence > 0.3 { // Threshold for reporting
                    results.append((templateType, confidence))
                }
            }
        }
        
        // Sort by confidence, descending
        return results.sorted { $0.confidence > $1.confidence }
    }
    
    /// Detects the most likely template for the given content
    /// - Parameter contentItems: The content items to analyze
    /// - Returns: The most likely template identifier, or nil if none match
    public func detectTemplate(_ contentItems: [AnyContentItem]) -> TemplateIdentifier? {
        let results = detectTemplates(contentItems)
        return results.first?.template
    }
    
    private func calculateConfidence(contentItems: [AnyContentItem], template: any SRTemplate.Type) -> Double {
        let rows = template.rows
        
        // Count how many mandatory rows have matching content
        var mandatoryMatched = 0
        var mandatoryTotal = 0
        var optionalMatched = 0
        var optionalTotal = 0
        
        for row in rows {
            let hasMatch = contentItems.contains { item in
                if item.valueType != row.valueType {
                    return false
                }
                switch row.conceptName {
                case .any:
                    return true
                case .exact(let concept):
                    return item.conceptName == concept
                case .oneOf(let concepts):
                    guard let itemConcept = item.conceptName else { return false }
                    return concepts.contains(itemConcept)
                case .fromContextGroup, .baselineCID:
                    return true
                }
            }
            
            if row.requirementLevel.isMandatory {
                mandatoryTotal += 1
                if hasMatch {
                    mandatoryMatched += 1
                }
            } else {
                optionalTotal += 1
                if hasMatch {
                    optionalMatched += 1
                }
            }
        }
        
        // Calculate confidence score
        var confidence = 0.0
        if mandatoryTotal > 0 {
            confidence = Double(mandatoryMatched) / Double(mandatoryTotal) * 0.7
        } else {
            confidence = 0.5 // No mandatory fields means moderate base confidence
        }
        
        if optionalTotal > 0 {
            confidence += Double(optionalMatched) / Double(optionalTotal) * 0.3
        }
        
        return confidence
    }
}
