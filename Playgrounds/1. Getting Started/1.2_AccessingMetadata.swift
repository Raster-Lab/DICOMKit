// DICOMKit Sample Code: Accessing Metadata
//
// This example demonstrates how to:
// - Query DICOM tags by tag numbers
// - Parse common value representations
// - Access patient demographics
// - Navigate nested sequences
// - Work with dates, times, and person names

import DICOMKit
import Foundation

// MARK: - Example 1: Basic Tag Access

func example1_basicTagAccess() throws {
    let fileURL = URL(fileURLWithPath: "/path/to/your/file.dcm")
    let file = try DICOMFile.read(from: fileURL)
    
    // Access tags using the DataSet
    let dataSet = file.dataSet
    
    // Get string values
    if let patientName = dataSet.string(for: .patientName) {
        print("Patient Name: \(patientName)")
    }
    
    if let patientID = dataSet.string(for: .patientID) {
        print("Patient ID: \(patientID)")
    }
    
    if let studyDescription = dataSet.string(for: .studyDescription) {
        print("Study Description: \(studyDescription)")
    }
}

// MARK: - Example 2: Accessing Patient Demographics

func example2_patientDemographics() throws {
    let fileURL = URL(fileURLWithPath: "/path/to/your/file.dcm")
    let file = try DICOMFile.read(from: fileURL)
    let dataSet = file.dataSet
    
    // Person Name (with components)
    if let name = dataSet.personName(for: .patientName) {
        print("Patient Name:")
        print("  Family Name: \(name.familyName ?? "")")
        print("  Given Name: \(name.givenName ?? "")")
        print("  Middle Name: \(name.middleName ?? "")")
    }
    
    // Patient ID
    if let patientID = dataSet.string(for: .patientID) {
        print("Patient ID: \(patientID)")
    }
    
    // Patient Birth Date
    if let birthDate = dataSet.date(for: .patientBirthDate) {
        print("Birth Date: \(birthDate.description)")
        // Convert to Foundation Date if needed
        if let foundationDate = birthDate.date {
            print("  As Date: \(foundationDate)")
        }
    }
    
    // Patient Age
    if let age = dataSet.age(for: .patientAge) {
        print("Patient Age: \(age.description)")
    }
    
    // Patient Sex
    if let sex = dataSet.string(for: .patientSex) {
        print("Patient Sex: \(sex)")
    }
}

// MARK: - Example 3: Accessing Study and Series Information

func example3_studySeriesInfo() throws {
    let fileURL = URL(fileURLWithPath: "/path/to/your/file.dcm")
    let file = try DICOMFile.read(from: fileURL)
    let dataSet = file.dataSet
    
    // Study Information
    print("=== Study Information ===")
    if let studyDate = dataSet.date(for: .studyDate) {
        print("Study Date: \(studyDate.description)")
    }
    if let studyTime = dataSet.time(for: .studyTime) {
        print("Study Time: \(studyTime.description)")
    }
    if let studyDescription = dataSet.string(for: .studyDescription) {
        print("Description: \(studyDescription)")
    }
    if let studyUID = dataSet.uid(for: .studyInstanceUID) {
        print("Study UID: \(studyUID.uid)")
    }
    
    // Series Information
    print("\n=== Series Information ===")
    if let seriesNumber = dataSet.int32(for: .seriesNumber) {
        print("Series Number: \(seriesNumber)")
    }
    if let seriesDescription = dataSet.string(for: .seriesDescription) {
        print("Description: \(seriesDescription)")
    }
    if let modality = dataSet.string(for: .modality) {
        print("Modality: \(modality)")
    }
    if let seriesUID = dataSet.uid(for: .seriesInstanceUID) {
        print("Series UID: \(seriesUID.uid)")
    }
}

// MARK: - Example 4: Working with Dates and Times

func example4_datesAndTimes() throws {
    let fileURL = URL(fileURLWithPath: "/path/to/your/file.dcm")
    let file = try DICOMFile.read(from: fileURL)
    let dataSet = file.dataSet
    
    // Date (DA VR - YYYYMMDD)
    if let studyDate = dataSet.date(for: .studyDate) {
        print("Study Date: \(studyDate.description)") // e.g., "20240101"
        if let date = studyDate.date {
            print("  As Swift Date: \(date)")
        }
    }
    
    // Time (TM VR - HHMMSS.FFFFFF)
    if let studyTime = dataSet.time(for: .studyTime) {
        print("Study Time: \(studyTime.description)") // e.g., "143022.123"
        if let timeComponents = studyTime.timeComponents {
            print("  Hour: \(timeComponents.hour ?? 0)")
            print("  Minute: \(timeComponents.minute ?? 0)")
            print("  Second: \(timeComponents.second ?? 0)")
        }
    }
    
    // DateTime (DT VR - YYYYMMDDHHMMSS.FFFFFF)
    if let acquisitionDateTime = dataSet.dateTime(for: .acquisitionDateTime) {
        print("Acquisition DateTime: \(acquisitionDateTime.description)")
        if let date = acquisitionDateTime.date {
            print("  As Swift Date: \(date)")
        }
    }
    
    // Convert to Foundation Date for easier manipulation
    if let foundationDate = dataSet.foundationDate(for: .studyDate) {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        print("Formatted: \(formatter.string(from: foundationDate))")
    }
}

