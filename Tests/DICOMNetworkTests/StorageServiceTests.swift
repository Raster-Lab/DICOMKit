import XCTest
import DICOMCore
@testable import DICOMNetwork

final class StorageServiceTests: XCTestCase {
    
    // MARK: - StoreResult Tests
    
    func testStoreResultSuccess() {
        let result = StoreResult(
            success: true,
            status: .success,
            affectedSOPClassUID: "1.2.840.10008.5.1.4.1.1.2",
            affectedSOPInstanceUID: "1.2.3.4.5.6.7.8.9",
            roundTripTime: 0.125,
            remoteAETitle: "PACS"
        )
        
        XCTAssertTrue(result.success)
        XCTAssertTrue(result.status.isSuccess)
        XCTAssertFalse(result.hasWarning)
        XCTAssertEqual(result.affectedSOPClassUID, "1.2.840.10008.5.1.4.1.1.2")
        XCTAssertEqual(result.affectedSOPInstanceUID, "1.2.3.4.5.6.7.8.9")
        XCTAssertEqual(result.roundTripTime, 0.125, accuracy: 0.001)
        XCTAssertEqual(result.remoteAETitle, "PACS")
    }
    
    func testStoreResultFailure() {
        let status = DIMSEStatus.refusedOutOfResources
        let result = StoreResult(
            success: false,
            status: status,
            affectedSOPClassUID: "1.2.840.10008.5.1.4.1.1.7",
            affectedSOPInstanceUID: "1.2.3.4.5.6",
            roundTripTime: 0.050,
            remoteAETitle: "TEST_SCP"
        )
        
        XCTAssertFalse(result.success)
        XCTAssertTrue(result.status.isFailure)
        XCTAssertFalse(result.hasWarning)
        XCTAssertEqual(result.remoteAETitle, "TEST_SCP")
    }
    
    func testStoreResultWarning() {
        // Create a warning status
        let status = DIMSEStatus.warningCoercionOfDataElements
        let result = StoreResult(
            success: true,
            status: status,
            affectedSOPClassUID: "1.2.840.10008.5.1.4.1.1.2",
            affectedSOPInstanceUID: "1.2.3.4.5.6.7.8.9",
            roundTripTime: 0.100,
            remoteAETitle: "PACS"
        )
        
        // Warning status may or may not be considered "success" depending on DIMSE status implementation
        // At minimum, we can verify hasWarning
        XCTAssertTrue(result.hasWarning)
    }
    
    func testStoreResultHashable() {
        let result1 = StoreResult(
            success: true,
            status: .success,
            affectedSOPClassUID: "1.2.840.10008.5.1.4.1.1.2",
            affectedSOPInstanceUID: "1.2.3.4.5.6.7.8.9",
            roundTripTime: 0.100,
            remoteAETitle: "PACS"
        )
        let result2 = StoreResult(
            success: true,
            status: .success,
            affectedSOPClassUID: "1.2.840.10008.5.1.4.1.1.2",
            affectedSOPInstanceUID: "1.2.3.4.5.6.7.8.9",
            roundTripTime: 0.100,
            remoteAETitle: "PACS"
        )
        let result3 = StoreResult(
            success: false,
            status: .success,
            affectedSOPClassUID: "1.2.840.10008.5.1.4.1.1.2",
            affectedSOPInstanceUID: "1.2.3.4.5.6.7.8.9",
            roundTripTime: 0.100,
            remoteAETitle: "PACS"
        )
        
        XCTAssertEqual(result1, result2)
        XCTAssertNotEqual(result1, result3)
    }
    
    func testStoreResultDescription() {
        let result = StoreResult(
            success: true,
            status: .success,
            affectedSOPClassUID: "1.2.840.10008.5.1.4.1.1.2",
            affectedSOPInstanceUID: "1.2.3.4.5.6.7.8.9",
            roundTripTime: 0.125,
            remoteAETitle: "PACS"
        )
        
        let description = result.description
        XCTAssertTrue(description.contains("SUCCESS"))
        XCTAssertTrue(description.contains("PACS"))
        XCTAssertTrue(description.contains("1.2.840.10008.5.1.4.1.1.2"))
    }
    
    // MARK: - StoreStatusCategory Tests
    
