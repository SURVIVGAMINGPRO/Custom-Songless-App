import Foundation

/// Clip lengths Songless uses, in seconds. Shown rounded to 0.1 s.
public let defaultSteps: [Double] = [0.13, 0.53, 2, 8, 15]

/// Longest clip a step may ask for: Deezer previews are 30 s.
public let maxStep: Double = 30

/// Read clip lengths typed as "0.1, 0.5, 2, 8, 15". Returns an error message if they don't work.
public func parseSteps(_ text: String) -> Result<[Double], StepsError> {
	let parts = text.split(whereSeparator: { $0 == "," || $0 == ";" || $0.isWhitespace }).map(String.init)
	let steps = parts.map { Double($0) ?? .nan }
	if steps.contains(where: { !$0.isFinite || $0 <= 0 }) { return .failure(.init("Use numbers of seconds, like 0.1, 0.5, 2, 8, 15.")) }
	if steps.count < 2 || steps.count > 8 { return .failure(.init("Use between 2 and 8 clip lengths.")) }
	if zip(steps, steps.dropFirst()).contains(where: { $1 <= $0 }) {
		return .failure(.init("Each clip has to be longer than the one before."))
	}
	if steps.last! > maxStep { return .failure(.init("Clips can be at most \(Int(maxStep)) seconds (the preview length).")) }
	return .success(steps)
}

public struct StepsError: Error, Equatable {
	public let message: String
	init(_ message: String) { self.message = message }
}

public func newRound(songId: Int, mode: Mode, day: Int? = nil) -> Round {
	Round(songId: songId, attempts: [], status: .playing, mode: mode, day: day, startedAt: nowMs(), endedAt: nil)
}

/// Index of the clip the player has unlocked.
public func stepIndex(_ round: Round, _ steps: [Double]) -> Int {
	min(round.attempts.count, steps.count - 1)
}

/// How many seconds the play button plays right now.
public func clipSeconds(_ round: Round, _ steps: [Double]) -> Double {
	round.status == .playing ? steps[stepIndex(round, steps)] : maxStep
}

public func judge(_ pick: GuessPick, _ answer: Song) -> GuessResult {
	if pick.id == answer.id { return .correct }
	if let a = pick.isrc, let b = answer.isrc, a.uppercased() == b.uppercased() { return .correct }
	let credits = (pick.artists?.isEmpty == false) ? pick.artists! : [pick.artist]
	let sameArtist = artistsOverlap(credits, answer.artists)
	if sameArtist, normalizeTitle(pick.title) == normalizeTitle(answer.title) { return .correct }
	return sameArtist ? .artist : .wrong
}

private func settle(_ round: Round, _ attempt: Attempt, _ steps: [Double]) -> Round {
	var r = round
	r.attempts.append(attempt)
	if case .guess(_, .correct) = attempt {
		r.status = .won
	} else {
		r.status = r.attempts.count >= steps.count ? .lost : .playing
	}
	r.endedAt = r.status == .playing ? nil : nowMs()
	return r
}

public func guess(_ round: Round, _ pick: GuessPick, _ answer: Song, _ steps: [Double]) -> Round {
	guard round.status == .playing else { return round }
	return settle(round, .guess(pick: pick, result: judge(pick, answer)), steps)
}

public func skip(_ round: Round, _ steps: [Double]) -> Round {
	guard round.status == .playing else { return round }
	return settle(round, .skip, steps)
}

public func emptyStats(_ steps: [Double]) -> Stats {
	Stats(played: 0, won: 0, dist: Array(repeating: 0, count: steps.count + 1), streak: 0, best: 0, lastDay: nil)
}

/// Add a finished round to the stats. Daily streaks break when a day is missed.
public func recordRound(_ stats: Stats, _ round: Round, _ steps: [Double]) -> Stats {
	var dist = stats.dist
	while dist.count < steps.count + 1 { dist.insert(0, at: max(0, dist.count - 1)) }
	let won = round.status == .won
	dist[won ? round.attempts.count - 1 : dist.count - 1] += 1
	var streak = won ? stats.streak + 1 : 0
	if won, round.mode == .daily, let day = round.day, let last = stats.lastDay, day != last + 1 { streak = 1 }
	return Stats(
		played: stats.played + 1,
		won: stats.won + (won ? 1 : 0),
		dist: dist,
		streak: streak,
		best: max(stats.best, streak),
		lastDay: round.mode == .daily ? round.day : stats.lastDay
	)
}

public func emojiGrid(_ round: Round, _ steps: [Double]) -> String {
	var cells = round.attempts.map { a -> String in
		switch a {
		case .skip: return "⬜"
		case .guess(_, .correct): return "🟩"
		case .guess(_, .artist): return "🟧"
		case .guess(_, .wrong): return "🟥"
		}
	}
	while cells.count < steps.count { cells.append("⬛") }
	return cells.joined()
}

/// "0.1 seconds", "2 seconds": how Songless labels a clip.
public func formatSeconds(_ s: Double, short: Bool = false) -> String {
	let n = (s * 10).rounded() / 10
	let text = n == n.rounded() ? String(Int(n)) : String(n)
	return short ? "\(text)s" : "\(text) \(n == 1 ? "second" : "seconds")"
}

public func shareText(app: String, game: String, tab: String?, round: Round, steps: [Double]) -> String {
	let place = [game, tab].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
	let title = round.mode == .daily && round.day != nil ? "\(app) #\(round.day! + 1)" : app
	let time = round.status == .won ? formatSeconds(steps[round.attempts.count - 1], short: true) : "X"
	return "\(title) · \(place)\n\(emojiGrid(round, steps)) \(time)"
}
