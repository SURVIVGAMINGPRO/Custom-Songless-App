import Foundation

// The saved data, in the same JSON shape as the desktop app's library and
// backups (src/lib/game/types.ts), so a backup made on one opens on the other.
// Times are milliseconds since 1970, as in JavaScript.

/// A song we can play: every song in the library is a Deezer track with a preview.
public struct Song: Codable, Hashable, Sendable, Identifiable {
	/// Deezer track ID.
	public var id: Int
	public var title: String
	/// Main artist.
	public var artist: String
	/// Every known artist, main artist first.
	public var artists: [String]
	public var album: String
	/// Album cover URL, or "" when Deezer has none.
	public var cover: String
	/// Full song length in seconds.
	public var duration: Int
	public var isrc: String?
	/// Spotify track ID, when the song came from a Spotify export.
	public var spotify: String?

	public init(
		id: Int, title: String, artist: String, artists: [String], album: String = "", cover: String = "",
		duration: Int = 0, isrc: String? = nil, spotify: String? = nil
	) {
		self.id = id
		self.title = title
		self.artist = artist
		self.artists = artists
		self.album = album
		self.cover = cover
		self.duration = duration
		self.isrc = isrc
		self.spotify = spotify
	}
}

/// A row from an import (CSV, pasted text) before it is matched to Deezer.
public struct ImportItem: Codable, Hashable, Sendable {
	public var title: String
	public var artists: [String]
	public var album: String?
	public var durationMs: Double?
	public var isrc: String?
	public var spotify: String?

	public init(
		title: String, artists: [String], album: String? = nil, durationMs: Double? = nil, isrc: String? = nil,
		spotify: String? = nil
	) {
		self.title = title
		self.artists = artists
		self.album = album
		self.durationMs = durationMs
		self.isrc = isrc
		self.spotify = spotify
	}
}

/// An imported row we couldn't match with confidence; shown for review.
public struct Unmatched: Codable, Hashable, Sendable {
	public enum Reason: String, Codable, Sendable { case notFound = "not_found", unsure }

	public var title: String
	public var artists: [String]
	public var album: String?
	public var durationMs: Double?
	public var isrc: String?
	public var spotify: String?
	public var reason: Reason
	public var candidates: [Song]

	public init(_ item: ImportItem, reason: Reason, candidates: [Song]) {
		title = item.title
		artists = item.artists
		album = item.album
		durationMs = item.durationMs
		isrc = item.isrc
		spotify = item.spotify
		self.reason = reason
		self.candidates = candidates
	}

	public var item: ImportItem {
		ImportItem(title: title, artists: artists, album: album, durationMs: durationMs, isrc: isrc, spotify: spotify)
	}
}

public struct Playlist: Codable, Hashable, Sendable, Identifiable {
	public enum Source: String, Codable, Sendable { case deezer, spotify, built }

	public var id: String
	public var name: String
	public var source: Source
	/// The link it was imported from, if any.
	public var sourceUrl: String?
	public var songIds: [Int]
	public var unmatched: [Unmatched]
	public var createdAt: Double
	public var updatedAt: Double
}

public enum GuessResult: String, Codable, Sendable { case correct, artist, wrong }

/// What a player picked from the search list.
public struct GuessPick: Codable, Hashable, Sendable {
	public var id: Int
	public var title: String
	public var artist: String
	public var artists: [String]?
	public var isrc: String?

	public init(id: Int, title: String, artist: String, artists: [String]? = nil, isrc: String? = nil) {
		self.id = id
		self.title = title
		self.artist = artist
		self.artists = artists
		self.isrc = isrc
	}

	public init(_ song: Song) {
		self.init(id: song.id, title: song.title, artist: song.artist, artists: song.artists, isrc: song.isrc)
	}
}

public enum Attempt: Codable, Hashable, Sendable {
	case skip
	case guess(pick: GuessPick, result: GuessResult)

	private enum CodingKeys: String, CodingKey { case kind, pick, result }

	public init(from decoder: Decoder) throws {
		let c = try decoder.container(keyedBy: CodingKeys.self)
		if try c.decode(String.self, forKey: .kind) == "skip" {
			self = .skip
		} else {
			self = .guess(pick: try c.decode(GuessPick.self, forKey: .pick), result: try c.decode(GuessResult.self, forKey: .result))
		}
	}

