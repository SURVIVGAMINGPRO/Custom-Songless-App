import Foundation

// The Deezer connection: only the paths the app needs, under Deezer's rate limit
// (50 requests per 5 seconds; we stay at 45), with a short cache. Same rules as
// the desktop app's deezer-core.ts. Deezer's terms: private, non-commercial use.

public struct DeezerError: Error, LocalizedError, Equatable {
	public let message: String
	public let code: Int
	public var errorDescription: String? { message }

	public init(message: String, code: Int) {
		self.message = message
		self.code = code
	}

	public static let unreachable = DeezerError(message: "Can't reach Deezer. Check your connection.", code: 0)
}

/// Deezer's "no data" error: the thing doesn't exist (or isn't public).
public let deezerNotFound = 800
private let quotaExceeded = 4

/// The fields we use from Deezer's track objects.
struct DzTrack: Decodable {
	struct Artist: Decodable { let name: String }
	struct Album: Decodable {
		let title: String
		let cover_medium: String?
	}

	let id: Int
	let readable: Bool?
	let title: String
	let isrc: String?
	let duration: Int?
	let preview: String?
	let artist: Artist
	let contributors: [Artist]?
	var album: Album?

	var hasPreview: Bool { readable != false && !(preview ?? "").isEmpty }

	var song: Song {
		var names = [artist.name]
		for c in contributors ?? [] where !names.contains(c.name) { names.append(c.name) }
		return Song(
			id: id, title: title, artist: artist.name, artists: names, album: album?.title ?? "",
			cover: album?.cover_medium ?? "", duration: duration ?? 0, isrc: isrc
		)
	}
}

private struct DzPage<T: Decodable>: Decodable {
	let data: [T]
	let next: String?
}

private struct DzErrorBody: Decodable {
	struct E: Decodable {
		let message: String?
		let code: Int?
	}
	let error: E?
}

private struct DzTitled: Decodable {
	let title: String
	let cover_medium: String?
}

/// A playlist or album from Deezer: the songs that can be previewed, and how many couldn't.
public struct DeezerCollection: Sendable {
	public let name: String
	public let songs: [Song]
	public let skipped: Int
}

/// Paths the app may ask for.
private let allowedPaths = [
	"^search$", "^track/\\d+$", "^track/isrc:[A-Z0-9]{12}$", "^playlist/\\d+$", "^playlist/\\d+/tracks$",
	"^album/\\d+$", "^album/\\d+/tracks$"
]

func deezerPathAllowed(_ path: String) -> Bool {
	allowedPaths.contains { path.matches(regex: $0, options: .caseInsensitive) }
}

/// Stops URLSession from following redirects, so share links can be read hop by hop.
private final class NoRedirects: NSObject, URLSessionTaskDelegate {
	func urlSession(
		_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
		newRequest request: URLRequest
	) async -> URLRequest? {
		nil
	}
}

