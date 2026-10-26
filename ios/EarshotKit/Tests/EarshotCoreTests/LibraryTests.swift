import Foundation
import Testing

@testable import EarshotCore

private func song(_ id: Int, _ title: String, _ artist: String = "Someone") -> Song {
	Song(id: id, title: title, artist: artist, artists: [artist], duration: 200)
}

@MainActor
@Suite struct LibraryStoreTests {
	let store = LibraryStore(file: nil)

	@Test func makesPlaylistsWithoutRepeats() {
		let p = store.createPlaylist(name: "  Road trip  ", source: .built, songs: [song(1, "A"), song(2, "B"), song(1, "A")])
		#expect(p.name == "Road trip")
		#expect(p.songIds == [1, 2])
		#expect(store.createPlaylist(name: " ", source: .built).name == "New playlist")
		#expect(store.addToPlaylist(p.id, [song(2, "B"), song(3, "C")]) == 1)
		#expect(store.playlist(p.id)?.songIds == [1, 2, 3])
	}

	@Test func forgetsSongsNoPlaylistUses() {
		let p = store.createPlaylist(name: "One", source: .built, songs: [song(1, "A"), song(2, "B")])
		store.removeFromPlaylist(p.id, songId: 2)
		#expect(store.song(2) == nil)
		#expect(store.song(1) != nil)
	}

	@Test func keepsTheSpotifyLinkWhenASongIsAddedAgain() {
		var s = song(1, "A")
		s.spotify = "4uLU6hMCjMI75M1A2tKUQC"
		store.addSongs([s])
		store.addSongs([song(1, "A")])
		#expect(store.song(1)?.spotify == "4uLU6hMCjMI75M1A2tKUQC")
	}

	@Test func givesEachPlaylistItsOwnGameAndShowsMixesSeparately() {
		let a = store.createPlaylist(name: "A", source: .built, songs: [song(1, "A")])
		let b = store.createPlaylist(name: "B", source: .built, songs: [song(2, "B")])
		let g = store.gameForPlaylist(a.id)!
		#expect(store.gameForPlaylist(a.id)?.id == g.id)
		#expect(store.tabs(g) == [GameTab(key: allTab, label: "A")])
		#expect(store.mixes.isEmpty)
		let mix = store.createGame(name: "Both", playlistIds: [a.id, b.id])
		#expect(store.mixes.map(\.id) == [mix.id])
		#expect(store.tabs(mix).map(\.label) == ["All", "A", "B"])
		#expect(store.pool(mix, tab: allTab) == [1, 2])
		#expect(store.pool(mix, tab: b.id) == [2])
		#expect(store.currentGame?.id == mix.id)
	}

	@Test func playsRoundsAndKeepsStats() throws {
		let p = store.createPlaylist(name: "A", source: .built, songs: [song(1, "A"), song(2, "B"), song(3, "C")])
		let g = store.gameForPlaylist(p.id)!
		var r = try #require(store.startRound(g.id, tab: allTab, mode: .unlimited, day: 0))
		let answer = try #require(store.song(r.songId))
		r = guess(r, GuessPick(answer), answer, g.steps)
		store.putRound(g.id, tab: allTab, r)
		let stats = store.stats(store.game(g.id)!, mode: .unlimited, tab: allTab)
		#expect(stats.played == 1)
		#expect(stats.dist.first == 1)

		// Today's song is the same every time it's started on the same day.
		let d1 = store.startRound(g.id, tab: allTab, mode: .daily, day: 300)
		let d2 = store.startRound(g.id, tab: allTab, mode: .daily, day: 300)
		#expect(d1?.songId == d2?.songId)
		#expect(d1?.songId == dailyPick([1, 2, 3], 300))
		// Old daily rounds are dropped.
		store.startRound(g.id, tab: allTab, mode: .daily, day: 200)
		store.startRound(g.id, tab: allTab, mode: .daily, day: 400)
		#expect(store.game(g.id)!.daily.keys.sorted() == ["all:400"])
	}

