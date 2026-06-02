// GatewayView.swift
// DICOMStudio
//
// DICOM Studio — DICOM Gateway view (dicom-gateway)
// Supports DICOM ↔ HL7 v2 and DICOM ↔ FHIR R4 conversion, routing, monitoring

#if canImport(SwiftUI)
import SwiftUI

/// DICOM Gateway view providing HL7 v2 / FHIR R4 ↔ DICOM conversion,
/// configurable routing rules, and real-time event monitoring.
@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
public struct GatewayView: View {
    @Bindable var viewModel: GatewayViewModel

    public init(viewModel: GatewayViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            tabPicker
            Divider()
            tabContent
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView("Working…")
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            if let msg = viewModel.errorMessage { Text(msg) }
        }
        .sheet(isPresented: $viewModel.isAddRuleSheetPresented) {
            addRuleSheet
        }
    }

    // MARK: - Tab Picker

    private var tabPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(GatewayTab.allCases) { tab in
                    Button { viewModel.activeTab = tab } label: {
                        Label(tab.displayName, systemImage: tab.sfSymbol)
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(viewModel.activeTab == tab ? Color.accentColor.opacity(0.15) : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(tab.displayName)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        switch viewModel.activeTab {
        case .gatewayConfig:  configContent
        case .hl7Conversion:  hl7Content
        case .fhirConversion: fhirContent
        case .routing:        routingContent
        case .monitoring:     monitoringContent
        }
    }

    // MARK: - Configuration

    private var configContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Gateway status
                HStack(spacing: 12) {
                    Circle()
                        .fill(viewModel.isGatewayRunning ? Color.green : Color.secondary.opacity(0.4))
                        .frame(width: 10, height: 10)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(viewModel.isGatewayRunning ? "Gateway Running" : "Gateway Stopped")
                            .font(.headline)
                        Text(viewModel.statusMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(viewModel.isGatewayRunning ? "Stop Gateway" : "Start Gateway") {
                        if viewModel.isGatewayRunning {
                            viewModel.stopGateway()
                        } else {
                            viewModel.startGateway()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(viewModel.isGatewayRunning ? .red : .green)
                    .accessibilityLabel(viewModel.isGatewayRunning ? "Stop gateway" : "Start gateway")
                }
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))

                GroupBox("Listener") {
                    HStack {
                        Text("Port")
                        Spacer()
                        TextField("Port", value: $viewModel.configuration.listenPort, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                            .accessibilityLabel("Listen port")
                    }
                    Picker("Protocol", selection: $viewModel.configuration.listenProtocol) {
                        ForEach(GatewayProtocol.allCases) { p in
                            Text(p.displayName).tag(p)
                        }
                    }
                    .accessibilityLabel("Listener protocol")
                }

                GroupBox("Target") {
                    HStack {
                        TextField("Host", text: $viewModel.configuration.targetHost)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityLabel("Target host")
                        TextField("Port", value: $viewModel.configuration.targetPort, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                            .accessibilityLabel("Target port")
                    }
                    Picker("Protocol", selection: $viewModel.configuration.targetProtocol) {
                        ForEach(GatewayProtocol.allCases) { p in
                            Text(p.displayName).tag(p)
                        }
                    }
                    .accessibilityLabel("Target protocol")
                }

                GroupBox("Mode") {
                    Picker("Operation Mode", selection: $viewModel.configuration.operationMode) {
                        ForEach(GatewayOperationMode.allCases) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .accessibilityLabel("Gateway operation mode")

                    Picker("Missing Fields", selection: $viewModel.configuration.handleMissingFields) {
                        ForEach(MissingFieldBehavior.allCases) { b in
                            Text(b.displayName).tag(b)
                        }
                    }
                    .accessibilityLabel("Missing field behavior")

                    Toggle("Include Private Tags", isOn: $viewModel.configuration.includePrivateTags)
                        .accessibilityLabel("Include private tags in conversion")
                }

                Button("Save Configuration") {
                    viewModel.saveConfiguration()
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Save gateway configuration")
            }
            .padding()
        }
    }

    // MARK: - HL7 Conversion

    private var hl7Content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("HL7 Conversion")
                    .font(.title2).bold()

                Toggle("Convert HL7 → FHIR (instead of HL7 → DICOM)", isOn: $viewModel.hl7ToFhir)
                    .accessibilityLabel("Convert HL7 to FHIR instead of DICOM")

                GroupBox("Input") {
                    TextField("HL7 message file path", text: $viewModel.hl7InputPath)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("HL7 input path")
                }

                GroupBox("Output") {
                    TextField("Output path (optional)", text: $viewModel.hl7OutputPath)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("HL7 output path")
                }

                Button("Convert") {
                    viewModel.convertHL7()
                }
                .buttonStyle(.borderedProminent)
                .accessibilityLabel("Convert HL7 message")

                if !viewModel.hl7ConversionResult.isEmpty {
                    GroupBox("Command") {
                        Text(viewModel.hl7ConversionResult)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding()
        }
    }

    // MARK: - FHIR Conversion

    private var fhirContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("FHIR Conversion")
                    .font(.title2).bold()

                Toggle("Convert FHIR → DICOM (instead of DICOM → FHIR)", isOn: $viewModel.fhirToDicom)
                    .accessibilityLabel("Convert FHIR to DICOM")

                GroupBox("Input") {
                    TextField("FHIR or DICOM file path", text: $viewModel.fhirInputPath)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("FHIR/DICOM input path")
                }

                GroupBox("Output") {
                    TextField("Output path (optional)", text: $viewModel.fhirOutputPath)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("Output path")
                }

                Button("Convert") {
                    viewModel.convertFHIR()
                }
                .buttonStyle(.borderedProminent)
                .accessibilityLabel("Convert FHIR/DICOM")

                if !viewModel.fhirConversionResult.isEmpty {
                    GroupBox("Command") {
                        Text(viewModel.fhirConversionResult)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding()
        }
    }

    // MARK: - Routing

    private var routingContent: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Routing Rules")
                    .font(.headline)
                Spacer()
                Button {
                    viewModel.isAddRuleSheetPresented = true
                } label: {
                    Label("Add Rule", systemImage: "plus")
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Add routing rule")
            }
            .padding()
            Divider()

            if viewModel.routingRules.isEmpty {
                ContentUnavailableView(
                    "No Routing Rules",
                    systemImage: "arrow.triangle.branch",
                    description: Text("Add routing rules to forward messages based on field patterns.")
                )
            } else {
                List {
                    ForEach(viewModel.routingRules) { rule in
                        HStack {
                            Toggle("", isOn: Binding(
                                get: { rule.isEnabled },
                                set: { _ in viewModel.toggleRoutingRule(id: rule.id) }
                            ))
                            .labelsHidden()
                            .accessibilityLabel("Enable rule \(rule.name)")

                            VStack(alignment: .leading, spacing: 2) {
                                Text(rule.name).font(.subheadline).bold()
                                Text("\(rule.matchField) matches \"\(rule.matchPattern)\"")
                                    .font(.caption).foregroundStyle(.secondary)
                                Text("→ \(rule.targetHost):\(rule.targetPort) (\(rule.targetProtocol.displayName))")
                                    .font(.caption2).foregroundStyle(.tertiary)
                            }
                            Spacer()
                            Button {
                                viewModel.removeRoutingRule(id: rule.id)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Remove rule \(rule.name)")
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
    }

    // MARK: - Monitoring

    private var monitoringContent: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Event Log")
                    .font(.headline)
                Spacer()
                Picker("Filter", selection: $viewModel.eventLevelFilter) {
                    Text("All").tag(Optional<GatewayEventLevel>.none)
                    ForEach(GatewayEventLevel.allCases, id: \.rawValue) { level in
                        Text(level.displayName).tag(Optional(level))
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 280)
                .accessibilityLabel("Event level filter")

                Button {
                    viewModel.clearEvents()
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear event log")
            }
            .padding()
            Divider()

            if viewModel.filteredEvents.isEmpty {
                ContentUnavailableView(
                    "No Events",
                    systemImage: "chart.xyaxis.line",
                    description: Text("Gateway events will appear here when the gateway is running.")
                )
            } else {
                List(viewModel.filteredEvents) { event in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: event.level.sfSymbol)
                            .foregroundStyle(
                                event.level == .error ? Color.red :
                                event.level == .warning ? Color.orange : Color.secondary
                            )
                        VStack(alignment: .leading, spacing: 2) {
                            Text(event.message)
                                .font(.caption)
                            HStack {
                                Text("\(event.sourceProtocol.displayName) → \(event.targetProtocol.displayName)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                if !event.patientID.isEmpty {
                                    Text("Patient: \(event.patientID)")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                                Spacer()
                                Text(event.timestamp, style: .time)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    // MARK: - Add Rule Sheet

    private var addRuleSheet: some View {
        NavigationStack {
            Form {
                Section("Rule") {
                    TextField("Rule name", text: $viewModel.newRule.name)
                        .accessibilityLabel("Rule name")
                }
                Section("Match") {
                    TextField("Match field (e.g. PatientID, Modality)", text: $viewModel.newRule.matchField)
                        .accessibilityLabel("Match field")
                    TextField("Pattern (wildcards: * ?)", text: $viewModel.newRule.matchPattern)
                        .accessibilityLabel("Match pattern")
                }
                Section("Target") {
                    TextField("Host", text: $viewModel.newRule.targetHost)
                        .accessibilityLabel("Target host")
                    TextField("Port", value: $viewModel.newRule.targetPort, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("Target port")
                    Picker("Protocol", selection: $viewModel.newRule.targetProtocol) {
                        ForEach(GatewayProtocol.allCases) { p in
                            Text(p.displayName).tag(p)
                        }
                    }
                    .accessibilityLabel("Target protocol")
                }
            }
            .navigationTitle("Add Routing Rule")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { viewModel.isAddRuleSheetPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { viewModel.addRoutingRule() }
                }
            }
        }
        .frame(minWidth: 420, minHeight: 350)
    }
}
#endif