    func testStoreStatusCategorySuccess() {
        let category = StoreStatusCategory(from: .success)
        XCTAssertEqual(category, StoreStatusCategory.success)
    }
    
    func testStoreStatusCategoryWarning() {
        let category = StoreStatusCategory(from: .warningCoercionOfDataElements)
        XCTAssertEqual(category, StoreStatusCategory.warning)
    }
    
    func testStoreStatusCategoryFailure() {
        let category = StoreStatusCategory(from: .refusedOutOfResources)
        XCTAssertEqual(category, StoreStatusCategory.failure)
    }
    
    // MARK: - StorageConfiguration Tests
    
    func testStorageConfigurationDefaults() throws {
        let callingAE = try AETitle("CALLING")
        let calledAE = try AETitle("CALLED")
        
        let config = StorageConfiguration(
            callingAETitle: callingAE,
            calledAETitle: calledAE
        )
        
        XCTAssertEqual(config.callingAETitle.value, "CALLING")
        XCTAssertEqual(config.calledAETitle.value, "CALLED")
        XCTAssertEqual(config.timeout, 60)
        XCTAssertEqual(config.maxPDUSize, defaultMaxPDUSize)
        XCTAssertEqual(config.implementationClassUID, StorageConfiguration.defaultImplementationClassUID)
        XCTAssertEqual(config.implementationVersionName, StorageConfiguration.defaultImplementationVersionName)
        XCTAssertEqual(config.priority, .medium)
    }
    
    func testStorageConfigurationCustomValues() throws {
        let callingAE = try AETitle("MY_SCU")
        let calledAE = try AETitle("PACS")
        
        let config = StorageConfiguration(
            callingAETitle: callingAE,
            calledAETitle: calledAE,
            timeout: 120,
            maxPDUSize: 32768,
            implementationClassUID: "1.2.3.4.5",
            implementationVersionName: "TEST_V1",
            priority: .high
        )
        
        XCTAssertEqual(config.callingAETitle.value, "MY_SCU")
        XCTAssertEqual(config.calledAETitle.value, "PACS")
        XCTAssertEqual(config.timeout, 120)
        XCTAssertEqual(config.maxPDUSize, 32768)
        XCTAssertEqual(config.implementationClassUID, "1.2.3.4.5")
        XCTAssertEqual(config.implementationVersionName, "TEST_V1")
        XCTAssertEqual(config.priority, .high)
    }
    
    func testStorageConfigurationHashable() throws {
        let callingAE = try AETitle("SCU")
        let calledAE = try AETitle("SCP")
        
        let config1 = StorageConfiguration(
            callingAETitle: callingAE,
            calledAETitle: calledAE,
            timeout: 60
        )
        let config2 = StorageConfiguration(
            callingAETitle: callingAE,
            calledAETitle: calledAE,
            timeout: 60
        )
        let config3 = StorageConfiguration(
            callingAETitle: callingAE,
            calledAETitle: calledAE,
            timeout: 120
        )
        
        XCTAssertEqual(config1, config2)
        XCTAssertNotEqual(config1, config3)
    }
    
    // MARK: - BatchStoreProgress Tests
    
    func testBatchStoreProgressInitial() {
        let progress = BatchStoreProgress(total: 10)
        
        XCTAssertEqual(progress.total, 10)
        XCTAssertEqual(progress.succeeded, 0)
        XCTAssertEqual(progress.failed, 0)
        XCTAssertEqual(progress.warnings, 0)
        XCTAssertEqual(progress.fractionComplete, 0.0, accuracy: 0.001)
        XCTAssertFalse(progress.isComplete)
    }
    
    func testBatchStoreProgressPartial() {
        let progress = BatchStoreProgress(total: 10, succeeded: 5, failed: 1, warnings: 1)
        
        XCTAssertEqual(progress.total, 10)
        XCTAssertEqual(progress.succeeded, 5)
        XCTAssertEqual(progress.failed, 1)
        XCTAssertEqual(progress.warnings, 1)
        XCTAssertEqual(progress.fractionComplete, 0.7, accuracy: 0.001)
        XCTAssertFalse(progress.isComplete)
    }
    
