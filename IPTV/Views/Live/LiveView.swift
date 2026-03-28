import SwiftUI

struct LiveView: View {
    @Environment(AppState.self) private var appState
    @Bindable var viewModel: LiveViewModel

    var body: some View {
        HSplitView {
            // MARK: Column 1 - Categories
            categoryColumn

            // MARK: Column 2 - Channels
            channelColumn

            // MARK: Column 3 - Player + EPG
            playerColumn
        }
        .onChange(of: viewModel.selectedCategory) { _, category in
            guard let category else { return }
            Task {
                await viewModel.loadStreams(
                    api: appState.api,
                    categoryID: category.isAll ? nil : category.categoryID
                )
            }
        }
        .onChange(of: viewModel.selectedStream) { _, stream in
            guard let stream else { return }
            Task {
                await viewModel.loadEPG(api: appState.api, streamID: stream.streamID)
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
                    HStack {
                        Text(category.categoryName)
                            .lineLimit(1)
                        Spacer()
                    }
                    .tag(category)
                }
                .listStyle(.sidebar)
            }
        }
        .frame(minWidth: 160, idealWidth: 200, maxWidth: 260)
    }

    // MARK: - Channel Column

    private var channelColumn: some View {
        VStack(spacing: 0) {
            // Search bar
            SearchField(text: $viewModel.searchText, placeholder: "Kanal suchen...")

            Divider()

            if viewModel.isLoadingStreams {
                LoadingView()
            } else if viewModel.filteredStreams.isEmpty {
                EmptyStateView(
                    message: viewModel.selectedCategory == nil
                        ? "Waehle eine Kategorie"
                        : "Keine Kanaele gefunden",
                    icon: "antenna.radiowaves.left.and.right"
                )
            } else {
                List(viewModel.filteredStreams, selection: $viewModel.selectedStream) { stream in
                    ChannelRow(stream: stream)
                        .tag(stream)
                }
                .listStyle(.plain)
            }
        }
        .frame(minWidth: 220, idealWidth: 280, maxWidth: 380)
    }

    // MARK: - Player Column

    private var playerColumn: some View {
        VStack(spacing: 0) {
            if let stream = viewModel.selectedStream,
               let creds = appState.credentials {
                // Player
                PlayerView(
                    url: creds.liveURL(streamID: stream.streamID),
                    title: stream.name
                )

                // Channel info + EPG
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        if let iconURL = stream.streamIcon, let url = URL(string: iconURL) {
                            AsyncImage(url: url) { image in
                                image.resizable().aspectRatio(contentMode: .fit)
                            } placeholder: {
                                Color.clear
                            }
                            .frame(width: 28, height: 28)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        }

                        Text(stream.name)
                            .font(.headline)

                        Spacer()

                        if stream.hasCatchUp {
                            Label("Catch-Up", systemImage: "clock.arrow.circlepath")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if !viewModel.epgData.isEmpty {
                        EPGListView(listings: viewModel.epgData)
                    }
                }
                .padding(12)
                .background(.bar)
            } else {
                PlayerPlaceholderView(
                    icon: "tv",
                    message: "Waehle einen Kanal"
                )
            }
        }
        .frame(minWidth: 400)
    }
}

// MARK: - Channel Row

struct ChannelRow: View {
    let stream: LiveStream

    var body: some View {
        HStack(spacing: 10) {
            if let iconURL = stream.streamIcon, let url = URL(string: iconURL) {
                AsyncImage(url: url) { image in
                    image.resizable().aspectRatio(contentMode: .fit)
                } placeholder: {
                    Image(systemName: "tv")
                        .foregroundStyle(.tertiary)
                }
                .frame(width: 30, height: 30)
                .clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
                Image(systemName: "tv")
                    .frame(width: 30, height: 30)
                    .foregroundStyle(.tertiary)
            }

            Text(stream.name)
                .lineLimit(1)

            Spacer()

            if stream.hasCatchUp {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - EPG List

struct EPGListView: View {
    let listings: [EPGListing]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("TV Programm", systemImage: "clock")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(listings) { listing in
                        HStack(alignment: .top, spacing: 8) {
                            if let start = listing.startDate {
                                Text(start.formatted(date: .omitted, time: .shortened))
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                                    .frame(width: 50, alignment: .leading)
                            }
                            Text(listing.decodedTitle)
                                .font(.caption)
                                .lineLimit(2)
                        }
                    }
                }
            }
        }
        .frame(maxHeight: 120)
    }
}

// MARK: - Shared Components

struct SectionHeader: View {
    let title: String
    let icon: String

    var body: some View {
        Label(title, systemImage: icon)
            .font(.headline)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.bar)
    }
}

struct SearchField: View {
    @Binding var text: String
    let placeholder: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.caption)
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.body)
            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(8)
        .background(.bar)
    }
}

struct LoadingView: View {
    var body: some View {
        VStack {
            Spacer()
            ProgressView()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct EmptyStateView: View {
    let message: String
    let icon: String

    var body: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: icon)
                .font(.title)
                .foregroundStyle(.tertiary)
            Text(message)
                .foregroundStyle(.secondary)
                .font(.subheadline)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