// MARK: - Example 5: Accessing Numeric Values

func example5_numericValues() throws {
    let fileURL = URL(fileURLWithPath: "/path/to/your/file.dcm")
    let file = try DICOMFile.read(from: fileURL)
    let dataSet = file.dataSet
    
    // Integer values
    if let rows = dataSet.uint16(for: .rows) {
        print("Rows: \(rows)")
    }
    if let columns = dataSet.uint16(for: .columns) {
        print("Columns: \(columns)")
    }
    if let bitsAllocated = dataSet.uint16(for: .bitsAllocated) {
        print("Bits Allocated: \(bitsAllocated)")
    }
    
    // Integer String (IS VR - stored as string but represents integer)
    if let instanceNumber = dataSet.integerString(for: .instanceNumber) {
        print("Instance Number: \(instanceNumber.value)")
    }
    
    // Decimal String (DS VR - stored as string but represents decimal)
    if let sliceThickness = dataSet.decimalString(for: .sliceThickness) {
        print("Slice Thickness: \(sliceThickness.value) mm")
    }
    
    // Floating point values
    if let windowCenter = dataSet.float64(for: .windowCenter) {
        print("Window Center: \(windowCenter)")
    }
    if let windowWidth = dataSet.float64(for: .windowWidth) {
        print("Window Width: \(windowWidth)")
    }
}

// MARK: - Example 6: Multiple Values (VM > 1)

func example6_multipleValues() throws {
    let fileURL = URL(fileURLWithPath: "/path/to/your/file.dcm")
    let file = try DICOMFile.read(from: fileURL)
    let dataSet = file.dataSet
    
    // Many DICOM tags can have multiple values (Value Multiplicity > 1)
    
    // Pixel Spacing (typically 2 values: row spacing, column spacing)
    if let pixelSpacing = dataSet.strings(for: .pixelSpacing) {
        print("Pixel Spacing: \(pixelSpacing)")
        if pixelSpacing.count >= 2 {
            print("  Row Spacing: \(pixelSpacing[0]) mm")
            print("  Column Spacing: \(pixelSpacing[1]) mm")
        }
    }
    
    // Image Position (Patient) - 3 values (x, y, z)
    if let imagePosition = dataSet.strings(for: .imagePositionPatient) {
        if imagePosition.count >= 3 {
            print("Image Position: (\(imagePosition[0]), \(imagePosition[1]), \(imagePosition[2]))")
        }
    }
    
    // Window Center and Width can have multiple values for multi-window display
    if let windowCenters = dataSet.strings(for: .windowCenter) {
        print("Window Centers: \(windowCenters)")
    }
}

// MARK: - Example 7: Navigating Sequences

func example7_sequences() throws {
    let fileURL = URL(fileURLWithPath: "/path/to/your/file.dcm")
    let file = try DICOMFile.read(from: fileURL)
    let dataSet = file.dataSet
    
    // Sequences are nested data sets (SQ VR)
    // Each sequence contains one or more items
    
    // Example: Referenced Series Sequence
    if let element = dataSet[.referencedSeriesSequence],
       case .sequence(let items) = element.value {
        print("Referenced Series Sequence has \(items.count) items")
        
        for (index, item) in items.enumerated() {
            print("\nItem \(index + 1):")
            
            // Access tags within the sequence item
            if let seriesUID = item.uid(for: .seriesInstanceUID) {
                print("  Series UID: \(seriesUID.uid)")
            }
            
            // Sequences can be nested
            if let referencedImages = item[.referencedImageSequence],
               case .sequence(let imageItems) = referencedImages.value {
                print("  Referenced Images: \(imageItems.count)")
                
                for imageItem in imageItems {
                    if let sopInstanceUID = imageItem.uid(for: .referencedSOPInstanceUID) {
                        print("    Image: \(sopInstanceUID.uid)")
                    }
                }
            }
        }
    }
}

// MARK: - Example 8: Iterating All Tags

