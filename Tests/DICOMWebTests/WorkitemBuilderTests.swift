import XCTest
@testable import DICOMWeb

/// Tests for WorkitemBuilder, Workitem.toDICOMJSON(), Workitem.parse(), and Workitem.validate()
final class WorkitemBuilderTests: XCTestCase {
    
    // MARK: - WorkitemBuilder Basic Creation
    
    func testBuilderBasicCreation() throws {
        let workitem = try WorkitemBuilder(workitemUID: "1.2.3.4.5")
            .build()
        
        XCTAssertEqual(workitem.workitemUID, "1.2.3.4.5")
        XCTAssertEqual(workitem.state, .scheduled)
        XCTAssertEqual(workitem.priority, .medium)
    }
    
    func testBuilderWithStateAndPriority() throws {
        let workitem = try WorkitemBuilder(workitemUID: "1.2.3.4.5")
            .setState(.scheduled)
            .setPriority(.high)
            .build()
        
        XCTAssertEqual(workitem.state, .scheduled)
        XCTAssertEqual(workitem.priority, .high)
    }
    
    // MARK: - WorkitemBuilder With All Properties
    
    func testBuilderWithAllProperties() throws {
        let startDate = Date(timeIntervalSince1970: 1700000000)
        let completionDate = Date(timeIntervalSince1970: 1700003600)
        let modDate = Date(timeIntervalSince1970: 1700001000)
        
        let performer = HumanPerformer(
            performerCode: CodedEntry(codeValue: "121081", codingSchemeDesignator: "DCM", codeMeaning: "Physician"),
            performerName: "Smith^Jane",
            performerOrganization: "City Hospital"
        )
        
        let inputRef = ReferencedInstance(
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            sopInstanceUID: "1.2.3.4.5.6.7",
            studyInstanceUID: "1.2.3.4",
            seriesInstanceUID: "1.2.3.4.5"
        )
        
        let workitemCode = CodedEntry(
            codeValue: "CT001",
            codingSchemeDesignator: "99LOCAL",
            codingSchemeVersion: "1.0",
            codeMeaning: "CT Scan Abdomen"
        )
        
        let workitem = try WorkitemBuilder(workitemUID: "1.2.3.4.5")
            .setState(.scheduled)
            .setPriority(.stat)
            .setPatientName("Doe^John")
            .setPatientID("PAT001")
            .setPatientBirthDate("19800115")
            .setPatientSex("M")
            .setScheduledStartDateTime(startDate)
            .setExpectedCompletionDateTime(completionDate)
            .setModificationDateTime(modDate)
            .setStudyInstanceUID("2.16.840.1.2.3")
            .setAccessionNumber("ACC123")
            .setReferringPhysicianName("Jones^Alice")
            .setRequestedProcedureID("RP001")
            .setScheduledProcedureStepID("SPS001")
            .setProcedureStepLabel("CT Abdomen")
            .setWorklistLabel("Radiology Worklist")
            .setComments("Urgent scan required")
            .setScheduledHumanPerformers([performer])
            .setScheduledWorkitemCode(workitemCode)
            .setInputInformation([inputRef])
            .setProgressInformation(ProgressInformation(progressPercentage: 0, progressDescription: "Queued"))
            .setAdmissionID("ADM001")
            .setIssuerOfAdmissionID("HOSP001")
            .build()
        
        XCTAssertEqual(workitem.workitemUID, "1.2.3.4.5")
        XCTAssertEqual(workitem.state, .scheduled)
        XCTAssertEqual(workitem.priority, .stat)
        XCTAssertEqual(workitem.patientName, "Doe^John")
        XCTAssertEqual(workitem.patientID, "PAT001")
        XCTAssertEqual(workitem.patientBirthDate, "19800115")
        XCTAssertEqual(workitem.patientSex, "M")
        XCTAssertEqual(workitem.scheduledStartDateTime, startDate)
        XCTAssertEqual(workitem.expectedCompletionDateTime, completionDate)
        XCTAssertEqual(workitem.modificationDateTime, modDate)
        XCTAssertEqual(workitem.studyInstanceUID, "2.16.840.1.2.3")
        XCTAssertEqual(workitem.accessionNumber, "ACC123")
        XCTAssertEqual(workitem.referringPhysicianName, "Jones^Alice")
        XCTAssertEqual(workitem.requestedProcedureID, "RP001")
        XCTAssertEqual(workitem.scheduledProcedureStepID, "SPS001")
        XCTAssertEqual(workitem.procedureStepLabel, "CT Abdomen")
        XCTAssertEqual(workitem.worklistLabel, "Radiology Worklist")
        XCTAssertEqual(workitem.comments, "Urgent scan required")
        XCTAssertEqual(workitem.scheduledHumanPerformers?.count, 1)
        XCTAssertEqual(workitem.scheduledHumanPerformers?.first?.performerName, "Smith^Jane")
        XCTAssertEqual(workitem.scheduledWorkitemCode?.codeValue, "CT001")
        XCTAssertEqual(workitem.inputInformation?.count, 1)
        XCTAssertEqual(workitem.progressInformation?.progressPercentage, 0)
        XCTAssertEqual(workitem.admissionID, "ADM001")
        XCTAssertEqual(workitem.issuerOfAdmissionID, "HOSP001")
    }
    
