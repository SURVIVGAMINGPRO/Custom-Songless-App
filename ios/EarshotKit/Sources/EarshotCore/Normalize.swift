import Foundation

private func isLetterOrNumber(_ u: Unicode.Scalar) -> Bool {
	switch u.properties.generalCategory {
	case .uppercaseLetter, .lowercaseLetter, .titlecaseLetter, .modifierLetter, .otherLetter,
		.decimalNumber, .letterNumber, .otherNumber:
		return true
	default:
		return false
	}
}

private func isMark(_ u: Unicode.Scalar) -> Bool {
	switch u.properties.generalCategory {
	case .nonspacingMark, .spacingMark, .enclosingMark: return true
	default: return false
	}
}

/// Lowercase, strip accents and turn every run of non-letters/digits into one space.
public func fold(_ s: String) -> String {
	var stripped = String.UnicodeScalarView()
	for u in s.decomposedStringWithCompatibilityMapping.unicodeScalars where !isMark(u) { stripped.append(u) }
	let lower = String(stripped).lowercased().replacingOccurrences(of: "&", with: " and ")
	var out = String.UnicodeScalarView()
	var space = false
	for u in lower.unicodeScalars {
		if isLetterOrNumber(u) {
			if space, !out.isEmpty { out.append(" ") }
			space = false
			out.append(u)
		} else {
			space = true
		}
	}
	return String(out)
}

/// The part of a title that names the song, so different releases compare equal:
/// "Come Together - Remastered 2009", "Come Together (Remastered 2009)" and
/// "Come Together (feat. X)" all become "come together".
public func normalizeTitle(_ title: String) -> String {
	var t = title.replacing(regex: #"\s+[-–—]\s+.*$"#, with: "")
	t = t.replacing(regex: #"[(\[{][^)\]}]*[)\]}]"#, with: " ")
	t = t.replacing(regex: #"\s(feat|ft|featuring)\.?\s.*$"#, with: "", options: .caseInsensitive)
	let folded = fold(t)
	return folded.isEmpty ? fold(title) : folded
}

/// "The Beatles" and "Beatles" are the same artist.
public func normalizeArtist(_ name: String) -> String {
	fold(name).replacing(regex: "^the ", with: "")
}

/// Split a credit like "A feat. B & C" into its artists.
public func splitArtists(_ credit: String) -> [String] {
	let pattern = #"\s*(?:,|;|/|&|\bx\b|\band\b|\bfeat\.?|\bft\.?|\bfeaturing\b|\bwith\b|\bvs\.?)\s*"#
	let marked = credit.replacing(regex: pattern, with: "\u{1F}", options: .caseInsensitive)
	return marked.split(separator: "\u{1F}", omittingEmptySubsequences: false)
		.map { normalizeArtist(String($0)) }
		.filter { !$0.isEmpty }
}

/// True when the two credits share an artist.
public func artistsOverlap(_ a: [String], _ b: [String]) -> Bool {
	let fullA = Set(a.map(normalizeArtist))
	if b.contains(where: { fullA.contains(normalizeArtist($0)) }) { return true }
	let partsA = Set(a.flatMap(splitArtists).filter { $0.count > 2 })
	return b.flatMap(splitArtists).contains { $0.count > 2 && partsA.contains($0) }
}

/// Share of words in `a` that also appear in `b` (0 to 1).
public func wordOverlap(_ a: String, _ b: String) -> Double {
	let wa = a.split(separator: " ")
	guard !wa.isEmpty else { return 0 }
	let wb = Set(b.split(separator: " "))
	return Double(wa.filter { wb.contains($0) }.count) / Double(wa.count)
}
