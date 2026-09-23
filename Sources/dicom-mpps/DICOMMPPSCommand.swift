import Foundation
import ArgumentParser
import DICOMCore
import DICOMNetwork

@main
struct DICOMMPPSCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "dicom-mpps",
        abstract: "DICOM Modality Performed Procedure Step (MPPS) operations",
        discussion: """
            Create and update DICOM Modality Performed Procedure Step (MPPS) instances.
            Implements the MPPS SOP Class for notifying PACS/RIS systems about
            procedure execution status.
            
            URL Format:
              hostname               - PACS server hostname or IP address
              hostname:port          - Hostname with embedded port
              --port port            - Optional explicit port (default: 11112)
            
            Examples:
              # Create MPPS (procedure started)
              dicom-mpps create server --port 11112 \\
                --aet MODALITY --called-aet PACS_SCP \\
                --study-uid 1.2.3.4.5.6.7.8.9 \\
                --status "IN PROGRESS"
              
              # Update MPPS (procedure completed)
              dicom-mpps update server --port 11112 \\
                --aet MODALITY \\
                --mpps-uid 1.2.840.113619.2.xxx \\
                --status COMPLETED

              # Discontinue with a coded reason (CID 9300, scheme DCM)
              dicom-mpps update server --port 11112 \\
                --aet MODALITY \\
                --mpps-uid 1.2.840.113619.2.xxx \\
                --status DISCONTINUED \\
                --discontinuation-reason "110513|DCM|Doctor cancelled procedure"
            
            Reference: PS3.4 Annex F - Modality Performed Procedure Step SOP Class
            """,
        version: "1.0.0",
        subcommands: [Create.self, Update.self]
    )
    
    // MARK: - Shared Helper Functions
    
    /// Resolves the final host and port from ``--host`` and ``--port`` options.
    static func resolveHostPort(host: String, port: UInt16?) -> (host: String, port: UInt16) {
        var resolvedHost = host
        var resolvedPort: UInt16 = port ?? 11112

        if resolvedHost.hasPrefix("pacs://") {
            resolvedHost = String(resolvedHost.dropFirst(7))
        }

        if let lastColon = resolvedHost.lastIndex(of: ":") {
            let portString = String(resolvedHost[resolvedHost.index(after: lastColon)...])
            if let embeddedPort = UInt16(portString) {
                resolvedHost = String(resolvedHost[..<lastColon])
                if port == nil {
                    resolvedPort = embeddedPort
                }
            }
        }

        return (resolvedHost, resolvedPort)
    }
    
    static func parseStatus(_ statusString: String) throws -> MPPSStatus {
        switch statusString.uppercased().replacingOccurrences(of: " ", with: "") {
        case "INPROGRESS", "IN_PROGRESS":
            return .inProgress
        case "COMPLETED":
            return .completed
        case "DISCONTINUED":
            return .discontinued
        default:
            throw ValidationError("Invalid status. Use 'IN PROGRESS', 'COMPLETED', or 'DISCONTINUED'")
        }
    }

    /// Parses a `CODE|SCHEME|MEANING` coded entry (e.g. `110513|DCM|Doctor cancelled procedure`).
    ///
    /// The grammar lives in `MPPSCodedEntry.parse` (DICOMNetwork) so this CLI and the
    /// CLI Workshop's matching field accept exactly the same input and reject it with
    /// the same wording.
    static func parseCodedEntry(_ raw: String, option: String) throws -> MPPSCodedEntry {
        guard let entry = MPPSCodedEntry.parse(raw) else {
            throw ValidationError(MPPSCodedEntry.parseErrorMessage(option: option))
        }
        return entry
    }

    /// Prints an SCP warning status to stderr — the operation was performed, but
    /// the SCP coerced or dropped attributes (PS3.7 Annex C).
    static func reportWarning(_ result: MPPSOperationResult) {
        if let warning = result.warning {
            FileHandle.standardError.write(Data(
                "warning: SCP completed the operation with \(warning) — attributes may have been coerced or dropped\n".utf8))
        }
    }
}

// MARK: - Create Subcommand