    // MARK: - WorkitemBuilder Validation
    
    func testBuilderValidationEmptyUID() {
        XCTAssertThrowsError(try WorkitemBuilder(workitemUID: "").build()) { error in
            if case UPSError.missingRequiredAttribute(let name) = error {
                XCTAssertEqual(name, "workitemUID")
            } else {
                XCTFail("Expected missingRequiredAttribute error, got \(error)")
            }
        }
    }
    
    func testBuilderValidationInProgressWithoutTransactionUID() {
        XCTAssertThrowsError(
            try WorkitemBuilder(workitemUID: "1.2.3")
                .setState(.inProgress)
                .build()
        ) { error in
            if case UPSError.invalidWorkitemData(let reason) = error {
                XCTAssertTrue(reason.contains("Transaction UID"))
            } else {
                XCTFail("Expected invalidWorkitemData error, got \(error)")
            }
        }
    }
    
    func testBuilderValidationInProgressWithTransactionUID() throws {
        let workitem = try WorkitemBuilder(workitemUID: "1.2.3")
            .setState(.inProgress)
            .setTransactionUID("9.8.7.6")
            .build()
        
        XCTAssertEqual(workitem.state, .inProgress)
        XCTAssertEqual(workitem.transactionUID, "9.8.7.6")
    }
    
    // MARK: - WorkitemBuilder Factory Methods
    
    func testScheduledProcedureFactory() throws {
        let startDate = Date()
        let workitem = try WorkitemBuilder.scheduledProcedure(
            workitemUID: "1.2.3.4.5",
            patientName: "Smith^John",
            patientID: "PAT001",
            procedureStepLabel: "CT Scan",
            priority: .high,
            scheduledStartDateTime: startDate
        ).build()
        
        XCTAssertEqual(workitem.workitemUID, "1.2.3.4.5")
        XCTAssertEqual(workitem.state, .scheduled)
        XCTAssertEqual(workitem.priority, .high)
        XCTAssertEqual(workitem.patientName, "Smith^John")
        XCTAssertEqual(workitem.patientID, "PAT001")
        XCTAssertEqual(workitem.procedureStepLabel, "CT Scan")
        XCTAssertEqual(workitem.scheduledStartDateTime, startDate)
    }
    
    func testSimpleTaskFactory() throws {
        let workitem = try WorkitemBuilder.simpleTask(
            workitemUID: "1.2.3.4.5",
            label: "Process Report",
            priority: .low
        ).build()
        
        XCTAssertEqual(workitem.workitemUID, "1.2.3.4.5")
        XCTAssertEqual(workitem.state, .scheduled)
        XCTAssertEqual(workitem.priority, .low)
        XCTAssertEqual(workitem.procedureStepLabel, "Process Report")
    }
    
    func testScheduledProcedureFactoryDefaultPriority() throws {
        let workitem = try WorkitemBuilder.scheduledProcedure(
            workitemUID: "1.2.3",
            patientName: "Doe^Jane",
            patientID: "PAT002",
            procedureStepLabel: "MRI Brain"
        ).build()
        
        XCTAssertEqual(workitem.priority, .medium)
    }
    
    // MARK: - WorkitemBuilder Add Methods
    
    func testAddScheduledHumanPerformer() throws {
        let performer1 = HumanPerformer(performerName: "Smith^Jane")
        let performer2 = HumanPerformer(performerName: "Doe^John")
        
        let workitem = try WorkitemBuilder(workitemUID: "1.2.3")
            .addScheduledHumanPerformer(performer1)
            .addScheduledHumanPerformer(performer2)
            .build()
        
        XCTAssertEqual(workitem.scheduledHumanPerformers?.count, 2)
        XCTAssertEqual(workitem.scheduledHumanPerformers?[0].performerName, "Smith^Jane")
        XCTAssertEqual(workitem.scheduledHumanPerformers?[1].performerName, "Doe^John")
    }
    
