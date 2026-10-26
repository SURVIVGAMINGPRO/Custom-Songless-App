import Foundation
import Testing

@testable import EarshotCore

// Ported from the desktop app's src/lib/sources/sources.test.ts and deezer-core.test.ts.

@Suite struct LinkTests {
	@Test func readsDeezerPlaylistAndAlbumLinks() {
		#expect(parseLink("https://www.deezer.com/en/playlist/3155776842") == .deezerPlaylist(id: "3155776842"))
		#expect(parseLink("deezer.com/playlist/123?utm_source=x") == .deezerPlaylist(id: "123"))
		#expect(parseLink("https://www.deezer.com/fr/album/302127") == .deezerAlbum(id: "302127"))
		#expect(parseLink("https://link.deezer.com/s/30abcDEF") == .deezerShort(url: "https://link.deezer.com/s/30abcDEF"))
	}

	@Test func readsSpotifyPlaylistLinksAndUris() {
		let id = "37i9dQZF1DXcBWIGoYBM5M"
		let url = "https://open.spotify.com/playlist/\(id)"
		#expect(parseLink("\(url)?si=abc") == .spotifyPlaylist(id: id, url: url))
		#expect(parseLink("https://open.spotify.com/intl-de/playlist/\(id)") == .spotifyPlaylist(id: id, url: url))
		#expect(parseLink("spotify:playlist:\(id)") == .spotifyPlaylist(id: id, url: url))
	}

	@Test func ignoresEverythingElse() {
		#expect(parseLink("https://open.spotify.com/track/4uLU6hMCjMI75M1A2tKUQC") == nil)
		#expect(parseLink("https://example.com/playlist/1") == nil)
		#expect(parseLink("not a link") == nil)
	}

	@Test func makesTrackLinks() {
		#expect(spotifyTrackUrl("4uLU6hMCjMI75M1A2tKUQC")?.absoluteString == "https://open.spotify.com/track/4uLU6hMCjMI75M1A2tKUQC")
		#expect(spotifyTrackUrl("../../evil") == nil)
		#expect(deezerTrackUrl(3135556).absoluteString == "https://www.deezer.com/track/3135556")
	}
}

@Suite struct CsvTests {
	@Test func handlesQuotesCommasAndNewlinesInsideFields() {
		#expect(parseCsv("a,b\r\n\"x, y\",\"he said \"\"hi\"\"\nthere\"\n") == [["a", "b"], ["x, y", "he said \"hi\"\nthere"]])
	}

	@Test func readsAnExportifyExport() {
		let csv = [
			"\u{FEFF}\"Track URI\",\"Track Name\",\"Artist URI(s)\",\"Artist Name(s)\",\"Album Name\",\"Track Duration (ms)\",\"ISRC\"",
			"\"spotify:track:2EqlS6tkEnglzr7tkKAAYD\",\"Come Together - Remastered 2009\",\"spotify:artist:3WrFJ7ztbogyGnTHbHJFl2\",\"The Beatles\",\"Abbey Road\",\"259946\",\"gbaye0601690\"",
			"\"spotify:track:0000000000000000000000\",\"Under Pressure\",\"x\",\"Queen, David Bowie\",\"Hot Space\",\"248440\",\"\""
		].joined(separator: "\n")
		#expect(
			itemsFromCsv(csv) == .items([
				ImportItem(
					title: "Come Together - Remastered 2009", artists: ["The Beatles"], album: "Abbey Road", durationMs: 259946,
					isrc: "GBAYE0601690", spotify: "2EqlS6tkEnglzr7tkKAAYD"
				),
				ImportItem(
					title: "Under Pressure", artists: ["Queen", "David Bowie"], album: "Hot Space", durationMs: 248440,
					spotify: "0000000000000000000000"
				)
			])
		)
	}

	@Test func readsSimplerExports() {
		#expect(itemsFromCsv("Title,Artist,ISRC\nHello,Adele,GBBKS1500214") == .items([ImportItem(title: "Hello", artists: ["Adele"], isrc: "GBBKS1500214")]))
	}

	@Test func explainsFilesItCannotRead() {
		guard case .error = itemsFromCsv("Foo,Bar\n1,2") else { Issue.record("should fail"); return }
		guard case .error = itemsFromCsv("") else { Issue.record("should fail"); return }
	}

	@Test func readsPastedLines() {
		#expect(itemsFromLines("Queen - Bohemian Rhapsody\n\nHey Jude\n") == [
			ImportItem(title: "Bohemian Rhapsody", artists: ["Queen"]), ImportItem(title: "Hey Jude", artists: [])
		])
	}
}

