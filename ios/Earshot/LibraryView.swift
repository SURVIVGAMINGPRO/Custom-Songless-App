import EarshotCore
import SwiftUI

private let sourceLabel: [Playlist.Source: String] = [.spotify: "From Spotify", .deezer: "From Deezer", .built: "Made here"]

/// Home: the player's playlists. Pressing a cover plays that playlist.
struct LibraryView: View {
	@Environment(AppModel.self) private var model
	@State private var loadingSample = false

	private var library: LibraryStore { model.library }
	private let columns = [GridItem(.adaptive(minimum: 150, maximum: 240), spacing: 16, alignment: .top)]

	var body: some View {
		ScrollView {
			if library.data.playlists.isEmpty {
				empty
			} else {
				VStack(alignment: .leading, spacing: 28) {
					jumpBackIn
					playlists
					if library.data.playlists.count > 1 { mixes }
				}
				.padding(.horizontal)
				.padding(.bottom, 24)
			}
		}
		.navigationTitle("Playlists")
		.toolbar {
			ToolbarItem(placement: .topBarTrailing) {
				Menu {
					Button("Add Playlist", systemImage: "square.and.arrow.down") { model.addingPlaylist = true }
					Button("New Playlist", systemImage: "music.note.list") { newPlaylist() }
					if library.data.playlists.count > 1 {
						Button("New Mix", systemImage: "square.stack") { model.open(.newMix) }
					}
				} label: {
					Label("Add", systemImage: "plus")
				}
			}
		}
	}

	private func newPlaylist() {
		let p = library.createPlaylist(name: "New Playlist", source: .built)
		model.open(.playlist(p.id))
	}

	// MARK: No playlists yet

