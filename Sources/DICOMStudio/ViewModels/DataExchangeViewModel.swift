// DataExchangeViewModel.swift
// DICOMStudio
//
// DICOM Studio — ViewModel for Data Exchange & Export (Milestone 12)
// Reference: DICOM PS3.10 (Media Storage), PS3.18 Annex F (JSON), PS3.19 Annex A (XML)

import Foundation
import Observation

@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
@Observable
public final class DataExchangeViewModel {
    private let service: DataExchangeService

    // Navigation
    public var activeTab: DataExchangeTab = .jsonConversion
    public var isLoading: Bool = false
    public var errorMessage: String? = nil

    // 12.1 JSON
    public var jsonSettings: JSONConversionSettings = JSONConversionSettings()
    public var jsonOutput: String = ""
    public var jsonInputFilePath: String = ""
    public var isJSONExportSheetPresented: Bool = false

    // 12.2 XML
    public var xmlSettings: XMLConversionSettings = XMLConversionSettings()
    public var xmlOutput: String = ""
    public var xmlInputFilePath: String = ""
    public var isXMLExportSheetPresented: Bool = false

    // 12.3 Image Export
    public var imageExportSettings: ImageExportSettings = ImageExportSettings()
    public var exportedImagePaths: [String] = []
    public var isImageExportSheetPresented: Bool = false
    public var imageInputFilePath: String = ""

    // 12.4 Transfer Syntax
    public var conversionJobs: [TransferSyntaxConversionJob] = []
    public var selectedTargetSyntaxUID: String = "1.2.840.10008.1.2.1"
    public var isAddConversionJobSheetPresented: Bool = false

    // 12.5 DICOMDIR
    public var dicomdirEntries: [DICOMDIREntry] = []
    public var dicomdirOutputPath: String = ""
    public var isAddDICOMDIREntrySheetPresented: Bool = false

    // 12.6 PDF
    public var pdfMode: PDFEncapsulationMode = .encapsulate
    public var pdfInputPath: String = ""
    public var pdfOutputPath: String = ""
    public var pdfPatientName: String = ""
    public var pdfPatientID: String = ""

    // 12.7 Batch
    public var batchJobs: [BatchJob] = []
    public var selectedBatchOperationType: BatchOperationType = .tagModification
    public var batchTagModifications: [BatchTagModification] = []
    public var isAddBatchJobSheetPresented: Bool = false

    public init(service: DataExchangeService = DataExchangeService()) {
        self.service = service
        loadFromService()
    }

    // MARK: - Load

    public func loadFromService() {
        jsonSettings = service.getJSONSettings()
        jsonOutput = service.getJSONOutput()
        jsonInputFilePath = service.getJSONInputFilePath()
        xmlSettings = service.getXMLSettings()
        xmlOutput = service.getXMLOutput()
        xmlInputFilePath = service.getXMLInputFilePath()
        imageExportSettings = service.getImageExportSettings()
        exportedImagePaths = service.getExportedImagePaths()
        conversionJobs = service.getConversionJobs()
        selectedTargetSyntaxUID = service.getSelectedTargetSyntaxUID()
        dicomdirEntries = service.getDICOMDIREntries()
        dicomdirOutputPath = service.getDICOMDIROutputPath()
        pdfMode = service.getPDFMode()
        pdfInputPath = service.getPDFInputPath()
        pdfOutputPath = service.getPDFOutputPath()
        pdfPatientName = service.getPDFPatientName()
        pdfPatientID = service.getPDFPatientID()
        batchJobs = service.getBatchJobs()
        selectedBatchOperationType = service.getSelectedBatchOperationType()
        batchTagModifications = service.getBatchTagModifications()
    }

    // MARK: - 12.1 JSON

    public func setJSONInputFilePath(_ path: String) {
        jsonInputFilePath = path
        service.setJSONInputFilePath(path)
    }

    public func updateJSONSettings(_ settings: JSONConversionSettings) {
        jsonSettings = settings
        service.setJSONSettings(settings)
    }

    public func clearJSONOutput() {
        jsonOutput = ""
        service.setJSONOutput("")
    }

