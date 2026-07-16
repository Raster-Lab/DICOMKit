import Foundation
import Testing

@testable import DICOMNetwork

#if canImport(Network)

  private final class ControlledDICOMConnectionTransport: DICOMConnectionTransport,
    @unchecked Sendable
  {
    private let lock = NSLock()
    private let startRelease = DispatchSemaphore(value: 0)
    private let readyOnStart: Bool
    private let holdStartAfterReady: Bool
    private let completeSendsImmediately: Bool

    private var stateHandler: (@Sendable (DICOMConnectionTransportState) -> Void)?
    private var pendingSendCompletions: [@Sendable (String?) -> Void] = []
    private var recordedSends: [Data] = []
    private var recordedStartCount = 0
    private var recordedCancelCount = 0
    private var recordedForceCancelCount = 0
    private var deliveredReadyAndBlocked = false

    init(
      readyOnStart: Bool = false,
      holdStartAfterReady: Bool = false,
      completeSendsImmediately: Bool = true
    ) {
      self.readyOnStart = readyOnStart
      self.holdStartAfterReady = holdStartAfterReady
      self.completeSendsImmediately = completeSendsImmediately
    }

    var startCount: Int {
      lock.lock()
      defer { lock.unlock() }
      return recordedStartCount
    }

    var cancelCount: Int {
      lock.lock()
      defer { lock.unlock() }
      return recordedCancelCount
    }

    var forceCancelCount: Int {
      lock.lock()
      defer { lock.unlock() }
      return recordedForceCancelCount
    }

    var sentData: [Data] {
      lock.lock()
      defer { lock.unlock() }
      return recordedSends
    }

    var isBlockedAfterReady: Bool {
      lock.lock()
      defer { lock.unlock() }
      return deliveredReadyAndBlocked
    }

    func setStateUpdateHandler(
      _ handler: (@Sendable (DICOMConnectionTransportState) -> Void)?
    ) {
      lock.lock()
      stateHandler = handler
      lock.unlock()
    }

    func start() {
      lock.lock()
      recordedStartCount += 1
      let handler = stateHandler
      lock.unlock()

      guard readyOnStart else { return }
      handler?(.ready)

      if holdStartAfterReady {
        lock.lock()
        deliveredReadyAndBlocked = true
        lock.unlock()
        startRelease.wait()
      }
    }

    func send(content: Data, completion: @escaping @Sendable (String?) -> Void) {
      lock.lock()
      recordedSends.append(content)
      if !completeSendsImmediately {
        pendingSendCompletions.append(completion)
      }
      lock.unlock()

      if completeSendsImmediately {
        completion(nil)
      }
    }

    func receive(
      minimumIncompleteLength _: Int,
      maximumLength _: Int,
      completion: @escaping @Sendable (Data?, Bool, String?) -> Void
    ) {
      completion(nil, true, "No receive fixture configured")
    }

    func cancel() {
      lock.lock()
      recordedCancelCount += 1
      let handler = stateHandler
      lock.unlock()
      handler?(.cancelled)
    }

    func forceCancel() {
      lock.lock()
      recordedForceCancelCount += 1
      let handler = stateHandler
      lock.unlock()
      handler?(.cancelled)
    }

    func becomeReady() {
      lock.lock()
      let handler = stateHandler
      lock.unlock()
      handler?(.ready)
    }

    func releaseStart() {
      startRelease.signal()
    }

    func completePendingSendsTwice() {
      lock.lock()
      let completions = pendingSendCompletions
      pendingSendCompletions.removeAll()
      lock.unlock()

      for completion in completions {
        completion(nil)
        completion("late duplicate callback")
      }
    }
  }

  @Suite("DICOM Client DIMSE Security Propagation")
  struct DICOMClientSecurityPropagationTests {
    private let tls = TLSConfiguration(
      minimumVersion: .tlsProtocol13,
      maximumVersion: .tlsProtocol13,
      certificateValidation: .disabled,
      applicationProtocols: ["dicom-test"]
    )

    private let identity = UserIdentity.usernameAndPasscode(
      username: "diagnostic-user",
      passcode: "ephemeral-passcode",
      positiveResponseRequested: true
    )

    private func clientConfiguration() throws -> DICOMClientConfiguration {
      try DICOMClientConfiguration(
        host: "pacs.example.test",
        port: 2762,
        callingAE: "WORKSTATION",
        calledAE: "PACS",
        timeout: 17,
        maxPDUSize: 32_768,
        implementationClassUID: "1.2.826.0.1.3680043.10.543.99",
        implementationVersionName: "SECURITY_TEST",
        tlsConfiguration: tls,
        userIdentity: identity
      )
    }

    private func expectExactSecurity(_ association: AssociationConfiguration) {
      #expect(association.tlsConfiguration == tls)
      #expect(association.tlsEnabled)
      #expect(association.userIdentity == identity)
      #expect(association.timeout == 17)
      #expect(association.maxPDUSize == 32_768)
      #expect(association.implementationClassUID == "1.2.826.0.1.3680043.10.543.99")
      #expect(association.implementationVersionName == "SECURITY_TEST")
    }

    private func diagnosticText<T>(for value: T) -> String {
      var text = "describing=\(String(describing: value))\n"
      text += "reflecting=\(String(reflecting: value))\n"
      dump(value, to: &text)
      for child in Mirror(reflecting: value).children {
        text += "child[\(child.label ?? "_")]=\(String(reflecting: child.value))\n"
      }
      return text
    }

    private func occurrenceCount(of needle: String, in text: String) -> Int {
      text.components(separatedBy: needle).count - 1
    }

    private func eventually(
      _ condition: @escaping @Sendable () -> Bool
    ) async -> Bool {
      for _ in 0..<200 {
        if condition() { return true }
        try? await Task.sleep(for: .milliseconds(5))
      }
      return condition()
    }

    private func credentialBearingAssociation(
      transport: ControlledDICOMConnectionTransport,
      timeout: TimeInterval = 5
    ) throws -> Association {
      let configuration = AssociationConfiguration(
        callingAETitle: AETitle("WORKSTATION"),
        calledAETitle: AETitle("PACS"),
        host: "pacs.example.test",
        port: 2762,
        implementationClassUID: "1.2.826.0.1.3680043.10.543.99",
        timeout: timeout,
        tlsConfiguration: nil,
        userIdentity: .usernameAndPasscode(
          username: "CANCELLED_USER_MUST_NOT_SEND",
          passcode: "CANCELLED_SECRET_MUST_NOT_SEND"
        )
      )
      return Association(configuration: configuration) { configuration in
        DICOMConnection(
          host: configuration.host,
          port: configuration.port,
          maxPDUSize: configuration.maxPDUSize,
          timeout: configuration.timeout,
          tlsConfiguration: configuration.tlsConfiguration,
          transport: transport
        )
      }
    }

    private func verificationContext() throws -> PresentationContext {
      try PresentationContext(
        id: 1,
        abstractSyntax: verificationSOPClassUID,
        transferSyntaxes: [implicitVRLittleEndianTransferSyntaxUID]
      )
    }

    @Test("Association configuration preserves the full TLS policy")
    func associationConfigurationPreservesExactTLSPolicy() throws {
      let association = AssociationConfiguration(
        callingAETitle: AETitle("WORKSTATION"),
        calledAETitle: AETitle("PACS"),
        host: "pacs.example.test",
        port: 2762,
        implementationClassUID: "1.2.3",
        tlsConfiguration: tls,
        userIdentity: identity
      )

      #expect(association.tlsConfiguration == tls)
      #expect(association.tlsConfiguration != .default)
      #expect(association.userIdentity == identity)

      let connection = try Association(configuration: association).makeConnection()
      #expect(connection.tlsConfiguration == tls)
      #expect(connection.tlsConfiguration != .default)
    }

    @Test("Echo and association diagnostics keep TLS and user identity")
    func echoConfigurationKeepsSecurity() throws {
      let operation = try clientConfiguration().verificationServiceConfiguration
      #expect(operation.tlsConfiguration == tls)
      #expect(operation.userIdentity == identity)

      expectExactSecurity(
        operation.associationConfiguration(host: "pacs.example.test", port: 2762)
      )
    }

    @Test("C-FIND keeps TLS and user identity")
    func queryConfigurationKeepsSecurity() throws {
      let operation = try clientConfiguration().queryServiceConfiguration
      #expect(operation.tlsConfiguration == tls)
      #expect(operation.userIdentity == identity)

      expectExactSecurity(
        operation.associationConfiguration(host: "pacs.example.test", port: 2762)
      )
    }

    @Test("C-GET and C-MOVE keep TLS and user identity")
    func retrieveConfigurationKeepsSecurity() throws {
      let operation = try clientConfiguration().retrieveServiceConfiguration
      #expect(operation.tlsConfiguration == tls)
      #expect(operation.userIdentity == identity)

      expectExactSecurity(
        operation.associationConfiguration(host: "pacs.example.test", port: 2762)
      )
    }

    @Test("Single and batch C-STORE keep TLS and user identity")
    func storageConfigurationKeepsSecurity() throws {
      let operation = try clientConfiguration().storageServiceConfiguration(priority: .high)
      #expect(operation.tlsConfiguration == tls)
      #expect(operation.userIdentity == identity)
      #expect(operation.priority == .high)

      expectExactSecurity(
        operation.associationConfiguration(host: "pacs.example.test", port: 2762)
      )
    }

    @Test("Connection pool keeps the exact client transport and identity")
    func connectionPoolConfigurationKeepsSecurity() throws {
      let association = try clientConfiguration().pooledAssociationConfiguration()
      expectExactSecurity(association)
      #expect(association.host == "pacs.example.test")
      #expect(association.port == 2762)
      #expect(association.artimTimeout == 30)
    }

    @Test("Storage client keeps each server's transport and identity")
    func storageClientConfigurationKeepsSecurity() throws {
      let server = ServerEntry(
        host: "storage.example.test",
        port: 2763,
        aeTitle: AETitle("STORE_SCP"),
        tlsConfiguration: tls,
        userIdentity: identity,
        maxPDUSize: 65_536,
        timeout: 29
      )
      let client = DICOMStorageClientConfiguration(
        callingAETitle: AETitle("WORKSTATION"),
        serverPool: ServerPool(),
        implementationClassUID: "1.2.826.0.1.3680043.10.543.100",
        implementationVersionName: "STORAGE_SECURITY"
      )

      let operation = client.storageConfiguration(for: server, priority: .low)
      #expect(operation.callingAETitle == AETitle("WORKSTATION"))
      #expect(operation.calledAETitle == AETitle("STORE_SCP"))
      #expect(operation.timeout == 29)
      #expect(operation.maxPDUSize == 65_536)
      #expect(operation.implementationClassUID == "1.2.826.0.1.3680043.10.543.100")
      #expect(operation.implementationVersionName == "STORAGE_SECURITY")
      #expect(operation.priority == .low)
      #expect(operation.tlsConfiguration == tls)
      #expect(operation.userIdentity == identity)

      let association = operation.associationConfiguration(
        host: server.host,
        port: server.port
      )
      #expect(association.tlsConfiguration == tls)
      #expect(association.userIdentity == identity)
    }

    @Test("Boolean TLS compatibility initializer maps only to the default policy")
    func booleanTLSInitializerRemainsCompatible() {
      let enabled = AssociationConfiguration(
        callingAETitle: AETitle("WORKSTATION"),
        calledAETitle: AETitle("PACS"),
        host: "pacs.example.test",
        implementationClassUID: "1.2.3",
        tlsEnabled: true
      )
      let disabled = AssociationConfiguration(
        callingAETitle: AETitle("WORKSTATION"),
        calledAETitle: AETitle("PACS"),
        host: "pacs.example.test",
        implementationClassUID: "1.2.3"
      )

      #expect(enabled.tlsConfiguration == .default)
      #expect(enabled.tlsEnabled)
      #expect(disabled.tlsConfiguration == nil)
      #expect(!disabled.tlsEnabled)
    }

    @Test("Association diagnostic result reports association facts, not DIMSE success")
    func associationDiagnosticResultIsAssociationScoped() {
      let context = AcceptedPresentationContext(
        id: 1,
        result: .acceptance,
        transferSyntax: explicitVRLittleEndianTransferSyntaxUID
      )
      let result = AssociationDiagnosticResult(
        associationRoundTripTime: 0.125,
        remoteAETitle: "PACS",
        acceptedPresentationContexts: [context],
        maxPDUSize: 16_384,
        remoteImplementationClassUID: "1.2.3.4",
        remoteImplementationVersionName: "REMOTE_1",
        userIdentityServerResponse: nil,
        usedTLS: true
      )

      #expect(result.acceptedPresentationContexts == [context])
      #expect(result.usedTLS)
      #expect(result.remoteAETitle == "PACS")
    }

    @Test("Credential-bearing DIMSE values redact descriptions and recursive reflection")
    func credentialValuesAreReflectionSafe() throws {
      let username = "USERNAME_SENTINEL_7D4B"
      let passcode = "PASSCODE_SENTINEL_8E5C"
      let jwt = "JWT_SENTINEL_9F6D"
      let p12Password = "PKCS12_PASSWORD_SENTINEL_A07E"
      let keychainLabel = "KEYCHAIN_LABEL_SENTINEL_B18F"

      let usernameIdentity = UserIdentity.usernameAndPasscode(
        username: username,
        passcode: passcode,
        positiveResponseRequested: true
      )
      let jwtIdentity = UserIdentity.jwt(token: jwt)
      let clientIdentity = ClientIdentity(
        pkcs12Data: Data("PKCS12_DATA_SENTINEL_C290".utf8),
        password: p12Password
      )
      let keychainIdentity = ClientIdentity(keychainLabel: keychainLabel)
      let credentialTLS = TLSConfiguration(
        minimumVersion: .tlsProtocol13,
        maximumVersion: .tlsProtocol13,
        certificateValidation: .disabled,
        clientIdentity: clientIdentity
      )
      let association = AssociationConfiguration(
        callingAETitle: AETitle("WORKSTATION"),
        calledAETitle: AETitle("PACS"),
        host: "pacs.example.test",
        implementationClassUID: "1.2.3",
        tlsConfiguration: credentialTLS,
        userIdentity: usernameIdentity
      )
      let client = try DICOMClientConfiguration(
        host: "pacs.example.test",
        callingAE: "WORKSTATION",
        calledAE: "PACS",
        tlsConfiguration: credentialTLS,
        userIdentity: usernameIdentity
      )
      let query = QueryConfiguration(
        callingAETitle: AETitle("WORKSTATION"),
        calledAETitle: AETitle("PACS"),
        tlsConfiguration: credentialTLS,
        userIdentity: jwtIdentity
      )
      let retrieve = RetrieveConfiguration(
        callingAETitle: AETitle("WORKSTATION"),
        calledAETitle: AETitle("PACS"),
        tlsConfiguration: credentialTLS,
        userIdentity: usernameIdentity
      )
      let storage = StorageConfiguration(
        callingAETitle: AETitle("WORKSTATION"),
        calledAETitle: AETitle("PACS"),
        tlsConfiguration: credentialTLS,
        userIdentity: usernameIdentity
      )
      let verification = VerificationConfiguration(
        callingAETitle: AETitle("WORKSTATION"),
        calledAETitle: AETitle("PACS"),
        tlsConfiguration: credentialTLS,
        userIdentity: usernameIdentity
      )
      let server = ServerEntry(
        host: "pacs.example.test",
        aeTitle: AETitle("PACS"),
        tlsConfiguration: credentialTLS,
        userIdentity: usernameIdentity
      )
      var serverPool = ServerPool()
      serverPool.addServer(server)
      let storageClient = DICOMStorageClientConfiguration(
        callingAETitle: AETitle("WORKSTATION"),
        serverPool: serverPool
      )

      let output = [
        diagnosticText(for: usernameIdentity),
        diagnosticText(for: jwtIdentity),
        diagnosticText(for: clientIdentity),
        diagnosticText(for: clientIdentity.source),
        diagnosticText(for: keychainIdentity),
        diagnosticText(for: keychainIdentity.source),
        diagnosticText(for: credentialTLS),
        diagnosticText(for: association),
        diagnosticText(for: client),
        diagnosticText(for: query),
        diagnosticText(for: retrieve),
        diagnosticText(for: storage),
        diagnosticText(for: verification),
        diagnosticText(for: server),
        diagnosticText(for: storageClient),
      ].joined(separator: "\n")

      for secret in [username, passcode, jwt, p12Password, keychainLabel] {
        #expect(!output.contains(secret), "Reflection leaked credential marker: \(secret)")
      }
      #expect(output.contains("identityType"))
      #expect(output.contains("minimumVersion"))
      #expect(output.contains("hasClientIdentity"))
    }

    @Test("Every DICOMClient DIMSE route consumes an exact security projection")
    func dicomClientRoutesCannotSilentlyFallBackToLegacyConvenienceAPIs() throws {
      let repositoryRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
      let sourceURL =
        repositoryRoot
        .appendingPathComponent("Sources/DICOMNetwork/DICOMClient.swift")
      let source = try String(contentsOf: sourceURL, encoding: .utf8)
      let operationSource = try #require(
        source.components(separatedBy: "// MARK: - Verification (C-ECHO)").last?
          .components(separatedBy: "// MARK: - Retry Logic").first
      )

      #expect(
        occurrenceCount(
          of: "configuration: self.configuration.verificationServiceConfiguration",
          in: operationSource
        ) == 3
      )
      #expect(
        occurrenceCount(
          of: "configuration: self.configuration.queryServiceConfiguration",
          in: operationSource
        ) == 3
      )
      #expect(
        occurrenceCount(
          of: "configuration.retrieveServiceConfiguration",
          in: operationSource
        ) == 6
      )
      #expect(
        occurrenceCount(
          of: "storageServiceConfiguration(priority: priority)",
          in: operationSource
        ) == 3
      )
      #expect(!operationSource.contains("callingAE:"))
      #expect(!operationSource.contains("calledAE:"))
    }

    @Test("Batch C-STORE terminates its producer when the stream is abandoned")
    func batchStoreProducerRetainsCancellationHooks() throws {
      let repositoryRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
      let sourceURL =
        repositoryRoot
        .appendingPathComponent("Sources/DICOMNetwork/StorageService.swift")
      let source = try String(contentsOf: sourceURL, encoding: .utf8)
      let batchSource = try #require(
        source.components(separatedBy: "private static func makeBatchStoreStream").last?
          .components(separatedBy: "/// Performs the batch C-STORE operation").first
      )
      let producerSource = try #require(
        source.components(separatedBy: "private static func performBatchStore").last?
          .components(separatedBy: "/// Performs the C-STORE request/response exchange").first
      )

      #expect(batchSource.contains("continuation.onTermination"))
      #expect(batchSource.contains("producer.cancel()"))
      #expect(batchSource.contains("catch is CancellationError"))
      #expect(occurrenceCount(of: "Task.checkCancellation()", in: producerSource) >= 3)
    }

    @Test("Cancelling connection setup prevents a later credential-bearing association send")
    func cancelledConnectCannotLaterSendUserIdentity() async throws {
      let transport = ControlledDICOMConnectionTransport()
      let association = try credentialBearingAssociation(transport: transport)
      let context = try verificationContext()

      let request = Task { () -> String in
        do {
          _ = try await association.request(presentationContexts: [context])
          return "unexpected success"
        } catch is CancellationError {
          return "cancelled"
        } catch {
          return String(reflecting: error)
        }
      }

      #expect(await eventually { transport.startCount == 1 })
      request.cancel()
      #expect(await request.value == "cancelled")
      #expect(transport.cancelCount == 1)
      #expect(transport.sentData.isEmpty)

      // Simulate a stale late-ready callback. It must not resurrect the cancelled
      // connection or submit the A-ASSOCIATE-RQ containing User Identity.
      transport.becomeReady()
      await Task.yield()
      #expect(transport.sentData.isEmpty)
    }

    // Parks a cooperative-pool thread in `startRelease.wait()` (see
    // `ControlledDICOMConnectionTransport.start()`) to force a deterministic race
    // window; under `swift test --parallel` that can starve the pool so
    // `releaseStart()` never gets scheduled. Bound the damage to a fast, clear
    // failure instead of a multi-hour CI hang if that ever happens.
    @Test(
      "Cancellation after transport readiness is rechecked before A-ASSOCIATE-RQ",
      .timeLimit(.minutes(1))
    )
    func cancellationAfterReadyStillPreventsUserIdentitySend() async throws {
      let transport = ControlledDICOMConnectionTransport(
        readyOnStart: true,
        holdStartAfterReady: true
      )
      let association = try credentialBearingAssociation(transport: transport)
      let context = try verificationContext()

      let request = Task { () -> String in
        do {
          _ = try await association.request(presentationContexts: [context])
          return "unexpected success"
        } catch is CancellationError {
          return "cancelled"
        } catch {
          return String(reflecting: error)
        }
      }

      #expect(await eventually { transport.isBlockedAfterReady })
      let releaseBlockedStart = Task.detached {
        // `Task.cancel()` runs cancellation handlers synchronously. Release the
        // intentionally blocked transport from another executor after the task's
        // cancellation bit is set, so the association-level recheck owns the race.
        try? await Task.sleep(for: .milliseconds(10))
        transport.releaseStart()
      }
      request.cancel()
      await releaseBlockedStart.value

      #expect(await request.value == "cancelled")
      #expect(transport.sentData.isEmpty)
    }

    @Test("An already-expired timeout aborts before transport startup")
    func expiredTimeoutCannotStartCredentialTransport() async throws {
      let transport = ControlledDICOMConnectionTransport()
      let association = try credentialBearingAssociation(
        transport: transport,
        timeout: 0
      )
      let context = try verificationContext()

      let request = Task { () -> String in
        do {
          _ = try await association.request(presentationContexts: [context])
          return "unexpected success"
        } catch DICOMNetworkError.timeout {
          return "timeout"
        } catch {
          return String(reflecting: error)
        }
      }

      #expect(await request.value == "timeout")
      #expect(transport.forceCancelCount == 1)
      #expect(transport.startCount == 0)
      #expect(transport.sentData.isEmpty)

      // The terminal path clears its state callback; a stale late-ready signal
      // cannot resurrect the transport or send the identity-bearing request.
      transport.becomeReady()
      await Task.yield()
      #expect(transport.sentData.isEmpty)
    }

    @Test("Cancelling a pending send aborts transport and ignores duplicate late callbacks")
    func pendingSendCancellationResumesExactlyOnce() async throws {
      let transport = ControlledDICOMConnectionTransport(
        readyOnStart: true,
        completeSendsImmediately: false
      )
      let connection = DICOMConnection(
        host: "pacs.example.test",
        timeout: 5,
        transport: transport
      )
      try await connection.connect()

      let send = Task { () -> String in
        do {
          try await connection.send(data: Data("credential-bearing-pdu".utf8))
          return "unexpected success"
        } catch is CancellationError {
          return "cancelled"
        } catch {
          return String(reflecting: error)
        }
      }

      #expect(await eventually { transport.sentData.count == 1 })
      send.cancel()
      #expect(await send.value == "cancelled")
      #expect(transport.forceCancelCount == 1)

      // A transport may race cancellation with its completion callback. Replaying
      // both success and failure must not trap from a double continuation resume.
      transport.completePendingSendsTwice()
      await Task.yield()
      #expect(transport.forceCancelCount == 1)
    }

    @Test("A task cancelled before send never submits bytes to transport")
    func alreadyCancelledSendDoesNotSubmit() async throws {
      let transport = ControlledDICOMConnectionTransport(readyOnStart: true)
      let connection = DICOMConnection(
        host: "pacs.example.test",
        timeout: 5,
        transport: transport
      )
      try await connection.connect()

      let send = Task { () -> String in
        withUnsafeCurrentTask { task in
          task?.cancel()
        }
        do {
          try await connection.send(data: Data("must-not-send".utf8))
          return "unexpected success"
        } catch is CancellationError {
          return "cancelled"
        } catch {
          return String(reflecting: error)
        }
      }

      #expect(await send.value == "cancelled")
      #expect(transport.sentData.isEmpty)
      #expect(transport.forceCancelCount == 1)
    }
  }

#endif