public actor DeezerClient {
	public static let shared = DeezerClient()

	private let session: URLSession
	private let noRedirect: URLSession
	private var stamps: [Date] = []
	private var cache: [String: (at: Date, data: Data)] = [:]

	/// Pass a configuration to use other URL protocols (tests).
	public init(configuration: URLSessionConfiguration? = nil) {
		session = configuration.map { URLSession(configuration: $0) } ?? .shared
		noRedirect = URLSession(configuration: configuration ?? .ephemeral, delegate: NoRedirects(), delegateQueue: nil)
	}

	/// Wait for a free slot in Deezer's rate limit.
	private func slot() async {
		while true {
			let now = Date()
			stamps.removeAll { now.timeIntervalSince($0) >= 5 }
			if stamps.count < 45 {
				stamps.append(now)
				return
			}
			let wait = 5 - now.timeIntervalSince(stamps[0]) + 0.01
			try? await Task.sleep(for: .seconds(wait))
		}
	}

	/// Track lookups hold preview links that expire after about 15 minutes.
	private func ttl(_ path: String) -> TimeInterval {
		if path.hasPrefix("track/") { return 5 * 60 }
		if path == "search" { return 10 * 60 }
		return 2 * 60
	}

	/// GET an allowed path and decode it; Deezer's own errors come back in the body.
	private func get<T: Decodable>(_ path: String, _ query: [String: String] = [:], as: T.Type) async throws -> T {
		guard deezerPathAllowed(path) else { throw DeezerError(message: "Not available.", code: 404) }
		var comps = URLComponents(string: "https://api.deezer.com/\(path)")!
		let items = ["q", "limit", "index"].compactMap { k in query[k].map { URLQueryItem(name: k, value: String($0.prefix(200))) } }
		if !items.isEmpty { comps.queryItems = items }
		let url = comps.url!
		let key = url.absoluteString

		if let hit = cache[key], Date().timeIntervalSince(hit.at) < ttl(path) { return try decode(hit.data, as: T.self) }
		for attempt in 0..<4 {
			await slot()
			let data: Data
			do {
				var request = URLRequest(url: url)
				request.timeoutInterval = 10
				(data, _) = try await session.data(for: request)
			} catch {
				throw DeezerError.unreachable
			}
			if let body = try? JSONDecoder().decode(DzErrorBody.self, from: data), let e = body.error {
				if e.code == quotaExceeded, attempt < 3 {
					try? await Task.sleep(for: .seconds(1.5 * Double(attempt + 1)))
					continue
				}
				throw DeezerError(message: e.message ?? "Deezer refused the request.", code: e.code ?? 0)
			}
			cache[key] = (Date(), data)
			if cache.count > 1000, let oldest = cache.min(by: { $0.value.at < $1.value.at })?.key { cache[oldest] = nil }
			return try decode(data, as: T.self)
		}
		throw DeezerError(message: "Deezer is busy. Try again in a moment.", code: quotaExceeded)
	}

	private func decode<T: Decodable>(_ data: Data, as: T.Type) throws -> T {
		do { return try JSONDecoder().decode(T.self, from: data) } catch {
			throw DeezerError(message: "Deezer sent something unreadable.", code: 0)
		}
	}

	/// Search Deezer's catalogue. Only songs with a preview come back.
	public func search(_ q: String, limit: Int = 10) async throws -> [Song] {
		let trimmed = q.trimmed()
		guard !trimmed.isEmpty else { return [] }
		let page = try await get("search", ["q": trimmed, "limit": String(limit)], as: DzPage<DzTrack>.self)
		return page.data.filter(\.hasPreview).map(\.song)
	}

	/// A track with a fresh preview link.
	public func track(_ id: Int) async throws -> (song: Song, preview: URL?) {
		let t = try await get("track/\(id)", as: DzTrack.self)
		return (t.song, t.hasPreview ? t.preview.flatMap(URL.init(string:)) : nil)
	}

	func trackByIsrc(_ isrc: String) async throws -> DzTrack? {
		do { return try await get("track/isrc:\(isrc)", as: DzTrack.self) } catch let e as DeezerError where e.code == deezerNotFound {
			return nil
		}
	}

	private func allTracks(_ path: String, progress: (@Sendable (Int) -> Void)? = nil) async throws -> [DzTrack] {
		var tracks: [DzTrack] = []
		var index = 0
		while index < 5000 {
			let page = try await get(path, ["index": String(index), "limit": "100"], as: DzPage<DzTrack>.self)
			tracks += page.data
			progress?(tracks.count)
			if page.next == nil || page.data.isEmpty { break }
			index += 100
		}
		return tracks
	}

	private func collect(_ name: String, _ tracks: [DzTrack]) -> DeezerCollection {
		var seen = Set<Int>()
		let playable = tracks.filter(\.hasPreview)
		let songs = playable.map(\.song).filter { seen.insert($0.id).inserted }
		return DeezerCollection(name: name, songs: songs, skipped: tracks.count - playable.count)
	}

	public func playlist(_ id: String, progress: (@Sendable (Int) -> Void)? = nil) async throws -> DeezerCollection {
		let info = try await get("playlist/\(id)", as: DzTitled.self)
		return collect(info.title, try await allTracks("playlist/\(id)/tracks", progress: progress))
	}

	public func album(_ id: String) async throws -> DeezerCollection {
		let info = try await get("album/\(id)", as: DzTitled.self)
		// Album track lists leave out the album itself.
		let tracks = try await allTracks("album/\(id)/tracks").map { t -> DzTrack in
			var t = t
			if t.album == nil { t.album = .init(title: info.title, cover_medium: info.cover_medium) }
			return t
		}
		return collect(info.title, tracks)
	}

	/// Follow a Deezer share link's redirects, staying on Deezer's own hosts.
	public func resolveShortLink(_ input: String) async throws -> String {
		guard var url = URL(string: input), let host = url.host, deezerShortHosts.contains(host) else {
			throw DeezerError(message: "That share link didn't lead to a playlist.", code: 404)
		}
		for _ in 0..<5 {
			var request = URLRequest(url: url)
			request.timeoutInterval = 10
			guard let (_, response) = try? await noRedirect.data(for: request), let http = response as? HTTPURLResponse,
				let location = http.value(forHTTPHeaderField: "Location"), let next = URL(string: location, relativeTo: url)?.absoluteURL
			else { break }
			url = next
			let nextHost = (url.host ?? "").replacing(regex: "^www\\.", with: "")
			if nextHost == "deezer.com" {
				if url.path.matches(regex: "/(playlist|album)/\\d+") { return url.absoluteString }
				break
			}
			if !deezerShortHosts.contains(url.host ?? "") { break }
		}
		throw DeezerError(message: "That share link didn't lead to a playlist.", code: 404)
	}
}

