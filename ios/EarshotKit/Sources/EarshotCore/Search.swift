import Foundation

/// One way of spelling a song for search: its title and artist as space-separated words.
private struct Spelling: Sendable {
	var title: String
	var artist: String
}

private struct SongKeys: Sendable {
	/// As written (accents removed).
	var exact: Spelling
	/// Romanized and loosened, for titles in other alphabets (one per reading of "ou").
	var roman: [Spelling] = []
	/// Romanized consonants only, for Hebrew and Arabic titles.
	var bare: Spelling?
}

private let ouReadings = ["o", "u"]

private func romanize(_ text: String, ou: String) -> String {
	loose(fold(toLatin(text)), ou: ou)
}

private final class KeyCache: @unchecked Sendable {
	static let shared = KeyCache()
	private var keys: [String: SongKeys] = [:]
	private let lock = NSLock()

	func keys(for song: Song) -> SongKeys {
		let artist = song.artists.joined(separator: " ")
		let id = "\(song.id)|\(song.title)|\(artist)"
		lock.lock()
		if let k = keys[id] {
			lock.unlock()
			return k
		}
		lock.unlock()
		var k = SongKeys(exact: Spelling(title: fold(song.title), artist: fold(artist)))
		let both = "\(song.title) \(artist)"
		if hasOtherScript(both) {
			k.roman = ouReadings.map { Spelling(title: romanize(song.title, ou: $0), artist: romanize(artist, ou: $0)) }
			if writesFewVowels(both) {
				k.bare = Spelling(title: consonants(k.roman[0].title), artist: consonants(k.roman[0].artist))
			}
		}
		lock.lock()
		keys[id] = k
		lock.unlock()
		return k
	}
}

/// How well the typed words fit a spelling; nil when they don't. Lower is better.
private func rank(_ words: [String], in s: Spelling) -> Double? {
	guard !words.isEmpty else { return nil }
	let title = " \(s.title)"
	let haystack = " \(s.title) \(s.artist)"
	guard words.allSatisfy({ haystack.contains(" \($0)") }) else { return nil }
	let q = words.joined(separator: " ")
	if s.title.hasPrefix(q) { return 0 }
	if title.contains(" \(q)") { return 1 }
	if words.allSatisfy({ title.contains(" \($0)") }) { return 1.5 }
	if " \(s.artist)".contains(" \(q)") { return 2 }
	return 3
}

private func words(_ s: String) -> [String] {
	s.split(separator: " ").map(String.init)
}

/// Find songs in the game's own playlists as the player types. Every word typed
/// has to start a word of the title or artist; titles that start with the
/// query come first, then other title matches, then artist matches. Titles in
/// other alphabets also match their romanized spelling ("bankomat" → "Банкомат").
public func searchSongs(_ songs: [Song], _ query: String, limit: Int = 8) -> [Song] {
	let exact = words(fold(query))
	guard !exact.isEmpty else { return [] }
	let romans = ouReadings.map { words(romanize(query, ou: $0)) }
	let bare = romans[0].map(consonants).filter { !$0.isEmpty }

	var hits: [(song: Song, rank: Double)] = []
	var seen = Set<String>()
	for song in songs {
		let keys = KeyCache.shared.keys(for: song)
		var ranks = [rank(exact, in: keys.exact)]
		for spelling in keys.roman {
			for q in romans { ranks.append(rank(q, in: spelling)) }
		}
		// Consonants alone are a loose fit, so they rank after real matches.
		if let b = keys.bare, bare.count == romans[0].count {
			ranks.append(rank(bare, in: b).map { $0 + 0.25 })
		}
		guard let best = ranks.compactMap({ $0 }).min() else { continue }

		let key = "\(normalizeTitle(song.title))|\(normalizeArtist(song.artist))"
		guard !seen.contains(key) else { continue }
		seen.insert(key)
		hits.append((song, best))
	}
	return hits
		.sorted { $0.rank != $1.rank ? $0.rank < $1.rank : $0.song.title.localizedCompare($1.song.title) == .orderedAscending }
		.prefix(limit)
		.map(\.song)
}
