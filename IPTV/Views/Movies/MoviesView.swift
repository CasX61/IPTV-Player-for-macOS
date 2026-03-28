import SwiftUI

struct MoviesView: View {
    @Environment(AppState.self) private var appState
    @Bindable var viewModel: MoviesViewModel

    private let columns = [GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 16)]

    var body: some View {
        HSplitView {
            categoryColumn
            contentColumn
        }
        .onChange(of: viewModel.selectedCategory) { _, category in
            guard let category else { return }
            Task {
                await viewModel.loadMovies(
                    api: appState.api,
                    categoryID: category.isAll ? nil : category.categoryID
                )
            }
        }
        .sheet(item: $viewModel.inspectedMovie) { movie in
            MovieInfoSheet(movie: movie, viewModel: viewModel)
                .environment(appState)
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
        if let movie = viewModel.playingMovie {
            moviePlayerView(movie: movie)
        } else {
            movieGridView
        }
    }

    // MARK: - Movie Grid

    private var movieGridView: some View {
        VStack(spacing: 0) {
            SearchField(text: $viewModel.searchText, placeholder: "Film suchen...")
            Divider()

            if viewModel.isLoadingMovies {
                LoadingView()
            } else if viewModel.filteredMovies.isEmpty {
                EmptyStateView(
                    message: viewModel.selectedCategory == nil
                        ? "Waehle eine Kategorie"
                        : "Keine Filme gefunden",
                    icon: "film"
                )
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(viewModel.filteredMovies) { movie in
                            MovieCard(
                                movie: movie,
                                watchProgress: appState.getWatchProgress(
                                    key: ProfileStore.movieKey(movie.streamID)
                                )
                            )
                                .onTapGesture {
                                    viewModel.inspectedMovie = movie
                                    Task {
                                        await viewModel.loadMovieInfo(
                                            api: appState.api,
                                            streamID: movie.streamID
                                        )
                                    }
                                }
                                .contextMenu {
                                    Button("Abspielen") {
                                        viewModel.playingMovie = movie
                                    }
                                    Button("Info anzeigen") {
                                        viewModel.inspectedMovie = movie
                                        Task {
                                            await viewModel.loadMovieInfo(
                                                api: appState.api,
                                                streamID: movie.streamID
                                            )
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

    // MARK: - Movie Player

    private func moviePlayerView(movie: VODStream) -> some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: { viewModel.playingMovie = nil }) {
                    Label("Zurueck", systemImage: "chevron.left")
                }
                .buttonStyle(.borderless)

                Spacer()

                Text(movie.name)
                    .font(.headline)
                    .lineLimit(1)

                Spacer()

                if movie.ratingValue > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                        Text(String(format: "%.1f", movie.ratingValue))
                    }
                    .font(.subheadline)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.bar)

            Divider()

            if let creds = appState.credentials {
                PlayerView(
                    url: creds.movieURL(
                        streamID: movie.streamID,
                        ext: movie.containerExtension ?? "mp4"
                    ),
                    title: movie.name,
                    showProgressBar: true,
                    progressKey: ProfileStore.movieKey(movie.streamID)
                )
            }
        }
    }
}

// MARK: - Movie Info Sheet

struct MovieInfoSheet: View {
    let movie: VODStream
    @Bindable var viewModel: MoviesViewModel
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Header: Cover + Basic Info
                    HStack(alignment: .top, spacing: 16) {
                        CoverImageView(
                            url: detailCover ?? movie.streamIcon,
                            aspectRatio: 2.0 / 3.0,
                            cornerRadius: 8
                        )
                        .frame(width: 160)
                        .shadow(color: .black.opacity(0.3), radius: 6, y: 3)

                        VStack(alignment: .leading, spacing: 8) {
                            Text(movie.name)
                                .font(.title2.bold())
                                .lineLimit(3)

                            if movie.ratingValue > 0 {
                                HStack(spacing: 4) {
                                    ForEach(0..<5) { i in
                                        Image(systemName: i < Int(movie.ratingValue.rounded()) ? "star.fill" : "star")
                                            .foregroundStyle(.yellow)
                                            .font(.caption)
                                    }
                                    Text(String(format: "%.1f", movie.ratingValue))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            if let info = viewModel.movieInfo?.info {
                                if let genre = info.genre, !genre.isEmpty {
                                    Label(genre, systemImage: "tag")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                if let year = info.releaseDate, !year.isEmpty {
                                    Label(year, systemImage: "calendar")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                if let duration = info.duration, !duration.isEmpty {
                                    Label(duration, systemImage: "clock")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                if let country = info.country, !country.isEmpty {
                                    Label(country, systemImage: "globe")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                if let director = info.director, !director.isEmpty {
                                    Label("Regie: \(director)", systemImage: "person.fill")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            } else if viewModel.isLoadingInfo {
                                ProgressView("Lade Infos...")
                                    .controlSize(.small)
                            }
                        }
                    }

                    // Plot
                    if let info = viewModel.movieInfo?.info, let plot = info.displayPlot, !plot.isEmpty {
                        Divider()
                        Text("Beschreibung")
                            .font(.headline)
                        Text(plot)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }

                    // Cast
                    if let info = viewModel.movieInfo?.info, let cast = info.displayCast, !cast.isEmpty {
                        Divider()
                        Text("Besetzung")
                            .font(.headline)
                        Text(cast)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .lineLimit(4)
                    }
                }
                .padding(24)
            }

            Divider()

            // Action buttons
            HStack(spacing: 12) {
                Button(action: { dismiss() }) {
                    Text("Schliessen")
                        .frame(width: 100)
                }
                .buttonStyle(.bordered)
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button(action: {
                    dismiss()
                    viewModel.playingMovie = movie
                }) {
                    Label("Abspielen", systemImage: "play.fill")
                        .frame(width: 140)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
            .padding(16)
        }
        .frame(width: 600, height: 500)
    }

    private var detailCover: String? {
        viewModel.movieInfo?.info?.coverBig ?? viewModel.movieInfo?.info?.movieImage
    }
}

// MARK: - Movie Card

struct MovieCard: View {
    let movie: VODStream
    var watchProgress: WatchProgress?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            CoverImageView(
                url: movie.streamIcon,
                aspectRatio: 2.0 / 3.0,
                cornerRadius: 8
            )
            .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
            .overlay(alignment: .bottom) {
                if let progress = watchProgress, progress.position > 0.01 {
                    GeometryReader { geo in
                        VStack {
                            Spacer()
                            ZStack(alignment: .leading) {
                                Rectangle()
                                    .fill(.black.opacity(0.5))
                                    .frame(height: 3)
                                Rectangle()
                                    .fill(progress.isFinished ? .green : .blue)
                                    .frame(width: geo.size.width * CGFloat(progress.position), height: 3)
                            }
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .overlay(alignment: .topTrailing) {
                if let progress = watchProgress, progress.isFinished {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                        .padding(4)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(movie.name)
                    .font(.caption)
                    .lineLimit(2)
                    .foregroundStyle(.primary)

                if movie.ratingValue > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                        Text(String(format: "%.1f", movie.ratingValue))
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .contentShape(Rectangle())
    }
}

// MARK: - Cover Image View

struct CoverImageView: View {
    let url: String?
    let aspectRatio: CGFloat
    let cornerRadius: CGFloat

    var body: some View {
        AsyncImage(url: imageURL) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            case .failure:
                placeholder
            default:
                ZStack {
                    placeholder
                    ProgressView()
                        .controlSize(.small)
                }
            }
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }

    private var imageURL: URL? {
        guard let url, !url.isEmpty else { return nil }
        return URL(string: url)
    }

    private var placeholder: some View {
        Rectangle()
            .fill(.quaternary)
            .overlay {
                Image(systemName: "photo")
                    .font(.title2)
                    .foregroundStyle(.tertiary)
            }
    }
}