	public func encode(to encoder: Encoder) throws {
		var c = encoder.container(keyedBy: CodingKeys.self)
		switch self {
		case .skip:
			try c.encode("skip", forKey: .kind)
		case let .guess(pick, result):
			try c.encode("guess", forKey: .kind)
			try c.encode(pick, forKey: .pick)
			try c.encode(result, forKey: .result)
		}
	}
}

public enum Mode: String, Codable, Sendable, CaseIterable { case unlimited, daily }

public struct Round: Codable, Hashable, Sendable {
	public enum Status: String, Codable, Sendable { case playing, won, lost }

	public var songId: Int
	public var attempts: [Attempt]
	public var status: Status
	public var mode: Mode
	/// Daily rounds: the day number (see `dayNumber`).
	public var day: Int?
	public var startedAt: Double
	public var endedAt: Double?
}

/// A shuffled order of song IDs, dealt one by one so songs don't repeat.
public struct Deck: Codable, Hashable, Sendable {
	public var order: [Int]
	public var pos: Int
	/// Recently dealt IDs, kept out of the start of the next shuffle.
	public var recent: [Int]
}

public struct Stats: Codable, Hashable, Sendable {
	public var played: Int
	public var won: Int
	/// dist[i] = rounds won on attempt i + 1; the last slot counts losses.
	public var dist: [Int]
	public var streak: Int
	public var best: Int
	/// Daily stats: the last day played, to know whether the streak continues.
	public var lastDay: Int?
}

public enum GuessScope: String, Codable, Sendable { case catalog, game }

public struct Game: Codable, Hashable, Sendable, Identifiable {
	public var id: String
	public var name: String
	public var playlistIds: [String]
	/// Clip length in seconds for each attempt.
	public var steps: [Double]
	/// Kept for older saves; guesses always come from the game's own songs.
	public var guessScope: GuessScope
	/// Keyed by tab ("all" or a playlist ID).
	public var decks: [String: Deck]
	/// Current endless round, keyed by tab.
	public var rounds: [String: Round]
	/// Daily rounds, keyed "\(tab):\(day)".
	public var daily: [String: Round]
	/// Keyed "\(mode):\(tab)".
	public var stats: [String: Stats]
	public var createdAt: Double
	public var updatedAt: Double
}

public enum Appearance: String, Codable, Sendable, CaseIterable { case system, light, dark }

public struct Settings: Codable, Hashable, Sendable {
	/// 0 to 1.
	public var volume: Double = 0.8
	public var appearance: Appearance = .system
	public var mode: Mode = .unlimited
	public var gameId: String?
	public var seenHelp = false
	/// Changed keyboard shortcuts on the desktop app; kept so a backup round-trips.
	public var keys: [String: String?]?

	public init() {}

	private enum CodingKeys: String, CodingKey { case volume, appearance, mode, gameId, seenHelp, keys }

	public init(from decoder: Decoder) throws {
		let c = try decoder.container(keyedBy: CodingKeys.self)
		volume = try c.decodeIfPresent(Double.self, forKey: .volume) ?? 0.8
		appearance = (try? c.decodeIfPresent(Appearance.self, forKey: .appearance)) ?? .system
		mode = (try? c.decodeIfPresent(Mode.self, forKey: .mode)) ?? .unlimited
		gameId = try c.decodeIfPresent(String.self, forKey: .gameId)
		seenHelp = try c.decodeIfPresent(Bool.self, forKey: .seenHelp) ?? false
		keys = try? c.decodeIfPresent([String: String?].self, forKey: .keys)
	}
}

public struct Library: Codable, Hashable, Sendable {
	public var version = 1
	public var songs: [Int: Song] = [:]
	public var playlists: [Playlist] = []
	public var games: [Game] = []
	public var settings = Settings()

	public init() {}

	private enum CodingKeys: String, CodingKey { case version, songs, playlists, games, settings }

	public init(from decoder: Decoder) throws {
		let c = try decoder.container(keyedBy: CodingKeys.self)
		version = try c.decode(Int.self, forKey: .version)
		songs = try c.decode([Int: Song].self, forKey: .songs)
		playlists = try c.decode([Playlist].self, forKey: .playlists)
		games = try c.decode([Game].self, forKey: .games)
		settings = try c.decodeIfPresent(Settings.self, forKey: .settings) ?? Settings()
	}
}

/// Milliseconds since 1970, like JavaScript's Date.now().
public func nowMs() -> Double {
	(Date().timeIntervalSince1970 * 1000).rounded()
}