    func testAddInputInformation() throws {
        let ref1 = ReferencedInstance(sopClassUID: "1.2.3", sopInstanceUID: "4.5.6")
        let ref2 = ReferencedInstance(sopClassUID: "7.8.9", sopInstanceUID: "10.11.12")
        
        let workitem = try WorkitemBuilder(workitemUID: "1.2.3")
            .addInputInformation(ref1)
            .addInputInformation(ref2)
            .build()
        
        XCTAssertEqual(workitem.inputInformation?.count, 2)
    }
    
    // MARK: - Workitem.toDICOMJSON() Tests
    
    func testToDICOMJSONBasicFields() {
        let workitem = Workitem(workitemUID: "1.2.3.4.5", state: .scheduled, priority: .high)
        let json = workitem.toDICOMJSON()
        
        // SOP Instance UID
        let uidElement = json[UPSTag.sopInstanceUID] as? [String: Any]
        XCTAssertEqual(uidElement?["vr"] as? String, "UI")
        let uidValues = uidElement?["Value"] as? [String]
        XCTAssertEqual(uidValues?.first, "1.2.3.4.5")
        
        // State
        let stateElement = json[UPSTag.procedureStepState] as? [String: Any]
        XCTAssertEqual(stateElement?["vr"] as? String, "CS")
        let stateValues = stateElement?["Value"] as? [String]
        XCTAssertEqual(stateValues?.first, "SCHEDULED")
        
        // Priority
        let priorityElement = json[UPSTag.scheduledProcedureStepPriority] as? [String: Any]
        XCTAssertEqual(priorityElement?["vr"] as? String, "CS")
        let priorityValues = priorityElement?["Value"] as? [String]
        XCTAssertEqual(priorityValues?.first, "HIGH")
    }
    
    func testToDICOMJSONPatientInfo() {
        var workitem = Workitem(workitemUID: "1.2.3")
        workitem.patientName = "Smith^John"
        workitem.patientID = "PAT001"
        workitem.patientBirthDate = "19800115"
        workitem.patientSex = "M"
        
        let json = workitem.toDICOMJSON()
        
        // Patient Name (PN format)
        let nameElement = json[UPSTag.patientName] as? [String: Any]
        XCTAssertEqual(nameElement?["vr"] as? String, "PN")
        let nameValues = nameElement?["Value"] as? [[String: Any]]
        XCTAssertEqual(nameValues?.first?["Alphabetic"] as? String, "Smith^John")
        
        // Patient ID
        let idElement = json[UPSTag.patientID] as? [String: Any]
        XCTAssertEqual(idElement?["vr"] as? String, "LO")
        let idValues = idElement?["Value"] as? [String]
        XCTAssertEqual(idValues?.first, "PAT001")
        
        // Birth Date
        let birthElement = json[UPSTag.patientBirthDate] as? [String: Any]
        XCTAssertEqual(birthElement?["vr"] as? String, "DA")
        
        // Sex
        let sexElement = json[UPSTag.patientSex] as? [String: Any]
        XCTAssertEqual(sexElement?["vr"] as? String, "CS")
    }
    
    func testToDICOMJSONOmitsNilFields() {
        let workitem = Workitem(workitemUID: "1.2.3")
        let json = workitem.toDICOMJSON()
        
        // These should not be present since they're nil
        XCTAssertNil(json[UPSTag.patientName])
        XCTAssertNil(json[UPSTag.patientID])
        XCTAssertNil(json[UPSTag.studyInstanceUID])
        XCTAssertNil(json[UPSTag.accessionNumber])
        XCTAssertNil(json[UPSTag.procedureStepLabel])
        XCTAssertNil(json[UPSTag.commentsOnScheduledProcedureStep])
        XCTAssertNil(json[UPSTag.transactionUID])
        XCTAssertNil(json[UPSTag.inputInformationSequence])
        XCTAssertNil(json[UPSTag.outputInformationSequence])
        XCTAssertNil(json[UPSTag.scheduledHumanPerformersSequence])
    }
    