    func testBatchStoreProgressComplete() {
        let progress = BatchStoreProgress(total: 10, succeeded: 8, failed: 1, warnings: 1)
        
        XCTAssertTrue(progress.isComplete)
        XCTAssertEqual(progress.fractionComplete, 1.0, accuracy: 0.001)
    }
    
    func testBatchStoreProgressZeroTotal() {
        let progress = BatchStoreProgress(total: 0)
        
        XCTAssertEqual(progress.fractionComplete, 0.0, accuracy: 0.001)
    }
    
    func testBatchStoreProgressDescription() {
        let progress = BatchStoreProgress(total: 10, succeeded: 5, failed: 2, warnings: 1)
        
        let description = progress.description
        XCTAssertTrue(description.contains("8/10"))
        XCTAssertTrue(description.contains("5 succeeded"))
        XCTAssertTrue(description.contains("2 failed"))
        XCTAssertTrue(description.contains("1 warnings"))
    }
    
    // MARK: - Default Implementation Constants Tests
    
    func testDefaultImplementationClassUID() {
        let uid = StorageConfiguration.defaultImplementationClassUID
        XCTAssertFalse(uid.isEmpty)
        XCTAssertTrue(uid.hasPrefix("1.2."))
    }
    
    func testDefaultImplementationVersionName() {
        let name = StorageConfiguration.defaultImplementationVersionName
        XCTAssertNotNil(name)
        XCTAssertFalse(name.isEmpty)
        XCTAssertTrue(name.contains("DICOMKIT"))
    }
    
    // MARK: - C-STORE Message Tests
    
    func testCStoreRequestCreation() {
        let request = CStoreRequest(
            messageID: 1,
            affectedSOPClassUID: "1.2.840.10008.5.1.4.1.1.2",
            affectedSOPInstanceUID: "1.2.3.4.5.6.7.8.9",
            priority: .high,
            presentationContextID: 1
        )
        
        XCTAssertEqual(request.messageID, 1)
        XCTAssertEqual(request.affectedSOPClassUID, "1.2.840.10008.5.1.4.1.1.2")
        XCTAssertEqual(request.affectedSOPInstanceUID, "1.2.3.4.5.6.7.8.9")
        XCTAssertEqual(request.priority, .high)
        XCTAssertEqual(request.presentationContextID, 1)
        XCTAssertTrue(request.hasDataSet)
        XCTAssertEqual(request.commandSet.command, .cStoreRequest)
    }
    
    func testCStoreRequestWithMoveOriginator() {
        let request = CStoreRequest(
            messageID: 1,
            affectedSOPClassUID: "1.2.840.10008.5.1.4.1.1.2",
            affectedSOPInstanceUID: "1.2.3.4.5.6.7.8.9",
            priority: .medium,
            moveOriginatorAETitle: "MOVE_SCU",
            moveOriginatorMessageID: 42,
            presentationContextID: 1
        )
        
        XCTAssertEqual(request.moveOriginatorAETitle, "MOVE_SCU")
        XCTAssertEqual(request.moveOriginatorMessageID, 42)
    }
    
    func testCStoreResponseCreation() {
        let response = CStoreResponse(
            messageIDBeingRespondedTo: 1,
            affectedSOPClassUID: "1.2.840.10008.5.1.4.1.1.2",
            affectedSOPInstanceUID: "1.2.3.4.5.6.7.8.9",
            status: .success,
            presentationContextID: 1
        )
        
        XCTAssertEqual(response.messageIDBeingRespondedTo, 1)
        XCTAssertEqual(response.affectedSOPClassUID, "1.2.840.10008.5.1.4.1.1.2")
        XCTAssertEqual(response.affectedSOPInstanceUID, "1.2.3.4.5.6.7.8.9")
        XCTAssertTrue(response.status.isSuccess)
        XCTAssertFalse(response.hasDataSet)
        XCTAssertEqual(response.commandSet.command, .cStoreResponse)
    }
    
    // MARK: - Command Set Encoding Tests
    
