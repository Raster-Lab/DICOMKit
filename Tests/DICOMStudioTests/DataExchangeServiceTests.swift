// DataExchangeServiceTests.swift
// DICOMStudioTests

import Testing
@testable import DICOMStudio
import Foundation

@Suite("Data Exchange Service Tests")
struct DataExchangeServiceTests {

    // MARK: - 12.1 JSON

    @Test("DataExchangeService default JSON settings outputFormat is pretty")
    func testDefaultJSONSettingsFormat() {
        let service = DataExchangeService()
        #expect(service.getJSONSettings().outputFormat == .pretty)
    }

    @Test("DataExchangeService setJSONSettings persists settings")
    func testSetJSONSettings() {
        let service = DataExchangeService()
        var settings = JSONConversionSettings()
        settings.outputFormat = .compact
        service.setJSONSettings(settings)
        #expect(service.getJSONSettings().outputFormat == .compact)
    }

    @Test("DataExchangeService setJSONOutput persists output")
    func testSetJSONOutput() {
        let service = DataExchangeService()
        service.setJSONOutput("{\"hello\":\"world\"}")
        #expect(service.getJSONOutput() == "{\"hello\":\"world\"}")
    }

    @Test("DataExchangeService setJSONInputFilePath persists path")
    func testSetJSONInputFilePath() {
        let service = DataExchangeService()
        service.setJSONInputFilePath("/tmp/input.dcm")
        #expect(service.getJSONInputFilePath() == "/tmp/input.dcm")
    }

    // MARK: - 12.2 XML

    @Test("DataExchangeService setXMLSettings persists settings")
    func testSetXMLSettings() {
        let service = DataExchangeService()
        var settings = XMLConversionSettings()
        settings.outputFormat = .noKeywords
        service.setXMLSettings(settings)
        #expect(service.getXMLSettings().outputFormat == .noKeywords)
    }

    @Test("DataExchangeService setXMLOutput persists output")
    func testSetXMLOutput() {
        let service = DataExchangeService()
        service.setXMLOutput("<NativeDicomModel/>")
        #expect(service.getXMLOutput() == "<NativeDicomModel/>")
    }

    @Test("DataExchangeService setXMLInputFilePath persists path")
    func testSetXMLInputFilePath() {
        let service = DataExchangeService()
        service.setXMLInputFilePath("/tmp/scan.dcm")
        #expect(service.getXMLInputFilePath() == "/tmp/scan.dcm")
    }

    // MARK: - 12.3 Image Export

    @Test("DataExchangeService addExportedImagePath increases count")
    func testAddExportedImagePath() {
        let service = DataExchangeService()
        service.addExportedImagePath("/tmp/frame1.png")
        #expect(service.getExportedImagePaths().count == 1)
    }

    @Test("DataExchangeService clearExportedImagePaths empties list")
    func testClearExportedImagePaths() {
        let service = DataExchangeService()
        service.addExportedImagePath("/tmp/frame1.png")
        service.addExportedImagePath("/tmp/frame2.png")
        service.clearExportedImagePaths()
        #expect(service.getExportedImagePaths().isEmpty)
    }

    // MARK: - 12.4 Transfer Syntax

    @Test("DataExchangeService addConversionJob increases count")
    func testAddConversionJob() {
        let service = DataExchangeService()
        let job = TransferSyntaxConversionJob(sourceFilePath: "/tmp/a.dcm", targetTransferSyntaxUID: "1.2.840.10008.1.2.1")
        service.addConversionJob(job)
        #expect(service.getConversionJobs().count == 1)
    }

    @Test("DataExchangeService updateConversionJob modifies existing job")
    func testUpdateConversionJob() {
        let service = DataExchangeService()
        var job = TransferSyntaxConversionJob(sourceFilePath: "/tmp/a.dcm", targetTransferSyntaxUID: "1.2.840.10008.1.2.1")
        service.addConversionJob(job)
        job.status = .completed
        service.updateConversionJob(job)
        #expect(service.getConversionJobs().first?.status == .completed)
    }

    @Test("DataExchangeService removeConversionJob decreases count")
    func testRemoveConversionJob() {
        let service = DataExchangeService()
        let job = TransferSyntaxConversionJob(sourceFilePath: "/tmp/a.dcm", targetTransferSyntaxUID: "1.2.840.10008.1.2.1")
        service.addConversionJob(job)
        service.removeConversionJob(id: job.id)
        #expect(service.getConversionJobs().isEmpty)
    }

    @Test("DataExchangeService setSelectedTargetSyntaxUID persists UID")
    func testSetSelectedTargetSyntaxUID() {
        let service = DataExchangeService()
        service.setSelectedTargetSyntaxUID("1.2.840.10008.1.2.4.50")
        #expect(service.getSelectedTargetSyntaxUID() == "1.2.840.10008.1.2.4.50")
    }

