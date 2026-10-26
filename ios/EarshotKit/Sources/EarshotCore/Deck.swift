import Foundation

/// A source of random numbers in 0..<1.
public typealias Rng = () -> Double

/// Small seeded random number generator (mulberry32), bit-for-bit the same as the
/// desktop app's, so the daily song is the same on every device.
public func seeded(_ seed: UInt32) -> Rng {
	var a = seed
	return {
		a = a &+ 0x6D2B_79F5
		var t = a
		t = (t ^ (t >> 15)) &* (t | 1)
		t ^= t &+ ((t ^ (t >> 7)) &* (t | 61))
		return Double(t ^ (t >> 14)) / 4_294_967_296
	}
}

/// The system's random numbers, for endless rounds.
public func systemRng() -> Rng {
	{ Double.random(in: 0..<1) }
}

/// FNV-1a hash of a string's UTF-16 code units (as JavaScript's charCodeAt sees them).
public func hash(_ s: String) -> UInt32 {
	var h: UInt32 = 0x811C_9DC5
	for unit in s.utf16 {
		h ^= UInt32(unit)
		h = h &* 0x0100_0193
	}
	return h
}

public func shuffle<T>(_ items: [T], _ rng: Rng) -> [T] {
	var a = items
	var i = a.count - 1
	while i > 0 {
		let j = Int((rng() * Double(i + 1)).rounded(.down))
		a.swapAt(i, j)
		i -= 1
	}
	return a
}

/// How many recently played songs are kept out of the start of a reshuffle.
private func recentLimit(_ size: Int) -> Int {
	min(50, size / 3)
}

/// A fresh shuffle; recently played songs go to the back so they don't come straight back.
public func newDeck(_ pool: [Int], _ rng: Rng, recent: [Int] = []) -> Deck {
	let avoid = Set(recent)
	let order = shuffle(pool, rng)
	return Deck(
		order: order.filter { !avoid.contains($0) } + order.filter { avoid.contains($0) },
		pos: 0,
		recent: Array(recent.suffix(recentLimit(pool.count)))
	)
}

/// Bring a deck in line with the pool: drop removed songs, slot new ones into the part not dealt yet.
public func syncDeck(_ deck: Deck, _ pool: [Int], _ rng: Rng) -> Deck {
	let inPool = Set(pool)
	let dealt = deck.order.prefix(deck.pos).filter { inPool.contains($0) }
	var ahead = deck.order.dropFirst(deck.pos).filter { inPool.contains($0) }
	let known = Set(deck.order)
	for id in pool where !known.contains(id) {
		ahead.insert(id, at: Int((rng() * Double(ahead.count + 1)).rounded(.down)))
	}
	return Deck(order: dealt + ahead, pos: dealt.count, recent: deck.recent.filter { inPool.contains($0) })
}

/// Deal the next song. Reshuffles when every song has been played once.
public func draw(_ deck: Deck?, _ pool: [Int], _ rng: Rng) -> (deck: Deck, id: Int)? {
	guard !pool.isEmpty else { return nil }
	var d = deck.map { syncDeck($0, pool, rng) } ?? newDeck(pool, rng)
	if d.pos >= d.order.count { d = newDeck(pool, rng, recent: d.recent) }
	let id = d.order[d.pos]
	let recent = Array((d.recent.filter { $0 != id } + [id]).suffix(recentLimit(pool.count)))
	return (Deck(order: d.order, pos: d.pos + 1, recent: recent), id)
}

/// Days since 1 January 2026 in the player's local time.
public func dayNumber(_ date: Date = Date()) -> Int {
	var utc = Calendar(identifier: .gregorian)
	utc.timeZone = TimeZone(identifier: "UTC")!
	let local = Calendar.current.dateComponents([.year, .month, .day], from: date)
	let start = utc.date(from: DateComponents(year: 2026, month: 1, day: 1))!
	let today = utc.date(from: DateComponents(year: local.year, month: local.month, day: local.day))!
	return Int((today.timeIntervalSince(start) / 86_400).rounded())
}

/// The daily song: the same for everyone with the same songs, and no repeats
/// until every song has had its day.
public func dailyPick(_ pool: [Int], _ day: Int) -> Int? {
	let sorted = Array(Set(pool)).sorted()
	guard !sorted.isEmpty else { return nil }
	let n = sorted.count
	let cycle = Int((Double(day) / Double(n)).rounded(.down))
	let seed = hash(sorted.map(String.init).joined(separator: ",")) ^ UInt32(truncatingIfNeeded: cycle)
	let order = shuffle(sorted, seeded(seed))
	return order[((day % n) + n) % n]
}
