#if canImport(SwiftUI) && os(macOS)
import SwiftUI

/// Observable model for network configuration UI binding
@Observable
public class NetworkConfigModel {
    public var aeTitle: String = NetworkConfig.defaultAETitle
    public var calledAET: String = NetworkConfig.defaultCalledAET
    public var host: String = NetworkConfig.defaultHost
    public var port: Int = NetworkConfig.defaultPort
    public var timeout: Int = NetworkConfig.defaultTimeout
    public var protocolType: ProtocolType = .dicom

    public init() {}

    /// Creates an immutable NetworkConfig from the current model state
    public func toNetworkConfig() -> NetworkConfig {
        NetworkConfig(
            aeTitle: aeTitle,
            calledAET: calledAET,
            host: host,
            port: port,
            timeout: timeout,
            protocolType: protocolType
        )
    }

    public var isValid: Bool {
        toNetworkConfig().isValid
    }

    public var serverURL: String {
        toNetworkConfig().serverURL
    }
}

/// Persistent PACS network configuration bar displayed above tabs
public struct NetworkConfigView: View {
    @Binding var config: NetworkConfigModel

    public init(config: Binding<NetworkConfigModel>) {
        self._config = config
    }

    public var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("PACS Configuration")
                        .font(.headline)
                    Spacer()
                    Button(action: {}) {
                        Label("Test Connection", systemImage: "antenna.radiowaves.left.and.right")
                    }
                    .disabled(!config.isValid)
                }

                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("AE Title").font(.caption).foregroundStyle(.secondary)
                        TextField("AE Title", text: $config.aeTitle)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 140)
                            .onChange(of: config.aeTitle) { _, newValue in
                                // Enforce 16-char max and ASCII-only
                                if newValue.count > 16 {
                                    config.aeTitle = String(newValue.prefix(16))
                                }
                                let filtered = newValue.filter { $0.isASCII }
                                if filtered != newValue {
                                    config.aeTitle = filtered
                                }
                            }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Called AET").font(.caption).foregroundStyle(.secondary)
                        TextField("Called AET", text: $config.calledAET)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 140)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Host").font(.caption).foregroundStyle(.secondary)
                        TextField("Host", text: $config.host)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 180)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Port").font(.caption).foregroundStyle(.secondary)
                        TextField("Port", value: $config.port, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Timeout").font(.caption).foregroundStyle(.secondary)
                        HStack(spacing: 4) {
                            TextField("Timeout", value: $config.timeout, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 60)
                            Text("s").foregroundStyle(.secondary)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Protocol").font(.caption).foregroundStyle(.secondary)
                        Picker("", selection: $config.protocolType) {
                            ForEach(ProtocolType.allCases, id: \.self) { proto in
                                Text(proto.rawValue).tag(proto)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 150)
                    }
                }
            }
            .padding(8)
        }
    }
}
#endif