    // MARK: - 12.5 DICOMDIR

    @Test("DataExchangeService addDICOMDIREntry increases count")
    func testAddDICOMDIREntry() {
        let service = DataExchangeService()
        let entry = DICOMDIREntry(studyInstanceUID: "1.2.3", patientName: "Doe^John",
                                  patientID: "001", studyDate: "20240101",
                                  modalities: ["CT"], seriesCount: 2, instanceCount: 40)
        service.addDICOMDIREntry(entry)
        #expect(service.getDICOMDIREntries().count == 1)
    }

    @Test("DataExchangeService removeDICOMDIREntry decreases count")
    func testRemoveDICOMDIREntry() {
        let service = DataExchangeService()
        let entry = DICOMDIREntry(studyInstanceUID: "1.2.3", patientName: "Doe^John",
                                  patientID: "001", studyDate: "20240101",
                                  modalities: ["CT"], seriesCount: 2, instanceCount: 40)
        service.addDICOMDIREntry(entry)
        service.removeDICOMDIREntry(id: entry.id)
        #expect(service.getDICOMDIREntries().isEmpty)
    }

    @Test("DataExchangeService setDICOMDIROutputPath persists path")
    func testSetDICOMDIROutputPath() {
        let service = DataExchangeService()
        service.setDICOMDIROutputPath("/Volumes/DICOM/DICOMDIR")
        #expect(service.getDICOMDIROutputPath() == "/Volumes/DICOM/DICOMDIR")
    }

    // MARK: - 12.6 PDF

    @Test("DataExchangeService setPDFMode persists mode")
    func testSetPDFMode() {
        let service = DataExchangeService()
        service.setPDFMode(.extract)
        #expect(service.getPDFMode() == .extract)
    }

    @Test("DataExchangeService setPDFInputPath and OutputPath persist")
    func testSetPDFPaths() {
        let service = DataExchangeService()
        service.setPDFInputPath("/tmp/report.pdf")
        service.setPDFOutputPath("/tmp/report.dcm")
        #expect(service.getPDFInputPath() == "/tmp/report.pdf")
        #expect(service.getPDFOutputPath() == "/tmp/report.dcm")
    }

    @Test("DataExchangeService setPDFPatientName and PatientID persist")
    func testSetPDFPatientInfo() {
        let service = DataExchangeService()
        service.setPDFPatientName("Smith^Jane")
        service.setPDFPatientID("P002")
        #expect(service.getPDFPatientName() == "Smith^Jane")
        #expect(service.getPDFPatientID() == "P002")
    }

    // MARK: - 12.7 Batch

    @Test("DataExchangeService addBatchJob increases count")
    func testAddBatchJob() {
        let service = DataExchangeService()
        let job = BatchJob(operationType: .anonymization, inputPaths: ["/tmp/a.dcm"], outputDirectory: "/tmp/out")
        service.addBatchJob(job)
        #expect(service.getBatchJobs().count == 1)
    }

    @Test("DataExchangeService removeBatchJob decreases count")
    func testRemoveBatchJob() {
        let service = DataExchangeService()
        let job = BatchJob(operationType: .imageExport, inputPaths: [], outputDirectory: "")
        service.addBatchJob(job)
        service.removeBatchJob(id: job.id)
        #expect(service.getBatchJobs().isEmpty)
    }

    @Test("DataExchangeService addBatchTagModification increases count")
    func testAddBatchTagModification() {
        let service = DataExchangeService()
        let mod = BatchTagModification(tagKeyword: "PatientName", tagGroup: 0x0010, tagElement: 0x0010,
                                       operation: .remove, newValue: "")
        service.addBatchTagModification(mod)
        #expect(service.getBatchTagModifications().count == 1)
    }

    @Test("DataExchangeService clearBatchTagModifications empties list")
    func testClearBatchTagModifications() {
        let service = DataExchangeService()
        let mod = BatchTagModification(tagKeyword: "PatientName", tagGroup: 0x0010, tagElement: 0x0010,
                                       operation: .remove, newValue: "")
        service.addBatchTagModification(mod)
        service.clearBatchTagModifications()
        #expect(service.getBatchTagModifications().isEmpty)
    }

    @Test("DataExchangeService setSelectedBatchOperationType persists type")
    func testSetSelectedBatchOperationType() {
        let service = DataExchangeService()
        service.setSelectedBatchOperationType(.transferSyntaxConversion)
        #expect(service.getSelectedBatchOperationType() == .transferSyntaxConversion)
    }
}