	private var empty: some View {
		VStack(spacing: 18) {
			LogoMark(size: 56)
				.frame(width: 104, height: 104)
				.background(Color(.secondarySystemFill), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
				.padding(.top, 32)
			VStack(spacing: 6) {
				Text("No Playlists Yet").font(.title2.bold())
				Text("Every playlist you add becomes its own song guessing game.")
					.foregroundStyle(.secondary)
					.multilineTextAlignment(.center)
			}
			VStack(spacing: 0) {
				way("doc.badge.plus", "From Spotify", "Export it as a file with Exportify, then add it.") { model.addingPlaylist = true }
				Divider().padding(.leading, 60)
				way("link", "From Deezer", "Paste a playlist or album link.") { model.addingPlaylist = true }
				Divider().padding(.leading, 60)
				way("plus", "Make One Here", "Search for songs and add them.") { newPlaylist() }
			}
			.background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
			Button {
				Task { await trySample() }
			} label: {
				Label(loadingSample ? "Loading…" : "Try Deezer's \(samplePlaylist.name)", systemImage: "sparkles")
			}
			.buttonStyle(.quiet)
			.disabled(loadingSample)
		}
		.padding(.horizontal)
		.frame(maxWidth: 520)
		.frame(maxWidth: .infinity)
	}

	private func way(_ icon: String, _ title: String, _ text: String, action: @escaping () -> Void) -> some View {
		Button(action: action) {
			HStack(spacing: 14) {
				Image(systemName: icon)
					.font(.body.weight(.semibold))
					.foregroundStyle(Color.brandInk)
					.frame(width: 32, height: 32)
					.background(Color.brand, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
				VStack(alignment: .leading, spacing: 2) {
					Text(title).foregroundStyle(.primary)
					Text(text).font(.subheadline).foregroundStyle(.secondary)
				}
				.frame(maxWidth: .infinity, alignment: .leading)
				Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
			}
			.padding(.horizontal, 14)
			.padding(.vertical, 12)
			.contentShape(Rectangle())
		}
		.buttonStyle(.plain)
	}

	private func trySample() async {
		loadingSample = true
		defer { loadingSample = false }
		do {
			let c = try await DeezerClient.shared.playlist(samplePlaylist.id)
			let p = library.createPlaylist(
				name: c.name, source: .deezer, sourceUrl: "https://www.deezer.com/playlist/\(samplePlaylist.id)", songs: c.songs
			)
			model.play(p)
		} catch {
			model.show(error.localizedDescription, error: true)
		}
	}

	// MARK: Playlists and mixes

	@ViewBuilder private var jumpBackIn: some View {
		if let last = library.currentGame, !library.pool(last, tab: allTab).isEmpty {
			Button {
				model.play(last)
			} label: {
				HStack(spacing: 14) {
					Mosaic(songs: library.songsOf(last.playlistIds, limit: 4), seed: last.id, corner: 8)
						.frame(width: 56, height: 56)
					VStack(alignment: .leading, spacing: 2) {
						Text("Jump Back In").font(.caption.weight(.semibold)).foregroundStyle(.secondary).textCase(.uppercase)
						Text(last.name).font(.headline).foregroundStyle(.primary).lineLimit(1)
					}
					.frame(maxWidth: .infinity, alignment: .leading)
					Image(systemName: "play.fill")
						.font(.body.weight(.bold))
						.foregroundStyle(Color.brandInk)
						.frame(width: 40, height: 40)
						.background(Color.brand, in: Circle())
				}
				.padding(10)
				.background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
			}
			.buttonStyle(PressStyle())
			.accessibilityLabel("Jump back in: \(last.name)")
		}
	}

	private var playlists: some View {
		VStack(alignment: .leading, spacing: 12) {
			GroupTitle(text: "All Playlists")
			LazyVGrid(columns: columns, spacing: 20) {
				ForEach(library.data.playlists) { p in
					PlaylistCard(
						title: p.name,
						meta: "\(plural(p.songIds.count, "song")) · \(sourceLabel[p.source] ?? "")",
						tag: p.unmatched.isEmpty ? nil : "\(p.unmatched.count) to check",
						songs: library.songsOf([p.id], limit: 8),
						seed: p.id,
						play: { model.play(p) },
						open: { model.open(.playlist(p.id)) }
					)
				}
			}
		}
	}

	private var mixes: some View {
		VStack(alignment: .leading, spacing: 12) {
			HStack {
				GroupTitle(text: "Mixes")
				Button("New Mix", systemImage: "plus") { model.open(.newMix) }
					.buttonStyle(.quiet)
			}
			if library.mixes.isEmpty {
				Text("Put several playlists in one game, each with its own tab.")
					.font(.subheadline)
					.foregroundStyle(.secondary)
			} else {
				LazyVGrid(columns: columns, spacing: 20) {
					ForEach(library.mixes) { g in
						PlaylistCard(
							title: g.name,
							meta: "\(g.playlistIds.count) playlists · \(plural(library.pool(g, tab: allTab).count, "song"))",
							tag: nil,
							songs: library.songsOf(g.playlistIds, limit: 8),
							seed: g.id,
							stacked: true,
							play: { model.play(g) },
							open: { model.open(.mix(g.id)) }
						)
					}
				}
			}
		}
	}
}

/// A playlist's cover (press to play) with its name and details (press to open).
struct PlaylistCard: View {
	let title: String
	let meta: String
	let tag: String?
	let songs: [Song]
	let seed: String
	var stacked = false
	let play: () -> Void
	let open: () -> Void

	var body: some View {
		VStack(alignment: .leading, spacing: 8) {
			Button(action: play) {
				Mosaic(songs: songs, seed: seed)
					.background(alignment: .top) {
						if stacked {
							// Mixes look like a small stack of playlists.
							RoundedRectangle(cornerRadius: 12, style: .continuous)
								.fill(Color(.tertiarySystemFill))
								.padding(.horizontal, 10)
								.offset(y: -7)
						}
					}
					.overlay(alignment: .bottomTrailing) {
						Image(systemName: "play.fill")
							.font(.body.weight(.bold))
							.foregroundStyle(Color.brandInk)
							.frame(width: 40, height: 40)
							.background(Color.brand, in: Circle())
							.shadow(color: .black.opacity(0.25), radius: 6, y: 2)
							.padding(10)
					}
					.overlay(alignment: .topLeading) {
						if let tag {
							Text(tag)
								.font(.caption2.weight(.semibold))
								.padding(.horizontal, 8)
								.padding(.vertical, 4)
								.background(.regularMaterial, in: Capsule())
								.padding(8)
						}
					}
			}
			.buttonStyle(PressStyle())
			.accessibilityLabel("Play \(title)")

			Button(action: open) {
				VStack(alignment: .leading, spacing: 2) {
					Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.primary).lineLimit(1)
					Text(meta).font(.caption).foregroundStyle(.secondary).lineLimit(1)
				}
				.frame(maxWidth: .infinity, alignment: .leading)
				.contentShape(Rectangle())
			}
			.buttonStyle(.plain)
			.accessibilityHint("Opens the playlist")
		}
		.padding(.top, stacked ? 7 : 0)
		.contextMenu {
			Button("Play", systemImage: "play.fill", action: play)
			Button(stacked ? "Edit Mix" : "Open Playlist", systemImage: stacked ? "slider.horizontal.3" : "music.note.list", action: open)
		}
	}
}

/// Shrinks a little while pressed.
struct PressStyle: ButtonStyle {
	func makeBody(configuration: Configuration) -> some View {
		configuration.label
			.scaleEffect(configuration.isPressed ? 0.97 : 1)
			.animation(.snappy(duration: 0.2), value: configuration.isPressed)
	}
}
