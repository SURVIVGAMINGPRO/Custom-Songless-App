import EarshotCore
import SwiftUI
import UniformTypeIdentifiers

/// Bring a playlist in: a Deezer link, a Spotify export file (Exportify), or build one here.
struct AddPlaylistView: View {
	/// Exports bigger than this are surely not a playlist CSV.
	private let maxFile = 5 * 1024 * 1024
	private let maxRows = 2000

	private struct Done {
		let playlist: Playlist
		let added: Int
		let check: Int
		let skipped: Int
	}

	@Environment(AppModel.self) private var model
	@Environment(\.dismiss) private var dismiss
	@State private var link = ""
	@State private var spotifyUrl: String?
	@State private var error: String?
	@State private var busyLabel: String?
	@State private var progress = ImportProgress()
	@State private var task: Task<Void, Never>?
	@State private var done: Done?
	@State private var choosingFile = false

	private var library: LibraryStore { model.library }

	var body: some View {
		NavigationStack {
			Form {
				if let busyLabel {
					Section {
						ProgressView(value: Double(progress.done), total: Double(max(1, progress.total))) {
							Text(busyLabel)
						} currentValueLabel: {
							Text(progress.total > 0 ? "\(progress.done) of \(progress.total)" : "")
						}
						Button("Stop", role: .cancel) { task?.cancel() }
					}
				} else {
					if let done { doneSection(done) }
					linkSection
					if let spotifyUrl { spotifySection(spotifyUrl) }
					Section {
						Button {
							choosingFile = true
						} label: {
							Label("Choose a .csv File", systemImage: "doc.badge.plus")
						}
					} header: {
						Text("Spotify Export")
					} footer: {
						Text("Save the file from Exportify, TuneMyMusic or Soundiiz to Files, then choose it here.")
					}
					Section {
						Button {
							let p = library.createPlaylist(name: "New Playlist", source: .built)
							dismiss()
							model.open(.playlist(p.id))
						} label: {
							Label("New Playlist", systemImage: "plus")
						}
					} header: {
						Text("Or Build One")
					} footer: {
						Text("Search for songs and add them, or paste a list.")
					}
				}
			}
			.navigationTitle("Add Playlist")
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button("Done") {
						task?.cancel()
						dismiss()
					}
				}
			}
			.fileImporter(isPresented: $choosingFile, allowedContentTypes: [.commaSeparatedText, .plainText]) { result in
				switch result {
				case let .success(url): importFile(url)
				case .failure: error = "Couldn't open that file."
				}
			}
			.interactiveDismissDisabled(busyLabel != nil)
		}
	}

	private var linkSection: some View {
		Section {
			HStack {
				TextField("Spotify or Deezer playlist link", text: $link)
					.keyboardType(.URL)
					.textContentType(.URL)
					.textInputAutocapitalization(.never)
					.autocorrectionDisabled()
					.submitLabel(.go)
					.onSubmit(importLink)
					.onChange(of: link) { error = nil }
				Button("Add", action: importLink)
					.buttonStyle(.prominent)
					.disabled(link.trimmed().isEmpty)
			}
		} header: {
			Text("Paste a Link")
		} footer: {
			if let error {
				Text(error).foregroundStyle(Color.bad)
			} else {
				Text("Deezer playlists and albums come straight in. Spotify links show you how to export.")
			}
		}
	}

	private func spotifySection(_ url: String) -> some View {
		Section {
			Text("Spotify doesn't let apps read playlists for games, so export it with Exportify (a free tool that uses your own Spotify login), then choose the file below.")
			Label {
				Text("Open Exportify and sign in with Spotify.")
			} icon: {
				Image(systemName: "1.circle.fill").foregroundStyle(Color.brand)
			}
			Label {
				Text("Find this playlist and press **Export**.")
			} icon: {
				Image(systemName: "2.circle.fill").foregroundStyle(Color.brand)
			}
			Label {
				Text("Save the **.csv** file to Files and choose it below.")
			} icon: {
				Image(systemName: "3.circle.fill").foregroundStyle(Color.brand)
			}
			Link(destination: exportifyUrl) {
				Label("Open exportify.app", systemImage: "arrow.up.right.square")
			}
		} header: {
			Text("Bring This Spotify Playlist In as a File")
		} footer: {
			Text("If the playlist isn't yours and Exportify can't see it, add its songs to a playlist of your own in Spotify first.")
		}
	}

	private func doneSection(_ d: Done) -> some View {
		Section {
			Label("Added \(plural(d.added, "song")) to “\(d.playlist.name)”", systemImage: "checkmark.circle.fill")
				.font(.headline)
				.foregroundStyle(Color.good)
			if d.check > 0 {
				Text("\(plural(d.check, "song")) couldn't be matched for sure. You can check them on the playlist page.")
					.foregroundStyle(.secondary)
			}
			if d.skipped > 0 {
				Text("\(plural(d.skipped, "song")) had no preview on Deezer and were left out.").foregroundStyle(.secondary)
			}
			HStack(spacing: 10) {
				Button {
					dismiss()
					model.play(d.playlist)
				} label: {
					Label("Play", systemImage: "play.fill")
				}
				.buttonStyle(.prominent)
				.disabled(d.added == 0)
				Button("Open Playlist") {
					dismiss()
					model.open(.playlist(d.playlist.id))
				}
				.buttonStyle(.quiet)
			}
		}
	}

	private func start(_ label: String, total: Int = 0) {
		error = nil
		done = nil
		busyLabel = label
		progress.done = 0
		progress.total = total
	}

	private func importLink() {
		guard var target = parseLink(link) else {
			error = "That doesn't look like a Spotify or Deezer playlist link."
			return
		}
		if case let .spotifyPlaylist(_, url) = target {
			spotifyUrl = url
			error = nil
			return
		}
		spotifyUrl = nil
		start("Reading the playlist from Deezer")
		let progress = progress
		task = Task {
			do {
				let client = DeezerClient.shared
				if case let .deezerShort(url) = target {
					guard let full = parseLink(try await client.resolveShortLink(url)) else {
						throw DeezerError(message: "That share link didn't lead to a playlist.", code: 404)
					}
					target = full
				}
				let collection: DeezerCollection
				let sourceUrl: String
				switch target {
				case let .deezerPlaylist(id):
					collection = try await client.playlist(id) { n in
						Task { @MainActor in
							progress.done = n
							progress.total = n
						}
					}
					sourceUrl = "https://www.deezer.com/playlist/\(id)"
				case let .deezerAlbum(id):
					collection = try await client.album(id)
					sourceUrl = "https://www.deezer.com/album/\(id)"
				default:
					throw DeezerError(message: "That share link didn't lead to a playlist.", code: 404)
				}
				guard !collection.songs.isEmpty else {
					throw DeezerError(message: "This playlist has no songs with previews.", code: 0)
				}
				let p = library.createPlaylist(name: collection.name, source: .deezer, sourceUrl: sourceUrl, songs: collection.songs)
				done = Done(playlist: p, added: collection.songs.count, check: 0, skipped: collection.skipped)
				link = ""
			} catch {
				if !Task.isCancelled { self.error = error.localizedDescription }
			}
			busyLabel = nil
		}
	}

	private func importFile(_ url: URL) {
		error = nil
		let access = url.startAccessingSecurityScopedResource()
		defer { if access { url.stopAccessingSecurityScopedResource() } }
		guard let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize, size <= maxFile else {
			error = "That file is too big to be a playlist export."
			return
		}
		guard let data = try? Data(contentsOf: url) else {
			error = "Couldn't open that file."
			return
		}
		let items: [ImportItem]
		switch itemsFromCsv(String(decoding: data, as: UTF8.self)) {
		case let .items(rows): items = Array(rows.prefix(maxRows))
		case let .error(message):
			error = message
			return
		}
		let name = url.deletingPathExtension().lastPathComponent.replacing(/[_-]+/, with: " ").trimmed()
		start("Finding songs on Deezer", total: items.count)
		let progress = progress
		let spotify = spotifyUrl
		task = Task {
			do {
				let r = try await matchAll(items) { n, total in
					Task { @MainActor in
						progress.done = n
						progress.total = total
					}
				}
				let p = library.createPlaylist(
					name: name.isEmpty ? "Spotify Playlist" : name, source: .spotify, sourceUrl: spotify, songs: r.songs,
					unmatched: r.unmatched
				)
				done = Done(playlist: p, added: r.songs.count, check: r.unmatched.count, skipped: 0)
				spotifyUrl = nil
			} catch {
				if !Task.isCancelled { self.error = error.localizedDescription }
			}
			busyLabel = nil
		}
	}
}
