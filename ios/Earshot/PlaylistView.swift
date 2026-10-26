import EarshotCore
import SwiftUI

private let sourceLabel: [Playlist.Source: String] = [.spotify: "From Spotify", .deezer: "From Deezer", .built: "Made here"]

/// Opens Add Songs, searching for something to start with.
private struct AddRequest: Identifiable {
	let id = UUID()
	let query: String
}

/// A playlist: play it, rename or delete it, fix songs that need a look, add and remove songs.
struct PlaylistView: View {
	let playlistId: String
	@Environment(AppModel.self) private var model
	@State private var renaming = false
	@State private var newName = ""
	@State private var confirmDelete = false
	@State private var adding: AddRequest?
	@State private var filter = ""

	private var library: LibraryStore { model.library }

	var body: some View {
		if let p = library.playlist(playlistId) {
			content(p)
		} else {
			ContentUnavailableView("Playlist Not Found", systemImage: "music.note.list")
		}
	}

	private func content(_ p: Playlist) -> some View {
		let songs = p.songIds.compactMap(library.song)
		let f = fold(filter)
		let shown = f.isEmpty ? songs : songs.filter { fold("\($0.title) \($0.artists.joined(separator: " "))").contains(f) }
		return List {
			Section {
				header(p, songs: songs)
			}
			.listRowBackground(Color.clear)
			.listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 8, trailing: 0))

			if !p.unmatched.isEmpty { review(p) }

			Section {
				if songs.isEmpty {
					Text("No songs yet. Add some to play this playlist.").foregroundStyle(.secondary)
				}
				ForEach(Array(shown.enumerated()), id: \.element.id) { i, s in
					SongRow(song: s, index: f.isEmpty ? i + 1 : nil) {
						Text(songLength(s.duration)).font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
					}
					.swipeActions {
						Button("Remove", systemImage: "minus.circle", role: .destructive) {
							library.removeFromPlaylist(p.id, songId: s.id)
						}
					}
				}
				Button {
					adding = AddRequest(query: "")
				} label: {
					Label("Add Songs", systemImage: "plus.circle.fill")
				}
			} header: {
				Text("Songs")
			}
		}
		.listStyle(.insetGrouped)
		.searchable(text: $filter, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "Filter songs")
		.navigationTitle(p.name)
		.navigationBarTitleDisplayMode(.inline)
		.toolbar {
			Menu("More", systemImage: "ellipsis.circle") {
				Button("Rename", systemImage: "pencil") {
					newName = p.name
					renaming = true
				}
				Button("Delete Playlist", systemImage: "trash", role: .destructive) { confirmDelete = true }
			}
		}
		.alert("Rename Playlist", isPresented: $renaming) {
			TextField("Name", text: $newName)
			Button("Cancel", role: .cancel) {}
			Button("Rename") { library.renamePlaylist(p.id, to: newName) }
		}
		.confirmationDialog("Delete “\(p.name)”?", isPresented: $confirmDelete, titleVisibility: .visible) {
			Button("Delete", role: .destructive) {
				library.deletePlaylist(p.id)
				model.path.removeAll()
				model.show("Deleted the playlist")
			}
		} message: {
			Text("The playlist and its songs are removed. Mixes that only used this playlist are removed too.")
		}
		.sheet(item: $adding) { req in
			AddSongsView(playlistId: p.id, initialQuery: req.query)
		}
	}

	private func header(_ p: Playlist, songs: [Song]) -> some View {
		let minutes = Int((Double(songs.reduce(0) { $0 + $1.duration }) / 60).rounded())
		return VStack(spacing: 14) {
			Mosaic(songs: Array(songs.prefix(8)), seed: p.id, corner: 14)
				.frame(width: 220, height: 220)
				.shadow(color: .black.opacity(0.15), radius: 14, y: 6)
			VStack(spacing: 4) {
				Button {
					newName = p.name
					renaming = true
				} label: {
					Text(p.name).font(.title2.bold()).foregroundStyle(.primary).multilineTextAlignment(.center)
				}
				.buttonStyle(.plain)
				.accessibilityHint("Renames the playlist")
				Text([sourceLabel[p.source] ?? "", plural(songs.count, "song"), minutes > 0 ? "\(minutes) min" : ""].filter { !$0.isEmpty }.joined(separator: " · "))
					.font(.subheadline)
					.foregroundStyle(.secondary)
			}
			HStack(spacing: 12) {
				Button {
					model.play(p)
				} label: {
					Label("Play", systemImage: "play.fill").frame(maxWidth: .infinity)
				}
				.buttonStyle(.prominent(large: true))
				.disabled(songs.isEmpty)
				Button {
					adding = AddRequest(query: "")
				} label: {
					Label("Add Songs", systemImage: "plus").frame(maxWidth: .infinity)
				}
				.buttonStyle(.quiet(large: true))
			}
			.frame(maxWidth: 420)
		}
		.frame(maxWidth: .infinity)
		.padding(.top, 8)
	}

	private func review(_ p: Playlist) -> some View {
		Section {
			ForEach(Array(p.unmatched.enumerated()), id: \.offset) { i, u in
				VStack(alignment: .leading, spacing: 10) {
					HStack(spacing: 8) {
						VStack(alignment: .leading, spacing: 2) {
							Text(u.title).fontWeight(.semibold).lineLimit(2)
							Text("\(u.artists.isEmpty ? "Unknown artist" : u.artists.joined(separator: ", ")) · \(u.reason == .unsure ? "Not sure which one" : "Not found on Deezer")")
								.font(.subheadline)
								.foregroundStyle(.secondary)
						}
						.frame(maxWidth: .infinity, alignment: .leading)
						Button("Search") { adding = AddRequest(query: searchQuery(u.item)) }.buttonStyle(.quiet)
						Button("Drop") { library.resolveUnmatched(p.id, at: i, with: nil) }.buttonStyle(.quiet)
					}
					ForEach(u.candidates) { c in
						SongRow(song: c) {
							Button("Use This") { library.resolveUnmatched(p.id, at: i, with: c) }.buttonStyle(.prominent)
						}
					}
				}
				.padding(.vertical, 4)
			}
		} header: {
			Text("Needs a Look · \(p.unmatched.count)")
		} footer: {
			Text("These couldn't be matched for sure. Pick the right song, search for it, or drop it.")
		}
	}
}

