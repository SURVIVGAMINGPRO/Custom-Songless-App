import EarshotCore
import SwiftUI

enum AppTab: Hashable {
	case playlists, stats, settings
}

/// Screens pushed onto the Playlists tab.
enum Route: Hashable {
	case playlist(String)
	case play(String)
	case mix(String)
	case newMix
}

struct Toast: Identifiable, Equatable {
	let id = UUID()
	let text: String
	let error: Bool
}

/// The library, the clip player and what's on screen, shared by every view.
@Observable
final class AppModel {
	let library: LibraryStore
	let player: ClipPlayer

	var tab: AppTab = .playlists
	var path: [Route] = []
	var addingPlaylist = false
	var showingHelp = false
	private(set) var toast: Toast?

	init() {
		library = LibraryStore(file: LibraryStore.defaultFile())
		player = ClipPlayer()
		player.volume = library.data.settings.volume
	}

	func show(_ text: String, error: Bool = false) {
		let t = Toast(text: text, error: error)
		withAnimation(.snappy) { toast = t }
		Task {
			try? await Task.sleep(for: .seconds(2.6))
			if toast == t { withAnimation(.easeOut(duration: 0.25)) { toast = nil } }
		}
	}

	func open(_ route: Route) {
		tab = .playlists
		if path.last != route { path.append(route) }
	}

	/// Pressing a playlist plays it: every playlist has its own game behind the scenes.
	func play(_ playlist: Playlist) {
		guard !playlist.songIds.isEmpty else {
			show("Add some songs to this playlist first")
			return
		}
		if let g = library.gameForPlaylist(playlist.id) { play(g) }
	}

	func play(_ game: Game) {
		library.selectGame(game.id)
		open(.play(game.id))
	}

	/// The playlist page for a single-playlist game, the mix editor for a mix.
	func edit(_ game: Game) -> Route {
		game.playlistIds.count == 1 ? .playlist(game.playlistIds[0]) : .mix(game.id)
	}

	var colorScheme: ColorScheme? {
		switch library.data.settings.appearance {
		case .system: nil
		case .light: .light
		case .dark: .dark
		}
	}
}
