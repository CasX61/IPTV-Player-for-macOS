import SwiftUI

@Observable
@MainActor
final class MoviesViewModel {
    var categories: [Category] = []
    var movies: [VODStream] = []
    var selectedCategory: Category?
    var isLoadingCategories = false
    var isLoadingMovies = false
    var searchText = ""
    var errorMessage: String?

    // Playback state
    var playingMovie: VODStream?

    // Info popup state
    var inspectedMovie: VODStream?
    var movieInfo: VODInfo?
    var isLoadingInfo = false

    var filteredMovies: [VODStream] {
        if searchText.isEmpty { return movies }
        return movies.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    static let allCategory = Category.allCategory

    func loadCategories(api: XtreamAPI) async {
        isLoadingCategories = true
        errorMessage = nil
        do {
            var cats = try await api.getVODCategories()
            cats.insert(Self.allCategory, at: 0)
            categories = cats
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoadingCategories = false
    }

    func loadMovies(api: XtreamAPI, categoryID: String?) async {
        movies = []
        playingMovie = nil
        inspectedMovie = nil
        movieInfo = nil
        searchText = ""
        isLoadingMovies = true
        do {
            movies = try await api.getVODStreams(categoryID: categoryID)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoadingMovies = false
    }

    func loadMovieInfo(api: XtreamAPI, streamID: Int) async {
        isLoadingInfo = true
        movieInfo = nil
        do {
            movieInfo = try await api.getVODInfo(vodID: streamID)
        } catch {
            movieInfo = nil
        }
        isLoadingInfo = false
    }

    func dismissInfo() {
        inspectedMovie = nil
        movieInfo = nil
    }
}