    func testToDICOMJSONSequenceFields() {
        var workitem = Workitem(workitemUID: "1.2.3")
        workitem.inputInformation = [
            ReferencedInstance(sopClassUID: "1.2.840.10008.5.1.4.1.1.2", sopInstanceUID: "1.2.3.4.5")
        ]
        workitem.scheduledHumanPerformers = [
            HumanPerformer(
                performerCode: CodedEntry(codeValue: "121081", codingSchemeDesignator: "DCM", codeMeaning: "Physician"),
                performerName: "Smith^Jane"
            )
        ]
        workitem.scheduledWorkitemCode = CodedEntry(
            codeValue: "CT001",
            codingSchemeDesignator: "99LOCAL",
            codeMeaning: "CT Scan"
        )
        
        let json = workitem.toDICOMJSON()
        
        // Input Information Sequence
        let inputElement = json[UPSTag.inputInformationSequence] as? [String: Any]
        XCTAssertEqual(inputElement?["vr"] as? String, "SQ")
        let inputItems = inputElement?["Value"] as? [[String: Any]]
        XCTAssertEqual(inputItems?.count, 1)
        
        // Human Performers Sequence
        let perfElement = json[UPSTag.scheduledHumanPerformersSequence] as? [String: Any]
        XCTAssertEqual(perfElement?["vr"] as? String, "SQ")
        
        // Workitem Code Sequence
        let codeElement = json[UPSTag.scheduledWorkitemCodeSequence] as? [String: Any]
        XCTAssertEqual(codeElement?["vr"] as? String, "SQ")
    }
    
    func testToDICOMJSONProgressInfo() {
        var workitem = Workitem(workitemUID: "1.2.3")
        workitem.progressInformation = ProgressInformation(
            progressPercentage: 75,
            progressDescription: "Processing images"
        )
        
        let json = workitem.toDICOMJSON()
        
        let progressElement = json[UPSTag.procedureStepProgress] as? [String: Any]
        XCTAssertNotNil(progressElement)
        let progressValues = progressElement?["Value"] as? [Int]
        XCTAssertEqual(progressValues?.first, 75)
        
        let descElement = json[UPSTag.procedureStepProgressDescription] as? [String: Any]
        let descValues = descElement?["Value"] as? [String]
        XCTAssertEqual(descValues?.first, "Processing images")
    }
    
    // MARK: - Workitem.parse() Tests
    
    func testParseBasicWorkitem() {
        let json: [String: Any] = [
            UPSTag.sopInstanceUID: ["vr": "UI", "Value": ["1.2.3.4.5"]],
            UPSTag.procedureStepState: ["vr": "CS", "Value": ["SCHEDULED"]],
            UPSTag.scheduledProcedureStepPriority: ["vr": "CS", "Value": ["HIGH"]]
        ]
        
        let workitem = Workitem.parse(json: json)
        XCTAssertNotNil(workitem)
        XCTAssertEqual(workitem?.workitemUID, "1.2.3.4.5")
        XCTAssertEqual(workitem?.state, .scheduled)
        XCTAssertEqual(workitem?.priority, .high)
    }
    
    func testParseReturnsNilForMissingUID() {
        let json: [String: Any] = [
            UPSTag.procedureStepState: ["vr": "CS", "Value": ["SCHEDULED"]]
        ]
        
        XCTAssertNil(Workitem.parse(json: json))
    }
    
    func testParseDefaultsForMissingStateAndPriority() {
        let json: [String: Any] = [
            UPSTag.sopInstanceUID: ["vr": "UI", "Value": ["1.2.3"]]
        ]
        
        let workitem = Workitem.parse(json: json)
        XCTAssertNotNil(workitem)
        XCTAssertEqual(workitem?.state, .scheduled)
        XCTAssertEqual(workitem?.priority, .medium)
    }
    
    func testParsePatientInfo() {
        let json: [String: Any] = [
            UPSTag.sopInstanceUID: ["vr": "UI", "Value": ["1.2.3"]],
            UPSTag.patientName: ["vr": "PN", "Value": [["Alphabetic": "Smith^John"]]],
            UPSTag.patientID: ["vr": "LO", "Value": ["PAT001"]],
            UPSTag.patientBirthDate: ["vr": "DA", "Value": ["19800115"]],
            UPSTag.patientSex: ["vr": "CS", "Value": ["M"]]
        ]
        
        let workitem = Workitem.parse(json: json)
        XCTAssertEqual(workitem?.patientName, "Smith^John")
        XCTAssertEqual(workitem?.patientID, "PAT001")
        XCTAssertEqual(workitem?.patientBirthDate, "19800115")
        XCTAssertEqual(workitem?.patientSex, "M")
    }
    
