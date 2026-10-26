import EarshotCore
import SwiftUI

@main
struct EarshotApp: App {
	@State private var model = AppModel()
	@Environment(\.scenePhase) private var scenePhase

	var body: some Scene {
		WindowGroup {
			RootView()
				.environment(model)
		}
		.onChange(of: scenePhase) { _, phase in
			// Save right away when the app leaves the screen; it may not come back.
			if phase != .active { model.library.flush() }
			if phase == .background { model.player.stop() }
		}
	}
}
