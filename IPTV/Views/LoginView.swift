import SwiftUI

struct LoginView: View {
    @Environment(AppState.self) private var appState
    @State private var showAddForm = false
    @State private var editingProfile: Profile?

    // Form fields
    @State private var name = ""
    @State private var server = ""
    @State private var username = ""
    @State private var password = ""

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 24) {
                // Logo
                VStack(spacing: 8) {
                    Image(systemName: "play.tv")
                        .font(.system(size: 56))
                        .foregroundStyle(.blue)
                    Text("IPTV Player")
                        .font(.largeTitle.bold())
                    Text("Waehle eine Playlist oder erstelle eine neue")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 8)

                // Profile list
                if !appState.profileStore.profiles.isEmpty && !showAddForm {
                    profileList
                }

                // Add/Edit form
                if showAddForm {
                    profileForm
                } else {
                    Button(action: {
                        clearForm()
                        editingProfile = nil
                        showAddForm = true
                    }) {
                        Label("Neue Playlist hinzufuegen", systemImage: "plus.circle.fill")
                            .frame(maxWidth: 400)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }

                // Error message
                if let error = appState.errorMessage {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }

            Spacer()
        }
        .padding(40)
        .frame(minWidth: 500, minHeight: 400)
        .onAppear {
            // If only one profile, no need to show list immediately
            if appState.profileStore.profiles.isEmpty {
                showAddForm = true
            }
        }
    }

    // MARK: - Profile List

    private var profileList: some View {
        VStack(spacing: 8) {
            ForEach(appState.profileStore.profiles) { profile in
                HStack(spacing: 12) {
                    Image(systemName: "tv")
                        .font(.title2)
                        .foregroundStyle(.blue)
                        .frame(width: 36)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(profile.name)
                            .font(.headline)
                        Text("\(profile.username) @ \(profile.server)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    if appState.isLoading {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        // Edit button
                        Button(action: {
                            editingProfile = profile
                            name = profile.name
                            server = profile.server
                            username = profile.username
                            password = profile.password
                            showAddForm = true
                        }) {
                            Image(systemName: "pencil")
                                .font(.caption)
                        }
                        .buttonStyle(.borderless)
                        .help("Bearbeiten")

                        // Delete button
                        Button(action: {
                            appState.profileStore.deleteProfile(profile)
                        }) {
                            Image(systemName: "trash")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.borderless)
                        .help("Loeschen")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.quaternary.opacity(0.5))
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    guard !appState.isLoading else { return }
                    Task {
                        await appState.login(profile: profile)
                    }
                }
            }
        }
        .frame(maxWidth: 450)
    }

    // MARK: - Profile Form

    private var profileForm: some View {
        VStack(spacing: 12) {
            Text(editingProfile == nil ? "Neue Playlist" : "Playlist bearbeiten")
                .font(.headline)

            TextField("Playlist Name (z.B. Mein IPTV)", text: $name)
                .textFieldStyle(.roundedBorder)

            TextField("Server URL (z.B. http://example.com:8080)", text: $server)
                .textFieldStyle(.roundedBorder)

            TextField("Benutzername", text: $username)
                .textFieldStyle(.roundedBorder)

            SecureField("Passwort", text: $password)
                .textFieldStyle(.roundedBorder)

            HStack(spacing: 12) {
                Button("Abbrechen") {
                    showAddForm = false
                    clearForm()
                    appState.errorMessage = nil
                }
                .buttonStyle(.bordered)
                .keyboardShortcut(.cancelAction)

                Button(action: saveAndConnect) {
                    Group {
                        if appState.isLoading {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text(editingProfile == nil ? "Speichern & Verbinden" : "Aktualisieren & Verbinden")
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isValid || appState.isLoading)
                .keyboardShortcut(.defaultAction)
            }
        }
        .frame(maxWidth: 400)
    }

    // MARK: - Helpers

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !server.trimmingCharacters(in: .whitespaces).isEmpty &&
        !username.trimmingCharacters(in: .whitespaces).isEmpty &&
        !password.isEmpty
    }

    private func saveAndConnect() {
        if var existing = editingProfile {
            existing.name = name
            existing.server = server
            existing.username = username
            existing.password = password
            appState.profileStore.updateProfile(existing)
            Task {
                await appState.login(profile: existing)
            }
        } else {
            let profile = Profile(
                name: name,
                server: server,
                username: username,
                password: password
            )
            appState.profileStore.addProfile(profile)
            Task {
                await appState.login(profile: profile)
            }
        }
        showAddForm = false
    }

    private func clearForm() {
        name = ""
        server = ""
        username = ""
        password = ""
        editingProfile = nil
    }
}
