import Foundation

// MARK: - Flexible JSON Decoding Helpers

/// Xtream Codes APIs are notoriously inconsistent with types.
/// These helpers handle Int/String/Double mismatches gracefully.
extension KeyedDecodingContainer {
    func flexInt(forKey key: K) throws -> Int {
        if let v = try? decode(Int.self, forKey: key) { return v }
        if let s = try? decode(String.self, forKey: key), let v = Int(s) { return v }
        if let d = try? decode(Double.self, forKey: key) { return Int(d) }
        throw DecodingError.typeMismatch(Int.self, .init(
            codingPath: codingPath + [key],
            debugDescription: "Expected Int-compatible value for \(key.stringValue)"
        ))
    }

    func flexIntIfPresent(forKey key: K) -> Int? {
        if let v = try? decode(Int.self, forKey: key) { return v }
        if let s = try? decode(String.self, forKey: key), let v = Int(s) { return v }
        if let d = try? decode(Double.self, forKey: key) { return Int(d) }
        return nil
    }

    func flexString(forKey key: K) throws -> String {
        if let v = try? decode(String.self, forKey: key) { return v }
        if let v = try? decode(Int.self, forKey: key) { return String(v) }
        if let v = try? decode(Double.self, forKey: key) { return String(v) }
        throw DecodingError.typeMismatch(String.self, .init(
            codingPath: codingPath + [key],
            debugDescription: "Expected String-compatible value for \(key.stringValue)"
        ))
    }

    func flexStringIfPresent(forKey key: K) -> String? {
        if let v = try? decode(String.self, forKey: key) { return v.isEmpty ? nil : v }
        if let v = try? decode(Int.self, forKey: key) { return String(v) }
        if let v = try? decode(Double.self, forKey: key) { return String(v) }
        return nil
    }

    func flexDoubleIfPresent(forKey key: K) -> Double? {
        if let v = try? decode(Double.self, forKey: key) { return v }
        if let v = try? decode(Int.self, forKey: key) { return Double(v) }
        if let s = try? decode(String.self, forKey: key), let v = Double(s) { return v }
        return nil
    }
}

/// Decodes a JSON array, silently skipping elements that fail to decode.
struct SafeArray<Element: Decodable>: Decodable {
    let items: [Element]

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        var items: [Element] = []
        while !container.isAtEnd {
            do {
                let item = try container.decode(Element.self)
                items.append(item)
            } catch {
                _ = try? container.decode(AnyJSON.self)
            }
        }
        self.items = items
    }
}

/// Can decode any JSON value - used to skip broken elements in arrays.
private enum AnyJSON: Decodable {
    case value

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .value; return }
        if (try? c.decode(Bool.self)) != nil { self = .value; return }
        if (try? c.decode(Int.self)) != nil { self = .value; return }
        if (try? c.decode(Double.self)) != nil { self = .value; return }
        if (try? c.decode(String.self)) != nil { self = .value; return }
        if (try? c.decode([AnyJSON].self)) != nil { self = .value; return }
        if (try? c.decode([String: AnyJSON].self)) != nil { self = .value; return }
        self = .value
    }
}

// MARK: - Server Credentials

struct ServerCredentials: Codable, Equatable {
    var server: String
    var username: String
    var password: String

    var baseURL: String {
        var url = server.trimmingCharacters(in: .whitespacesAndNewlines)
        if url.hasSuffix("/") { url = String(url.dropLast()) }
        return url
    }

    func liveURL(streamID: Int, format: String = "ts") -> URL? {
        URL(string: "\(baseURL)/live/\(username)/\(password)/\(streamID).\(format)")
    }

    func movieURL(streamID: Int, ext: String = "mp4") -> URL? {
        URL(string: "\(baseURL)/movie/\(username)/\(password)/\(streamID).\(ext)")
    }

    func seriesURL(streamID: Int, ext: String = "mp4") -> URL? {
        URL(string: "\(baseURL)/series/\(username)/\(password)/\(streamID).\(ext)")
    }

