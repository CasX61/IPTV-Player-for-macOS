import Foundation

// MARK: - Profile Model

struct Profile: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var server: String
    var username: String
    var password: String
    var createdAt: Date

    var credentials: ServerCredentials {
        ServerCredentials(server: server, username: username, password: password)
    }

    init(name: String, server: String, username: String, password: String) {
        self.id = UUID()
        self.name = name
        self.server = server
        self.username = username
        self.password = password
        self.createdAt = Date()
    }
}

// MARK: - Watch Progress

struct WatchProgress: Codable {
    var position: Float      // 0...1
    var timestamp: Date      // when last saved
    var durationSecs: Int?   // total duration in seconds if known

    var isFinished: Bool { position > 0.92 }
}

// MARK: - Profile Store

@Observable
@MainActor
final class ProfileStore {
    private let profilesKey = "saved_profiles"

    var profiles: [Profile] = []

    init() {
        loadProfiles()
    }

    // MARK: - Profile CRUD

    private func loadProfiles() {
        guard let data = UserDefaults.standard.data(forKey: profilesKey),
              let decoded = try? JSONDecoder().decode([Profile].self, from: data) else {
            // Migrate old single-credential if present
            migrateOldCredentials()
            return
        }
        profiles = decoded
    }

    private func save() {
        if let data = try? JSONEncoder().encode(profiles) {
            UserDefaults.standard.set(data, forKey: profilesKey)
        }
    }

    func addProfile(_ profile: Profile) {
        profiles.append(profile)
        save()
    }

    func updateProfile(_ profile: Profile) {
        if let idx = profiles.firstIndex(where: { $0.id == profile.id }) {
            profiles[idx] = profile
            save()
        }
    }

    func deleteProfile(_ profile: Profile) {
        profiles.removeAll { $0.id == profile.id }
        // Clean up watch progress
        UserDefaults.standard.removeObject(forKey: progressKey(for: profile.id))
        save()
    }

    // MARK: - Watch Progress

    private func progressKey(for profileID: UUID) -> String {
        "watch_progress_\(profileID.uuidString)"
    }

    private func allProgress(for profileID: UUID) -> [String: WatchProgress] {
        guard let data = UserDefaults.standard.data(forKey: progressKey(for: profileID)),
              let decoded = try? JSONDecoder().decode([String: WatchProgress].self, from: data) else {
            return [:]
        }
        return decoded
    }

    private func saveAllProgress(_ progress: [String: WatchProgress], for profileID: UUID) {
        if let data = try? JSONEncoder().encode(progress) {
            UserDefaults.standard.set(data, forKey: progressKey(for: profileID))
        }
    }

    func saveProgress(profileID: UUID, key: String, position: Float, durationSecs: Int? = nil) {
        var all = allProgress(for: profileID)
        all[key] = WatchProgress(position: position, timestamp: Date(), durationSecs: durationSecs)
        saveAllProgress(all, for: profileID)
    }

    func getProgress(profileID: UUID, key: String) -> WatchProgress? {
        allProgress(for: profileID)[key]
    }

    func isWatched(profileID: UUID, key: String) -> Bool {
        getProgress(profileID: profileID, key: key)?.isFinished ?? false
    }

    // MARK: - Static Keys

    static func movieKey(_ streamID: Int) -> String {
        "movie_\(streamID)"
    }

    static func episodeKey(_ episodeID: String) -> String {
        "episode_\(episodeID)"
    }

    // MARK: - Migration from old single-credential system

    private func migrateOldCredentials() {
        guard let data = UserDefaults.standard.data(forKey: "saved_credentials"),
              let creds = try? JSONDecoder().decode(ServerCredentials.self, from: data) else {
            return
        }
        let profile = Profile(
            name: "Meine Playlist",
            server: creds.server,
            username: creds.username,
            password: creds.password
        )
        profiles = [profile]
        save()
        UserDefaults.standard.removeObject(forKey: "saved_credentials")
    }
}
