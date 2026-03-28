import SwiftUI

@Observable
@MainActor
final class LiveViewModel {
    var categories: [Category] = []
    var streams: [LiveStream] = []
    var selectedCategory: Category?
    var selectedStream: LiveStream?
    var epgData: [EPGListing] = []
    var isLoadingCategories = false
    var isLoadingStreams = false
    var searchText = ""
    var errorMessage: String?

    var filteredStreams: [LiveStream] {
        if searchText.isEmpty { return streams }
        return streams.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    static let allCategory = Category.allCategory

    func loadCategories(api: XtreamAPI) async {
        isLoadingCategories = true
        errorMessage = nil
        do {
            var cats = try await api.getLiveCategories()
            cats.insert(Self.allCategory, at: 0)
            categories = cats
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoadingCategories = false
    }

    func loadStreams(api: XtreamAPI, categoryID: String?) async {
        streams = []
        selectedStream = nil
        epgData = []
        searchText = ""
        isLoadingStreams = true
        do {
            streams = try await api.getLiveStreams(categoryID: categoryID)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoadingStreams = false
    }

    func loadEPG(api: XtreamAPI, streamID: Int) async {
        do {
            let response = try await api.getShortEPG(streamID: streamID)
            epgData = response.epgListings
        } catch {
            epgData = []
        }
    }
}