extension DICOMMPPSCommand {
    struct Create: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "create",
            abstract: "Create MPPS instance (N-CREATE)"
        )
        
        @Argument(help: "PACS server hostname or IP address, optionally with port (host:port)")
        var host: String
        
        @Option(name: .long, help: "PACS server port (default: 11112)")
        var port: UInt16?
        
        @Option(name: .long, help: "Local Application Entity Title (calling AE)")
        var aet: String
        
        @Option(name: .long, help: "Remote Application Entity Title (default: ANY-SCP)")
        var calledAet: String = "ANY-SCP"
        
        @Option(name: .long, help: "Study Instance UID for the procedure")
        var studyUid: String
        
        @Option(name: .long, help: "Patient's Name (0010,0010) in DICOM format e.g. DOE^JOHN")
        var patientName: String?
        
        @Option(name: .long, help: "Patient ID (0010,0020)")
        var patientId: String?
        
        @Option(name: .long, help: "Initial status — must be IN PROGRESS; N-CREATE always starts the step (default: IN PROGRESS)")
        var status: String = "IN PROGRESS"
        
        @Option(name: .long, help: "Scheduled Procedure Step ID from the MWL item — links this MPPS to the worklist entry so the server can transition its status (0040,0009)")
        var spsId: String?
        
        @Option(name: .long, help: "Accession Number linking the procedure to the imaging order (0008,0050)")
        var accessionNumber: String?

        @Option(name: .long, help: ArgumentHelp(stringLiteral: ModalityOptionValidator.helpText("value")))
        var modality: String?

        @Flag(name: .long, help: "Reject a --modality value that is not a current DICOM Defined Term")
        var strictModality: Bool = false

        @Option(name: .long, help: "Patient's Birth Date (0010,0030) YYYYMMDD")
        var patientBirthDate: String?

        @Option(name: .long, help: "Patient's Sex (0010,0040): M, F or O")
        var patientSex: String?

        @Option(name: .long, help: "Study ID (0020,0010)")
        var studyId: String?

        @Option(name: .long, help: "Performed Station Name (0040,0242)")
        var stationName: String?

        @Option(name: .long, help: "Performed Location (0040,0243)")
        var performedLocation: String?

        @Option(name: .long, help: "Performed Procedure Step ID (0040,0253) (default: 1)")
        var procedureStepId: String?

        @Option(name: .long, help: "Performed Procedure Step Description (0040,0254)")
        var procedureStepDescription: String?

        @Option(name: .long, help: "Performing Physician's Name (0008,1050), DICOM PN format")
        var performingPhysician: String?

        @Option(name: .long, help: "Requested Procedure ID (0040,1001) from the MWL item")
        var requestedProcedureId: String?

        @Option(name: .long, help: "Requested Procedure Description (0032,1060) from the MWL item")
        var requestedProcedureDescription: String?

        @Option(name: .long, help: "Scheduled Procedure Step Description (0040,0007) from the MWL item")
        var spsDescription: String?

        @Option(name: .long, help: "Referenced Study SOP Instance UID (0008,1155) from the MWL item's Referenced Study Sequence")
        var referencedStudyUid: String?

        @Option(name: .long, help: "Force the Specific Character Set (0008,0005), e.g. ISO_IR 100 or ISO_IR 192. By default the narrowest set that represents every text value is chosen")
        var specificCharacterSet: String?
        
        @Option(name: .long, help: "Connection timeout in seconds (default: 60)")
        var timeout: Int = 60
        
        @Flag(name: .shortAndLong, help: "Show verbose output")
        var verbose: Bool = false
        
        mutating func run() async throws {
            // Validate --modality up front: an unrecognized code otherwise
            // reaches the PACS as a filter that silently matches nothing.
            modality = try ModalityOptionValidator.resolve(
                modality, strict: strictModality, verbose: verbose)

            #if canImport(Network)
            let serverInfo = DICOMMPPSCommand.resolveHostPort(host: host, port: port)

            // Parse status
            let mppsStatus = try DICOMMPPSCommand.parseStatus(status)

            // N-CREATE always STARTS the performed procedure step IN PROGRESS; the
            // terminal states (COMPLETED / DISCONTINUED) are reached only via `update`
            // (N-SET). Reject anything else so a step can never be minted already in a
            // terminal state — mirroring the Update subcommand's status guard.
            guard mppsStatus == .inProgress else {
                throw ValidationError("Create status must be IN PROGRESS — use 'dicom-mpps update --status COMPLETED|DISCONTINUED' to transition the step")
            }

            // Verbose header via the SHARED NetworkConsole formatter (DICOMNetwork) to
            // STDOUT — the IDENTICAL builder the Studio MPPS panel uses, so the chrome
            // can't drift. The order matches the app (the parity harness diffs the
            // binary's stdout+stderr against the app's in-process console).
            if verbose {
                var fields: [(label: String, value: String)] = [("Study UID:", studyUid)]
                if let patientName { fields.append(("Patient Name:", patientName)) }
                if let patientId { fields.append(("Patient ID:", patientId)) }
                if let spsId { fields.append(("SPS ID:", spsId)) }
                if let accessionNumber { fields.append(("Accession Number:", accessionNumber)) }
                print(NetworkConsole.mppsHeader(
                    isCreate: true,
                    host: serverInfo.host, port: serverInfo.port,
                    callingAE: aet, calledAE: calledAet,
                    status: mppsStatus.rawValue, timeout: timeout,
                    fields: fields), terminator: "")
            }

            print(NetworkConsole.mppsProgress(isCreate: true), terminator: "")

            // Create MPPS
            let result = try await DICOMMPPSService.createDetailed(
                host: serverInfo.host,
                port: serverInfo.port,
                callingAE: aet,
                calledAE: calledAet,
                studyInstanceUID: studyUid,
                status: mppsStatus,
                timeout: TimeInterval(timeout),
                patientName: patientName,
                patientID: patientId,
                modality: modality,
                procedureStepID: procedureStepId,
                procedureStepDescription: procedureStepDescription,
                performingPhysicianName: performingPhysician,
                performedStationName: stationName,
                accessionNumber: accessionNumber,
                scheduledProcedureStepID: spsId,
                patientBirthDate: patientBirthDate,
                patientSex: patientSex,
                studyID: studyId,
                performedLocation: performedLocation,
                requestedProcedureID: requestedProcedureId,
                requestedProcedureDescription: requestedProcedureDescription,
                scheduledProcedureStepDescription: spsDescription,
                referencedStudySOPInstanceUID: referencedStudyUid,
                specificCharacterSet: specificCharacterSet
            )
            let mppsInstanceUID = result.sopInstanceUID
            DICOMMPPSCommand.reportWarning(result)
            if result.sopInstanceUIDWasReassigned {
                FileHandle.standardError.write(Data(
                    "note: SCP assigned MPPS SOP Instance UID \(result.sopInstanceUID) (requested \(result.requestedSOPInstanceUID)); use the assigned UID for the N-SET (PS3.7 10.1.5.1.4)\n".utf8))
            }

            // Result via the SHARED formatter — preserves the "MPPS Instance UID:" marker
            // the parity comparator threads into the subsequent N-SET. The CLI-specific
            // next-step hint (the literal update command) stays local: it's legitimately
            // different from the app's UI instruction.
            print(NetworkConsole.mppsCreateResult(uid: mppsInstanceUID), terminator: "")
            print("")
            print("Use this UID to update the MPPS when the procedure completes:")
            print("  dicom-mpps update \(serverInfo.host) --port \(serverInfo.port) \\")
            print("    --aet \(aet) --mpps-uid \(mppsInstanceUID) --status COMPLETED")
            
            #else
            throw ValidationError("Network functionality is not available on this platform")
            #endif
        }
    }
}

