import Foundation

actor XtreamAPI {
    private let session: URLSession
    private let decoder: JSONDecoder

    private(set) var credentials: ServerCredentials?

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 300
        self.session = URLSession(configuration: config)
        self.decoder = JSONDecoder()
    }

    // MARK: - Authentication

    func authenticate(credentials: ServerCredentials) async throws -> AuthResponse {
        self.credentials = credentials
        var components = URLComponents(string: "\(credentials.baseURL)/player_api.php")!
        components.queryItems = [
            URLQueryItem(name: "username", value: credentials.username),
            URLQueryItem(name: "password", value: credentials.password),
        ]
        let response: AuthResponse = try await fetch(url: components.url!)
        guard response.userInfo.isActive else {
            throw APIError.accountInactive
        }
        return response
    }

    // MARK: - Live TV

    func getLiveCategories() async throws -> [Category] {
        try await fetchSafeArray("get_live_categories")
    }

    func getLiveStreams(categoryID: String? = nil) async throws -> [LiveStream] {
        var params: [String: String] = [:]
        if let catID = categoryID { params["category_id"] = catID }
        return try await fetchSafeArray("get_live_streams", params: params)
    }

    // MARK: - VOD (Movies)

    func getVODCategories() async throws -> [Category] {
        try await fetchSafeArray("get_vod_categories")
    }

    func getVODStreams(categoryID: String? = nil) async throws -> [VODStream] {
        var params: [String: String] = [:]
        if let catID = categoryID { params["category_id"] = catID }
        return try await fetchSafeArray("get_vod_streams", params: params)
    }

    // MARK: - Series

    func getSeriesCategories() async throws -> [Category] {
        try await fetchSafeArray("get_series_categories")
    }

    func getSeries(categoryID: String? = nil) async throws -> [Series] {
        var params: [String: String] = [:]
        if let catID = categoryID { params["category_id"] = catID }
        return try await fetchSafeArray("get_series", params: params)
    }

    func getVODInfo(vodID: Int) async throws -> VODInfo {
        try await fetchAction("get_vod_info", params: ["vod_id": String(vodID)])
    }

    func getSeriesInfo(seriesID: Int) async throws -> SeriesInfo {
        try await fetchAction("get_series_info", params: ["series_id": String(seriesID)])
    }

    // MARK: - EPG

    func getShortEPG(streamID: Int) async throws -> EPGResponse {
        try await fetchAction("get_short_epg", params: ["stream_id": String(streamID)])
    }

    // MARK: - Private

    /// Fetch an array endpoint with SafeArray - skips individual items that fail to decode.
    private func fetchSafeArray<T: Decodable>(_ action: String, params: [String: String] = [:]) async throws -> [T] {
        guard let url = credentials?.apiURL(action: action, params: params) else {
            throw APIError.notAuthenticated
        }
        let result: SafeArray<T> = try await fetch(url: url)
        return result.items
    }

    private func fetchAction<T: Decodable>(_ action: String, params: [String: String] = [:]) async throws -> T {
        guard let url = credentials?.apiURL(action: action, params: params) else {
            throw APIError.notAuthenticated
        }
        return try await fetch(url: url)
    }

    private func fetch<T: Decodable>(url: URL) async throws -> T {
        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(httpResponse.statusCode)
        }
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error.localizedDescription)
        }
    }
}

// MARK: - API Errors

enum APIError: LocalizedError {
    case invalidURL
    case notAuthenticated
    case invalidResponse
    case httpError(Int)
    case accountInactive
    case decodingError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Ungueltige Server-URL"
        case .notAuthenticated:
            return "Nicht angemeldet. Bitte zuerst einloggen."
        case .invalidResponse:
            return "Ungueltige Server-Antwort"
        case .httpError(let code):
            return "Server-Fehler (HTTP \(code))"
        case .accountInactive:
            return "Account ist nicht aktiv"
        case .decodingError(let msg):
            return "Daten konnten nicht gelesen werden: \(msg)"
        }
    }
}
