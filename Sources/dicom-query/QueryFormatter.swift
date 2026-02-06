import Foundation
import DICOMCore
import DICOMNetwork

/// Formats query results in various output formats
struct QueryFormatter {
    let format: OutputFormat
    let level: QueryLevel
    
    func format(results: [GenericQueryResult]) -> String {
        switch format {
        case .table:
            return formatTable(results)
        case .json:
            return formatJSON(results)
        case .csv:
            return formatCSV(results)
        case .compact:
            return formatCompact(results)
        }
    }
    
    // MARK: - Table Format
    
    private func formatTable(_ results: [GenericQueryResult]) -> String {
        guard !results.isEmpty else {
            return "No results found.\n"
        }
        
        switch level {
        case .patient:
            return formatPatientTable(results)
        case .study:
            return formatStudyTable(results)
        case .series:
            return formatSeriesTable(results)
        case .image:
            return formatInstanceTable(results)
        }
    }
    
    private func formatPatientTable(_ results: [GenericQueryResult]) -> String {
        var output = ""
        
        // Header
        output += String(repeating: "─", count: 100) + "\n"
        output += padRight("Patient Name", 30) + " "
        output += padRight("Patient ID", 15) + " "
        output += padRight("Birth Date", 12) + " "
        output += padRight("Sex", 5) + " "
        output += padRight("Studies", 8) + "\n"
        output += String(repeating: "─", count: 100) + "\n"
        
        // Rows
        for result in results {
            let patient = result.toPatientResult()
            output += padRight(patient.patientName ?? "", 30) + " "
            output += padRight(patient.patientID ?? "", 15) + " "
            output += padRight(formatDate(patient.patientBirthDate), 12) + " "
            output += padRight(patient.patientSex ?? "", 5) + " "
            output += padRight(patient.numberOfPatientRelatedStudies.map(String.init) ?? "", 8) + "\n"
        }
        
        output += String(repeating: "─", count: 100) + "\n"
        output += "Total: \(results.count) patient(s)\n"
        
        return output
    }
    
    private func formatStudyTable(_ results: [GenericQueryResult]) -> String {
        var output = ""
        
        // Header
        output += String(repeating: "─", count: 120) + "\n"
        output += padRight("Patient Name", 25) + " "
        output += padRight("Patient ID", 12) + " "
        output += padRight("Date", 12) + " "
        output += padRight("Description", 30) + " "
        output += padRight("Modalities", 12) + " "
        output += padRight("Series", 8) + "\n"
        output += String(repeating: "─", count: 120) + "\n"
        
        // Rows
        for result in results {
            let study = result.toStudyResult()
            output += padRight(study.patientName ?? "", 25) + " "
            output += padRight(study.patientID ?? "", 12) + " "
            output += padRight(formatDate(study.studyDate), 12) + " "
            output += padRight(study.studyDescription ?? "", 30) + " "
            output += padRight(study.modalitiesInStudy ?? "", 12) + " "
            output += padRight(study.numberOfStudyRelatedSeries.map(String.init) ?? "", 8) + "\n"
        }
        
        output += String(repeating: "─", count: 120) + "\n"
        output += "Total: \(results.count) study(ies)\n"
        
        return output
    }
    
    private func formatSeriesTable(_ results: [GenericQueryResult]) -> String {
        var output = ""
        
        // Header
        output += String(repeating: "─", count: 100) + "\n"
        output += padRight("Series Number", 15) + " "
        output += padRight("Modality", 10) + " "
        output += padRight("Description", 40) + " "
        output += padRight("Date", 12) + " "
        output += padRight("Instances", 10) + "\n"
        output += String(repeating: "─", count: 100) + "\n"
        
        // Rows
        for result in results {
            let series = result.toSeriesResult()
            output += padRight(series.seriesNumber.map(String.init) ?? "", 15) + " "
            output += padRight(series.modality ?? "", 10) + " "
            output += padRight(series.seriesDescription ?? "", 40) + " "
            output += padRight(formatDate(series.seriesDate), 12) + " "
            output += padRight(series.numberOfSeriesRelatedInstances.map(String.init) ?? "", 10) + "\n"
        }
        
        output += String(repeating: "─", count: 100) + "\n"
        output += "Total: \(results.count) series\n"
        
        return output
    }
    
