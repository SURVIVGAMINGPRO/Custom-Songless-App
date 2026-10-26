import Foundation
import Testing

@testable import EarshotCore

// Ported from the desktop app's src/lib/game/game.test.ts.

private let answer = Song(
	id: 116_348_128, title: "Come Together (Remastered 2009)", artist: "The Beatles", artists: ["The Beatles"],
	album: "Abbey Road", duration: 258, isrc: "GBAYE0601690"
)

private func pick(id: Int = 1, title: String = "Something", artist: String = "Nobody", isrc: String? = nil) -> GuessPick {
	GuessPick(id: id, title: title, artist: artist, isrc: isrc)
}

@Suite struct NormalizeTests {
	@Test func dropsVersionNotesFromTitles() {
		#expect(normalizeTitle("Come Together - Remastered 2009") == "come together")
		#expect(normalizeTitle("Come Together (Remastered 2009)") == "come together")
		#expect(normalizeTitle("Señorita (feat. Someone)") == "senorita")
		#expect(normalizeTitle("Song feat. Other Person") == "song")
		#expect(normalizeTitle("Rock & Roll") == "rock and roll")
	}

	@Test func keepsTitlesThatAreOnlyBrackets() {
		#expect(normalizeTitle("(Intro)") == "intro")
	}

	@Test func treatsTheXAndXAsOneArtist() {
		#expect(normalizeArtist("The Beatles") == normalizeArtist("beatles"))
		#expect(normalizeArtist("Beyoncé") == "beyonce")
	}

	@Test func splitsSharedCredits() {
		#expect(splitArtists("Calvin Harris feat. Rihanna & Someone") == ["calvin harris", "rihanna", "someone"])
		#expect(artistsOverlap(["Calvin Harris, Rihanna"], ["Rihanna"]))
		#expect(artistsOverlap(["Simon & Garfunkel"], ["Simon & Garfunkel"]))
		#expect(!artistsOverlap(["Queen"], ["Queens of the Stone Age"]))
	}
}

@Suite struct JudgeTests {
	@Test func acceptsTheSameTrackIsrcOrSongOnAnotherRelease() {
		#expect(judge(pick(id: answer.id), answer) == .correct)
		#expect(judge(pick(isrc: "gbaye0601690"), answer) == .correct)
		#expect(judge(pick(title: "Come Together - 2019 Mix", artist: "Beatles"), answer) == .correct)
	}

	@Test func givesOrangeForTheRightArtistAndRedOtherwise() {
		#expect(judge(pick(title: "Something", artist: "The Beatles"), answer) == .artist)
		#expect(judge(pick(title: "Come Together", artist: "Aerosmith"), answer) == .wrong)
	}
}

@Suite struct RoundTests {
	let steps = defaultSteps

	@Test func unlocksALongerClipAfterEachMissOrSkip() {
		var r = newRound(songId: answer.id, mode: .unlimited)
		#expect(clipSeconds(r, steps) == 0.13)
		r = skip(r, steps)
		#expect(stepIndex(r, steps) == 1)
		r = guess(r, pick(artist: "The Beatles"), answer, steps)
		#expect(clipSeconds(r, steps) == 2)
		r = guess(r, pick(id: answer.id), answer, steps)
		#expect(r.status == .won)
		#expect(emojiGrid(r, steps) == "⬜🟧🟩⬛⬛")
		#expect(clipSeconds(r, steps) == 30)
	}

	@Test func endsAfterTheLastClip() {
		var r = newRound(songId: answer.id, mode: .unlimited)
		for _ in steps { r = skip(r, steps) }
		#expect(r.status == .lost)
		#expect(skip(r, steps) == r)
	}

	@Test func readsTypedClipLengths() throws {
		#expect(try parseSteps("0.13, 0.53, 2, 8, 15").get() == defaultSteps)
		#expect(try parseSteps("1 2 4").get() == [1, 2, 4])
		func failure(_ text: String) -> String {
			if case let .failure(e) = parseSteps(text) { return e.message }
			return ""
		}
		#expect(failure("2, 1").contains("longer"))
		#expect(failure("1, 40").contains("at most"))
		#expect(failure("1").contains("between"))
		#expect(failure("a, b").contains("numbers"))
	}

	@Test func formatsClipLengthsLikeSongless() {
		#expect(formatSeconds(0.13) == "0.1 seconds")
		#expect(formatSeconds(0.53) == "0.5 seconds")
		#expect(formatSeconds(1) == "1 second")
		#expect(formatSeconds(15, short: true) == "15s")
	}

	@Test func writesShareText() {
		var r = newRound(songId: answer.id, mode: .daily, day: 11)
		r = guess(r, pick(), answer, steps)
		r = guess(r, pick(id: answer.id), answer, steps)
		#expect(shareText(app: "Earshot", game: "Road trip", tab: "All", round: r, steps: steps) == "Earshot #12 · Road trip · All\n🟥🟩⬛⬛⬛ 0.5s")
	}
}

@Suite struct StatsTests {
	let steps = defaultSteps

	func won(day: Int? = nil) -> Round {
		guess(newRound(songId: 1, mode: day == nil ? .unlimited : .daily, day: day), pick(id: answer.id), answer, steps)
	}

	@Test func countsWinsLossesAndStreaks() {
		var s = emptyStats(steps)
		s = recordRound(s, won(), steps)
		s = recordRound(s, won(), steps)
		var lost = newRound(songId: 1, mode: .unlimited)
		for _ in steps { lost = skip(lost, steps) }
		s = recordRound(s, lost, steps)
		#expect(s.played == 3)
		#expect(s.won == 2)
		#expect(s.streak == 0)
		#expect(s.best == 2)
		#expect(s.dist == [2, 0, 0, 0, 0, 1])
	}