	@Test func restartsRoundsInProgressWhenAMixChanges() throws {
		let a = store.createPlaylist(name: "A", source: .built, songs: [song(1, "A")])
		let b = store.createPlaylist(name: "B", source: .built, songs: [song(2, "B")])
		let mix = store.createGame(name: "Mix", playlistIds: [a.id, b.id])
		_ = try #require(store.startRound(mix.id, tab: allTab, mode: .unlimited, day: 0))
		store.updateGame(mix.id, name: "Renamed")
		#expect(store.game(mix.id)?.rounds[allTab] != nil)
		store.updateGame(mix.id, steps: [1, 2, 4])
		#expect(store.game(mix.id)?.rounds[allTab] == nil)
	}

	@Test func deletingAPlaylistRemovesItFromGames() {
		let a = store.createPlaylist(name: "A", source: .built, songs: [song(1, "A")])
		let b = store.createPlaylist(name: "B", source: .built, songs: [song(2, "B")])
		store.gameForPlaylist(a.id)
		let mix = store.createGame(name: "Mix", playlistIds: [a.id, b.id])
		store.deletePlaylist(a.id)
		#expect(store.data.games.count == 1)
		#expect(store.game(mix.id)?.playlistIds == [b.id])
		#expect(store.song(1) == nil)
	}

	@Test func settlesImportRowsThatNeededALook() {
		let row = Unmatched(ImportItem(title: "B", artists: ["Someone"]), reason: .unsure, candidates: [song(2, "B")])
		let p = store.createPlaylist(name: "A", source: .spotify, songs: [song(1, "A")], unmatched: [row, row])
		store.resolveUnmatched(p.id, at: 0, with: song(2, "B"))
		store.resolveUnmatched(p.id, at: 0, with: nil)
		#expect(store.playlist(p.id)?.songIds == [1, 2])
		#expect(store.playlist(p.id)?.unmatched.isEmpty == true)
	}

	@Test func savesAndLoadsAFile() throws {
		let file = FileManager.default.temporaryDirectory.appendingPathComponent("earshot-\(UUID().uuidString).json")
		defer { try? FileManager.default.removeItem(at: file) }
		let a = LibraryStore(file: file)
		a.createPlaylist(name: "Saved", source: .built, songs: [song(5, "E")])
		a.setVolume(0.5)
		a.flush()
		let b = LibraryStore(file: file)
		#expect(b.data == a.data)
		#expect(b.data.settings.volume == 0.5)
	}
}