@Suite struct MatchingTests {
	func song(id: Int = 1, title: String, artists: [String], duration: Int = 200) -> Song {
		Song(id: id, title: title, artist: artists[0], artists: artists, duration: duration)
	}

	let item = ImportItem(title: "Come Together - Remastered 2009", artists: ["The Beatles"], durationMs: 259946)

	@Test func isSureAboutTheSameSongByTheSameArtist() {
		#expect(scoreCandidate(item, song(title: "Come Together (Remastered 2009)", artists: ["The Beatles"], duration: 259)) >= sureScore)
	}

	@Test func isUnsureAboutALongerTitleByTheSameArtist() {
		let s = scoreCandidate(item, song(title: "Come Together / Something (Live)", artists: ["The Beatles"], duration: 400))
		#expect(s >= maybeScore)
		#expect(s < sureScore)
	}

	@Test func rejectsCoversByOtherArtists() {
		#expect(scoreCandidate(item, song(title: "Come Together", artists: ["Aerosmith"], duration: 230)) < sureScore)
	}

	@Test func ranksTheBestResultFirst() {
		let ranked = rankCandidates(item, [
			song(id: 2, title: "Come Together", artists: ["Aerosmith"]),
			song(id: 3, title: "Come Together", artists: ["The Beatles"], duration: 260)
		])
		#expect(ranked.first?.song.id == 3)
	}

	@Test func searchesWithTheMainArtistAndACleanTitle() {
		#expect(searchQuery(item) == "The Beatles Come Together")
		#expect(searchQuery(ImportItem(title: "Hey Jude", artists: [])) == "Hey Jude")
	}
}

// --- Deezer client, with requests answered by a stub instead of the network ---

private final class Stub: URLProtocol, @unchecked Sendable {
	typealias Handler = @Sendable (URL) -> (status: Int, headers: [String: String], body: Data)

	private static let lock = NSLock()
	nonisolated(unsafe) private static var handler: Handler?
	nonisolated(unsafe) private static var seen: [String] = []

	static func set(_ h: @escaping Handler) {
		lock.withLock {
			handler = h
			seen = []
		}
	}

	static var requests: [String] { lock.withLock { seen } }

	override class func canInit(with request: URLRequest) -> Bool { true }
	override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

	override func startLoading() {
		let url = request.url!
		let h = Self.lock.withLock {
			Self.seen.append(url.absoluteString)
			return Self.handler
		}
		let (status, headers, body) = h?(url) ?? (500, [:], Data())
		client?.urlProtocol(self, didReceive: HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: headers)!, cacheStoragePolicy: .notAllowed)
		client?.urlProtocol(self, didLoad: body)
		client?.urlProtocolDidFinishLoading(self)
	}

	override func stopLoading() {}

	static func client() -> DeezerClient {
		let config = URLSessionConfiguration.ephemeral
		config.protocolClasses = [Stub.self]
		return DeezerClient(configuration: config)
	}
}

private func json(_ text: String) -> (status: Int, headers: [String: String], body: Data) {
	(200, ["Content-Type": "application/json"], Data(text.utf8))
}

private let trackJson = #"{"id":1,"title":"Hello","isrc":"GBBKS1500214","duration":295,"preview":"https://cdnt-preview.dzcdn.net/x.mp3","artist":{"name":"Adele"},"album":{"title":"25","cover_medium":"https://e-cdns-images.dzcdn.net/c.jpg"}}"#

@Suite(.serialized) struct DeezerClientTests {
	@Test func allowsOnlyThePathsTheAppUses() {
		#expect(deezerPathAllowed("search"))
		#expect(deezerPathAllowed("track/123"))
		#expect(deezerPathAllowed("track/isrc:GBAYE0601690"))
		#expect(deezerPathAllowed("playlist/1/tracks"))
		#expect(!deezerPathAllowed("user/1/flow"))
		#expect(!deezerPathAllowed("track/123/../../user"))
	}