	@Test func breaksADailyStreakWhenADayIsMissed() {
		var s = emptyStats(steps)
		s = recordRound(s, won(day: 3), steps)
		s = recordRound(s, won(day: 4), steps)
		#expect(s.streak == 2)
		s = recordRound(s, won(day: 6), steps)
		#expect(s.streak == 1)
		#expect(s.best == 2)
	}
}

@Suite struct DeckTests {
	let pool = Array(1...20)

	@Test func dealsEverySongOnceBeforeRepeating() {
		let rng = seeded(7)
		var deck: Deck?
		var seen: [Int] = []
		for _ in pool {
			let r = draw(deck, pool, rng)!
			deck = r.deck
			seen.append(r.id)
		}
		#expect(seen.sorted() == pool)
	}

	@Test func keepsRecentSongsOutOfTheStartOfTheNextShuffle() {
		let rng = seeded(3)
		var deck: Deck?
		var first: [Int] = []
		for _ in pool {
			let r = draw(deck, pool, rng)!
			deck = r.deck
			first.append(r.id)
		}
		let next = draw(deck, pool, rng)!
		#expect(!first.suffix(6).contains(next.id))
	}

	@Test func followsSongsBeingAddedAndRemoved() {
		let rng = seeded(1)
		var dealt = newDeck([1, 2, 3, 4], rng)
		dealt.pos = 2
		let synced = syncDeck(dealt, [2, 3, 4, 5, 6], rng)
		#expect(synced.order.count == 5)
		#expect(!synced.order.contains(1))
		#expect(Set(synced.order) == [2, 3, 4, 5, 6])
		// New songs only go into the part not dealt yet.
		#expect(!synced.order.prefix(synced.pos).contains(5))
	}

	@Test func dailyIsTheSameForTheSameSongsAndCyclesWithoutRepeats() {
		let pool = [30, 10, 20, 40, 50]
		#expect(dailyPick(pool, 9) == dailyPick(pool.reversed(), 9))
		#expect(Set((0..<5).compactMap { dailyPick(pool, $0) }).count == 5)
		#expect(dailyPick([], 3) == nil)
	}

	@Test func countsDaysFromTheFirstOfJanuary2026() {
		let cal = Calendar.current
		#expect(dayNumber(cal.date(from: DateComponents(year: 2026, month: 1, day: 1, hour: 23))!) == 0)
		#expect(dayNumber(cal.date(from: DateComponents(year: 2026, month: 10, day: 25, hour: 8))!) == 297)
	}
}

/// The same seeds must give the same songs as the desktop app, so a playlist's
/// "Today's song" is the same on both. Values from running the desktop's deck.ts.
@Suite struct DesktopParityTests {
	@Test func seededRandomNumbers() {
		let r = seeded(7)
		let values = (0..<5).map { _ in r() }
		#expect(values == [0.011704753153026104, 0.06195825757458806, 0.97690763277933, 0.6990287057124078, 0.5214452685322613])
	}

	@Test func stringHashes() {
		#expect(hash("") == 2_166_136_261)
		#expect(hash("a") == 3_826_002_220)
		#expect(hash("hello") == 1_335_831_723)
		#expect(hash("1,2,3") == 567_137_239)
		#expect(hash("Банкомат") == 2_711_772_899)
		#expect(hash("a😀b") == 2_412_414_209)
	}

	@Test func shufflesAndDeals() {
		#expect(shuffle(Array(1...10), seeded(42)) == [1, 8, 4, 6, 3, 2, 9, 10, 5, 7])
		let rng = seeded(5)
		var deck: Deck?
		var dealt: [Int] = []
		for _ in 0..<15 {
			let next = draw(deck, Array(1...12), rng)!
			deck = next.deck
			dealt.append(next.id)
		}
		#expect(dealt == [11, 2, 8, 4, 10, 7, 5, 1, 6, 3, 12, 9, 10, 11, 4])
	}

	@Test func dailyPicks() {
		#expect([0, 1, 2, 3, 4, 5, 6, 297, 1000].map { dailyPick([30, 10, 20, 40, 50], $0)! } == [30, 40, 10, 20, 50, 40, 30, 50, 10])
		let big = (0..<37).map { 1000 + $0 * 7 }
		#expect([0, 1, 2, 3, 99].map { dailyPick(big, $0)! } == [1133, 1014, 1175, 1007, 1182])
	}
}

@Suite struct SilenceTests {
	func samples(seconds: Int, loudFrom: Double, rate: Int = 1000) -> [Float] {
		(0..<(seconds * rate)).map { i in i >= Int((loudFrom * Double(rate)).rounded()) ? Float(sin(Double(i)) * 0.5) : 0 }
	}

	func start(_ s: [Float]) -> Double {
		s.withUnsafeBufferPointer { soundStart($0, sampleRate: 1000) }
	}

	@Test func startsAtZeroWhenLoudFromTheStart() {
		#expect(start(samples(seconds: 10, loudFrom: 0)) == 0)
	}

	@Test func skipsLeadingSilence() {
		#expect(abs(start(samples(seconds: 10, loudFrom: 1.5)) - 1.49) < 0.005)
	}

	@Test func givesUpAfterFourSeconds() {
		#expect(start(samples(seconds: 10, loudFrom: 6)) == 0)
	}

	@Test func refusesDataThatIsNotAudio() {
		#expect(throws: AudioDecodeError.self) { try decodeAudio(Data("not an mp3".utf8)) }
	}
}