    func testParseStudyReference() {
        let json: [String: Any] = [
            UPSTag.sopInstanceUID: ["vr": "UI", "Value": ["1.2.3"]],
            UPSTag.studyInstanceUID: ["vr": "UI", "Value": ["2.16.840.1.2.3"]],
            UPSTag.accessionNumber: ["vr": "SH", "Value": ["ACC123"]],
            UPSTag.referringPhysicianName: ["vr": "PN", "Value": [["Alphabetic": "Jones^Alice"]]]
        ]
        
        let workitem = Workitem.parse(json: json)
        XCTAssertEqual(workitem?.studyInstanceUID, "2.16.840.1.2.3")
        XCTAssertEqual(workitem?.accessionNumber, "ACC123")
        XCTAssertEqual(workitem?.referringPhysicianName, "Jones^Alice")
    }
    
    func testParseIdentification() {
        let json: [String: Any] = [
            UPSTag.sopInstanceUID: ["vr": "UI", "Value": ["1.2.3"]],
            UPSTag.procedureStepLabel: ["vr": "LO", "Value": ["CT Abdomen"]],
            UPSTag.worklistLabel: ["vr": "LO", "Value": ["Radiology"]],
            UPSTag.scheduledProcedureStepID: ["vr": "SH", "Value": ["SPS001"]],
            UPSTag.commentsOnScheduledProcedureStep: ["vr": "LT", "Value": ["Urgent"]]
        ]
        
        let workitem = Workitem.parse(json: json)
        XCTAssertEqual(workitem?.procedureStepLabel, "CT Abdomen")
        XCTAssertEqual(workitem?.worklistLabel, "Radiology")
        XCTAssertEqual(workitem?.scheduledProcedureStepID, "SPS001")
        XCTAssertEqual(workitem?.comments, "Urgent")
    }
    
    func testParseTransactionAndCancellation() {
        let json: [String: Any] = [
            UPSTag.sopInstanceUID: ["vr": "UI", "Value": ["1.2.3"]],
            UPSTag.procedureStepState: ["vr": "CS", "Value": ["CANCELED"]],
            UPSTag.transactionUID: ["vr": "UI", "Value": ["9.8.7.6"]],
            UPSTag.reasonForCancellation: ["vr": "LT", "Value": ["Patient refused"]]
        ]
        
        let workitem = Workitem.parse(json: json)
        XCTAssertEqual(workitem?.state, .canceled)
        XCTAssertEqual(workitem?.transactionUID, "9.8.7.6")
        XCTAssertEqual(workitem?.cancellationReason, "Patient refused")
    }
    
    func testParseInputOutputSequences() {
        let json: [String: Any] = [
            UPSTag.sopInstanceUID: ["vr": "UI", "Value": ["1.2.3"]],
            UPSTag.inputInformationSequence: [
                "vr": "SQ",
                "Value": [
                    [
                        UPSTag.referencedSOPClassUID: ["vr": "UI", "Value": ["1.2.840.10008.5.1.4.1.1.2"]],
                        UPSTag.referencedSOPInstanceUID: ["vr": "UI", "Value": ["4.5.6.7.8"]]
                    ]
                ]
            ],
            UPSTag.outputInformationSequence: [
                "vr": "SQ",
                "Value": [
                    [
                        UPSTag.referencedSOPClassUID: ["vr": "UI", "Value": ["1.2.840.10008.5.1.4.1.1.7"]],
                        UPSTag.referencedSOPInstanceUID: ["vr": "UI", "Value": ["9.10.11.12"]]
                    ]
                ]
            ]
        ]
        
        let workitem = Workitem.parse(json: json)
        XCTAssertEqual(workitem?.inputInformation?.count, 1)
        XCTAssertEqual(workitem?.inputInformation?.first?.sopClassUID, "1.2.840.10008.5.1.4.1.1.2")
        XCTAssertEqual(workitem?.inputInformation?.first?.sopInstanceUID, "4.5.6.7.8")
        XCTAssertEqual(workitem?.outputInformation?.count, 1)
        XCTAssertEqual(workitem?.outputInformation?.first?.sopClassUID, "1.2.840.10008.5.1.4.1.1.7")
    }
    