    func testCStoreRequestCommandSetEncoding() {
        let request = CStoreRequest(
            messageID: 42,
            affectedSOPClassUID: "1.2.840.10008.5.1.4.1.1.2",
            affectedSOPInstanceUID: "1.2.3.4.5.6.7.8.9.10",
            priority: .medium,
            presentationContextID: 1
        )
        
        let encodedData = request.commandSet.encode()
        
        // Verify the command set can be encoded
        XCTAssertGreaterThan(encodedData.count, 0)
        
        // Verify round-trip decode
        do {
            let decodedCommandSet = try CommandSet.decode(from: encodedData)
            XCTAssertEqual(decodedCommandSet.command, .cStoreRequest)
            XCTAssertEqual(decodedCommandSet.messageID, 42)
            XCTAssertEqual(decodedCommandSet.affectedSOPClassUID, "1.2.840.10008.5.1.4.1.1.2")
            XCTAssertEqual(decodedCommandSet.affectedSOPInstanceUID, "1.2.3.4.5.6.7.8.9.10")
            XCTAssertEqual(decodedCommandSet.priority, .medium)
            XCTAssertTrue(decodedCommandSet.hasDataSet)
        } catch {
            XCTFail("Failed to decode command set: \(error)")
        }
    }
    
    func testCStoreResponseCommandSetEncoding() {
        let response = CStoreResponse(
            messageIDBeingRespondedTo: 42,
            affectedSOPClassUID: "1.2.840.10008.5.1.4.1.1.2",
            affectedSOPInstanceUID: "1.2.3.4.5.6.7.8.9.10",
            status: .success,
            presentationContextID: 1
        )
        
        let encodedData = response.commandSet.encode()
        
        // Verify round-trip decode
        do {
            let decodedCommandSet = try CommandSet.decode(from: encodedData)
            XCTAssertEqual(decodedCommandSet.command, .cStoreResponse)
            XCTAssertEqual(decodedCommandSet.messageIDBeingRespondedTo, 42)
            XCTAssertEqual(decodedCommandSet.affectedSOPClassUID, "1.2.840.10008.5.1.4.1.1.2")
            XCTAssertEqual(decodedCommandSet.affectedSOPInstanceUID, "1.2.3.4.5.6.7.8.9.10")
            XCTAssertTrue(decodedCommandSet.status?.isSuccess ?? false)
            XCTAssertFalse(decodedCommandSet.hasDataSet)
        } catch {
            XCTFail("Failed to decode command set: \(error)")
        }
    }
    
    // MARK: - Message Fragmentation Tests
    
    func testCStoreRequestFragmentation() {
        let request = CStoreRequest(
            messageID: 1,
            affectedSOPClassUID: "1.2.840.10008.5.1.4.1.1.7",
            affectedSOPInstanceUID: "1.2.3.4.5.6.7.8.9",
            presentationContextID: 1
        )
        
        // Create a small data set
        let dataSet = Data(repeating: 0xAB, count: 1024)
        
        let fragmenter = MessageFragmenter(maxPDUSize: 16384)
        let pdus = fragmenter.fragmentMessage(
            commandSet: request.commandSet,
            dataSet: dataSet,
            presentationContextID: 1
        )
        
        // Should have at least 2 PDUs (command + data set)
        XCTAssertGreaterThanOrEqual(pdus.count, 2)
        
        // First PDU should be command
        let firstPDV = pdus[0].presentationDataValues[0]
        XCTAssertTrue(firstPDV.isCommand)
        XCTAssertEqual(firstPDV.presentationContextID, 1)
        
        // Last PDU should be data (not command)
        let lastPDV = pdus[pdus.count - 1].presentationDataValues[0]
        XCTAssertFalse(lastPDV.isCommand)
        XCTAssertTrue(lastPDV.isLastFragment)
    }
    