func example8_allTags() throws {
    let fileURL = URL(fileURLWithPath: "/path/to/your/file.dcm")
    let file = try DICOMFile.read(from: fileURL)
    let dataSet = file.dataSet
    
    // Iterate over all elements in the data set
    print("=== All DICOM Tags ===")
    
    for element in dataSet.elements {
        let tag = element.tag
        let tagString = String(format: "(%04X,%04X)", tag.group, tag.element)
        
        // Get tag name from dictionary (if known)
        let tagName = tag.name ?? "Unknown"
        
        // Display value (truncate if too long)
        var valueString = "\(element.value)"
        if valueString.count > 80 {
            valueString = String(valueString.prefix(77)) + "..."
        }
        
        print("\(tagString) \(tagName): \(valueString)")
    }
}

// MARK: - Example 9: Checking for Tag Existence

func example9_checkingTags() throws {
    let fileURL = URL(fileURLWithPath: "/path/to/your/file.dcm")
    let file = try DICOMFile.read(from: fileURL)
    let dataSet = file.dataSet
    
    // Check if a tag exists before accessing
    if dataSet[.pixelData] != nil {
        print("✅ File contains pixel data")
    } else {
        print("❌ No pixel data (possibly a structured report or other non-image IOD)")
    }
    
    // Use optional binding for safe access
    if let modality = dataSet.string(for: .modality) {
        print("Modality: \(modality)")
        
        // Conditional logic based on modality
        switch modality {
        case "CT":
            print("This is a CT scan")
            if let kvp = dataSet.decimalString(for: .kvp) {
                print("  KVP: \(kvp.value)")
            }
        case "MR":
            print("This is an MR scan")
            if let magneticFieldStrength = dataSet.decimalString(for: .magneticFieldStrength) {
                print("  Field Strength: \(magneticFieldStrength.value) T")
            }
        case "CR", "DX":
            print("This is an X-ray")
        default:
            print("Other modality: \(modality)")
        }
    }
}

// MARK: - Running the Examples

// Uncomment to run individual examples:
// try? example1_basicTagAccess()
// try? example2_patientDemographics()
// try? example3_studySeriesInfo()
// try? example4_datesAndTimes()
// try? example5_numericValues()
// try? example6_multipleValues()
// try? example7_sequences()
// try? example8_allTags()
// try? example9_checkingTags()

// MARK: - Quick Reference

/*
 DICOMKit Metadata Access Methods:
 
 String Values:
 • .string(for: tag)          → String?
 • .strings(for: tag)         → [String]?      (for VM > 1)
 
 Numeric Values:
 • .uint16(for: tag)          → UInt16?
 • .uint32(for: tag)          → UInt32?
 • .int16(for: tag)           → Int16?
 • .int32(for: tag)           → Int32?
 • .float32(for: tag)         → Float?
 • .float64(for: tag)         → Double?
 
 Date/Time Values:
 • .date(for: tag)            → DICOMDate?
 • .time(for: tag)            → DICOMTime?
 • .dateTime(for: tag)        → DICOMDateTime?
 • .foundationDate(for: tag)  → Date?
 
 Specialized Types:
 • .personName(for: tag)      → DICOMPersonName?
 • .personNames(for: tag)     → [DICOMPersonName]?
 • .uid(for: tag)             → DICOMUniqueIdentifier?
 • .age(for: tag)             → DICOMAgeString?
 • .decimalString(for: tag)   → DICOMDecimalString?
 • .integerString(for: tag)   → DICOMIntegerString?
 • .applicationEntity(for:)   → DICOMApplicationEntity?
 
 Direct Access:
 • dataSet[tag]               → DataElement?
 • dataSet.elements           → [DataElement]
 
 Sequence Navigation:
 • If element.value is .sequence(let items)
 • Each item is a DataSet
 • Access nested tags: item.string(for: tag)
 
 Common Tags (use Tag.* constants):
 • .patientName, .patientID, .patientBirthDate, .patientSex, .patientAge
 • .studyDate, .studyTime, .studyDescription, .studyInstanceUID
 • .seriesNumber, .seriesDescription, .seriesInstanceUID, .modality
 • .instanceNumber, .sopInstanceUID, .sopClassUID
 • .rows, .columns, .bitsAllocated, .pixelData
 • .windowCenter, .windowWidth, .pixelSpacing
 
 Tips:
 
 1. Always use optional binding (if let) for tag access
 2. Check tag existence with dataSet[tag] != nil
 3. Use appropriate type for each tag (string, numeric, date, etc.)
 4. Tags with VM > 1 return arrays
 5. Sequences contain nested DataSets
 6. Person names have components (family, given, middle)
 7. Dates and times have structured components
 */
