import SwiftUI
import Sparkle

// MARK: - Auto-Update (Sparkle)

/// Spiegelt `canCheckForUpdates` des Updaters, damit der Menuepunkt
/// waehrend einer laufenden Pruefung deaktiviert ist.
final class CheckForUpdatesViewModel: ObservableObject {
    @Published var canCheckForUpdates = false

    init(updater: SPUUpdater) {
        updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
    }
}

/// Menuepunkt "Nach Updates suchen…" im App-Menue.
struct CheckForUpdatesView: View {
    @ObservedObject private var viewModel: CheckForUpdatesViewModel
    private let updater: SPUUpdater

    init(updater: SPUUpdater) {
        self.updater = updater
        self.viewModel = CheckForUpdatesViewModel(updater: updater)
    }

    var body: some View {
        Button("Nach Updates suchen…", action: updater.checkForUpdates)
            .disabled(!viewModel.canCheckForUpdates)
    }
}