    func testCStoreRequestFragmentationLargeDataSet() {
        let request = CStoreRequest(
            messageID: 1,
            affectedSOPClassUID: "1.2.840.10008.5.1.4.1.1.2",
            affectedSOPInstanceUID: "1.2.3.4.5.6.7.8.9",
            presentationContextID: 1
        )
        
        // Create a large data set (larger than max PDV size)
        let dataSet = Data(repeating: 0xCD, count: 32768)
        
        let fragmenter = MessageFragmenter(maxPDUSize: 16384)
        let pdus = fragmenter.fragmentMessage(
            commandSet: request.commandSet,
            dataSet: dataSet,
            presentationContextID: 1
        )
        
        // Should have multiple PDUs due to fragmentation
        XCTAssertGreaterThan(pdus.count, 2)
        
        // Verify first command PDV
        let firstPDV = pdus[0].presentationDataValues[0]
        XCTAssertTrue(firstPDV.isCommand)
        
        // Count data PDVs and verify their properties
        var dataByteCount = 0
        var foundLastFragment = false
        
        for (index, pdu) in pdus.enumerated() {
            for pdv in pdu.presentationDataValues {
                if !pdv.isCommand {
                    dataByteCount += pdv.data.count
                    if pdv.isLastFragment {
                        XCTAssertFalse(foundLastFragment, "Should only have one last fragment")
                        foundLastFragment = true
                        XCTAssertEqual(index, pdus.count - 1, "Last fragment should be in last PDU")
                    }
                }
            }
        }
        
        XCTAssertEqual(dataByteCount, dataSet.count, "All data bytes should be accounted for")
        XCTAssertTrue(foundLastFragment, "Should have found last fragment")
    }
    
    // MARK: - Message Assembly Tests
    
    func testCStoreResponseAssembly() throws {
        // Create a C-STORE response
        let response = CStoreResponse(
            messageIDBeingRespondedTo: 1,
            affectedSOPClassUID: "1.2.840.10008.5.1.4.1.1.2",
            affectedSOPInstanceUID: "1.2.3.4.5.6.7.8.9",
            status: .success,
            presentationContextID: 1
        )
        
        // Fragment it
        let fragmenter = MessageFragmenter(maxPDUSize: 16384)
        let pdus = fragmenter.fragmentMessage(
            commandSet: response.commandSet,
            dataSet: nil,
            presentationContextID: 1
        )
        
        // Assemble it back
        let assembler = MessageAssembler()
        var assembledMessage: AssembledMessage?
        
        for pdu in pdus {
            assembledMessage = try assembler.addPDVs(from: pdu)
        }
        
        XCTAssertNotNil(assembledMessage)
        
        let storeResponse = assembledMessage?.asCStoreResponse()
        XCTAssertNotNil(storeResponse)
        XCTAssertEqual(storeResponse?.messageIDBeingRespondedTo, 1)
        XCTAssertEqual(storeResponse?.affectedSOPClassUID, "1.2.840.10008.5.1.4.1.1.2")
        XCTAssertEqual(storeResponse?.affectedSOPInstanceUID, "1.2.3.4.5.6.7.8.9")
        XCTAssertTrue(storeResponse?.status.isSuccess ?? false)
    }
    
    // MARK: - Presentation Context Tests
    
    func testStoragePresentationContext() throws {
        let context = try PresentationContext(
            id: 1,
            abstractSyntax: "1.2.840.10008.5.1.4.1.1.2", // CT Image Storage
            transferSyntaxes: [
                explicitVRLittleEndianTransferSyntaxUID,
                implicitVRLittleEndianTransferSyntaxUID
            ]
        )
        
        XCTAssertEqual(context.id, 1)
        XCTAssertEqual(context.abstractSyntax, "1.2.840.10008.5.1.4.1.1.2")
        XCTAssertEqual(context.transferSyntaxes.count, 2)
        XCTAssertTrue(context.transferSyntaxes.contains(explicitVRLittleEndianTransferSyntaxUID))
        XCTAssertTrue(context.transferSyntaxes.contains(implicitVRLittleEndianTransferSyntaxUID))
    }
    
    // MARK: - Common Storage SOP Class UIDs Tests
    
    func testCommonStorageSOPClassUIDsIncludesCT() {
        // CT Image Storage
        XCTAssertTrue(commonStorageSOPClassUIDs.contains("1.2.840.10008.5.1.4.1.1.2"))
    }
    
    func testCommonStorageSOPClassUIDsIncludesMR() {
        // MR Image Storage
        XCTAssertTrue(commonStorageSOPClassUIDs.contains("1.2.840.10008.5.1.4.1.1.4"))
    }
    
    func testCommonStorageSOPClassUIDsIncludesSecondaryCapture() {
        // Secondary Capture Image Storage
        XCTAssertTrue(commonStorageSOPClassUIDs.contains("1.2.840.10008.5.1.4.1.1.7"))
    }
    