    func apiURL(action: String, params: [String: String] = [:]) -> URL? {
        var components = URLComponents(string: "\(baseURL)/player_api.php")
        var queryItems = [
            URLQueryItem(name: "username", value: username),
            URLQueryItem(name: "password", value: password),
        ]
        if !action.isEmpty {
            queryItems.append(URLQueryItem(name: "action", value: action))
        }
        for (key, value) in params {
            queryItems.append(URLQueryItem(name: key, value: value))
        }
        components?.queryItems = queryItems
        return components?.url
    }
}

// MARK: - Authentication Response

struct AuthResponse: Codable {
    let userInfo: UserInfo
    let serverInfo: ServerInfo

    enum CodingKeys: String, CodingKey {
        case userInfo = "user_info"
        case serverInfo = "server_info"
    }
}

struct UserInfo: Codable {
    let username: String
    let password: String
    let status: String
    let expDate: String?
    let isTrial: String?
    let activeCons: String?
    let createdAt: String?
    let maxConnections: String?
    let allowedOutputFormats: [String]?

    enum CodingKeys: String, CodingKey {
        case username, password, status
        case expDate = "exp_date"
        case isTrial = "is_trial"
        case activeCons = "active_cons"
        case createdAt = "created_at"
        case maxConnections = "max_connections"
        case allowedOutputFormats = "allowed_output_formats"
    }

    var isActive: Bool { status.lowercased() == "active" }

    var expirationDate: Date? {
        guard let exp = expDate, let timestamp = TimeInterval(exp) else { return nil }
        return Date(timeIntervalSince1970: timestamp)
    }
}

struct ServerInfo: Codable {
    let url: String?
    let port: String?
    let httpsPort: String?
    let serverProtocol: String?
    let rtmpPort: String?
    let timezone: String?
    let timestampNow: Int?
    let timeNow: String?

    enum CodingKeys: String, CodingKey {
        case url, port, timezone
        case httpsPort = "https_port"
        case serverProtocol = "server_protocol"
        case rtmpPort = "rtmp_port"
        case timestampNow = "timestamp_now"
        case timeNow = "time_now"
    }
}

// MARK: - Category

struct Category: Identifiable, Hashable {
    let categoryID: String
    let categoryName: String
    let parentID: Int?

    var id: String { categoryID }
    var isAll: Bool { categoryID == "__all__" }

    static let allCategory = Category(categoryID: "__all__", categoryName: "Alle", parentID: nil)

    init(categoryID: String, categoryName: String, parentID: Int?) {
        self.categoryID = categoryID
        self.categoryName = categoryName
        self.parentID = parentID
    }
}

extension Category: Codable {
    enum CodingKeys: String, CodingKey {
        case categoryID = "category_id"
        case categoryName = "category_name"
        case parentID = "parent_id"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        categoryID = try c.flexString(forKey: .categoryID)
        categoryName = (try? c.flexString(forKey: .categoryName)) ?? "Unbekannt"
        parentID = c.flexIntIfPresent(forKey: .parentID)
    }
}

// MARK: - Live Stream

struct LiveStream: Identifiable, Hashable {
    let num: Int?
    let name: String
    let streamType: String?
    let streamID: Int
    let streamIcon: String?
    let epgChannelID: String?
    let added: String?
    let categoryID: String?
    let tvArchive: Int?
    let directSource: String?
    let tvArchiveDuration: Int?

    var id: Int { streamID }
    var hasCatchUp: Bool { tvArchive == 1 }
}

extension LiveStream: Codable {
    enum CodingKeys: String, CodingKey {
        case num, name, added
        case streamType = "stream_type"
        case streamID = "stream_id"
        case streamIcon = "stream_icon"
        case epgChannelID = "epg_channel_id"
        case categoryID = "category_id"
        case tvArchive = "tv_archive"
        case directSource = "direct_source"
        case tvArchiveDuration = "tv_archive_duration"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        num = c.flexIntIfPresent(forKey: .num)
        name = (try? c.flexString(forKey: .name)) ?? "Unbekannt"
        streamType = try? c.decode(String.self, forKey: .streamType)
        streamID = try c.flexInt(forKey: .streamID)
        streamIcon = c.flexStringIfPresent(forKey: .streamIcon)
        epgChannelID = c.flexStringIfPresent(forKey: .epgChannelID)
        added = c.flexStringIfPresent(forKey: .added)
        categoryID = c.flexStringIfPresent(forKey: .categoryID)
        tvArchive = c.flexIntIfPresent(forKey: .tvArchive)
        directSource = c.flexStringIfPresent(forKey: .directSource)
        tvArchiveDuration = c.flexIntIfPresent(forKey: .tvArchiveDuration)
    }
}

