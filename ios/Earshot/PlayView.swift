import EarshotCore
import SwiftUI

private let modes: [(Mode, String)] = [(.unlimited, "Endless"), (.daily, "Today's Song")]

/// One playlist's (or mix's) game: listen to a clip, guess, or skip for a longer one.
struct PlayView: View {
	let gameId: String
	@Environment(AppModel.self) private var model
	@Environment(\.scenePhase) private var scenePhase
	@State private var tab = allTab
	@State private var day = dayNumber()
	/// Songs whose preview failed this session; left out of new rounds.
	@State private var broken: Set<Int> = []

	private var library: LibraryStore { model.library }
	private var player: ClipPlayer { model.player }

	var body: some View {
		if let game = library.game(gameId) {
			Board(game: game, tab: $tab, day: day, broken: $broken)
				.onChange(of: scenePhase) { _, phase in
					if phase == .active { day = dayNumber() }
				}
				.onAppear {
					library.selectGame(game.id)
					if !library.data.settings.seenHelp {
						model.showingHelp = true
						library.markHelpSeen()
					}
				}
				.onDisappear { player.stop() }
		} else {
			ContentUnavailableView(
				"This Game Is Gone", systemImage: "music.note.list", description: Text("Its playlist may have been deleted.")
			)
		}
	}
}

private struct Board: View {
	let game: Game
	@Binding var tab: String
	let day: Int
	@Binding var broken: Set<Int>
	@Environment(AppModel.self) private var model

	private var library: LibraryStore { model.library }
	private var player: ClipPlayer { model.player }
	private var mode: Mode { library.data.settings.mode }
	private var tabs: [GameTab] { library.tabs(game) }
	private var pool: [Int] { library.pool(game, tab: tab) }
	/// Every song in the game: guesses can only be one of these.
	private var gameSongs: [Song] { library.pool(game, tab: allTab).compactMap(library.song) }
	private var round: Round? { library.round(game, tab: tab, mode: mode, day: day) }
	private var steps: [Double] { game.steps }

	var body: some View {
		let round = round
		let answer = round.flatMap { library.song($0.songId) }
		ScrollView {
			VStack(spacing: 18) {
				controls
				if pool.isEmpty {
					ContentUnavailableView {
						Label("No Songs to Play Yet", systemImage: "music.note")
					} actions: {
						Button("Add Songs") { model.open(model.edit(game)) }.buttonStyle(.quiet)
					}
				} else if let round, let answer {
					RoundView(game: game, tab: tab, round: round, answer: answer, tabLabel: tabLabel, skipBroken: skipBroken, next: next)
						.id("\(round.songId):\(tab):\(mode)")
						.transition(.opacity.combined(with: .scale(scale: 0.98)))
				}
			}
			.padding(.horizontal)
			.padding(.bottom, 16)
			.frame(maxWidth: 640)
			.frame(maxWidth: .infinity)
			.animation(.snappy, value: round?.songId)
		}
		.scrollDismissesKeyboard(.interactively)
		.background(Color(.systemGroupedBackground))
		.safeAreaInset(edge: .bottom) {
			if let round, let answer, round.status == .playing {
				GuessBar(
					songs: gameSongs, round: round, answer: answer, steps: steps,
					onGuess: { guess($0, round: round, answer: answer) }, onSkip: { skip(round: round, answer: answer) }
				)
				.id("\(round.songId):\(tab):\(mode)")
			}
		}
		.navigationTitle(game.name)
		.navigationBarTitleDisplayMode(.inline)
		.toolbar(.hidden, for: .tabBar)
		.toolbar {
			ToolbarItemGroup(placement: .topBarTrailing) {
				Button("How to Play", systemImage: "questionmark.circle") { model.showingHelp = true }
				Menu("More", systemImage: "ellipsis.circle") {
					Button(game.playlistIds.count > 1 ? "Edit Mix" : "Edit Playlist", systemImage: "pencil") {
						model.open(model.edit(game))
					}
					Text("\(game.playlistIds.count > 1 ? "Mix" : "Playlist") · \(plural(gameSongs.count, "song"))")
				}
			}
		}
		// Deal a song when this tab has no round yet (or its song was removed).
		.task(id: "\(game.id):\(tab):\(mode.rawValue):\(day):\(pool.count)") {
			if !pool.isEmpty, round == nil || answer == nil {
				library.startRound(game.id, tab: tab, mode: mode, day: day, exclude: broken)
			}
		}
		// Stop the music when the song or view changes; fetch the clip early.
		.onChange(of: "\(tab):\(mode.rawValue):\(round?.songId ?? 0)") { player.stop() }
		.task(id: answer?.id) {
			if let answer { player.preload(answer.id) }
		}
		.onChange(of: tabs) {
			if !tabs.contains(where: { $0.key == tab }) { tab = tabs.first?.key ?? allTab }
		}
		.sensoryFeedback(trigger: round?.attempts.count ?? 0) { old, new in
			guard new > old, let last = round?.attempts.last else { return nil }
			switch last {
			case .skip: return .impact(weight: .light)
			case .guess(_, .correct): return .success
			case .guess(_, .artist): return .warning
			case .guess(_, .wrong): return .error
			}
		}
	}

