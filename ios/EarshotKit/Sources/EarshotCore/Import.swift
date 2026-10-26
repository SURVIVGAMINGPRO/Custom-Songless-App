import Foundation

// --- CSV (Exportify, TuneMyMusic, Soundiiz) -----------------------------------------

/// RFC 4180 CSV: quoted fields, doubled quotes, commas and newlines inside quotes.
public func parseCsv(_ text: String) -> [[String]] {
	var rows: [[String]] = []
	var row: [String] = []
	var field = String.UnicodeScalarView()
	var quoted = false
	var chars = Array(text.unicodeScalars)
	if chars.first == "\u{FEFF}" { chars.removeFirst() }
	var i = 0
	while i < chars.count {
		let c = chars[i]
		if quoted {
			if c == "\"" {
				if i + 1 < chars.count, chars[i + 1] == "\"" {
					field.append("\"")
					i += 1
				} else {
					quoted = false
				}
			} else {
				field.append(c)
			}
		} else if c == "\"" {
			quoted = true
		} else if c == "," {
			row.append(String(field))
			field = String.UnicodeScalarView()
		} else if c == "\n" || c == "\r" {
			if c == "\r", i + 1 < chars.count, chars[i + 1] == "\n" { i += 1 }
			row.append(String(field))
			rows.append(row)
			row = []
			field = String.UnicodeScalarView()
		} else {
			field.append(c)
		}
		i += 1
	}
	if !field.isEmpty || !row.isEmpty {
		row.append(String(field))
		rows.append(row)
	}
	return rows.filter { $0.contains { !$0.trimmed().isEmpty } }
}

/// Header names used by Exportify, TuneMyMusic, Soundiiz and similar tools.
private let columns: [String: [String]] = [
	"title": ["track name", "title", "track", "song", "name", "song name", "track title"],
	"artists": ["artist name s", "artist names", "artist name", "artist", "artists"],
	"album": ["album name", "album", "album title"],
	"duration": ["track duration ms", "duration ms", "duration"],
	"isrc": ["isrc", "track isrc"],
	"uri": ["track uri", "spotify uri", "uri", "spotify id", "track id"]
]

private func findColumn(_ headers: [String], _ names: [String]) -> Int? {
	let folded = headers.map(fold)
	for name in names {
		if let i = folded.firstIndex(of: name) { return i }
	}
	return nil
}

/// Artists in one cell: Exportify separates them with commas.
private func splitArtistCell(_ cell: String) -> [String] {
	cell.split(whereSeparator: { $0 == "," || $0 == ";" }).map { String($0).trimmed() }.filter { !$0.isEmpty }
}

private func spotifyId(_ cell: String) -> String? {
	cell.firstMatch(regex: "(?:spotify:track:|open\\.spotify\\.com/track/)?([A-Za-z0-9]{22})")?[1]
}

public enum CsvResult: Equatable {
	case items([ImportItem])
	case error(String)
}

/// Turn an exported playlist CSV into import rows.
public func itemsFromCsv(_ text: String) -> CsvResult {
	let rows = parseCsv(text)
	guard rows.count >= 2 else { return .error("This file has no songs in it.") }
	let headers = rows[0]
	guard let titleCol = findColumn(headers, columns["title"]!), let artistCol = findColumn(headers, columns["artists"]!) else {
		return .error("This file doesn't have track name and artist columns. Export it again with Exportify.")
	}
	let albumCol = findColumn(headers, columns["album"]!)
	let durationCol = findColumn(headers, columns["duration"]!)
	let isrcCol = findColumn(headers, columns["isrc"]!)
	let uriCol = findColumn(headers, columns["uri"]!)
	func cell(_ r: [String], _ col: Int?) -> String? {
		guard let col, col < r.count else { return nil }
		return r[col]
	}

	var items: [ImportItem] = []
	for r in rows.dropFirst() {
		guard let title = cell(r, titleCol)?.trimmed(), !title.isEmpty else { continue }
		let artists = splitArtistCell(cell(r, artistCol) ?? "")
		guard !artists.isEmpty else { continue }
		var item = ImportItem(title: title, artists: artists)
		if let album = cell(r, albumCol)?.trimmed(), !album.isEmpty { item.album = album }
		if let ms = cell(r, durationCol).flatMap(Double.init), ms > 0 { item.durationMs = ms > 10_000 ? ms : ms * 1000 }
		if let isrc = cell(r, isrcCol)?.trimmed().uppercased(), isrc.matches(regex: "^[A-Z0-9]{12}$") { item.isrc = isrc }
		if let id = cell(r, uriCol).flatMap(spotifyId) { item.spotify = id }
		items.append(item)
	}
	return items.isEmpty ? .error("No songs could be read from this file.") : .items(items)
}

