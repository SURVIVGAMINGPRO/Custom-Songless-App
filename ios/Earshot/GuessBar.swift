import EarshotCore
import SwiftUI

/// The bar above the keyboard: a small Play button, the search (songs from this
/// playlist only), and Skip or Guess. Return picks the highlighted song, then
/// guesses it; on an empty search it skips only when pressed twice.
struct GuessBar: View {
	let songs: [Song]
	let round: Round
	let answer: Song
	let steps: [Double]
	let onGuess: (GuessPick) -> Void
	let onSkip: () -> Void

	/// A Return this soon after a guess is a second press out of habit, not a request to skip.
	private let afterGuess: TimeInterval = 0.9
	/// How long "press again to skip" waits for the second press.
	private let armFor: Duration = .seconds(2)

	@Environment(AppModel.self) private var model
	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	@State private var query = ""
	@State private var picked: Song?
	@State private var highlighted = 0
	@State private var skipArmed = false
	@State private var armTask: Task<Void, Never>?
	@State private var lastGuessAt = Date.distantPast
	@State private var nudges = 0
	@FocusState private var focused: Bool

	private var player: ClipPlayer { model.player }
	private var clip: Double { clipSeconds(round, steps) }

	private var guessed: Set<Int> {
		Set(round.attempts.compactMap { if case let .guess(pick, _) = $0 { pick.id } else { nil } })
	}

	private var listOpen: Bool { picked == nil && !query.trimmed().isEmpty }
	private var already: Bool { picked.map { guessed.contains($0.id) } ?? false }

	var body: some View {
		let results = listOpen ? searchSongs(songs, query, limit: 8) : []
		VStack(spacing: 8) {
			if listOpen { suggestions(results) }
			if skipArmed {
				Text("Press Return again to skip")
					.font(.footnote.weight(.semibold))
					.foregroundStyle(.secondary)
					.transition(.opacity)
			}
			HStack(spacing: 10) {
				PlayButton(playing: player.playing, loading: player.loading, label: "Play \(formatSeconds(clip))", action: togglePlay, size: 44)
				field(results)
				action
			}
		}
		.padding(10)
		.glassBar()
		.padding(.horizontal, 10)
		.padding(.bottom, 6)
		.animation(.snappy(duration: 0.25), value: listOpen)
		.animation(.snappy(duration: 0.25), value: skipArmed)
		.onChange(of: query) {
			disarm()
			highlighted = 0
			if let picked, query != label(picked) { self.picked = nil }
		}
		.sensoryFeedback(.selection, trigger: picked?.id)
		.sensoryFeedback(.error, trigger: nudges)
	}

	private func field(_ results: [Song]) -> some View {
		HStack(spacing: 8) {
			Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
			TextField("Search this playlist", text: $query)
				.focused($focused)
				.submitLabel(.go)
				.autocorrectionDisabled()
				.textInputAutocapitalization(.never)
				.onSubmit { returnPressed(results) }
				.onKeyPress(.downArrow) {
					move(1, in: results)
					return .handled
				}
				.onKeyPress(.upArrow) {
					move(-1, in: results)
					return .handled
				}
				.onKeyPress(keys: [.return]) { press in
					// Shift+Return skips at once, as on the desktop.
					guard press.modifiers.contains(.shift) else { return .ignored }
					skipNow()
					return .handled
				}
				.accessibilityLabel("Search this playlist for your guess")
			if !query.isEmpty {
				Button("Clear", systemImage: "xmark.circle.fill") {
					reset()
					focused = true
				}
				.labelStyle(.iconOnly)
				.foregroundStyle(.secondary)
				.buttonStyle(.plain)
			}
		}
		.padding(.horizontal, 12)
		.frame(minHeight: 44)
		.background(Color(.tertiarySystemFill), in: Capsule())
		.modifier(Shake(animatableData: reduceMotion ? 0 : CGFloat(nudges)))
		.animation(.linear(duration: 0.35), value: nudges)
	}