	private var tabLabel: String? {
		tabs.count > 1 ? tabs.first { $0.key == tab }?.label : nil
	}

	private var controls: some View {
		VStack(spacing: 10) {
			Picker("Mode", selection: Binding(get: { mode }, set: { library.setMode($0) })) {
				ForEach(modes, id: \.0) { Text($0.1).tag($0.0) }
			}
			.pickerStyle(.segmented)
			if tabs.count > 1 {
				ScrollView(.horizontal, showsIndicators: false) {
					HStack(spacing: 8) {
						ForEach(tabs) { t in
							Button(t.label) { tab = t.key }
								.font(.subheadline.weight(.semibold))
								.lineLimit(1)
								.padding(.horizontal, 14)
								.padding(.vertical, 7)
								.foregroundStyle(t.key == tab ? Color.brandInk : Color.primary)
								.background(Capsule().fill(t.key == tab ? AnyShapeStyle(Color.brand) : AnyShapeStyle(Color(.tertiarySystemFill))))
								.buttonStyle(.plain)
								.accessibilityAddTraits(t.key == tab ? .isSelected : [])
						}
					}
				}
				.scrollClipDisabled()
			}
		}
		.padding(.top, 4)
	}

	private func guess(_ pick: GuessPick, round: Round, answer: Song) {
		let next = EarshotCore.guess(round, pick, answer, steps)
		library.putRound(game.id, tab: tab, next)
		if next.status != .playing { player.play(answer.id, seconds: maxStep) }
	}

	private func skip(round: Round, answer: Song) {
		let next = EarshotCore.skip(round, steps)
		library.putRound(game.id, tab: tab, next)
		if next.status != .playing { player.play(answer.id, seconds: maxStep) }
	}

	private func next() {
		library.startRound(game.id, tab: tab, mode: mode, day: day, exclude: broken)
	}

	/// Leave out a song whose preview won't load. Doesn't count as a round.
	private func skipBroken(_ songId: Int) {
		broken.insert(songId)
		player.stop()
		player.error = nil
		library.startRound(game.id, tab: tab, mode: mode, day: day, exclude: broken)
	}
}

/// The guesses so far, the clip timeline and Play, then the answer once the round ends.
private struct RoundView: View {
	let game: Game
	let tab: String
	let round: Round
	let answer: Song
	let tabLabel: String?
	let skipBroken: (Int) -> Void
	let next: () -> Void
	@Environment(AppModel.self) private var model

	private var player: ClipPlayer { model.player }
	private var steps: [Double] { game.steps }
	private var playing: Bool { round.status == .playing }
	private var clip: Double { clipSeconds(round, steps) }
	private var timelineSteps: [Double] { playing || (steps.last ?? 0) >= maxStep ? steps : steps + [maxStep] }