	@Test func passesOnlyKnownQueryParametersAndCachesAnswers() async throws {
		Stub.set { _ in json(#"{"data":[]}"#) }
		let client = Stub.client()
		_ = try await client.search("hello", limit: 5)
		_ = try await client.search("hello", limit: 5)
		#expect(Stub.requests == ["https://api.deezer.com/search?q=hello&limit=5"])
	}

	@Test func readsTracksWithTheirPreview() async throws {
		Stub.set { _ in json(trackJson) }
		let (song, preview) = try await Stub.client().track(1)
		#expect(song == Song(id: 1, title: "Hello", artist: "Adele", artists: ["Adele"], album: "25", cover: "https://e-cdns-images.dzcdn.net/c.jpg", duration: 295, isrc: "GBBKS1500214"))
		#expect(preview?.absoluteString == "https://cdnt-preview.dzcdn.net/x.mp3")
	}

	@Test func retriesWhenDeezerSaysTheQuotaIsUsedUp() async throws {
		let calls = Counter()
		Stub.set { _ in calls.bump() == 1 ? json(#"{"error":{"code":4,"message":"Quota limit exceeded"}}"#) : json(trackJson) }
		let (song, _) = try await Stub.client().track(1)
		#expect(song.title == "Hello")
		#expect(Stub.requests.count == 2)
	}

	@Test func doesNotCacheDeezersErrors() async {
		Stub.set { _ in json(#"{"error":{"code":800,"message":"no data"}}"#) }
		let client = Stub.client()
		for _ in 0..<2 {
			await #expect(throws: DeezerError.self) { try await client.track(2) }
		}
		#expect(Stub.requests.count == 2)
	}

	@Test func followsShareLinksOnlyToDeezerPlaylistsAndAlbums() async throws {
		Stub.set { url in
			let to: String
			if url.path.contains("/s/good") {
				to = "https://www.deezer.com/en/playlist/123?utm=x"
			} else if url.path.contains("/s/away") {
				to = "https://example.com/playlist/1"
			} else {
				to = "https://www.deezer.com/deezer-links-404"
			}
			return (302, ["Location": to], Data())
		}
		let client = Stub.client()
		#expect(try await client.resolveShortLink("https://link.deezer.com/s/good") == "https://www.deezer.com/en/playlist/123?utm=x")
		for bad in ["https://link.deezer.com/s/away", "https://link.deezer.com/s/gone", "https://example.com/s/good"] {
			await #expect(throws: DeezerError.self) { try await client.resolveShortLink(bad) }
		}
	}

	@Test func matchesImportRowsByIsrcThenBySearch() async throws {
		Stub.set { url in
			if url.path.contains("isrc:GBBKS1500214") { return json(trackJson) }
			if url.path.contains("isrc:") { return json(#"{"error":{"code":800,"message":"no data"}}"#) }
			return json(#"{"data":[{"id":7,"title":"Hey Jude - Remastered 2015","duration":431,"preview":"https://cdnt-preview.dzcdn.net/j.mp3","artist":{"name":"The Beatles"},"album":{"title":"1"}}]}"#)
		}
		let items = [
			ImportItem(title: "Hello", artists: ["Adele"], isrc: "GBBKS1500214", spotify: "4sPmO7WMQUAf45kwMOtONw"),
			ImportItem(title: "Hey Jude", artists: ["The Beatles"], isrc: "GBAYE0601477"),
			ImportItem(title: "Nothing Like It", artists: ["Nobody"])
		]
		let (songs, unmatched) = try await matchAll(items, client: Stub.client())
		#expect(songs.map(\.id) == [1, 7])
		#expect(songs[0].spotify == "4sPmO7WMQUAf45kwMOtONw")
		#expect(unmatched.map(\.title) == ["Nothing Like It"])
	}
}

private final class Counter: @unchecked Sendable {
	private let lock = NSLock()
	private var n = 0

	func bump() -> Int {
		lock.withLock {
			n += 1
			return n
		}
	}
}

/// Talks to the real Deezer. Run with `EARSHOT_NETWORK=1 swift test`.
@Suite(.enabled(if: ProcessInfo.processInfo.environment["EARSHOT_NETWORK"] != nil))
struct LiveDeezerTests {
	@Test func decodesARealPreviewInMemory() async throws {
		let client = DeezerClient()
		let hits = try await client.search("daft punk harder better faster stronger", limit: 5)
		let first = try #require(hits.first)
		let (_, preview) = try await client.track(first.id)
		let (data, _) = try await URLSession.shared.data(from: try #require(preview))
		let buffer = try decodeAudio(data)
		let seconds = Double(buffer.frameLength) / buffer.format.sampleRate
		#expect(seconds > 25 && seconds < 32)
		let start = soundStart(UnsafeBufferPointer(start: buffer.floatChannelData![0], count: Int(buffer.frameLength)), sampleRate: buffer.format.sampleRate)
		#expect(start < 4)
	}
}