    func testParseHumanPerformers() {
        let json: [String: Any] = [
            UPSTag.sopInstanceUID: ["vr": "UI", "Value": ["1.2.3"]],
            UPSTag.scheduledHumanPerformersSequence: [
                "vr": "SQ",
                "Value": [
                    [
                        UPSTag.humanPerformerName: ["vr": "LO", "Value": ["Smith^Jane"]],
                        UPSTag.humanPerformerOrganization: ["vr": "LO", "Value": ["City Hospital"]],
                        UPSTag.humanPerformerCodeSequence: [
                            "vr": "SQ",
                            "Value": [
                                [
                                    UPSTag.codeValue: ["vr": "SH", "Value": ["121081"]],
                                    UPSTag.codingSchemeDesignator: ["vr": "SH", "Value": ["DCM"]],
                                    UPSTag.codeMeaning: ["vr": "LO", "Value": ["Physician"]]
                                ]
                            ]
                        ]
                    ]
                ]
            ]
        ]
        
        let workitem = Workitem.parse(json: json)
        XCTAssertEqual(workitem?.scheduledHumanPerformers?.count, 1)
        let performer = workitem?.scheduledHumanPerformers?.first
        XCTAssertEqual(performer?.performerName, "Smith^Jane")
        XCTAssertEqual(performer?.performerOrganization, "City Hospital")
        XCTAssertEqual(performer?.performerCode?.codeValue, "121081")
        XCTAssertEqual(performer?.performerCode?.codingSchemeDesignator, "DCM")
        XCTAssertEqual(performer?.performerCode?.codeMeaning, "Physician")
    }
    
    func testParseScheduledWorkitemCode() {
        let json: [String: Any] = [
            UPSTag.sopInstanceUID: ["vr": "UI", "Value": ["1.2.3"]],
            UPSTag.scheduledWorkitemCodeSequence: [
                "vr": "SQ",
                "Value": [
                    [
                        UPSTag.codeValue: ["vr": "SH", "Value": ["CT001"]],
                        UPSTag.codingSchemeDesignator: ["vr": "SH", "Value": ["99LOCAL"]],
                        UPSTag.codingSchemeVersion: ["vr": "SH", "Value": ["1.0"]],
                        UPSTag.codeMeaning: ["vr": "LO", "Value": ["CT Scan"]]
                    ]
                ]
            ]
        ]
        
        let workitem = Workitem.parse(json: json)
        XCTAssertEqual(workitem?.scheduledWorkitemCode?.codeValue, "CT001")
        XCTAssertEqual(workitem?.scheduledWorkitemCode?.codingSchemeDesignator, "99LOCAL")
        XCTAssertEqual(workitem?.scheduledWorkitemCode?.codingSchemeVersion, "1.0")
        XCTAssertEqual(workitem?.scheduledWorkitemCode?.codeMeaning, "CT Scan")
    }
    
    func testParseProgressInformation() {
        let json: [String: Any] = [
            UPSTag.sopInstanceUID: ["vr": "UI", "Value": ["1.2.3"]],
            UPSTag.procedureStepProgress: ["vr": "DS", "Value": [50]],
            UPSTag.procedureStepProgressDescription: ["vr": "LO", "Value": ["Processing"]]
        ]
        
        let workitem = Workitem.parse(json: json)
        XCTAssertEqual(workitem?.progressInformation?.progressPercentage, 50)
        XCTAssertEqual(workitem?.progressInformation?.progressDescription, "Processing")
    }
    
    // MARK: - Round-trip Tests
    