    private func formatInstanceTable(_ results: [GenericQueryResult]) -> String {
        var output = ""
        
        // Header
        output += String(repeating: "─", count: 100) + "\n"
        output += padRight("Instance Number", 17) + " "
        output += padRight("SOP Class", 30) + " "
        output += padRight("Dimensions", 15) + " "
        output += padRight("Frames", 8) + "\n"
        output += String(repeating: "─", count: 100) + "\n"
        
        // Rows
        for result in results {
            let instance = result.toInstanceResult()
            output += padRight(instance.instanceNumber.map(String.init) ?? "", 17) + " "
            output += padRight(shortenUID(instance.sopClassUID), 30) + " "
            
            let dimensions: String
            if let rows = instance.rows, let cols = instance.columns {
                dimensions = "\(cols)×\(rows)"
            } else {
                dimensions = ""
            }
            output += padRight(dimensions, 15) + " "
            output += padRight(instance.numberOfFrames.map(String.init) ?? "1", 8) + "\n"
        }
        
        output += String(repeating: "─", count: 100) + "\n"
        output += "Total: \(results.count) instance(s)\n"
        
        return output
    }
    
    // MARK: - JSON Format
    
    private func formatJSON(_ results: [GenericQueryResult]) -> String {
        var jsonArray: [[String: String]] = []
        
        for result in results {
            var jsonObject: [String: String] = [:]
            
            for (tag, data) in result.attributes {
                let key = tag.description
                
                // Try to decode as string
                if let string = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .ascii) {
                    let trimmed = string.trimmingCharacters(in: CharacterSet(charactersIn: " \0"))
                    if !trimmed.isEmpty {
                        jsonObject[key] = trimmed
                    }
                }
            }
            
            jsonArray.append(jsonObject)
        }
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        if let jsonData = try? encoder.encode(jsonArray),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            return jsonString + "\n"
        }
        
        return "[]\n"
    }
    
    // MARK: - CSV Format
    
    private func formatCSV(_ results: [GenericQueryResult]) -> String {
        guard !results.isEmpty else {
            return ""
        }
        
        var output = ""
        
        // Determine columns from first result
        let columns = results[0].attributes.keys.sorted { $0.description < $1.description }
        
        // Header row
        output += columns.map { escapeCSV($0.description) }.joined(separator: ",") + "\n"
        
        // Data rows
        for result in results {
            let row = columns.map { tag -> String in
                if let data = result.attributes[tag],
                   let string = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .ascii) {
                    return escapeCSV(string.trimmingCharacters(in: CharacterSet(charactersIn: " \0")))
                }
                return ""
            }
            output += row.joined(separator: ",") + "\n"
        }
        
        return output
    }
    
    // MARK: - Compact Format
    
    private func formatCompact(_ results: [GenericQueryResult]) -> String {
        var output = ""
        
        for result in results {
            var fields: [String] = []
            
            switch level {
            case .patient:
                let patient = result.toPatientResult()
                fields.append(patient.patientName ?? "")
                fields.append(patient.patientID ?? "")
                fields.append(patient.patientBirthDate ?? "")
            case .study:
                let study = result.toStudyResult()
                fields.append(study.patientName ?? "")
                fields.append(study.patientID ?? "")
                fields.append(study.studyDate ?? "")
                fields.append(study.studyDescription ?? "")
                fields.append(study.studyInstanceUID ?? "")
            case .series:
                let series = result.toSeriesResult()
                fields.append(series.seriesNumber.map(String.init) ?? "")
                fields.append(series.modality ?? "")
                fields.append(series.seriesDescription ?? "")
                fields.append(series.seriesInstanceUID ?? "")
            case .image:
                let instance = result.toInstanceResult()
                fields.append(instance.instanceNumber.map(String.init) ?? "")
                fields.append(instance.sopInstanceUID ?? "")
            }
            
            output += fields.joined(separator: " | ") + "\n"
        }
        
        return output
    }
    
    // MARK: - Utility Functions
    
    private func padRight(_ string: String, _ width: Int) -> String {
        let truncated = String(string.prefix(width))
        return truncated.padding(toLength: width, withPad: " ", startingAt: 0)
    }
    
    private func formatDate(_ dateString: String?) -> String {
        guard let dateString = dateString, dateString.count == 8 else {
            return dateString ?? ""
        }
        
        // Convert YYYYMMDD to YYYY-MM-DD
        let year = dateString.prefix(4)
        let month = dateString.dropFirst(4).prefix(2)
        let day = dateString.dropFirst(6)
        return "\(year)-\(month)-\(day)"
    }
    
    private func shortenUID(_ uid: String?) -> String {
        guard let uid = uid else { return "" }
        
        // Show last few components of UID for readability
        let components = uid.split(separator: ".")
        if components.count > 5 {
            return "..." + components.suffix(3).joined(separator: ".")
        }
        return uid
    }
    
    private func escapeCSV(_ string: String) -> String {
        if string.contains(",") || string.contains("\"") || string.contains("\n") {
            return "\"" + string.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return string
    }
}
