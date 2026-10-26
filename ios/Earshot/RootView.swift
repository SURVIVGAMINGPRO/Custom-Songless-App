import EarshotCore
import SwiftUI

/// Tabs for Playlists, Stats and Settings (a sidebar on iPad), with the launch logo on top.
struct RootView: View {
	@Environment(AppModel.self) private var model
	@State private var launching = true

	var body: some View {
		@Bindable var model = model
		TabView(selection: $model.tab) {
			Tab("Playlists", systemImage: "music.note.list", value: AppTab.playlists) {
				NavigationStack(path: $model.path) {
					LibraryView()
						.navigationDestination(for: Route.self) { route in
							switch route {
							case let .playlist(id): PlaylistView(playlistId: id)
							case let .play(id): PlayView(gameId: id)
							case let .mix(id): MixEditorView(gameId: id)
							case .newMix: MixEditorView(gameId: nil)
							}
						}
				}
			}
			Tab("Stats", systemImage: "chart.bar.fill", value: AppTab.stats) {
				NavigationStack { StatsView() }
			}
			Tab("Settings", systemImage: "gearshape.fill", value: AppTab.settings) {
				NavigationStack { SettingsView() }
			}
		}
		.tabViewStyle(.sidebarAdaptable)
		.sheet(isPresented: $model.addingPlaylist) { AddPlaylistView() }
		.sheet(isPresented: $model.showingHelp) { HowToPlayView() }
		.overlay(alignment: .top) { ToastBanner() }
		.overlay {
			if launching { LaunchView { launching = false } }
		}
		.preferredColorScheme(model.colorScheme)
	}
}

/// VC Alert's launch: the logo holds, then flies towards you and fades
/// (Animista's slide-out-fwd-center: 450 ms hold, 400 ms ease-in-sine).
struct LaunchView: View {
	let done: () -> Void
	@State private var gone = false
	@Environment(\.accessibilityReduceMotion) private var reduceMotion

	var body: some View {
		ZStack {
			Color(.systemBackground).opacity(gone ? 0 : 1)
			LogoMark(size: 88)
				.scaleEffect(gone && !reduceMotion ? 2.5 : 1)
				.opacity(gone ? 0 : 1)
		}
		.ignoresSafeArea()
		.allowsHitTesting(!gone)
		.task {
			try? await Task.sleep(for: .milliseconds(450))
			withAnimation(.timingCurve(0.47, 0, 0.745, 0.715, duration: 0.4)) { gone = true }
			try? await Task.sleep(for: .milliseconds(450))
			done()
		}
	}
}

/// A short message at the top, like "Deleted the playlist".
struct ToastBanner: View {
	@Environment(AppModel.self) private var model

	var body: some View {
		if let toast = model.toast {
			Label(toast.text, systemImage: toast.error ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
				.font(.subheadline.weight(.semibold))
				.foregroundStyle(toast.error ? Color.bad : Color.primary)
				.padding(.horizontal, 18)
				.padding(.vertical, 12)
				.background(.regularMaterial, in: Capsule())
				.shadow(color: .black.opacity(0.12), radius: 12, y: 4)
				.padding(.top, 8)
				.padding(.horizontal, 16)
				.transition(.move(edge: .top).combined(with: .opacity))
				.id(toast.id)
				.accessibilityAddTraits(.isStaticText)
				.onAppear { UIAccessibility.post(notification: .announcement, argument: toast.text) }
		}
	}
}
