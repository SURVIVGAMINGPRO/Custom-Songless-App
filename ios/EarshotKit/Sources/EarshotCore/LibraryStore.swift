import Foundation
import Observation

/// The "All" tab of a game.
public let allTab = "all"

public struct GameTab: Hashable, Sendable, Identifiable {
	public let key: String
	public let label: String
	public var id: String { key }
}

/// A library with the desktop app's backup marker.
private struct Backup: Encodable {
	let library: Library
	private enum CodingKeys: String, CodingKey { case app }

	func encode(to encoder: Encoder) throws {
		var c = encoder.container(keyedBy: CodingKeys.self)
		try c.encode("custom-songless", forKey: .app)
		try library.encode(to: encoder)
	}
}

/// Everything the player makes, kept in one JSON file in the app's storage (the
/// same shape as the desktop app's backups), saved shortly after each change.
@MainActor
@Observable
public final class LibraryStore {
	public private(set) var data: Library
	/// Set when saving failed (storage full).
	public private(set) var saveError = false

	@ObservationIgnored private let file: URL?
	@ObservationIgnored private var saveTask: Task<Void, Never>?
	/// Daily rounds older than this many days are dropped.
	private let keepDays = 60

	/// Load the library from `file`, or start empty. Pass nil to keep everything in memory (tests).
	public init(file: URL?) {
		self.file = file
		if let file, let bytes = try? Data(contentsOf: file), let saved = try? JSONDecoder().decode(Library.self, from: bytes), saved.version == 1 {
			data = saved
		} else {
			data = Library()
		}
	}

	/// The library file in Application Support.
	public static func defaultFile() -> URL {
		let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Earshot", isDirectory: true)
		try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
		return dir.appendingPathComponent("library.json")
	}

	private func save() {
		saveTask?.cancel()
		saveTask = Task { [weak self] in
			try? await Task.sleep(for: .milliseconds(300))
			guard !Task.isCancelled else { return }
			self?.flush()
		}
	}

	public func flush() {
		saveTask?.cancel()
		guard let file else { return }
		do {
			try JSONEncoder().encode(data).write(to: file, options: [.atomic])
			saveError = false
		} catch {
			saveError = true
		}
	}

	// MARK: Songs and playlists

	public func song(_ id: Int) -> Song? { data.songs[id] }

	public func playlist(_ id: String) -> Playlist? { data.playlists.first { $0.id == id } }

	private func playlistIndex(_ id: String) -> Int? { data.playlists.firstIndex { $0.id == id } }

	/// The first songs of these playlists that exist, for artwork.
	public func songsOf(_ playlistIds: [String], limit: Int = 12) -> [Song] {
		var out: [Song] = []
		for pid in playlistIds {
			for sid in playlist(pid)?.songIds ?? [] {
				if let s = data.songs[sid] { out.append(s) }
				if out.count >= limit { return out }
			}
		}
		return out
	}

	/// Games that mix two or more playlists. Single-playlist games stay behind the scenes.
	public var mixes: [Game] { data.games.filter { $0.playlistIds.count > 1 } }

	public func addSongs(_ songs: [Song]) {
		for s in songs {
			let old = data.songs[s.id]
			var merged = s
			merged.spotify = s.spotify ?? old?.spotify
			data.songs[s.id] = merged
		}
	}

	@discardableResult
	public func createPlaylist(
		name: String, source: Playlist.Source, sourceUrl: String? = nil, songs: [Song] = [], unmatched: [Unmatched] = []
	) -> Playlist {
		addSongs(songs)
		var seen = Set<Int>()
		let clean = String(name.trimmed().prefix(60))
		let p = Playlist(
			id: UUID().uuidString.lowercased(), name: clean.isEmpty ? "New playlist" : clean, source: source, sourceUrl: sourceUrl,
			songIds: songs.map(\.id).filter { seen.insert($0).inserted }, unmatched: unmatched, createdAt: nowMs(), updatedAt: nowMs()
		)
		data.playlists.append(p)
		save()
		return p
	}

	public func renamePlaylist(_ id: String, to name: String) {
		let clean = String(name.trimmed().prefix(60))
		guard let i = playlistIndex(id), !clean.isEmpty, clean != data.playlists[i].name else { return }
		data.playlists[i].name = clean
		data.playlists[i].updatedAt = nowMs()
		save()
	}

