import EarshotCore
import SwiftUI
import UniformTypeIdentifiers

/// A backup file for the share sheet and Files: the library as JSON, readable by the desktop app.
nonisolated struct BackupDocument: FileDocument {
	static let readableContentTypes: [UTType] = [.json]
	let data: Data

	init(data: Data) { self.data = data }

	init(configuration: ReadConfiguration) throws {
		data = configuration.file.regularFileContents ?? Data()
	}

	func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
		FileWrapper(regularFileWithContents: data)
	}
}

struct SettingsView: View {
	@Environment(AppModel.self) private var model
	@State private var exporting: BackupDocument?
	@State private var choosingBackup = false
	@State private var pending: Data?
	@State private var confirmReset = false

	private var library: LibraryStore { model.library }

	var body: some View {
		Form {
			Section {
				Picker("Theme", selection: Binding(get: { library.data.settings.appearance }, set: { library.setAppearance($0) })) {
					Text("Automatic").tag(Appearance.system)
					Text("Light").tag(Appearance.light)
					Text("Dark").tag(Appearance.dark)
				}
			} header: {
				Text("Appearance")
			} footer: {
				Text("Automatic follows your iPhone's light or dark setting.")
			}

			Section("Sound") {
				HStack(spacing: 12) {
					Image(systemName: "speaker.fill").foregroundStyle(.secondary)
					Slider(
						value: Binding(
							get: { library.data.settings.volume },
							set: {
								model.player.volume = $0
								library.setVolume($0)
							}
						),
						in: 0...1
					)
					.accessibilityLabel("Volume")
					Text("\(Int((library.data.settings.volume * 100).rounded()))%")
						.font(.subheadline.monospacedDigit())
						.foregroundStyle(.secondary)
						.frame(minWidth: 44, alignment: .trailing)
				}
			}

			Section {
				Button("Save a Backup…", systemImage: "square.and.arrow.up") {
					do {
						exporting = BackupDocument(data: try library.backup())
					} catch {
						model.show("Couldn't save the backup", error: true)
					}
				}
				Button("Restore a Backup…", systemImage: "square.and.arrow.down") { choosingBackup = true }
			} header: {
				Text("Backup")
			} footer: {
				Text("Your playlists, mixes and stats are saved on this iPhone only. Backups open in the desktop app too.")
			}

			Section {
				Button("Delete Everything…", role: .destructive) { confirmReset = true }
			}

			Section {
				Button("How to Play", systemImage: "questionmark.circle") { model.showingHelp = true }
			}

			Section("About") {
				Text("Song clips and search come from Deezer's free previews and API. Spotify playlists come in through files you export yourself; this app never connects to Spotify. Not connected with Deezer, Spotify or Lessgames' Songless.")
					.font(.footnote)
					.foregroundStyle(.secondary)
				LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")
			}
		}
		.navigationTitle("Settings")
		.fileExporter(
			isPresented: Binding(get: { exporting != nil }, set: { if !$0 { exporting = nil } }), document: exporting,
			contentType: .json, defaultFilename: "earshot-backup-\(Date().formatted(.iso8601.year().month().day()))"
		) { result in
			if case .success = result { model.show("Saved a backup") }
		}
		.fileImporter(isPresented: $choosingBackup, allowedContentTypes: [.json]) { result in
			guard case let .success(url) = result else { return }
			let access = url.startAccessingSecurityScopedResource()
			defer { if access { url.stopAccessingSecurityScopedResource() } }
			if let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize, size > 20 * 1024 * 1024 {
				model.show("That file is too big to be a backup", error: true)
				return
			}
			pending = try? Data(contentsOf: url)
		}
		.alert(
			"Restore This Backup?", isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } })
		) {
			Button("Cancel", role: .cancel) { pending = nil }
			Button("Replace", role: .destructive) {
				if let pending, library.restore(pending) {
					model.player.volume = library.data.settings.volume
					model.path.removeAll()
					model.show("Restored your backup")
				} else {
					model.show("That file isn't a backup from this app", error: true)
				}
				pending = nil
			}
		} message: {
			Text("It replaces every playlist, mix and stat on this iPhone.")
		}
		.confirmationDialog("Delete Everything?", isPresented: $confirmReset, titleVisibility: .visible) {
			Button("Delete Everything", role: .destructive) {
				library.reset()
				model.path.removeAll()
				model.show("Deleted everything")
			}
		} message: {
			Text("Every playlist, mix and stat on this iPhone is deleted. Save a backup first if you might want them back.")
		}
	}
}

/// How to play, shown the first time and from the ? button.
struct HowToPlayView: View {
	@Environment(\.dismiss) private var dismiss

	var body: some View {
		NavigationStack {
			List {
				Section {
					Text("Listen to a tiny clip from your playlist and guess the song. Each wrong guess or skip plays a longer clip.")
						.font(.body)
				}
				Section {
					row("play.circle.fill", .brand, "Play the current clip")
					row("forward.circle.fill", .secondary, "Skip to a longer clip")
					row(GuessResult.wrong.symbol, .bad, "Wrong artist and song")
					row(GuessResult.artist.symbol, .near, "Right artist, wrong song")
					row(GuessResult.correct.symbol, .good, "Got it")
				} footer: {
					Text("Search shows only songs from the playlist you're playing. Clips are \(defaultSteps.map { formatSeconds($0, short: true) }.joined(separator: ", ")) long, five tries in all, taken from each song's 30-second Deezer preview (which often starts partway into the song). Press Return once to pick a song and again to guess it.")
				}
			}
			.navigationTitle("How to Play")
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
			}
		}
		.presentationDetents([.medium, .large])
	}

	private func row(_ symbol: String, _ color: Color, _ text: String) -> some View {
		Label {
			Text(text)
		} icon: {
			Image(systemName: symbol).font(.title3).foregroundStyle(color)
		}
	}
}