	var body: some View {
		VStack(spacing: 20) {
			GuessBoard(attempts: round.attempts, rows: steps.count, active: playing)
			VStack(spacing: 16) {
				Timeline(
					steps: timelineSteps,
					unlocked: playing ? stepIndex(round, steps) : timelineSteps.count - 1,
					position: player.position,
					label: playing ? formatSeconds(clip) : "Full preview",
					detail: playing ? "Try \(round.attempts.count + 1) of \(steps.count)" : "\(round.attempts.count) of \(steps.count) tries used"
				)
				PlayButton(
					playing: player.playing, loading: player.loading, label: playing ? "Play \(formatSeconds(clip))" : "Play the preview"
				) { togglePlay() }
				if let error = player.error {
					VStack(spacing: 8) {
						Text(error).font(.subheadline).foregroundStyle(Color.bad).multilineTextAlignment(.center)
						Button("Skip This Song") { skipBroken(answer.id) }.buttonStyle(.quiet)
					}
				}
			}
			.padding(16)
			.background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))

			if playing {
				Text("Guesses come from this \(game.playlistIds.count > 1 ? "mix" : "playlist"). Return picks a song, then guesses it.")
					.font(.footnote)
					.foregroundStyle(.secondary)
					.multilineTextAlignment(.center)
			} else {
				RoundResult(
					song: answer, round: round, steps: steps, playing: player.playing,
					share: shareText(app: appName, game: game.name, tab: tabLabel, round: round, steps: steps),
					next: round.mode == .unlimited ? next : nil
				)
			}
		}
	}

	private func togglePlay() {
		if player.playing || player.loading { player.stop() } else { player.play(answer.id, seconds: clip) }
	}
}

// MARK: Guess board

struct GuessBoard: View {
	let attempts: [Attempt]
	let rows: Int
	let active: Bool

	var body: some View {
		VStack(spacing: 6) {
			ForEach(0..<rows, id: \.self) { i in
				row(i)
					.transition(.scale(scale: 0.96).combined(with: .opacity))
			}
		}
		.animation(.spring(duration: 0.35, bounce: 0.3), value: attempts.count)
		.accessibilityElement(children: .contain)
		.accessibilityLabel("Your guesses")
	}

	@ViewBuilder private func row(_ i: Int) -> some View {
		let current = active && i == attempts.count
		HStack(spacing: 12) {
			if i < attempts.count {
				switch attempts[i] {
				case .skip:
					Image(systemName: "forward.fill").foregroundStyle(.secondary).frame(width: 24)
					Text("Skipped").foregroundStyle(.secondary)
				case let .guess(pick, result):
					Image(systemName: result.symbol).font(.title3).foregroundStyle(result.color).frame(width: 24)
					Text("\(Text(pick.title).fontWeight(.semibold))  \(Text(pick.artist).foregroundStyle(.secondary))")
						.lineLimit(1)
					Spacer(minLength: 0)
					Text(result.label).font(.caption).foregroundStyle(result.color)
				}
			} else {
				Text("\(i + 1)").font(.subheadline.monospacedDigit().weight(.semibold)).foregroundStyle(.tertiary).frame(width: 24)
				Text(current ? "Your guess" : "").foregroundStyle(.tertiary)
			}
			Spacer(minLength: 0)
		}
		.frame(minHeight: 46)
		.padding(.horizontal, 14)
		.background(fill(i), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
		.overlay {
			if current {
				RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.brand, lineWidth: 2)
			}
		}
		.accessibilityElement(children: .combine)
	}

	private func fill(_ i: Int) -> Color {
		guard i < attempts.count else { return Color(.secondarySystemGroupedBackground) }
		if case let .guess(_, result) = attempts[i] { return result.wash }
		return Color(.tertiarySystemFill)
	}
}

// MARK: Timeline and Play

/// Where each clip ends, as a bar; the part played fills in.
struct Timeline: View {
	let steps: [Double]
	let unlocked: Int
	let position: Double
	let label: String
	let detail: String