	/// Add songs to a playlist. Returns how many were new to it.
	@discardableResult
	public func addToPlaylist(_ id: String, _ songs: [Song]) -> Int {
		guard let i = playlistIndex(id) else { return 0 }
		addSongs(songs)
		var have = Set(data.playlists[i].songIds)
		let fresh = songs.filter { have.insert($0.id).inserted }
		data.playlists[i].songIds += fresh.map(\.id)
		data.playlists[i].updatedAt = nowMs()
		save()
		return fresh.count
	}

	public func removeFromPlaylist(_ id: String, songId: Int) {
		guard let i = playlistIndex(id) else { return }
		data.playlists[i].songIds.removeAll { $0 == songId }
		data.playlists[i].updatedAt = nowMs()
		pruneSongs()
		save()
	}

	/// Settle an import row that needed a look: add the chosen song, or drop it.
	public func resolveUnmatched(_ id: String, at index: Int, with song: Song?) {
		guard let i = playlistIndex(id), data.playlists[i].unmatched.indices.contains(index) else { return }
		data.playlists[i].unmatched.remove(at: index)
		if let song { addToPlaylist(id, [song]) } else { save() }
	}

	public func addUnmatched(_ id: String, _ entries: [Unmatched]) {
		guard let i = playlistIndex(id) else { return }
		data.playlists[i].unmatched += entries
		save()
	}

	public func deletePlaylist(_ id: String) {
		data.playlists.removeAll { $0.id == id }
		for g in data.games.indices { data.games[g].playlistIds.removeAll { $0 == id } }
		data.games.removeAll { $0.playlistIds.isEmpty }
		pruneSongs()
		save()
	}

	/// Forget songs no playlist uses, unless a current round still needs them.
	private func pruneSongs() {
		var used = Set(data.playlists.flatMap(\.songIds))
		for g in data.games {
			for r in Array(g.rounds.values) + Array(g.daily.values) { used.insert(r.songId) }
		}
		data.songs = data.songs.filter { used.contains($0.key) }
	}

	// MARK: Games

	public func game(_ id: String) -> Game? { data.games.first { $0.id == id } }

	private func gameIndex(_ id: String) -> Int? { data.games.firstIndex { $0.id == id } }

	public var currentGame: Game? {
		data.games.first { $0.id == data.settings.gameId } ?? data.games.first
	}

	@discardableResult
	public func createGame(name: String, playlistIds: [String], steps: [Double]? = nil, guessScope: GuessScope = .catalog) -> Game {
		let clean = String(name.trimmed().prefix(60))
		let g = Game(
			id: UUID().uuidString.lowercased(), name: clean.isEmpty ? "New game" : clean, playlistIds: playlistIds,
			steps: steps ?? defaultSteps, guessScope: guessScope, decks: [:], rounds: [:], daily: [:], stats: [:],
			createdAt: nowMs(), updatedAt: nowMs()
		)
		data.games.append(g)
		data.settings.gameId = g.id
		save()
		return g
	}

	public func updateGame(_ id: String, name: String? = nil, playlistIds: [String]? = nil, steps: [Double]? = nil) {
		guard let i = gameIndex(id) else { return }
		let restart = (steps.map { $0 != data.games[i].steps } ?? false) || (playlistIds.map { $0 != data.games[i].playlistIds } ?? false)
		if let name, !name.trimmed().isEmpty { data.games[i].name = String(name.trimmed().prefix(60)) }
		if let playlistIds { data.games[i].playlistIds = playlistIds }
		if let steps { data.games[i].steps = steps }
		data.games[i].updatedAt = nowMs()
		// Rounds in progress used the old clip lengths or songs; start them again.
		if restart { data.games[i].rounds = data.games[i].rounds.filter { $0.value.status != .playing } }
		save()
	}

	public func deleteGame(_ id: String) {
		data.games.removeAll { $0.id == id }
		if data.settings.gameId == id { data.settings.gameId = data.games.first?.id }
		pruneSongs()
		save()
	}

	public func selectGame(_ id: String) {
		guard data.settings.gameId != id else { return }
		data.settings.gameId = id
		save()
	}

