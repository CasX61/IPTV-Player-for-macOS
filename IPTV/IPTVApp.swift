import SwiftUI
import Sparkle

@main
struct IPTVApp: App {
    @State private var appState = AppState()

    // Startet den Updater: prueft automatisch (taeglich) gegen den GitHub-Appcast
    private let updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )

    var body: some Scene {
        WindowGroup {
            Group {
                switch appState.currentScreen {
                case .login:
                    LoginView()
                case .main:
                    MainView()
                }
            }
            .environment(appState)
            .frame(minWidth: 1000, minHeight: 600)
        }
        .defaultSize(width: 1280, height: 800)
        .commands {
            CommandGroup(after: .appInfo) {
                CheckForUpdatesView(updater: updaterController.updater)
            }
        }
    }
}