	var body: some View {
		VStack(spacing: 8) {
			HStack {
				Text(label).font(.headline.monospacedDigit()).fontDesign(.rounded)
				Spacer()
				Text(detail).font(.subheadline).foregroundStyle(.secondary)
			}
			GeometryReader { geo in
				let total = steps.last ?? 1
				let gap: CGFloat = 3
				let width = geo.size.width - gap * CGFloat(steps.count - 1)
				HStack(spacing: gap) {
					ForEach(steps.indices, id: \.self) { i in
						let start = i == 0 ? 0 : steps[i - 1]
						let grow = steps[i] - start
						let fill = min(1, max(0, (position - start) / grow))
						Capsule()
							.fill(i <= unlocked ? Color(.systemFill) : Color(.quaternarySystemFill))
							.overlay(alignment: .leading) {
								Capsule().fill(Color.brand).scaleEffect(x: fill, anchor: .leading)
							}
							.frame(width: max(4, width * grow / total))
					}
				}
			}
			.frame(height: 8)
			.accessibilityElement()
			.accessibilityLabel("Clip progress")
			.accessibilityValue(String(format: "%.1f seconds", position))
		}
	}
}

struct PlayButton: View {
	let playing: Bool
	let loading: Bool
	let label: String
	let action: () -> Void
	var size: CGFloat = 76

	var body: some View {
		Button(action: action) {
			ZStack {
				Circle().fill(Color.brand)
				if loading {
					ProgressView().tint(Color.brandInk).controlSize(size > 60 ? .large : .regular)
				} else if playing {
					Image(systemName: "waveform")
						.font(.system(size: size * 0.38, weight: .bold))
						.symbolEffect(.variableColor.iterative.dimInactiveLayers, isActive: true)
				} else {
					Image(systemName: "play.fill").font(.system(size: size * 0.36, weight: .bold))
				}
			}
			.foregroundStyle(Color.brandInk)
			.frame(width: size, height: size)
			.shadow(color: Color.brand.opacity(0.35), radius: playing ? 14 : 6)
			.contentShape(Circle())
		}
		.buttonStyle(PressStyle())
		.accessibilityLabel(playing ? "Stop" : label)
		.animation(.snappy, value: playing)
	}
}

// MARK: Result

/// The answer: artwork that grows while the preview plays, links and Share.
struct RoundResult: View {
	let song: Song
	let round: Round
	let steps: [Double]
	let playing: Bool
	let share: String
	/// Endless mode only.
	let next: (() -> Void)?

	private var won: Bool { round.status == .won }

	var body: some View {
		VStack(spacing: 14) {
			Cover(song: song, size: 168, corner: 14)
				.shadow(color: .black.opacity(playing ? 0.3 : 0.15), radius: playing ? 22 : 10, y: 6)
				.scaleEffect(playing ? 1 : 0.9)
				.animation(.spring(duration: 0.6, bounce: 0.25), value: playing)
			Label(
				won ? "Got it in \(round.attempts.count) · \(formatSeconds(steps[round.attempts.count - 1]))" : "Out of tries",
				systemImage: won ? "checkmark.circle.fill" : "xmark.circle.fill"
			)
			.font(.subheadline.weight(.semibold))
			.foregroundStyle(won ? Color.good : Color.bad)
			VStack(spacing: 4) {
				Text(song.title).font(.title2.bold()).multilineTextAlignment(.center)
				Text(song.artists.joined(separator: ", ")).foregroundStyle(.secondary).multilineTextAlignment(.center)
			}
			if let next {
				Button(action: next) {
					Label("Next Song", systemImage: "forward.fill")
				}
				.buttonStyle(.prominent(large: true))
				.keyboardShortcut(.defaultAction)
			}
			HStack(spacing: 10) {
				ShareLink(item: share) { Label("Share", systemImage: "square.and.arrow.up") }
					.buttonStyle(.quiet)
				if let id = song.spotify, let url = spotifyTrackUrl(id) {
					Link(destination: url) { Label("Spotify", systemImage: "arrow.up.right") }.buttonStyle(.quiet)
				}
				Link(destination: deezerTrackUrl(song.id)) { Label("Deezer", systemImage: "arrow.up.right") }.buttonStyle(.quiet)
			}
			if next == nil {
				TimelineView(.periodic(from: .now, by: 30)) { context in
					Label("Next song of the day in \(untilMidnight(context.date))", systemImage: "calendar")
						.font(.footnote)
						.foregroundStyle(.secondary)
				}
			}
		}
		.frame(maxWidth: .infinity)
		.padding(.vertical, 8)
	}
}