	/// The game that plays just this playlist, made if needed.
	@discardableResult
	public func gameForPlaylist(_ playlistId: String) -> Game? {
		guard let p = playlist(playlistId) else { return nil }
		if let existing = data.games.first(where: { $0.playlistIds == [playlistId] }) {
			selectGame(existing.id)
			return existing
		}
		return createGame(name: p.name, playlistIds: [playlistId])
	}

	/// "All" plus one tab per playlist.
	public func tabs(_ game: Game) -> [GameTab] {
		let lists = game.playlistIds.compactMap(playlist)
		if lists.count == 1 { return [GameTab(key: allTab, label: lists[0].name)] }
		return [GameTab(key: allTab, label: "All")] + lists.map { GameTab(key: $0.id, label: $0.name) }
	}

	/// Song IDs a tab plays.
	public func pool(_ game: Game, tab: String) -> [Int] {
		let ids = tab == allTab ? game.playlistIds : game.playlistIds.filter { $0 == tab }
		var seen = Set<Int>()
		var pool: [Int] = []
		for pid in ids {
			for sid in playlist(pid)?.songIds ?? [] where data.songs[sid] != nil && seen.insert(sid).inserted { pool.append(sid) }
		}
		return pool
	}

	// MARK: Rounds

	public func round(_ game: Game, tab: String, mode: Mode, day: Int) -> Round? {
		mode == .daily ? game.daily["\(tab):\(day)"] : game.rounds[tab]
	}

	/// Start the next round. `exclude` leaves out songs that couldn't be played.
	@discardableResult
	public func startRound(_ gameId: String, tab: String, mode: Mode, day: Int, exclude: Set<Int> = []) -> Round? {
		guard let i = gameIndex(gameId) else { return nil }
		let pool = pool(data.games[i], tab: tab).filter { !exclude.contains($0) }
		guard !pool.isEmpty else { return nil }
		let r: Round
		if mode == .daily {
			guard let id = dailyPick(pool, day) else { return nil }
			r = newRound(songId: id, mode: .daily, day: day)
			data.games[i].daily["\(tab):\(day)"] = r
			data.games[i].daily = data.games[i].daily.filter { key, _ in (Int(key.split(separator: ":").last ?? "") ?? day) >= day - keepDays }
		} else {
			guard let next = draw(data.games[i].decks[tab], pool, systemRng()) else { return nil }
			data.games[i].decks[tab] = next.deck
			r = newRound(songId: next.id, mode: .unlimited)
			data.games[i].rounds[tab] = r
		}
		save()
		return r
	}

	/// Store a round after a guess or skip; finished rounds go into the stats.
	public func putRound(_ gameId: String, tab: String, _ round: Round) {
		guard let i = gameIndex(gameId) else { return }
		if round.mode == .daily {
			data.games[i].daily["\(tab):\(round.day ?? 0)"] = round
		} else {
			data.games[i].rounds[tab] = round
		}
		if round.status != .playing {
			let key = "\(round.mode.rawValue):\(tab)"
			let steps = data.games[i].steps
			data.games[i].stats[key] = recordRound(data.games[i].stats[key] ?? emptyStats(steps), round, steps)
		}
		save()
	}

	public func stats(_ game: Game, mode: Mode, tab: String) -> Stats {
		game.stats["\(mode.rawValue):\(tab)"] ?? emptyStats(game.steps)
	}

	// MARK: Settings and backups

	public func setVolume(_ v: Double) {
		data.settings.volume = v
		save()
	}

	public func setAppearance(_ a: Appearance) {
		data.settings.appearance = a
		save()
	}

	public func setMode(_ m: Mode) {
		data.settings.mode = m
		save()
	}

	public func markHelpSeen() {
		data.settings.seenHelp = true
		save()
	}

	/// The whole library as a backup file, readable by the desktop app too.
	public func backup() throws -> Data {
		let encoder = JSONEncoder()
		encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
		return try encoder.encode(Backup(library: data))
	}

	/// Replace everything with a backup. Returns false if the file isn't one.
	public func restore(_ bytes: Data) -> Bool {
		guard let lib = try? JSONDecoder().decode(Library.self, from: bytes), lib.version == 1 else { return false }
		data = lib
		flush()
		return true
	}

	public func reset() {
		data = Library()
		flush()
	}
}