    func testCommonStorageSOPClassUIDsIncludesUS() {
        // Ultrasound Image Storage
        XCTAssertTrue(commonStorageSOPClassUIDs.contains("1.2.840.10008.5.1.4.1.1.6.1"))
    }
    
    func testCommonStorageSOPClassUIDsIncludesRT() {
        // RT Image Storage
        XCTAssertTrue(commonStorageSOPClassUIDs.contains("1.2.840.10008.5.1.4.1.1.481.1"))
        // RT Structure Set Storage
        XCTAssertTrue(commonStorageSOPClassUIDs.contains("1.2.840.10008.5.1.4.1.1.481.3"))
        // RT Plan Storage
        XCTAssertTrue(commonStorageSOPClassUIDs.contains("1.2.840.10008.5.1.4.1.1.481.5"))
        // RT Dose Storage
        XCTAssertTrue(commonStorageSOPClassUIDs.contains("1.2.840.10008.5.1.4.1.1.481.2"))
    }
    
    // MARK: - FileStoreResult Tests
    
    func testFileStoreResultSuccess() {
        let result = FileStoreResult(
            index: 0,
            sopInstanceUID: "1.2.3.4.5.6.7.8.9",
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            success: true,
            status: .success,
            roundTripTime: 0.125,
            fileSize: 1024
        )
        
        XCTAssertEqual(result.index, 0)
        XCTAssertEqual(result.sopInstanceUID, "1.2.3.4.5.6.7.8.9")
        XCTAssertEqual(result.sopClassUID, "1.2.840.10008.5.1.4.1.1.2")
        XCTAssertTrue(result.success)
        XCTAssertTrue(result.status.isSuccess)
        XCTAssertFalse(result.hasWarning)
        XCTAssertEqual(result.roundTripTime, 0.125, accuracy: 0.001)
        XCTAssertEqual(result.fileSize, 1024)
        XCTAssertNil(result.errorMessage)
    }
    
    func testFileStoreResultFailure() {
        let result = FileStoreResult(
            index: 5,
            sopInstanceUID: "1.2.3.4.5.6",
            sopClassUID: "1.2.840.10008.5.1.4.1.1.7",
            success: false,
            status: .refusedOutOfResources,
            roundTripTime: 0.050,
            fileSize: 2048,
            errorMessage: "Storage full"
        )
        
        XCTAssertEqual(result.index, 5)
        XCTAssertFalse(result.success)
        XCTAssertTrue(result.status.isFailure)
        XCTAssertEqual(result.errorMessage, "Storage full")
    }
    
    func testFileStoreResultWarning() {
        let result = FileStoreResult(
            index: 2,
            sopInstanceUID: "1.2.3.4.5.6.7.8.9",
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            success: true,
            status: .warningCoercionOfDataElements,
            roundTripTime: 0.100,
            fileSize: 512
        )
        
        XCTAssertTrue(result.success)
        XCTAssertTrue(result.hasWarning)
    }
    
    func testFileStoreResultSuccessFactory() {
        let result = FileStoreResult.success(
            index: 1,
            sopInstanceUID: "1.2.3.4",
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            status: .success,
            roundTripTime: 0.200,
            fileSize: 4096
        )
        
        XCTAssertTrue(result.success)
        XCTAssertNil(result.errorMessage)
    }
    
    func testFileStoreResultFailureFactory() {
        let result = FileStoreResult.failure(
            index: 3,
            sopInstanceUID: "1.2.3.4",
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            status: .failedUnableToProcess,
            roundTripTime: 0.150,
            fileSize: 8192,
            errorMessage: "Processing error"
        )
        
        XCTAssertFalse(result.success)
        XCTAssertEqual(result.errorMessage, "Processing error")
    }
    
    func testFileStoreResultDescription() {
        let result = FileStoreResult(
            index: 0,
            sopInstanceUID: "1.2.3.4.5.6.7.8.9",
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            success: true,
            status: .success,
            roundTripTime: 0.125,
            fileSize: 1024
        )
        
        let description = result.description
        XCTAssertTrue(description.contains("SUCCESS"))
        XCTAssertTrue(description.contains("[0]"))
        XCTAssertTrue(description.contains("1.2.3.4.5.6.7.8.9"))
    }
    