/// A backup as the desktop app writes it (`JSON.stringify` of its library).
private let desktopBackup = #"""
{
 "app": "custom-songless",
 "version": 1,
 "songs": {
  "3135556": {"id": 3135556, "title": "Harder, Better, Faster, Stronger", "artist": "Daft Punk", "artists": ["Daft Punk"], "album": "Discovery", "cover": "https://e-cdns-images.dzcdn.net/images/cover/x/250x250.jpg", "duration": 224, "isrc": "GBDUW0000059", "spotify": "5W3cjX2J3tjhG8zb6u0qHn"},
  "116348128": {"id": 116348128, "title": "Come Together", "artist": "The Beatles", "artists": ["The Beatles"], "album": "Abbey Road", "cover": "", "duration": 258}
 },
 "playlists": [
  {"id": "6f1c2e7a-0b9d-4c55-9a51-2f0e5c3d1b77", "name": "Road trip", "source": "spotify", "sourceUrl": "https://open.spotify.com/playlist/37i9dQZF1DXcBWIGoYBM5M", "songIds": [3135556, 116348128], "unmatched": [{"title": "Lost Song", "artists": ["Nobody"], "durationMs": 200000, "reason": "not_found", "candidates": []}], "createdAt": 1767225600000, "updatedAt": 1767225600000}
 ],
 "games": [
  {"id": "0d9e8f7a-1111-4222-8333-944455566677", "name": "Road trip", "playlistIds": ["6f1c2e7a-0b9d-4c55-9a51-2f0e5c3d1b77"], "steps": [0.13, 0.53, 2, 8, 15], "guessScope": "catalog",
   "decks": {"all": {"order": [116348128, 3135556], "pos": 1, "recent": [116348128]}},
   "rounds": {"all": {"songId": 116348128, "attempts": [{"kind": "skip"}, {"kind": "guess", "pick": {"id": 3135556, "title": "Harder, Better, Faster, Stronger", "artist": "Daft Punk"}, "result": "wrong"}], "status": "playing", "mode": "unlimited", "startedAt": 1767225600000}},
   "daily": {"all:297": {"songId": 3135556, "attempts": [], "status": "playing", "mode": "daily", "day": 297, "startedAt": 1767225600000}},
   "stats": {"unlimited:all": {"played": 4, "won": 3, "dist": [1, 1, 1, 0, 0, 1], "streak": 0, "best": 3}},
   "createdAt": 1767225600000, "updatedAt": 1767225600000}
 ],
 "settings": {"volume": 0.6, "appearance": "dark", "mode": "unlimited", "seenHelp": true, "gameId": "0d9e8f7a-1111-4222-8333-944455566677", "keys": {"skip": "Shift+Enter", "share": null}}
}
"""#

@MainActor
@Suite struct BackupTests {
	@Test func opensADesktopBackup() throws {
		let store = LibraryStore(file: nil)
		#expect(store.restore(Data(desktopBackup.utf8)))
		let lib = store.data
		#expect(lib.songs[3_135_556]?.spotify == "5W3cjX2J3tjhG8zb6u0qHn")
		#expect(lib.playlists.first?.unmatched.first?.reason == .notFound)
		let game = try #require(store.currentGame)
		#expect(game.rounds[allTab]?.attempts.count == 2)
		#expect(game.rounds[allTab]?.attempts.last == .guess(pick: GuessPick(id: 3_135_556, title: "Harder, Better, Faster, Stronger", artist: "Daft Punk"), result: .wrong))
		#expect(game.daily["all:297"]?.day == 297)
		#expect(game.stats["unlimited:all"]?.won == 3)
		#expect(lib.settings.appearance == .dark)
		#expect(lib.settings.keys?["share"] == .some(nil))
	}

	@Test func writesBackupsTheDesktopCanOpen() throws {
		let store = LibraryStore(file: nil)
		#expect(store.restore(Data(desktopBackup.utf8)))
		let out = try store.backup()
		let object = try #require(try JSONSerialization.jsonObject(with: out) as? [String: Any])
		#expect(object["app"] as? String == "custom-songless")
		#expect(object["version"] as? Int == 1)
		// Song IDs stay object keys, as in JavaScript.
		#expect((object["songs"] as? [String: Any])?.keys.sorted() == ["116348128", "3135556"])
		let attempt = try #require(((((object["games"] as? [[String: Any]])?.first?["rounds"] as? [String: Any])?["all"] as? [String: Any])?["attempts"] as? [[String: Any]])?.first)
		#expect(attempt["kind"] as? String == "skip")
		// And it reads back the same.
		let again = LibraryStore(file: nil)
		#expect(again.restore(out))
		#expect(again.data == store.data)
	}

	@Test func refusesFilesThatAreNotBackups() {
		let store = LibraryStore(file: nil)
		store.createPlaylist(name: "Keep", source: .built)
		#expect(!store.restore(Data("{}".utf8)))
		#expect(!store.restore(Data(#"{"version": 2, "songs": {}, "playlists": [], "games": []}"#.utf8)))
		#expect(!store.restore(Data("not json".utf8)))
		#expect(store.data.playlists.count == 1)
	}
}

@Suite struct DisplayTests {
	@Test func showsCoversOnlyFromDeezer() {
		func song(_ cover: String) -> Song { Song(id: 1, title: "A", artist: "B", artists: ["B"], cover: cover) }
		#expect(coverUrl(song("https://e-cdns-images.dzcdn.net/images/cover/x/250x250.jpg")) != nil)
		#expect(coverUrl(song("https://api.deezer.com/album/1/image")) != nil)
		#expect(coverUrl(song("http://e-cdns-images.dzcdn.net/x.jpg")) == nil)
		#expect(coverUrl(song("https://evil.example/dzcdn.net.jpg")) == nil)
		#expect(coverUrl(song("")) == nil)
	}

	@Test func countsAndTimes() {
		#expect(plural(1, "song") == "1 song")
		#expect(plural(3, "song") == "3 songs")
		#expect(songLength(185) == "3:05")
		let cal = Calendar.current
		let evening = cal.date(from: DateComponents(year: 2026, month: 3, day: 3, hour: 18, minute: 48))!
		#expect(untilMidnight(evening) == "5 h 12 min")
		#expect(untilMidnight(cal.date(from: DateComponents(year: 2026, month: 3, day: 3, hour: 23, minute: 59, second: 30))!) == "1 min")
	}
}