// --- Matching import rows ---------------------------------------------------------

public enum MatchOutcome: Sendable {
	case matched(Song)
	case unmatched(Unmatched)
}

/// Find an import row on Deezer: by ISRC first, then by searching title and artist.
public func matchItem(_ item: ImportItem, client: DeezerClient = .shared) async throws -> MatchOutcome {
	func withSpotify(_ s: Song) -> Song {
		var s = s
		if let id = item.spotify { s.spotify = id }
		return s
	}
	if let isrc = item.isrc, let t = try await client.trackByIsrc(isrc), t.hasPreview {
		return .matched(withSpotify(t.song))
	}
	let ranked = rankCandidates(item, try await client.search(searchQuery(item), limit: 10))
	if let best = ranked.first, best.score >= sureScore { return .matched(withSpotify(best.song)) }
	let candidates = ranked.filter { $0.score >= maybeScore / 2 }.prefix(3).map { withSpotify($0.song) }
	let reason: Unmatched.Reason = (ranked.first?.score ?? 0) >= maybeScore ? .unsure : .notFound
	return .unmatched(Unmatched(item, reason: reason, candidates: Array(candidates)))
}

/// Match many rows, a few at a time. The client keeps Deezer's rate limit.
public func matchAll(
	_ items: [ImportItem], client: DeezerClient = .shared, concurrency: Int = 4,
	progress: (@Sendable (Int, Int) -> Void)? = nil
) async throws -> (songs: [Song], unmatched: [Unmatched]) {
	var outcomes = [MatchOutcome?](repeating: nil, count: items.count)
	var done = 0
	try await withThrowingTaskGroup(of: (Int, MatchOutcome).self) { group in
		var next = 0
		func add() {
			guard next < items.count else { return }
			let i = next
			next += 1
			group.addTask {
				try Task.checkCancellation()
				do {
					return (i, try await matchItem(items[i], client: client))
				} catch let e as DeezerError where e.code == 0 {
					// Give up on the whole import when Deezer can't be reached at all.
					throw e
				} catch is CancellationError {
					throw CancellationError()
				} catch {
					return (i, .unmatched(Unmatched(items[i], reason: .notFound, candidates: [])))
				}
			}
		}
		for _ in 0..<min(concurrency, items.count) { add() }
		while let (i, outcome) = try await group.next() {
			outcomes[i] = outcome
			done += 1
			progress?(done, items.count)
			add()
		}
	}
	var seen = Set<Int>()
	var songs: [Song] = []
	var unmatched: [Unmatched] = []
	for case let outcome? in outcomes {
		switch outcome {
		case let .matched(s): if seen.insert(s.id).inserted { songs.append(s) }
		case let .unmatched(u): unmatched.append(u)
		}
	}
	return (songs, unmatched)
}