    func testFileStoreResultHashable() {
        let result1 = FileStoreResult(
            index: 0,
            sopInstanceUID: "1.2.3.4",
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            success: true,
            status: .success,
            roundTripTime: 0.100,
            fileSize: 1024
        )
        let result2 = FileStoreResult(
            index: 0,
            sopInstanceUID: "1.2.3.4",
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            success: true,
            status: .success,
            roundTripTime: 0.100,
            fileSize: 1024
        )
        let result3 = FileStoreResult(
            index: 1,
            sopInstanceUID: "1.2.3.4",
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            success: true,
            status: .success,
            roundTripTime: 0.100,
            fileSize: 1024
        )
        
        XCTAssertEqual(result1, result2)
        XCTAssertNotEqual(result1, result3)
    }
    
    // MARK: - BatchStoreResult Tests
    
    func testBatchStoreResultSuccess() {
        let progress = BatchStoreProgress(total: 10, succeeded: 10, failed: 0, warnings: 0)
        let fileResults = (0..<10).map { index in
            FileStoreResult(
                index: index,
                sopInstanceUID: "1.2.3.4.5.\(index)",
                sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
                success: true,
                status: .success,
                roundTripTime: 0.100,
                fileSize: 1024
            )
        }
        
        let result = BatchStoreResult(
            progress: progress,
            fileResults: fileResults,
            totalBytesTransferred: 10240,
            totalTime: 1.5
        )
        
        XCTAssertTrue(result.allSucceeded)
        XCTAssertFalse(result.hasFailures)
        XCTAssertEqual(result.successfulFiles.count, 10)
        XCTAssertEqual(result.failedFiles.count, 0)
        XCTAssertEqual(result.totalBytesTransferred, 10240)
        XCTAssertEqual(result.totalTime, 1.5, accuracy: 0.001)
    }
    
    func testBatchStoreResultPartialFailure() {
        let progress = BatchStoreProgress(total: 10, succeeded: 7, failed: 2, warnings: 1)
        let fileResults = [
            FileStoreResult(index: 0, sopInstanceUID: "1.2.3.1", sopClassUID: "1.2.840.10008.5.1.4.1.1.2", success: true, status: .success, roundTripTime: 0.1, fileSize: 1024),
            FileStoreResult(index: 1, sopInstanceUID: "1.2.3.2", sopClassUID: "1.2.840.10008.5.1.4.1.1.2", success: false, status: .refusedOutOfResources, roundTripTime: 0.1, fileSize: 1024, errorMessage: "Out of resources"),
            FileStoreResult(index: 2, sopInstanceUID: "1.2.3.3", sopClassUID: "1.2.840.10008.5.1.4.1.1.2", success: true, status: .warningCoercionOfDataElements, roundTripTime: 0.1, fileSize: 1024)
        ]
        
        let result = BatchStoreResult(
            progress: progress,
            fileResults: fileResults,
            totalBytesTransferred: 3072,
            totalTime: 0.5
        )
        
        XCTAssertFalse(result.allSucceeded)
        XCTAssertTrue(result.hasFailures)
        XCTAssertEqual(result.failedFiles.count, 1)
    }
    
    func testBatchStoreResultAverageTransferRate() {
        let progress = BatchStoreProgress(total: 5, succeeded: 5)
        let result = BatchStoreResult(
            progress: progress,
            fileResults: [],
            totalBytesTransferred: 1_000_000, // 1 MB
            totalTime: 2.0 // 2 seconds
        )
        
        XCTAssertEqual(result.averageTransferRate, 500_000, accuracy: 1) // 500 KB/s
    }
    
    func testBatchStoreResultZeroTime() {
        let progress = BatchStoreProgress(total: 0)
        let result = BatchStoreResult(
            progress: progress,
            fileResults: [],
            totalBytesTransferred: 0,
            totalTime: 0
        )
        
        XCTAssertEqual(result.averageTransferRate, 0)
    }
    
    func testBatchStoreResultDescription() {
        let progress = BatchStoreProgress(total: 10, succeeded: 8, failed: 1, warnings: 1)
        let result = BatchStoreResult(
            progress: progress,
            fileResults: [],
            totalBytesTransferred: 1024 * 1024, // 1 MB
            totalTime: 5.0
        )
        
        let description = result.description
        XCTAssertTrue(description.contains("8 succeeded"))
        XCTAssertTrue(description.contains("1 failed"))
        XCTAssertTrue(description.contains("1 warnings"))
    }
    
