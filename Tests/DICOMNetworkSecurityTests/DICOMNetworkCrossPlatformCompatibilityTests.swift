import DICOMCore
import Foundation
import Testing

@testable import DICOMNetwork

@Suite("DICOM Network Cross-Platform Compatibility")
struct DICOMNetworkCrossPlatformCompatibilityTests {
  @Test("Legacy configuration APIs compile without Network.framework TLS types")
  func legacyConfigurationAPIsRemainAvailable() {
    let calling = AETitle("WORKSTATION")
    let called = AETitle("PACS")
    let identity = UserIdentity.username("compatibility-user")

    let association = AssociationConfiguration(
      callingAETitle: calling,
      calledAETitle: called,
      host: "pacs.example.test",
      implementationClassUID: "1.2.3",
      tlsEnabled: true,
      userIdentity: identity
    )
    let query = QueryConfiguration(
      callingAETitle: calling,
      calledAETitle: called,
      userIdentity: identity
    )
    let retrieve = RetrieveConfiguration(
      callingAETitle: calling,
      calledAETitle: called,
      userIdentity: identity
    )
    let storage = StorageConfiguration(
      callingAETitle: calling,
      calledAETitle: called,
      userIdentity: identity
    )
    let verification = VerificationConfiguration(
      callingAETitle: calling,
      calledAETitle: called,
      userIdentity: identity
    )

    #expect(association.tlsEnabled)
    #expect(association.userIdentity == identity)
    #expect(query.userIdentity == identity)
    #expect(retrieve.userIdentity == identity)
    #expect(storage.userIdentity == identity)
    #expect(verification.userIdentity == identity)

    #if canImport(Network)
      #expect(association.tlsConfiguration == .default)
      #expect(query.tlsConfiguration == nil)
      #expect(retrieve.tlsConfiguration == nil)
      #expect(storage.tlsConfiguration == nil)
      #expect(verification.tlsConfiguration == nil)
    #endif
  }

  @Test("Legacy initializer function types remain source compatible")
  func legacyInitializerFunctionTypesRemainSourceCompatible() {
    typealias AssociationFactory = (
      AETitle, AETitle, String, UInt16, UInt32, String, String?, TimeInterval,
      TimeInterval?, Bool, UserIdentity?
    ) -> AssociationConfiguration
    typealias QueryFactory = (
      AETitle, AETitle, TimeInterval, UInt32, String, String?,
      QueryRetrieveInformationModel, UserIdentity?
    ) -> QueryConfiguration
    typealias RetrieveFactory = (
      AETitle, AETitle, TimeInterval, UInt32, String, String?,
      QueryRetrieveInformationModel, UserIdentity?
    ) -> RetrieveConfiguration
    typealias StorageFactory = (
      AETitle, AETitle, TimeInterval, UInt32, String, String?, DIMSEPriority,
      UserIdentity?, TranscodingConfiguration?
    ) -> StorageConfiguration
    typealias VerificationFactory = (
      AETitle, AETitle, TimeInterval, UInt32, String, String?, UserIdentity?
    ) -> VerificationConfiguration

    let _: AssociationFactory = AssociationConfiguration.init
    let _: QueryFactory = QueryConfiguration.init
    let _: RetrieveFactory = RetrieveConfiguration.init
    let _: StorageFactory = StorageConfiguration.init
    let _: VerificationFactory = VerificationConfiguration.init
  }

  #if canImport(Network)
    @Test("Legacy service function types remain source compatible")
    func legacyServiceFunctionTypesRemainSourceCompatible() {
      typealias ProgressHandler = (@Sendable (RetrieveProgress) -> Void)?
      typealias GetStream = AsyncStream<DICOMRetrieveService.GetEvent>

      let _: (String, UInt16, String, String, TimeInterval) async throws -> Bool =
        DICOMVerificationService.verify
      let _: (String, UInt16, String, String, TimeInterval) async throws -> VerificationResult =
        DICOMVerificationService.echo

      let _:
        (String, UInt16, String, String, QueryKeys?, TimeInterval) async throws -> [StudyResult] =
          DICOMQueryService.findStudies
      let _:
        (String, UInt16, String, String, String, QueryKeys?, TimeInterval) async throws ->
          [SeriesResult] =
          DICOMQueryService.findSeries
      let _:
        (
          String, UInt16, String, String, String, String, QueryKeys?, TimeInterval
        ) async throws -> [InstanceResult] = DICOMQueryService.findInstances

      let _:
        (
          String, UInt16, String, String, String, String, ProgressHandler, TimeInterval
        ) async throws -> RetrieveResult = DICOMRetrieveService.moveStudy
      let _:
        (
          String, UInt16, String, String, String, String, String, ProgressHandler, TimeInterval
        ) async throws -> RetrieveResult = DICOMRetrieveService.moveSeries
      let _:
        (
          String, UInt16, String, String, String, String, String, String, ProgressHandler,
          TimeInterval
        ) async throws -> RetrieveResult = DICOMRetrieveService.moveInstance

      let _:
        (
          String, UInt16, String, String, String, [String]?, String?, TimeInterval
        ) async throws -> GetStream = DICOMRetrieveService.getStudy
      let _:
        (
          String, UInt16, String, String, String, String, [String]?, String?, TimeInterval
        ) async throws -> GetStream = DICOMRetrieveService.getSeries
      let _:
        (
          String, UInt16, String, String, String, String, String, [String]?, String?, TimeInterval
        ) async throws -> GetStream = DICOMRetrieveService.getInstance

      let _:
        (
          Data, String, UInt16, String, String, DIMSEPriority, TimeInterval
        ) async throws -> StoreResult = DICOMStorageService.store
      let _:
        (
          Data, String, String, UInt16, String, String, DIMSEPriority, TimeInterval
        ) async throws -> StoreResult = DICOMStorageService.store
      let _:
        (
          Data, String, String, String, String, UInt16, String, String, DIMSEPriority, TimeInterval
        ) async throws -> StoreResult = DICOMStorageService.store
      let _:
        (
          [Data], String, UInt16, String, String, DIMSEPriority, TimeInterval,
          BatchStorageConfiguration
        ) async throws -> AsyncThrowingStream<StorageProgressEvent, any Error> =
          DICOMStorageService.storeBatch
    }
  #endif
}
