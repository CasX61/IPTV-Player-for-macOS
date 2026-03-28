import SwiftUI

@Observable
@MainActor
final class AppState {

    // MARK: - Navigation

    enum Screen {
        case login
        case main
    }

    enum ContentTab: String, CaseIterable, Hashable {
        case live = "Live TV"
        case movies = "Filme"
        case series = "Serien"

        var icon: String {
            switch self {
            case .live: return "tv"
            case .movies: return "film"
            case .series: return "play.rectangle.on.rectangle"
            }
        }
    }

    var currentScreen: Screen = .login
    var selectedTab: ContentTab = .live

    // MARK: - Auth State

    var credentials: ServerCredentials?
    var userInfo: UserInfo?
    var serverInfo: ServerInfo?
    var isLoading = false
    var errorMessage: String?

    // MARK: - Profile

    let profileStore = ProfileStore()
    var activeProfile: Profile?

    // MARK: - API

    let api = XtreamAPI()

    // MARK: - Auth Actions

    func login(profile: Profile) async {
        let creds = profile.credentials
        isLoading = true
        errorMessage = nil

        do {
            let response = try await api.authenticate(credentials: creds)
            self.credentials = creds
            self.userInfo = response.userInfo
            self.serverInfo = response.serverInfo
            self.activeProfile = profile
            currentScreen = .main
        } catch {
            self.errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func logout() {
        credentials = nil
        userInfo = nil
        serverInfo = nil
        activeProfile = nil
        selectedTab = .live
        currentScreen = .login
    }

    // MARK: - Watch Progress Helpers

    func saveWatchProgress(key: String, position: Float, durationSecs: Int? = nil) {
        guard let profileID = activeProfile?.id else { return }
        profileStore.saveProgress(profileID: profileID, key: key, position: position, durationSecs: durationSecs)
    }

    func getWatchProgress(key: String) -> WatchProgress? {
        guard let profileID = activeProfile?.id else { return nil }
        return profileStore.getProgress(profileID: profileID, key: key)
    }
}
