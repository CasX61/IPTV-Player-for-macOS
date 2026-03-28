import SwiftUI

@Observable
@MainActor
final class SeriesViewModel {
    var categories: [Category] = []
    var seriesList: [Series] = []
    var selectedCategory: Category?
    var selectedSeries: Series?
    var seriesInfo: SeriesInfo?
    var selectedSeason: Int?
    var isLoadingCategories = false
    var isLoadingSeries = false
    var isLoadingInfo = false
    var searchText = ""
    var errorMessage: String?

    // Playback state
    var playingEpisode: Episode?

    var filteredSeries: [Series] {
        if searchText.isEmpty { return seriesList }
        return seriesList.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var seasons: [Int] {
        guard let episodes = seriesInfo?.episodes else { return [] }
        return episodes.keys.compactMap { Int($0) }.sorted()
    }

    var currentEpisodes: [Episode] {
        guard let season = selectedSeason,
              let episodes = seriesInfo?.episodes?[String(season)] else { return [] }
        return episodes.sorted { $0.episodeNum < $1.episodeNum }
    }

    static let allCategory = Category.allCategory

    func loadCategories(api: XtreamAPI) async {
        isLoadingCategories = true
        errorMessage = nil
        do {
            var cats = try await api.getSeriesCategories()
            cats.insert(Self.allCategory, at: 0)
            categories = cats
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoadingCategories = false
    }

    func loadSeries(api: XtreamAPI, categoryID: String?) async {
        seriesList = []
        selectedSeries = nil
        seriesInfo = nil
        playingEpisode = nil
        searchText = ""
        isLoadingSeries = true
        do {
            seriesList = try await api.getSeries(categoryID: categoryID)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoadingSeries = false
    }

    func loadSeriesInfo(api: XtreamAPI, seriesID: Int) async {
        isLoadingInfo = true
        playingEpisode = nil
        do {
            seriesInfo = try await api.getSeriesInfo(seriesID: seriesID)
            selectedSeason = seasons.first
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoadingInfo = false
    }

    func goBackToGrid() {
        selectedSeries = nil
        seriesInfo = nil
        selectedSeason = nil
        playingEpisode = nil
    }
}