// MARK: - VOD Stream (Movie)

struct VODStream: Identifiable, Hashable {
    let num: Int?
    let name: String
    let streamType: String?
    let streamID: Int
    let streamIcon: String?
    let rating: String?
    let rating5based: Double?
    let added: String?
    let categoryID: String?
    let containerExtension: String?
    let directSource: String?

    var id: Int { streamID }

    var ratingValue: Double {
        if let r5 = rating5based { return r5 }
        if let r = rating, let val = Double(r) { return val / 2.0 }
        return 0
    }
}

extension VODStream: Codable {
    enum CodingKeys: String, CodingKey {
        case num, name, added, rating
        case streamType = "stream_type"
        case streamID = "stream_id"
        case streamIcon = "stream_icon"
        case rating5based = "rating_5based"
        case categoryID = "category_id"
        case containerExtension = "container_extension"
        case directSource = "direct_source"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        num = c.flexIntIfPresent(forKey: .num)
        name = (try? c.flexString(forKey: .name)) ?? "Unbekannt"
        streamType = try? c.decode(String.self, forKey: .streamType)
        streamID = try c.flexInt(forKey: .streamID)
        streamIcon = c.flexStringIfPresent(forKey: .streamIcon)
        rating = c.flexStringIfPresent(forKey: .rating)
        rating5based = c.flexDoubleIfPresent(forKey: .rating5based)
        added = c.flexStringIfPresent(forKey: .added)
        categoryID = c.flexStringIfPresent(forKey: .categoryID)
        containerExtension = c.flexStringIfPresent(forKey: .containerExtension)
        directSource = c.flexStringIfPresent(forKey: .directSource)
    }
}

// MARK: - Series

struct Series: Identifiable, Hashable {
    let num: Int?
    let name: String
    let seriesID: Int
    let cover: String?
    let plot: String?
    let cast: String?
    let director: String?
    let genre: String?
    let releaseDate: String?
    let lastModified: String?
    let rating: String?
    let rating5based: Double?
    let backdropPath: [String]?
    let youtubeTrailer: String?
    let episodeRunTime: String?
    let categoryID: String?

    var id: Int { seriesID }

    var ratingValue: Double {
        if let r5 = rating5based { return r5 }
        if let r = rating, let val = Double(r) { return val / 2.0 }
        return 0
    }
}

extension Series: Codable {
    enum CodingKeys: String, CodingKey {
        case num, name, cover, plot, cast, director, genre, rating
        case seriesID = "series_id"
        case releaseDate
        case lastModified = "last_modified"
        case rating5based = "rating_5based"
        case backdropPath = "backdrop_path"
        case youtubeTrailer = "youtube_trailer"
        case episodeRunTime = "episode_run_time"
        case categoryID = "category_id"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        num = c.flexIntIfPresent(forKey: .num)
        name = (try? c.flexString(forKey: .name)) ?? "Unbekannt"
        seriesID = try c.flexInt(forKey: .seriesID)
        cover = c.flexStringIfPresent(forKey: .cover)
        plot = c.flexStringIfPresent(forKey: .plot)
        cast = c.flexStringIfPresent(forKey: .cast)
        director = c.flexStringIfPresent(forKey: .director)
        genre = c.flexStringIfPresent(forKey: .genre)
        releaseDate = c.flexStringIfPresent(forKey: .releaseDate)
        lastModified = c.flexStringIfPresent(forKey: .lastModified)
        rating = c.flexStringIfPresent(forKey: .rating)
        rating5based = c.flexDoubleIfPresent(forKey: .rating5based)
        backdropPath = try? c.decode([String].self, forKey: .backdropPath)
        youtubeTrailer = c.flexStringIfPresent(forKey: .youtubeTrailer)
        episodeRunTime = c.flexStringIfPresent(forKey: .episodeRunTime)
        categoryID = c.flexStringIfPresent(forKey: .categoryID)
    }
}

// MARK: - Series Detail

struct SeriesInfo: Codable {
    let seasons: [SeasonInfo]?
    let info: SeriesDetailInfo?
    let episodes: [String: [Episode]]?

