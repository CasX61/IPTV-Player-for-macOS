import SwiftUI

struct MainView: View {
    @Environment(AppState.self) private var appState
    @State private var liveVM = LiveViewModel()
    @State private var moviesVM = MoviesViewModel()
    @State private var seriesVM = SeriesViewModel()

    var body: some View {
        @Bindable var state = appState

        NavigationSplitView {
            VStack(spacing: 0) {
                List(selection: $state.selectedTab) {
                    Section("Inhalt") {
                        ForEach(AppState.ContentTab.allCases, id: \.self) { tab in
                            Label(tab.rawValue, systemImage: tab.icon)
                                .tag(tab)
                        }
                    }
                }
                .listStyle(.sidebar)

                Divider()

                // Account info + actions
                VStack(alignment: .leading, spacing: 6) {
                    if let profile = appState.activeProfile {
                        HStack {
                            Image(systemName: "tv")
                                .foregroundStyle(.blue)
                                .font(.caption)
                            Text(profile.name)
                                .font(.caption.bold())
                            Spacer()
                            Button(action: { appState.logout() }) {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                    .font(.caption)
                            }
                            .buttonStyle(.borderless)
                            .help("Zurueck zur Playlist-Auswahl")
                        }
                    }
                    if let user = appState.userInfo {
                        Text(user.username)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    if let exp = appState.userInfo?.expirationDate {
                        Text("Gueltig bis: \(exp.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Button(action: reloadCurrentTab) {
                        Label("Playlist neu laden", systemImage: "arrow.clockwise")
                            .font(.caption)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            .navigationSplitViewColumnWidth(min: 160, ideal: 190, max: 240)
        } detail: {
            contentView
        }
        .task {
            await liveVM.loadCategories(api: appState.api)
        }
        .onChange(of: appState.selectedTab) { _, newTab in
            Task {
                switch newTab {
                case .live:
                    if liveVM.categories.isEmpty {
                        await liveVM.loadCategories(api: appState.api)
                    }
                case .movies:
                    if moviesVM.categories.isEmpty {
                        await moviesVM.loadCategories(api: appState.api)
                    }
                case .series:
                    if seriesVM.categories.isEmpty {
                        await seriesVM.loadCategories(api: appState.api)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var contentView: some View {
        switch appState.selectedTab {
        case .live:
            LiveView(viewModel: liveVM)
        case .movies:
            MoviesView(viewModel: moviesVM)
        case .series:
            SeriesView(viewModel: seriesVM)
        }
    }

    private func reloadCurrentTab() {
        Task {
            switch appState.selectedTab {
            case .live:
                liveVM.categories = []
                liveVM.streams = []
                liveVM.selectedCategory = nil
                liveVM.selectedStream = nil
                await liveVM.loadCategories(api: appState.api)
            case .movies:
                moviesVM.categories = []
                moviesVM.movies = []
                moviesVM.selectedCategory = nil
                moviesVM.playingMovie = nil
                await moviesVM.loadCategories(api: appState.api)
            case .series:
                seriesVM.categories = []
                seriesVM.seriesList = []
                seriesVM.selectedCategory = nil
                seriesVM.selectedSeries = nil
                await seriesVM.loadCategories(api: appState.api)
            }
        }
    }
}
