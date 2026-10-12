import SwiftUI

struct SeriesView: View {
    @Environment(AppState.self) private var appState
    @Bindable var viewModel: SeriesViewModel

    private let columns = [GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 16)]

    var body: some View {
        HSplitView {
            // MARK: Categories
            categoryColumn

            // MARK: Content
            contentColumn
        }
        .onChange(of: viewModel.selectedCategory) { _, category in
            guard let category else { return }
            viewModel.selectedSeries = nil
            viewModel.seriesInfo = nil
            viewModel.playingEpisode = nil
            Task {
                await viewModel.loadSeries(
                    api: appState.api,
                    categoryID: category.isAll ? nil : category.categoryID
                )
            }
        }
    }

    // MARK: - Category Column

    private var categoryColumn: some View {
        VStack(spacing: 0) {
            SectionHeader(title: "Kategorien", icon: "list.bullet")

            if viewModel.isLoadingCategories {
                LoadingView()
            } else {
                List(viewModel.categories, selection: $viewModel.selectedCategory) { category in
                    Text(category.categoryName)
                        .lineLimit(1)
                        .tag(category)
                }
                .listStyle(.sidebar)
            }
        }
        .frame(minWidth: 160, idealWidth: 200, maxWidth: 260)
    }

    // MARK: - Content Column

    @ViewBuilder
    private var contentColumn: some View {
        if let episode = viewModel.playingEpisode {
            episodePlayerView(episode: episode)
        } else if let series = viewModel.selectedSeries {
            seriesDetailView(series: series)
        } else {
            seriesGridView
        }
    }

    // MARK: - Series Grid

    private var seriesGridView: some View {
        VStack(spacing: 0) {
            SearchField(text: $viewModel.searchText, placeholder: "Serie suchen...")
            Divider()

            if viewModel.isLoadingSeries {
                LoadingView()
            } else if viewModel.filteredSeries.isEmpty {
                EmptyStateView(
                    message: viewModel.selectedCategory == nil
                        ? "Waehle eine Kategorie"
                        : "Keine Serien gefunden",
                    icon: "play.rectangle.on.rectangle"
                )
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(viewModel.filteredSeries) { series in
                            SeriesCard(series: series)
                                .onTapGesture {
                                    viewModel.selectedSeries = series
                                    Task {
                                        await viewModel.loadSeriesInfo(
                                            api: appState.api,
                                            seriesID: series.seriesID
                                        )
                                    }
                                }
                        }
                    }
                    .padding(16)
                }
            }
        }
    }

    // MARK: - Series Detail

    private func seriesDetailView(series: Series) -> some View {
        VStack(spacing: 0) {
            // Back bar
            HStack {
                Button(action: { viewModel.goBackToGrid() }) {
                    Label("Zurueck", systemImage: "chevron.left")
                }
                .buttonStyle(.borderless)

                Spacer()

                Text(series.name)
                    .font(.headline)
                    .lineLimit(1)

                Spacer()

                if series.ratingValue > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                        Text(String(format: "%.1f", series.ratingValue))
                    }
                    .font(.subheadline)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.bar)

            Divider()

            if viewModel.isLoadingInfo {
                LoadingView()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Series info header
                        HStack(alignment: .top, spacing: 16) {
                            CoverImageView(
                                url: series.cover,
                                aspectRatio: 2.0 / 3.0,
                                cornerRadius: 8
                            )
                            .frame(width: 160)

                            VStack(alignment: .leading, spacing: 8) {
                                if let genre = series.genre, !genre.isEmpty {
                                    Text(genre)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                if let year = series.releaseDate, !year.isEmpty {
                                    Text(year)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                if let plot = series.plot, !plot.isEmpty {
                                    Text(plot)
                                        .font(.body)
                                        .lineLimit(6)
                                }
                                if let cast = series.cast, !cast.isEmpty {
                                    Text("Cast: \(cast)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                            }
                        }

                        Divider()

                        // Season picker
                        if !viewModel.seasons.isEmpty {
                            HStack(spacing: 12) {
                                Picker("Staffel", selection: $viewModel.selectedSeason) {
                                    ForEach(viewModel.seasons, id: \.self) { season in
                                        Text("Staffel \(season)")
                                            .tag(Optional(season))
                                    }
                                }
                                .pickerStyle(.menu)
                                .labelsHidden()
                                .fixedSize()

                                let episodeCount = viewModel.currentEpisodes.count
                                Text(episodeCount == 1 ? "1 Episode" : "\(episodeCount) Episoden")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)

                                Spacer()
                            }

                            // Episode list
                            VStack(spacing: 2) {
                                ForEach(viewModel.currentEpisodes) { episode in
                                    EpisodeRow(
                                        episode: episode,
                                        watchProgress: appState.getWatchProgress(
                                            key: ProfileStore.episodeKey(episode.id)
                                        )
                                    ) {
                                        viewModel.playingEpisode = episode
                                    }
                                }
                            }
                        }
                    }
                    .padding(16)
                }
            }
        }
    }

    // MARK: - Episode Player

    private func episodePlayerView(episode: Episode) -> some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: { viewModel.playingEpisode = nil }) {
                    Label("Zurueck", systemImage: "chevron.left")
                }
                .buttonStyle(.borderless)

                Spacer()

                if let series = viewModel.selectedSeries {
                    Text("\(series.name) - S\(episode.season)E\(episode.episodeNum)")
                        .font(.headline)
                        .lineLimit(1)
                }

                Spacer()

                Text(episode.title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.bar)

            Divider()

            if let creds = appState.credentials,
               let idInt = Int(episode.id) {
                PlayerView(
                    url: creds.seriesURL(
                        streamID: idInt,
                        ext: episode.containerExtension ?? "mp4"
                    ),
                    title: episode.title,
                    showProgressBar: true,
                    progressKey: ProfileStore.episodeKey(episode.id)
                )
            }
        }
    }
}