	private var action: some View {
		Button {
			if picked != nil { submit() } else { skipNow() }
		} label: {
			if picked != nil {
				Text(already ? "Guessed" : "Guess")
			} else {
				Label("Skip", systemImage: "forward.fill")
			}
		}
		.buttonStyle(picked != nil || skipArmed ? .prominent : .quiet)
		.disabled(already)
	}

	@ViewBuilder private func suggestions(_ results: [Song]) -> some View {
		if results.isEmpty {
			VStack(alignment: .leading, spacing: 2) {
				Text("No song in this playlist matches “\(query.trimmed())”.").font(.subheadline.weight(.semibold))
				Text("Try part of the title or the artist, or press Skip.").font(.subheadline).foregroundStyle(.secondary)
			}
			.frame(maxWidth: .infinity, alignment: .leading)
			.padding(.horizontal, 8)
			.padding(.vertical, 6)
		} else {
			ScrollView {
				VStack(spacing: 2) {
					ForEach(Array(results.enumerated()), id: \.element.id) { i, song in
						Button {
							pick(song)
						} label: {
							SongRow(song: song) {
								if guessed.contains(song.id) {
									Text("Guessed").font(.caption).foregroundStyle(.secondary)
								}
							}
							.padding(.horizontal, 8)
							.padding(.vertical, 5)
							.background(i == highlighted ? Color.brandWash : .clear, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
							.contentShape(Rectangle())
						}
						.buttonStyle(.plain)
					}
				}
			}
			.frame(maxHeight: CGFloat(min(results.count, 4)) * 56)
			.clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
			.scrollBounceBehavior(.basedOnSize)
		}
	}

	private func label(_ song: Song) -> String { "\(song.title) – \(song.artist)" }

	private func togglePlay() {
		if player.playing || player.loading { player.stop() } else { player.play(answer.id, seconds: clip) }
	}

	private func move(_ step: Int, in results: [Song]) {
		guard !results.isEmpty else { return }
		highlighted = (highlighted + step + results.count) % results.count
	}

	private func pick(_ song: Song) {
		picked = song
		query = label(song)
		focused = true
	}

	private func returnPressed(_ results: [Song]) {
		// Return would put the keyboard away; keep it up for the next guess.
		Task { focused = true }
		if picked != nil { return submit() }
		if listOpen, results.indices.contains(highlighted) { return pick(results[highlighted]) }
		if query.trimmed().isEmpty {
			if Date().timeIntervalSince(lastGuessAt) < afterGuess { return }
			if skipArmed { return skipNow() }
			arm()
			return
		}
		// Typed something that matches nothing: shake, don't guess.
		nudges += 1
	}

	private func arm() {
		skipArmed = true
		armTask?.cancel()
		armTask = Task {
			try? await Task.sleep(for: armFor)
			if !Task.isCancelled { skipArmed = false }
		}
	}

	private func disarm() {
		armTask?.cancel()
		skipArmed = false
	}

	private func submit() {
		disarm()
		if let picked {
			guard !guessed.contains(picked.id) else { return }
			lastGuessAt = Date()
			onGuess(GuessPick(picked))
		} else {
			onSkip()
		}
		reset()
	}

	/// The Skip button and Shift+Return skip at once.
	private func skipNow() {
		disarm()
		onSkip()
		reset()
	}

	private func reset() {
		query = ""
		picked = nil
		highlighted = 0
	}
}

/// A short side-to-side shake when Return finds nothing to guess.
struct Shake: GeometryEffect {
	var animatableData: CGFloat

	func effectValue(size: CGSize) -> ProjectionTransform {
		ProjectionTransform(CGAffineTransform(translationX: 6 * sin(animatableData * .pi * 4), y: 0))
	}
}

extension View {
	/// Liquid Glass on iOS 26, a translucent material before it.
	@ViewBuilder func glassBar(corner: CGFloat = 28) -> some View {
		let shape = RoundedRectangle(cornerRadius: corner, style: .continuous)
		if #available(iOS 26, *) {
			glassEffect(.regular, in: shape)
		} else {
			background(.regularMaterial, in: shape).shadow(color: .black.opacity(0.1), radius: 10, y: 2)
		}
	}
}