// MARK: - Update Subcommand

extension DICOMMPPSCommand {
    struct Update: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "update",
            abstract: "Update MPPS instance (N-SET)"
        )
        
        @Argument(help: "PACS server hostname or IP address, optionally with port (host:port)")
        var host: String
        
        @Option(name: .long, help: "PACS server port (default: 11112)")
        var port: UInt16?
        
        @Option(name: .long, help: "Local Application Entity Title (calling AE)")
        var aet: String
        
        @Option(name: .long, help: "Remote Application Entity Title (default: ANY-SCP)")
        var calledAet: String = "ANY-SCP"
        
        @Option(name: .long, help: "MPPS SOP Instance UID to update")
        var mppsUid: String
        
        @Option(name: .long, help: "New status (COMPLETED or DISCONTINUED)")
        var status: String
        
        @Option(name: .long, help: "Study Instance UID for referenced images")
        var studyUid: String?
        
        @Option(name: .long, help: "Series Instance UID for referenced images")
        var seriesUid: String?
        
        @Option(name: .long, help: "SOP Instance UID for referenced images (can be repeated)")
        var imageUid: [String] = []

        @Option(name: .long, help: "SOP Class UID (0008,1150) of the referenced images, e.g. 1.2.840.10008.5.1.4.1.1.2 for CT. Without it the Secondary Capture class is sent, which is wrong for anything but SC")
        var sopClassUid: String?

        @Option(name: .long, help: "Protocol Name (0018,1030) — Type 1 in every Performed Series item (default: UNSPECIFIED)")
        var protocolName: String?

        @Option(name: .long, help: "Series Description (0008,103E) for the performed series")
        var seriesDescription: String?

        @Option(name: .long, help: "Operators' Name (0008,1070), DICOM PN format")
        var operatorName: String?

        @Option(name: .long, help: "Performing Physician's Name (0008,1050), DICOM PN format")
        var performingPhysician: String?

        @Flag(name: .long, help: "Also send the Scheduled Step Attributes Sequence (0040,0270) in the N-SET. PS3.4 forbids it; use only for an SCP known to require it")
        var legacyNsetScheduledAttributes: Bool = false

        @Option(name: .long, help: "Performed Procedure Step Discontinuation Reason Code Sequence (0040,0281) as CODE|SCHEME|MEANING, only with --status DISCONTINUED. Codes normally come from CID 9300 'Procedure Discontinuation Reasons' with scheme DCM, e.g. \"110513|DCM|Doctor cancelled procedure\", \"110514|DCM|Equipment failure\", \"110518|DCM|Patient did not arrive\"")
        var discontinuationReason: String?

        @Option(name: .long, help: "Force the Specific Character Set (0008,0005), e.g. ISO_IR 100 or ISO_IR 192. By default the narrowest set that represents every text value is chosen")
        var specificCharacterSet: String?
        
        @Option(name: .long, help: "Connection timeout in seconds (default: 60)")
        var timeout: Int = 60
        
        @Flag(name: .shortAndLong, help: "Show verbose output")
        var verbose: Bool = false
        
        mutating func run() async throws {
            #if canImport(Network)
            let serverInfo = DICOMMPPSCommand.resolveHostPort(host: host, port: port)
            
            // Parse status
            let mppsStatus = try DICOMMPPSCommand.parseStatus(status)
            
            // Validate status
            guard mppsStatus == .completed || mppsStatus == .discontinued else {
                throw ValidationError("Update status must be COMPLETED or DISCONTINUED")
            }

            var reason: MPPSCodedEntry?
            if let discontinuationReason {
                guard mppsStatus == .discontinued else {
                    throw ValidationError("--discontinuation-reason is only valid with --status DISCONTINUED")
                }
                reason = try DICOMMPPSCommand.parseCodedEntry(discontinuationReason, option: "--discontinuation-reason")
            }

            if !imageUid.isEmpty, sopClassUid == nil {
                FileHandle.standardError.write(Data(
                    "warning: --sop-class-uid not given; Referenced SOP Class UID defaults to Secondary Capture (1.2.840.10008.5.1.4.1.1.7), which is non-conformant for CT/MR/… images\n".utf8))
            }
            
            // Verbose header via the SHARED NetworkConsole formatter (DICOMNetwork).
            if verbose {
                var fields: [(label: String, value: String)] = [("MPPS UID:", mppsUid)]
                if studyUid != nil, seriesUid != nil {
                    fields.append(("Referenced Images:", "\(imageUid.count) instance(s)"))
                }
                print(NetworkConsole.mppsHeader(
                    isCreate: false,
                    host: serverInfo.host, port: serverInfo.port,
                    callingAE: aet, calledAE: calledAet,
                    status: mppsStatus.rawValue, timeout: timeout,
                    fields: fields), terminator: "")
            }

            // Build referenced SOPs list
            var referencedSOPs: [(studyUID: String, seriesUID: String, sopInstanceUID: String)] = []
            if let study = studyUid, let series = seriesUid {
                for imageUID in imageUid {
                    referencedSOPs.append((study, series, imageUID))
                }
            }

            print(NetworkConsole.mppsProgress(isCreate: false), terminator: "")

            // Update MPPS
            let result = try await DICOMMPPSService.update(
                host: serverInfo.host,
                port: serverInfo.port,
                callingAE: aet,
                calledAE: calledAet,
                mppsInstanceUID: mppsUid,
                status: mppsStatus,
                referencedSOPs: referencedSOPs,
                timeout: TimeInterval(timeout),
                referencedSOPClassUID: sopClassUid,
                protocolName: protocolName,
                seriesDescription: seriesDescription,
                operatorsName: operatorName,
                performingPhysicianName: performingPhysician,
                legacyNSetScheduledStepAttributes: legacyNsetScheduledAttributes,
                discontinuationReason: reason,
                specificCharacterSet: specificCharacterSet
            )
            DICOMMPPSCommand.reportWarning(result)

            // Result via the SHARED formatter — preserves the "New Status:" /
            // "Referenced Images:" markers the parity comparator parses.
            print(NetworkConsole.mppsUpdateResult(
                uid: mppsUid,
                status: mppsStatus.rawValue,
                referencedImages: referencedSOPs.count), terminator: "")
            
            #else
            throw ValidationError("Network functionality is not available on this platform")
            #endif
        }
    }
}