/// Progress of a long import, updated from background work.
@Observable
final class ImportProgress {
	var done = 0
	var total = 0
}

/// Search Deezer's catalogue (only here, to add songs) or paste a list of songs.
struct AddSongsView: View {
	let playlistId: String
	let initialQuery: String
	@Environment(AppModel.self) private var model
	@Environment(\.dismiss) private var dismiss
	@State private var query = ""
	@State private var results: [Song] = []
	@State private var searching = false
	@State private var searchError: String?
	@State private var pasteText = ""
	@State private var pasting: Task<Void, Never>?
	@State private var progress = ImportProgress()

	private var library: LibraryStore { model.library }

	var body: some View {
		let inList = Set(library.playlist(playlistId)?.songIds ?? [])
		NavigationStack {
			List {
				if query.trimmed().count >= 2 {
					Section {
						if let searchError {
							Text(searchError).foregroundStyle(Color.bad)
						} else if results.isEmpty {
							Text(searching ? "Searching…" : "No songs found. Try the title and the artist.").foregroundStyle(.secondary)
						}
						ForEach(results) { s in
							SongRow(song: s) {
								if inList.contains(s.id) {
									Label("Added", systemImage: "checkmark").font(.subheadline.weight(.semibold)).foregroundStyle(Color.good)
								} else {
									Button("Add", systemImage: "plus") {
										library.addToPlaylist(playlistId, [s])
									}
									.buttonStyle(.quiet)
								}
							}
						}
					}
				}
				Section {
					TextEditor(text: $pasteText)
						.frame(minHeight: 120)
						.disabled(pasting != nil)
						.accessibilityLabel("Songs, one per line")
					if pasting != nil {
						ProgressView(value: Double(progress.done), total: Double(max(1, progress.total))) {
							Text("Finding songs on Deezer")
						} currentValueLabel: {
							Text("\(progress.done) of \(progress.total)")
						}
						Button("Stop", role: .cancel) { pasting?.cancel() }
					} else {
						Button("Find These Songs") { findPasted() }.disabled(pasteText.trimmed().isEmpty)
					}
				} header: {
					Text("Paste a List of Songs")
				} footer: {
					Text("One song per line, like “Queen - Bohemian Rhapsody”.")
				}
			}
			.searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search Deezer for a song or artist")
			.autocorrectionDisabled()
			.navigationTitle("Add Songs")
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
			}
			.task(id: query) { await search() }
			.onAppear { if query.isEmpty { query = initialQuery } }
		}
	}

	private func search() async {
		let q = query.trimmed()
		searchError = nil
		guard q.count >= 2 else {
			results = []
			searching = false
			return
		}
		searching = true
		try? await Task.sleep(for: .milliseconds(300))
		guard !Task.isCancelled else { return }
		do {
			let found = try await DeezerClient.shared.search(q, limit: 15)
			guard !Task.isCancelled else { return }
			results = found
		} catch {
			if !Task.isCancelled { searchError = error.localizedDescription }
		}
		if !Task.isCancelled { searching = false }
	}

	private func findPasted() {
		let items = Array(itemsFromLines(pasteText).prefix(500))
		guard !items.isEmpty else { return }
		let progress = progress
		progress.done = 0
		progress.total = items.count
		pasting = Task {
			do {
				let r = try await matchAll(items) { done, total in
					Task { @MainActor in
						progress.done = done
						progress.total = total
					}
				}
				let added = library.addToPlaylist(playlistId, r.songs)
				library.addUnmatched(playlistId, r.unmatched)
				pasteText = ""
				model.show("Added \(plural(added, "song"))\(r.unmatched.isEmpty ? "" : ". \(r.unmatched.count) need a look")")
			} catch {
				if !Task.isCancelled { model.show(error.localizedDescription, error: true) }
			}
			pasting = nil
		}
	}
}