/// Pasted lines like "Artist - Title" (or just a title) into import rows.
public func itemsFromLines(_ text: String) -> [ImportItem] {
	text.components(separatedBy: .newlines)
		.map { $0.trimmed() }
		.filter { !$0.isEmpty }
		.map { line in
			if let m = line.firstMatch(regex: #"^(.+?)\s+[-–—]\s+(.+)$"#), let artist = m[1], let title = m[2] {
				return ImportItem(title: title.trimmed(), artists: [artist.trimmed()])
			}
			return ImportItem(title: line, artists: [])
		}
}

// --- Links -----------------------------------------------------------------------

public enum ParsedLink: Equatable, Sendable {
	case deezerPlaylist(id: String)
	case deezerAlbum(id: String)
	case deezerShort(url: String)
	case spotifyPlaylist(id: String, url: String)
}

/// Hosts of Deezer's share links, which redirect to the real playlist URL.
public let deezerShortHosts = ["link.deezer.com", "deezer.page.link", "dzr.page.link"]

/// Recognise a pasted playlist link. Returns nil for anything else.
public func parseLink(_ input: String) -> ParsedLink? {
	let text = input.trimmed()
	if let m = text.firstMatch(regex: "^spotify:playlist:([A-Za-z0-9]{22})$"), let id = m[1] {
		return .spotifyPlaylist(id: id, url: "https://open.spotify.com/playlist/\(id)")
	}
	let withScheme = text.matches(regex: "^https?://", options: .caseInsensitive) ? text : "https://\(text)"
	guard let url = URLComponents(string: withScheme), let rawHost = url.host?.lowercased() else { return nil }
	let host = rawHost.hasPrefix("www.") ? String(rawHost.dropFirst(4)) : rawHost
	let path = url.path

	if host == "open.spotify.com" || host == "play.spotify.com" {
		guard let m = path.firstMatch(regex: "^/(?:intl-[a-z-]+/)?(?:embed/)?playlist/([A-Za-z0-9]{22})", options: .caseInsensitive),
			let id = m[1]
		else { return nil }
		return .spotifyPlaylist(id: id, url: "https://open.spotify.com/playlist/\(id)")
	}
	if host == "deezer.com" {
		guard let m = path.firstMatch(regex: "^/(?:[a-z]{2}(?:-[a-z]{2})?/)?(playlist|album)/(\\d+)", options: .caseInsensitive),
			let kind = m[1], let id = m[2]
		else { return nil }
		return kind.lowercased() == "playlist" ? .deezerPlaylist(id: id) : .deezerAlbum(id: id)
	}
	if deezerShortHosts.contains(host), let full = url.url?.absoluteString { return .deezerShort(url: full) }
	return nil
}

public func spotifyTrackUrl(_ id: String) -> URL? {
	id.matches(regex: "^[A-Za-z0-9]{22}$") ? URL(string: "https://open.spotify.com/track/\(id)") : nil
}

public func deezerTrackUrl(_ id: Int) -> URL {
	URL(string: "https://www.deezer.com/track/\(id)")!
}

// --- Matching import rows to Deezer -----------------------------------------------------

/// Score at or above which a search result is taken without asking.
public let sureScore: Double = 85
/// Score at or above which a result is offered for review.
public let maybeScore: Double = 55

/// How well a Deezer result fits an import row (roughly 0 to 100).
public func scoreCandidate(_ item: ImportItem, _ c: Song) -> Double {
	let t = normalizeTitle(item.title)
	let ct = normalizeTitle(c.title)
	var score: Double
	if t == ct {
		score = 50
	} else if ct.contains(t) || t.contains(ct) {
		score = 30
	} else {
		score = 30 * wordOverlap(t, ct)
	}

	if item.artists.isEmpty {
		score += 20
	} else {
		let credit = fold(item.artists.joined(separator: " "))
		if artistsOverlap(item.artists, c.artists) || c.artists.contains(where: { credit.contains(normalizeArtist($0)) }) {
			score += 40
		}
	}

	if let ms = item.durationMs, c.duration > 0 {
		let diff = abs(ms / 1000 - Double(c.duration))
		if diff <= 3 { score += 10 } else if diff > 20 { score -= 10 }
	}
	return score
}

public func rankCandidates(_ item: ImportItem, _ results: [Song]) -> [(song: Song, score: Double)] {
	results.map { ($0, scoreCandidate(item, $0)) }.sorted { $0.score > $1.score }
}

/// The search text for an import row: main artist and the title without version notes.
public func searchQuery(_ item: ImportItem) -> String {
	var title = item.title.replacing(regex: #"\s+[-–—]\s+.*$"#, with: "")
	title = title.replacing(regex: #"\s*[(\[][^)\]]*[)\]]"#, with: "").trimmed()
	if title.isEmpty { title = item.title }
	return [item.artists.first ?? "", title].joined(separator: " ").trimmed()
}