// MARK: - Series Card

struct SeriesCard: View {
    let series: Series

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            CoverImageView(
                url: series.cover,
                aspectRatio: 2.0 / 3.0,
                cornerRadius: 8
            )
            .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
            .overlay(alignment: .bottomTrailing) {
                if series.ratingValue > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 8))
                        Text(String(format: "%.1f", series.ratingValue))
                            .font(.caption2.bold())
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .padding(6)
                }
            }

            Text(series.name)
                .font(.caption)
                .lineLimit(2)
                .foregroundStyle(.primary)

            if let genre = series.genre, !genre.isEmpty {
                Text(genre)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .contentShape(Rectangle())
    }
}

// MARK: - Episode Row

struct EpisodeRow: View {
    let episode: Episode
    var watchProgress: WatchProgress?
    let onPlay: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Episode number with watched indicator
            ZStack {
                Text("E\(episode.episodeNum)")
                    .font(.subheadline.monospaced().bold())
                    .foregroundStyle(isWatched ? .green : .secondary)
            }
            .frame(width: 40)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(episode.title)
                        .font(.subheadline)
                        .lineLimit(1)

                    if isWatched {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(.green)
                    }
                }

                HStack(spacing: 8) {
                    if let duration = episode.info?.duration, !duration.isEmpty {
                        Label(duration, systemImage: "clock")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    if let progress = watchProgress, !progress.isFinished, progress.position > 0.01 {
                        Text("\(Int(progress.position * 100))% gesehen")
                            .font(.caption2)
                            .foregroundStyle(.blue)
                    }
                    if let plot = episode.info?.plot, !plot.isEmpty {
                        Text(plot)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            Button(action: onPlay) {
                Image(systemName: hasProgress && !isWatched ? "play.circle.badge.clock.fill" : "play.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.quaternary.opacity(isWatched ? 0.15 : 0.3))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private var isWatched: Bool {
        watchProgress?.isFinished ?? false
    }

    private var hasProgress: Bool {
        guard let p = watchProgress else { return false }
        return p.position > 0.01
    }
}