    enum CodingKeys: String, CodingKey {
        case seasons, info, episodes
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // Seasons: tolerate individual failures
        if let raw = try? c.decode(SafeArray<SeasonInfo>.self, forKey: .seasons) {
            seasons = raw.items
        } else {
            seasons = nil
        }
        info = try? c.decode(SeriesDetailInfo.self, forKey: .info)
        // Episodes: each season uses SafeArray so one bad episode doesn't kill the whole season
        if let rawEpisodes = try? c.decode([String: SafeArray<Episode>].self, forKey: .episodes) {
            episodes = rawEpisodes.mapValues { $0.items }
        } else {
            episodes = nil
        }
    }
}

struct SeasonInfo: Codable, Identifiable, Hashable {
    let airDate: String?
    let episodeCount: Int?
    let id: Int
    let name: String
    let overview: String?
    let seasonNumber: Int
    let cover: String?
    let coverBig: String?

    enum CodingKeys: String, CodingKey {
        case id, name, overview, cover
        case airDate = "air_date"
        case episodeCount = "episode_count"
        case seasonNumber = "season_number"
        case coverBig = "cover_big"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.flexInt(forKey: .id)
        name = (try? c.flexString(forKey: .name)) ?? ""
        seasonNumber = (try? c.flexInt(forKey: .seasonNumber)) ?? 0
        airDate = c.flexStringIfPresent(forKey: .airDate)
        episodeCount = c.flexIntIfPresent(forKey: .episodeCount)
        overview = c.flexStringIfPresent(forKey: .overview)
        cover = c.flexStringIfPresent(forKey: .cover)
        coverBig = c.flexStringIfPresent(forKey: .coverBig)
    }
}

struct SeriesDetailInfo: Codable {
    let name: String?
    let cover: String?
    let plot: String?
    let cast: String?
    let director: String?
    let genre: String?
    let releaseDate: String?
    let rating: String?
    let backdropPath: [String]?

    enum CodingKeys: String, CodingKey {
        case name, cover, plot, cast, director, genre, rating
        case releaseDate
        case backdropPath = "backdrop_path"
    }
}

struct Episode: Identifiable {
    let id: String
    let episodeNum: Int
    let title: String
    let containerExtension: String?
    let info: EpisodeInfo?
    let added: String?
    let season: Int
    let directSource: String?

    static func == (lhs: Episode, rhs: Episode) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension Episode: Hashable {}

extension Episode: Codable {
    enum CodingKeys: String, CodingKey {
        case id, title, added, season, info
        case episodeNum = "episode_num"
        case containerExtension = "container_extension"
        case directSource = "direct_source"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.flexString(forKey: .id)
        episodeNum = (try? c.flexInt(forKey: .episodeNum)) ?? 0
        title = (try? c.flexString(forKey: .title)) ?? "Episode"
        containerExtension = c.flexStringIfPresent(forKey: .containerExtension)
        info = try? c.decode(EpisodeInfo.self, forKey: .info)
        added = c.flexStringIfPresent(forKey: .added)
        season = (try? c.flexInt(forKey: .season)) ?? 1
        directSource = c.flexStringIfPresent(forKey: .directSource)
    }
}

struct EpisodeInfo: Codable {
    let duration: String?
    let plot: String?
    let coverBig: String?
    let rating: Double?
    let movieImage: String?

    enum CodingKeys: String, CodingKey {
        case duration, plot, rating
        case coverBig = "cover_big"
        case movieImage = "movie_image"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        duration = c.flexStringIfPresent(forKey: .duration)
        plot = c.flexStringIfPresent(forKey: .plot)
        coverBig = c.flexStringIfPresent(forKey: .coverBig)
        rating = c.flexDoubleIfPresent(forKey: .rating)
        movieImage = c.flexStringIfPresent(forKey: .movieImage)
    }
}

// MARK: - VOD Detail Info (get_vod_info)

struct VODInfo: Codable {
    let info: VODDetailInfo?
    let movieData: VODMovieData?