    // MARK: - BatchStorageConfiguration Tests
    
    func testBatchStorageConfigurationDefault() {
        let config = BatchStorageConfiguration.default
        
        XCTAssertTrue(config.continueOnError)
        XCTAssertEqual(config.maxFilesPerAssociation, 0)
        XCTAssertEqual(config.delayBetweenFiles, 0)
    }
    
    func testBatchStorageConfigurationFailFast() {
        let config = BatchStorageConfiguration.failFast
        
        XCTAssertFalse(config.continueOnError)
    }
    
    func testBatchStorageConfigurationCustom() {
        let config = BatchStorageConfiguration(
            continueOnError: false,
            maxFilesPerAssociation: 100,
            delayBetweenFiles: 0.5
        )
        
        XCTAssertFalse(config.continueOnError)
        XCTAssertEqual(config.maxFilesPerAssociation, 100)
        XCTAssertEqual(config.delayBetweenFiles, 0.5, accuracy: 0.001)
    }
    
    func testBatchStorageConfigurationNegativeValues() {
        let config = BatchStorageConfiguration(
            continueOnError: true,
            maxFilesPerAssociation: -10,
            delayBetweenFiles: -1.0
        )
        
        // Negative values should be clamped to 0
        XCTAssertEqual(config.maxFilesPerAssociation, 0)
        XCTAssertEqual(config.delayBetweenFiles, 0)
    }
    
    func testBatchStorageConfigurationHashable() {
        let config1 = BatchStorageConfiguration(
            continueOnError: true,
            maxFilesPerAssociation: 50,
            delayBetweenFiles: 0.1
        )
        let config2 = BatchStorageConfiguration(
            continueOnError: true,
            maxFilesPerAssociation: 50,
            delayBetweenFiles: 0.1
        )
        let config3 = BatchStorageConfiguration(
            continueOnError: false,
            maxFilesPerAssociation: 50,
            delayBetweenFiles: 0.1
        )
        
        XCTAssertEqual(config1, config2)
        XCTAssertNotEqual(config1, config3)
    }
    
    // MARK: - StorageProgressEvent Tests
    
    func testStorageProgressEventProgress() {
        let progress = BatchStoreProgress(total: 10, succeeded: 5, failed: 1)
        let event = StorageProgressEvent.progress(progress)
        
        if case .progress(let p) = event {
            XCTAssertEqual(p.total, 10)
            XCTAssertEqual(p.succeeded, 5)
            XCTAssertEqual(p.failed, 1)
        } else {
            XCTFail("Expected progress event")
        }
    }
    
    func testStorageProgressEventFileResult() {
        let fileResult = FileStoreResult(
            index: 0,
            sopInstanceUID: "1.2.3.4",
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            success: true,
            status: .success,
            roundTripTime: 0.1,
            fileSize: 1024
        )
        let event = StorageProgressEvent.fileResult(fileResult)
        
        if case .fileResult(let result) = event {
            XCTAssertEqual(result.sopInstanceUID, "1.2.3.4")
            XCTAssertTrue(result.success)
        } else {
            XCTFail("Expected fileResult event")
        }
    }
    
    func testStorageProgressEventCompleted() {
        let progress = BatchStoreProgress(total: 5, succeeded: 5)
        let batchResult = BatchStoreResult(
            progress: progress,
            fileResults: [],
            totalBytesTransferred: 5120,
            totalTime: 1.0
        )
        let event = StorageProgressEvent.completed(batchResult)
        
        if case .completed(let result) = event {
            XCTAssertEqual(result.progress.total, 5)
            XCTAssertTrue(result.allSucceeded)
        } else {
            XCTFail("Expected completed event")
        }
    }
    
    func testStorageProgressEventError() {
        let error = DICOMNetworkError.connectionFailed("Test error")
        let event = StorageProgressEvent.error(error)
        
        if case .error(let e) = event {
            XCTAssertTrue(e is DICOMNetworkError)
        } else {
            XCTFail("Expected error event")
        }
    }
}
