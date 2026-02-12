#if canImport(SwiftUI) && os(macOS)
import SwiftUI

/// Application settings view with tabs for preferences, profiles, and shortcuts
public struct SettingsView: View {
    @State private var isBeginnerMode: Bool = AppSettings.isBeginnerMode()
    @State private var defaultOutputDir: String = AppSettings.defaultOutputDirectory() ?? ""
    @State private var consoleFontSize: Double = AppSettings.consoleFontSize()
    @State private var profiles: [ServerProfile] = AppSettings.loadProfiles()
    @State private var editingProfile: ServerProfile?
    @State private var showingAddProfile = false

    public init() {}

    public var body: some View {
        TabView {
            generalTab
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }

            profilesTab
                .tabItem {
                    Label("Server Profiles", systemImage: "server.rack")
                }

            shortcutsTab
                .tabItem {
                    Label("Keyboard Shortcuts", systemImage: "keyboard")
                }
        }
        .frame(width: 550, height: 400)
    }

    // MARK: - General Tab

    @ViewBuilder
    private var generalTab: some View {
        Form {
            Section("Mode") {
                Toggle("Beginner Mode", isOn: $isBeginnerMode)
                    .help("Hides advanced parameters to simplify the interface")
                    .onChange(of: isBeginnerMode) { _, newValue in
                        AppSettings.setBeginnerMode(newValue)
                    }
                    .accessibilityLabel("Beginner Mode toggle")

                if isBeginnerMode {
                    Text("Advanced parameters are hidden. Toggle off to see all options.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Output") {
                HStack {
                    TextField("Default Output Directory", text: $defaultOutputDir)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("Default output directory path")

                    Button("Browse...") {
                        // On macOS this would open NSOpenPanel
                    }
                    .accessibilityLabel("Browse for output directory")
                }
                .onChange(of: defaultOutputDir) { _, newValue in
                    AppSettings.setDefaultOutputDirectory(newValue.isEmpty ? nil : newValue)
                }
            }

            Section("Console") {
                HStack {
                    Text("Font Size: \(Int(consoleFontSize))pt")
                        .accessibilityLabel("Console font size")
                    Slider(value: $consoleFontSize,
                           in: AppSettings.minConsoleFontSize...AppSettings.maxConsoleFontSize,
                           step: 1)
                    .accessibilityLabel("Console font size slider")
                    .onChange(of: consoleFontSize) { _, newValue in
                        AppSettings.setConsoleFontSize(newValue)
                    }
                }

                Text("Preview: dicom-info --format json scan.dcm")
                    .font(.system(size: consoleFontSize, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Profiles Tab

    @ViewBuilder
    private var profilesTab: some View {
        VStack {
            List {
                if profiles.isEmpty {
                    Text("No saved server profiles")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    ForEach(profiles) { profile in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(profile.name)
                                    .font(.headline)
                                Text("\(profile.host):\(profile.port) – AET: \(profile.aeTitle)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("Server profile \(profile.name), host \(profile.host), port \(profile.port)")

                            Spacer()

                            Button(action: { editingProfile = profile }) {
                                Image(systemName: "pencil")
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Edit profile \(profile.name)")

                            Button(action: {
                                AppSettings.deleteProfile(id: profile.id, from: &profiles)
                                AppSettings.saveProfiles(profiles)
                            }) {
                                Image(systemName: "trash")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Delete profile \(profile.name)")
                        }
                    }
                }
            }

            HStack {
                Spacer()
                Button(action: { showingAddProfile = true }) {
                    Label("Add Profile", systemImage: "plus")
                }
                .accessibilityLabel("Add new server profile")
            }
            .padding()
        }
        .sheet(isPresented: $showingAddProfile) {
            ProfileEditorView(
                profile: ServerProfile(name: "New Profile"),
                onSave: { profile in
                    AppSettings.addProfile(profile, to: &profiles)
                    AppSettings.saveProfiles(profiles)
                    showingAddProfile = false
                },
                onCancel: { showingAddProfile = false }
            )
        }
        .sheet(item: $editingProfile) { profile in
            ProfileEditorView(
                profile: profile,
                onSave: { updated in
                    AppSettings.updateProfile(updated, in: &profiles)
                    AppSettings.saveProfiles(profiles)
                    editingProfile = nil
                },
                onCancel: { editingProfile = nil }
            )
        }
    }

    // MARK: - Shortcuts Tab

    @ViewBuilder
    private var shortcutsTab: some View {
        Form {
            Section("Command Shortcuts") {
                shortcutRow(label: "Run Command", shortcut: "⌘↵")
                shortcutRow(label: "Copy Command", shortcut: "⌘C")
                shortcutRow(label: "Clear Console", shortcut: "⌘K")
                shortcutRow(label: "Open Settings", shortcut: "⌘,")
            }

            Section("Navigation") {
                shortcutRow(label: "Next Tab", shortcut: "⌃⇥")
                shortcutRow(label: "Previous Tab", shortcut: "⌃⇧⇥")
                shortcutRow(label: "Toggle Glossary", shortcut: "⌘G")
                shortcutRow(label: "Search", shortcut: "⌘F")
            }
        }
        .formStyle(.grouped)
    }

    @ViewBuilder
    private func shortcutRow(label: String, shortcut: String) -> some View {
        HStack {
            Text(label)
                .accessibilityLabel(label)
            Spacer()
            Text(shortcut)
                .font(.system(.body, design: .monospaced))
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(.quaternary)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .accessibilityLabel("Shortcut: \(shortcut)")
        }
    }
}

/// Editor sheet for creating/editing a server profile
struct ProfileEditorView: View {
    @State var profile: ServerProfile
    let onSave: (ServerProfile) -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text(profile.name == "New Profile" ? "Add Server Profile" : "Edit Server Profile")
                .font(.headline)

            Form {
                TextField("Profile Name", text: $profile.name)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Profile name")

                TextField("AE Title", text: $profile.aeTitle)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("AE Title")

                TextField("Called AET", text: $profile.calledAET)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Called AE Title")

                TextField("Host", text: $profile.host)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Host address")

                TextField("Port", value: $profile.port, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Port number")

                TextField("Timeout", value: $profile.timeout, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Connection timeout in seconds")
            }
            .formStyle(.grouped)

            HStack {
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                    .accessibilityLabel("Cancel editing profile")
                Spacer()
                Button("Save") {
                    onSave(profile)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(profile.name.isEmpty)
                .accessibilityLabel("Save profile")
            }
        }
        .padding()
        .frame(width: 400, height: 380)
    }
}
#endif