    enum CodingKeys: String, CodingKey {
        case info
        case movieData = "movie_data"
    }
}

struct VODDetailInfo: Codable {
    let name: String?
    let movieImage: String?
    let coverBig: String?
    let releaseDate: String?
    let director: String?
    let actors: String?
    let cast: String?
    let description: String?
    let plot: String?
    let genre: String?
    let duration: String?
    let durationSecs: Int?
    let rating: String?
    let country: String?
    let youtubeTrailer: String?

    enum CodingKeys: String, CodingKey {
        case name, director, actors, cast, description, plot, genre, duration, rating, country
        case movieImage = "movie_image"
        case coverBig = "cover_big"
        case releaseDate = "release_date"
        case durationSecs = "duration_secs"
        case youtubeTrailer = "youtube_trailer"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = c.flexStringIfPresent(forKey: .name)
        movieImage = c.flexStringIfPresent(forKey: .movieImage)
        coverBig = c.flexStringIfPresent(forKey: .coverBig)
        releaseDate = c.flexStringIfPresent(forKey: .releaseDate)
        director = c.flexStringIfPresent(forKey: .director)
        actors = c.flexStringIfPresent(forKey: .actors)
        cast = c.flexStringIfPresent(forKey: .cast)
        description = c.flexStringIfPresent(forKey: .description)
        plot = c.flexStringIfPresent(forKey: .plot)
        genre = c.flexStringIfPresent(forKey: .genre)
        duration = c.flexStringIfPresent(forKey: .duration)
        durationSecs = c.flexIntIfPresent(forKey: .durationSecs)
        rating = c.flexStringIfPresent(forKey: .rating)
        country = c.flexStringIfPresent(forKey: .country)
        youtubeTrailer = c.flexStringIfPresent(forKey: .youtubeTrailer)
    }

    var displayPlot: String? { plot ?? description }
    var displayCast: String? { cast ?? actors }
}

struct VODMovieData: Codable {
    let streamID: Int?
    let name: String?
    let containerExtension: String?

    enum CodingKeys: String, CodingKey {
        case name
        case streamID = "stream_id"
        case containerExtension = "container_extension"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        streamID = c.flexIntIfPresent(forKey: .streamID)
        name = c.flexStringIfPresent(forKey: .name)
        containerExtension = c.flexStringIfPresent(forKey: .containerExtension)
    }
}

// MARK: - EPG

struct EPGResponse: Codable {
    let epgListings: [EPGListing]

    enum CodingKeys: String, CodingKey {
        case epgListings = "epg_listings"
    }
}

struct EPGListing: Identifiable {
    let id: String
    let epgID: String?
    let title: String
    let lang: String?
    let start: String?
    let end: String?
    let description: String?
    let channelID: String?
    let startTimestamp: String?
    let stopTimestamp: String?

    var decodedTitle: String {
        if let data = Data(base64Encoded: title),
           let decoded = String(data: data, encoding: .utf8) {
            return decoded
        }
        return title
    }

    var decodedDescription: String {
        guard let desc = description else { return "" }
        if let data = Data(base64Encoded: desc),
           let decoded = String(data: data, encoding: .utf8) {
            return decoded
        }
        return desc
    }

    var startDate: Date? {
        guard let ts = startTimestamp, let interval = TimeInterval(ts) else { return nil }
        return Date(timeIntervalSince1970: interval)
    }

    var endDate: Date? {
        guard let ts = stopTimestamp, let interval = TimeInterval(ts) else { return nil }
        return Date(timeIntervalSince1970: interval)
    }
}

extension EPGListing: Codable {
    enum CodingKeys: String, CodingKey {
        case id, title, lang, start, end, description
        case epgID = "epg_id"
        case channelID = "channel_id"
        case startTimestamp = "start_timestamp"
        case stopTimestamp = "stop_timestamp"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.flexString(forKey: .id)
        title = (try? c.flexString(forKey: .title)) ?? ""
        epgID = c.flexStringIfPresent(forKey: .epgID)
        lang = c.flexStringIfPresent(forKey: .lang)
        start = c.flexStringIfPresent(forKey: .start)
        end = c.flexStringIfPresent(forKey: .end)
        description = c.flexStringIfPresent(forKey: .description)
        channelID = c.flexStringIfPresent(forKey: .channelID)
        startTimestamp = c.flexStringIfPresent(forKey: .startTimestamp)
        stopTimestamp = c.flexStringIfPresent(forKey: .stopTimestamp)
    }
}
