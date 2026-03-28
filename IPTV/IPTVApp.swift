import SwiftUI

@main
struct IPTVApp: App {
    @State private var appState = AppState()

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
    }
}
