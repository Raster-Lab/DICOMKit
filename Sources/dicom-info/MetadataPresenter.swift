import Foundation
import DICOMKit
import DICOMCore
import DICOMDictionary

/// Presents DICOM metadata in various output formats
struct MetadataPresenter {
    let file: DICOMFile
    let filterTags: [String]
    let includePrivate: Bool
    let showStats: Bool
    
    func render(format: OutputFormat) throws -> String {
        switch format {
        case .text:
            return renderPlainText()
        case .json:
            return try renderJSON()
        case .csv:
            return renderCSV()
        }
    }
    
    // MARK: - Plain Text Output
    
    private func renderPlainText() -> String {
        var output = ""
        
        if showStats {
            output += renderFileStatistics()
            output += "\n"
        }
        
        output += "=== File Meta Information ===\n"
        output += renderDataSetAsText(file.fileMetaInformation)
        output += "\n=== Main Data Set ===\n"
        output += renderDataSetAsText(file.dataSet)
        
        return output
    }
    
    private func renderFileStatistics() -> String {
        var stats = "=== File Statistics ===\n"
        
        if let transferSyntax = file.fileMetaInformation.string(for: .transferSyntaxUID) {
            stats += "Transfer Syntax: \(transferSyntax)\n"
        }
        
        if let sopClass = file.dataSet.string(for: .sopClassUID) {
            stats += "SOP Class: \(sopClass)\n"
        }
        
        if let modality = file.dataSet.string(for: .modality) {
            stats += "Modality: \(modality)\n"
        }
        
        return stats
    }
    
    private func renderDataSetAsText(_ dataSet: DataSet) -> String {
        var lines: [String] = []
        let allTags = dataSet.tags
        
        for tag in allTags {
            guard let element = dataSet[tag] else { continue }
            
            // Skip private tags unless requested
            if tag.isPrivate && !includePrivate {
                continue
            }
            
            // Filter by tag name if specified
            if !filterTags.isEmpty {
                let tagName = DataElementDictionary.lookup(tag: tag)?.name ?? ""
                let matches = filterTags.contains { filter in
                    tagName.localizedCaseInsensitiveContains(filter) ||
                    tag.description.localizedCaseInsensitiveContains(filter)
                }
                guard matches else { continue }
            }
            
            let valueStr = formatElementValue(element)
            let tagName = DataElementDictionary.lookup(tag: tag)?.name ?? "Unknown"
            let line = String(format: "%@ %-40s VR=%@ %s",
                             tag.description,
                             tagName,
                             element.vr.rawValue,
                             valueStr)
            lines.append(line)
        }
        
        return lines.joined(separator: "\n") + "\n"
    }
    
    // MARK: - JSON Output
    
    private func renderJSON() throws -> String {
        var jsonDict: [String: Any] = [:]
        
        if showStats {
            jsonDict["statistics"] = buildStatisticsDict()
        }
        
        jsonDict["fileMetaInformation"] = buildDataSetDict(file.fileMetaInformation)
        jsonDict["dataSet"] = buildDataSetDict(file.dataSet)
        
        let jsonData = try JSONSerialization.data(withJSONObject: jsonDict, options: [.prettyPrinted, .sortedKeys])
        return String(data: jsonData, encoding: .utf8) ?? ""
    }
    
    private func buildStatisticsDict() -> [String: String] {
        var stats: [String: String] = [:]
        
        if let transferSyntax = file.fileMetaInformation.string(for: .transferSyntaxUID) {
            stats["transferSyntax"] = transferSyntax
        }
        
        if let sopClass = file.dataSet.string(for: .sopClassUID) {
            stats["sopClass"] = sopClass
        }
        
        if let modality = file.dataSet.string(for: .modality) {
            stats["modality"] = modality
        }
        
        return stats
    }
    
    private func buildDataSetDict(_ dataSet: DataSet) -> [[String: Any]] {
        var elements: [[String: Any]] = []
        let allTags = dataSet.tags
        
        for tag in allTags {
            guard let element = dataSet[tag] else { continue }
            
            if tag.isPrivate && !includePrivate {
                continue
            }
            
            if !filterTags.isEmpty {
                let tagName = DataElementDictionary.lookup(tag: tag)?.name ?? ""
                let matches = filterTags.contains { filter in
                    tagName.localizedCaseInsensitiveContains(filter) ||
                    tag.description.localizedCaseInsensitiveContains(filter)
                }
                guard matches else { continue }
            }
            
            var elementDict: [String: Any] = [
                "tag": tag.description,
                "name": DataElementDictionary.lookup(tag: tag)?.name ?? "Unknown",
                "vr": element.vr.rawValue
            ]
            
            if let stringValue = element.stringValue {
                elementDict["value"] = stringValue
            }
            
            elements.append(elementDict)
        }
        
        return elements
    }
    
    // MARK: - CSV Output
    
    private func renderCSV() -> String {
        var csv = "Tag,Name,VR,Value\n"
        
        let allElements = collectAllElements()
        
        for (tag, element) in allElements {
            let valueStr = formatElementValue(element).replacingOccurrences(of: "\"", with: "\"\"")
            let tagName = DataElementDictionary.lookup(tag: tag)?.name ?? "Unknown"
            let line = "\"\(tag.description)\",\"\(tagName)\",\"\(element.vr.rawValue)\",\"\(valueStr)\"\n"
            csv += line
        }
        
        return csv
    }
    
    // MARK: - Helper Methods
    
    private func collectAllElements() -> [(Tag, DataElement)] {
        var results: [(Tag, DataElement)] = []
        
        for tag in file.fileMetaInformation.tags {
            guard let element = file.fileMetaInformation[tag] else { continue }
            if shouldIncludeElement(tag: tag) {
                results.append((tag, element))
            }
        }
        
        for tag in file.dataSet.tags {
            guard let element = file.dataSet[tag] else { continue }
            if shouldIncludeElement(tag: tag) {
                results.append((tag, element))
            }
        }
        
        return results
    }
    
    private func shouldIncludeElement(tag: Tag) -> Bool {
        if tag.isPrivate && !includePrivate {
            return false
        }
        
        if !filterTags.isEmpty {
            let tagName = DataElementDictionary.lookup(tag: tag)?.name ?? ""
            return filterTags.contains { filter in
                tagName.localizedCaseInsensitiveContains(filter) ||
                tag.description.localizedCaseInsensitiveContains(filter)
            }
        }
        
        return true
    }
    
    private func formatElementValue(_ element: DataElement) -> String {
        if let stringValue = element.stringValue {
            if stringValue.count > 80 {
                return String(stringValue.prefix(77)) + "..."
            }
            return stringValue
        }
        
        let valueLength = element.length
        if valueLength > 1024 {
            let mb = Double(valueLength) / 1_048_576.0
            return String(format: "<Binary data: %.2f MB>", mb)
        } else if valueLength > 0 {
            return "<Binary data: \(valueLength) bytes>"
        }
        
        return ""
    }
}