    // MARK: - 12.2 XML

    public func setXMLInputFilePath(_ path: String) {
        xmlInputFilePath = path
        service.setXMLInputFilePath(path)
    }

    public func updateXMLSettings(_ settings: XMLConversionSettings) {
        xmlSettings = settings
        service.setXMLSettings(settings)
    }

    public func clearXMLOutput() {
        xmlOutput = ""
        service.setXMLOutput("")
    }

    // MARK: - 12.3 Image Export

    public func setImageInputFilePath(_ path: String) {
        imageInputFilePath = path
    }

    public func updateImageExportSettings(_ settings: ImageExportSettings) {
        imageExportSettings = settings
        service.setImageExportSettings(settings)
    }

    public func addExportedImagePath(_ path: String) {
        exportedImagePaths.append(path)
        service.addExportedImagePath(path)
    }

    public func clearExportedImagePaths() {
        exportedImagePaths.removeAll()
        service.clearExportedImagePaths()
    }

    // MARK: - 12.4 Transfer Syntax

    public func addConversionJob(_ job: TransferSyntaxConversionJob) {
        conversionJobs.append(job)
        service.addConversionJob(job)
    }

    public func updateConversionJob(_ job: TransferSyntaxConversionJob) {
        if let idx = conversionJobs.firstIndex(where: { $0.id == job.id }) {
            conversionJobs[idx] = job
        }
        service.updateConversionJob(job)
    }

    public func removeConversionJob(id: UUID) {
        conversionJobs.removeAll { $0.id == id }
        service.removeConversionJob(id: id)
    }

    public func setSelectedTargetSyntaxUID(_ uid: String) {
        selectedTargetSyntaxUID = uid
        service.setSelectedTargetSyntaxUID(uid)
    }

    // MARK: - 12.5 DICOMDIR

    public func addDICOMDIREntry(_ entry: DICOMDIREntry) {
        dicomdirEntries.append(entry)
        service.addDICOMDIREntry(entry)
    }

    public func removeDICOMDIREntry(id: UUID) {
        dicomdirEntries.removeAll { $0.id == id }
        service.removeDICOMDIREntry(id: id)
    }

    public func setDICOMDIROutputPath(_ path: String) {
        dicomdirOutputPath = path
        service.setDICOMDIROutputPath(path)
    }

    // MARK: - 12.6 PDF

    public func setPDFMode(_ mode: PDFEncapsulationMode) {
        pdfMode = mode
        service.setPDFMode(mode)
    }

    public func setPDFInputPath(_ path: String) {
        pdfInputPath = path
        service.setPDFInputPath(path)
    }

    public func setPDFOutputPath(_ path: String) {
        pdfOutputPath = path
        service.setPDFOutputPath(path)
    }

    public func setPDFPatientName(_ name: String) {
        pdfPatientName = name
        service.setPDFPatientName(name)
    }

    public func setPDFPatientID(_ id: String) {
        pdfPatientID = id
        service.setPDFPatientID(id)
    }

    // MARK: - 12.7 Batch

    public func addBatchJob(_ job: BatchJob) {
        batchJobs.append(job)
        service.addBatchJob(job)
    }

    public func updateBatchJob(_ job: BatchJob) {
        if let idx = batchJobs.firstIndex(where: { $0.id == job.id }) {
            batchJobs[idx] = job
        }
        service.updateBatchJob(job)
    }

    public func removeBatchJob(id: UUID) {
        batchJobs.removeAll { $0.id == id }
        service.removeBatchJob(id: id)
    }

    public func setSelectedBatchOperationType(_ type: BatchOperationType) {
        selectedBatchOperationType = type
        service.setSelectedBatchOperationType(type)
    }

    public func addBatchTagModification(_ mod: BatchTagModification) {
        batchTagModifications.append(mod)
        service.addBatchTagModification(mod)
    }

    public func removeBatchTagModification(id: UUID) {
        batchTagModifications.removeAll { $0.id == id }
        service.removeBatchTagModification(id: id)
    }
}