    func testRoundTripBasicWorkitem() {
        let original = Workitem(workitemUID: "1.2.3.4.5", state: .scheduled, priority: .high)
        let json = original.toDICOMJSON()
        let parsed = Workitem.parse(json: json)
        
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.workitemUID, original.workitemUID)
        XCTAssertEqual(parsed?.state, original.state)
        XCTAssertEqual(parsed?.priority, original.priority)
    }
    
    func testRoundTripWithPatientInfo() {
        var original = Workitem(workitemUID: "1.2.3.4.5")
        original.patientName = "Doe^John"
        original.patientID = "PAT001"
        original.patientBirthDate = "19800115"
        original.patientSex = "M"
        
        let json = original.toDICOMJSON()
        let parsed = Workitem.parse(json: json)
        
        XCTAssertEqual(parsed?.patientName, original.patientName)
        XCTAssertEqual(parsed?.patientID, original.patientID)
        XCTAssertEqual(parsed?.patientBirthDate, original.patientBirthDate)
        XCTAssertEqual(parsed?.patientSex, original.patientSex)
    }
    
    func testRoundTripWithStudyReference() {
        var original = Workitem(workitemUID: "1.2.3.4.5")
        original.studyInstanceUID = "2.16.840.1.2.3"
        original.accessionNumber = "ACC123"
        original.referringPhysicianName = "Jones^Alice"
        
        let json = original.toDICOMJSON()
        let parsed = Workitem.parse(json: json)
        
        XCTAssertEqual(parsed?.studyInstanceUID, original.studyInstanceUID)
        XCTAssertEqual(parsed?.accessionNumber, original.accessionNumber)
        XCTAssertEqual(parsed?.referringPhysicianName, original.referringPhysicianName)
    }
    
    func testRoundTripWithLabelsAndComments() {
        var original = Workitem(workitemUID: "1.2.3.4.5")
        original.procedureStepLabel = "CT Abdomen"
        original.worklistLabel = "Radiology"
        original.scheduledProcedureStepID = "SPS001"
        original.comments = "Urgent scan"
        
        let json = original.toDICOMJSON()
        let parsed = Workitem.parse(json: json)
        
        XCTAssertEqual(parsed?.procedureStepLabel, original.procedureStepLabel)
        XCTAssertEqual(parsed?.worklistLabel, original.worklistLabel)
        XCTAssertEqual(parsed?.scheduledProcedureStepID, original.scheduledProcedureStepID)
        XCTAssertEqual(parsed?.comments, original.comments)
    }
    
    func testRoundTripWithSequences() {
        var original = Workitem(workitemUID: "1.2.3.4.5")
        original.inputInformation = [
            ReferencedInstance(
                sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
                sopInstanceUID: "4.5.6.7.8",
                studyInstanceUID: "1.2.3.4",
                seriesInstanceUID: "1.2.3.4.5"
            )
        ]
        original.scheduledHumanPerformers = [
            HumanPerformer(
                performerCode: CodedEntry(codeValue: "121081", codingSchemeDesignator: "DCM", codeMeaning: "Physician"),
                performerName: "Smith^Jane",
                performerOrganization: "City Hospital"
            )
        ]
        original.scheduledWorkitemCode = CodedEntry(
            codeValue: "CT001",
            codingSchemeDesignator: "99LOCAL",
            codingSchemeVersion: "1.0",
            codeMeaning: "CT Scan"
        )
        
        let json = original.toDICOMJSON()
        let parsed = Workitem.parse(json: json)
        
        // Input info
        XCTAssertEqual(parsed?.inputInformation?.count, 1)
        XCTAssertEqual(parsed?.inputInformation?.first?.sopClassUID, "1.2.840.10008.5.1.4.1.1.2")
        XCTAssertEqual(parsed?.inputInformation?.first?.sopInstanceUID, "4.5.6.7.8")
        XCTAssertEqual(parsed?.inputInformation?.first?.studyInstanceUID, "1.2.3.4")
        XCTAssertEqual(parsed?.inputInformation?.first?.seriesInstanceUID, "1.2.3.4.5")
        
        // Performers
        XCTAssertEqual(parsed?.scheduledHumanPerformers?.count, 1)
        XCTAssertEqual(parsed?.scheduledHumanPerformers?.first?.performerName, "Smith^Jane")
        XCTAssertEqual(parsed?.scheduledHumanPerformers?.first?.performerOrganization, "City Hospital")
        XCTAssertEqual(parsed?.scheduledHumanPerformers?.first?.performerCode?.codeValue, "121081")
        
        // Workitem Code
        XCTAssertEqual(parsed?.scheduledWorkitemCode?.codeValue, "CT001")
        XCTAssertEqual(parsed?.scheduledWorkitemCode?.codingSchemeVersion, "1.0")
    }
    
    func testRoundTripFromBuilder() throws {
        let startDate = Date(timeIntervalSince1970: 1700000000)
        
        let original = try WorkitemBuilder.scheduledProcedure(
            workitemUID: "1.2.3.4.5",
            patientName: "Smith^John",
            patientID: "PAT001",
            procedureStepLabel: "CT Scan",
            priority: .high,
            scheduledStartDateTime: startDate
        )
        .setAccessionNumber("ACC123")
        .setStudyInstanceUID("2.16.840.1.2.3")
        .setComments("Follow up scan")
        .setScheduledWorkitemCode(
            CodedEntry(codeValue: "CT001", codingSchemeDesignator: "99LOCAL", codeMeaning: "CT Scan")
        )
        .build()
        
        let json = original.toDICOMJSON()
        let parsed = Workitem.parse(json: json)
        
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.workitemUID, original.workitemUID)
        XCTAssertEqual(parsed?.state, original.state)
        XCTAssertEqual(parsed?.priority, original.priority)
        XCTAssertEqual(parsed?.patientName, original.patientName)
        XCTAssertEqual(parsed?.patientID, original.patientID)
        XCTAssertEqual(parsed?.procedureStepLabel, original.procedureStepLabel)
        XCTAssertEqual(parsed?.accessionNumber, original.accessionNumber)
        XCTAssertEqual(parsed?.studyInstanceUID, original.studyInstanceUID)
        XCTAssertEqual(parsed?.comments, original.comments)
        XCTAssertEqual(parsed?.scheduledWorkitemCode?.codeValue, original.scheduledWorkitemCode?.codeValue)
    }
    
    // MARK: - Workitem.validate() Tests
    
    func testValidateScheduledWorkitem() {
        let workitem = Workitem(workitemUID: "1.2.3.4.5", state: .scheduled, priority: .medium)
        let errors = workitem.validate()
        XCTAssertTrue(errors.isEmpty)
        XCTAssertTrue(workitem.isValid)
    }
    
    func testValidateEmptyWorkitemUID() {
        let workitem = Workitem(workitemUID: "", state: .scheduled, priority: .medium)
        let errors = workitem.validate()
        XCTAssertFalse(errors.isEmpty)
        XCTAssertFalse(workitem.isValid)
        XCTAssertTrue(errors.contains(.emptyWorkitemUID))
    }
    
    func testValidateInProgressWithoutTransactionUID() {
        let workitem = Workitem(workitemUID: "1.2.3", state: .inProgress, priority: .medium)
        let errors = workitem.validate()
        XCTAssertTrue(errors.contains(.missingTransactionUID))
    }
    
    func testValidateInProgressWithTransactionUID() {
        var workitem = Workitem(workitemUID: "1.2.3", state: .inProgress, priority: .medium)
        workitem.transactionUID = "9.8.7.6"
        let errors = workitem.validate()
        XCTAssertTrue(errors.isEmpty)
    }
    
    func testValidateCompletedWorkitem() {
        let workitem = Workitem(workitemUID: "1.2.3", state: .completed, priority: .medium)
        let errors = workitem.validate()
        XCTAssertTrue(errors.contains(.finalStateViolation(state: .completed)))
    }
    
    func testValidateCanceledWorkitem() {
        let workitem = Workitem(workitemUID: "1.2.3", state: .canceled, priority: .medium)
        let errors = workitem.validate()
        XCTAssertTrue(errors.contains(.finalStateViolation(state: .canceled)))
    }
    
    func testValidationErrorDescription() {
        XCTAssertTrue(WorkitemValidationError.emptyWorkitemUID.description.contains("empty"))
        XCTAssertTrue(WorkitemValidationError.missingTransactionUID.description.contains("Transaction UID"))
        XCTAssertTrue(WorkitemValidationError.finalStateViolation(state: .completed).description.contains("COMPLETED"))
        XCTAssertTrue(WorkitemValidationError.invalidField(name: "test", reason: "bad").description.contains("test"))
    }
    
    // MARK: - Edge Cases
    
    func testParsePersonNameAsString() {
        let json: [String: Any] = [
            UPSTag.sopInstanceUID: ["vr": "UI", "Value": ["1.2.3"]],
            UPSTag.patientName: ["vr": "PN", "Value": ["Smith^John"]]
        ]
        
        let workitem = Workitem.parse(json: json)
        XCTAssertEqual(workitem?.patientName, "Smith^John")
    }
    
    func testParseProgressPercentageAsString() {
        let json: [String: Any] = [
            UPSTag.sopInstanceUID: ["vr": "UI", "Value": ["1.2.3"]],
            UPSTag.procedureStepProgress: ["vr": "DS", "Value": ["75"]]
        ]
        
        let workitem = Workitem.parse(json: json)
        XCTAssertEqual(workitem?.progressInformation?.progressPercentage, 75)
    }
    
    func testToDICOMJSONCancellationFields() {
        var workitem = Workitem(workitemUID: "1.2.3", state: .canceled)
        workitem.cancellationReason = "Patient refused"
        workitem.cancellationDateTime = Date(timeIntervalSince1970: 1700000000)
        
        let json = workitem.toDICOMJSON()
        
        let reasonElement = json[UPSTag.reasonForCancellation] as? [String: Any]
        let reasonValues = reasonElement?["Value"] as? [String]
        XCTAssertEqual(reasonValues?.first, "Patient refused")
        
        let dtElement = json[UPSTag.procedureStepCancellationDateTime] as? [String: Any]
        XCTAssertNotNil(dtElement)
        XCTAssertEqual(dtElement?["vr"] as? String, "DT")
    }
}
