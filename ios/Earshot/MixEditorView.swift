import EarshotCore
import SwiftUI

/// "0.13, 0.53, 2, 8, 15", as the desktop app writes clip lengths.
func stepsText(_ steps: [Double]) -> String {
	steps.map { $0 == $0.rounded() ? String(Int($0)) : String($0) }.joined(separator: ", ")
}

/// Several playlists in one game. Each gets its own tab, plus All.
struct MixEditorView: View {
	/// nil makes a new mix.
	let gameId: String?
	@Environment(AppModel.self) private var model
	@State private var name = ""
	@State private var chosen: [String] = []
	@State private var steps = ""
	@State private var loaded = false
	@State private var confirmDelete = false

	private var library: LibraryStore { model.library }
	private var game: Game? { gameId.flatMap(library.game) }
	private var parsed: Result<[Double], StepsError> { parseSteps(steps) }
	private var stepsError: String? {
		if case let .failure(e) = parsed { e.message } else { nil }
	}
	private var canSave: Bool { chosen.count >= 2 && stepsError == nil }

	var body: some View {
		if gameId != nil, game == nil {
			ContentUnavailableView("Mix Not Found", systemImage: "square.stack")
		} else {
			form
		}
	}

	private var form: some View {
		Form {
			Section("Name") {
				TextField("Road Trip", text: $name)
			}
			Section {
				if library.data.playlists.isEmpty {
					Text("No playlists yet. Add one first.").foregroundStyle(.secondary)
				}
				ForEach(library.data.playlists) { p in
					Toggle(isOn: Binding(
						get: { chosen.contains(p.id) },
						set: { on in chosen = on ? chosen + [p.id] : chosen.filter { $0 != p.id } }
					)) {
						HStack(spacing: 12) {
							Cover(song: library.songsOf([p.id], limit: 1).first, size: 36)
							VStack(alignment: .leading, spacing: 1) {
								Text(p.name).lineLimit(1)
								Text(plural(p.songIds.count, "song")).font(.caption).foregroundStyle(.secondary)
							}
						}
					}
				}
			} header: {
				Text("Playlists")
			} footer: {
				Text("Pick two or more. Guesses come only from the songs in these playlists.")
			}
			Section {
				TextField("0.13, 0.53, 2, 8, 15", text: $steps)
					.keyboardType(.numbersAndPunctuation)
					.autocorrectionDisabled()
			} header: {
				Text("Clip Lengths (Seconds)")
			} footer: {
				if let stepsError {
					Text(stepsError).foregroundStyle(Color.bad)
				} else {
					Text("One per try. Songless uses \(stepsText(defaultSteps)).")
				}
			}
			if let game {
				Section {
					Button("Play", systemImage: "play.fill") { model.play(game) }
					Button("Delete Mix", systemImage: "trash", role: .destructive) { confirmDelete = true }
				}
			}
		}
		.navigationTitle(game == nil ? "New Mix" : "Edit Mix")
		.navigationBarTitleDisplayMode(.inline)
		.toolbar {
			ToolbarItem(placement: .confirmationAction) {
				Button(game == nil ? "Create and Play" : "Save", action: save).disabled(!canSave)
			}
		}
		.confirmationDialog("Delete “\(game?.name ?? "")”?", isPresented: $confirmDelete, titleVisibility: .visible) {
			Button("Delete", role: .destructive) {
				if let game { library.deleteGame(game.id) }
				model.path.removeAll()
				model.show("Deleted the mix")
			}
		} message: {
			Text("Its stats go with it. The playlists stay.")
		}
		.onAppear {
			guard !loaded else { return }
			loaded = true
			name = game?.name ?? ""
			chosen = game?.playlistIds ?? []
			steps = stepsText(game?.steps ?? defaultSteps)
		}
	}

	private func save() {
		guard canSave, case let .success(clips) = parsed else { return }
		if let game {
			library.updateGame(game.id, name: name, playlistIds: chosen, steps: clips)
			model.show("Saved the mix")
		} else {
			let fallback = chosen.compactMap { library.playlist($0)?.name }.prefix(2).joined(separator: " + ")
			let clean = name.trimmed()
			let g = library.createGame(
				name: clean.isEmpty ? (fallback.isEmpty ? "New Mix" : fallback) : clean, playlistIds: chosen, steps: clips, guessScope: .game
			)
			if model.path.last == .newMix { model.path.removeLast() }
			model.play(g)
		}
	}
}
