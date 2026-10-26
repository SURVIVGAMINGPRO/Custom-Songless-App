import EarshotCore
import SwiftUI

/// Played, won, streaks and how many tries each win took, per game, mode and tab.
struct StatsView: View {
	@Environment(AppModel.self) private var model
	@State private var gameId: String?
	@State private var mode: Mode?
	@State private var tab = allTab
	@State private var grown = false

	private var library: LibraryStore { model.library }
	private var game: Game? { library.game(gameId ?? "") ?? library.currentGame }

	var body: some View {
		ScrollView {
			if let game {
				content(game)
			} else {
				ContentUnavailableView(
					"No Stats Yet", systemImage: "chart.bar", description: Text("Play a playlist and your stats show up here.")
				)
				.padding(.top, 80)
			}
		}
		.navigationTitle("Stats")
		.background(Color(.systemGroupedBackground))
	}

	private func content(_ game: Game) -> some View {
		let mode = mode ?? library.data.settings.mode
		let tabs = library.tabs(game)
		let tab = tabs.contains { $0.key == self.tab } ? self.tab : allTab
		let stats = library.stats(game, mode: mode, tab: tab)
		let most = max(1, stats.dist.max() ?? 1)
		let winRate = stats.played > 0 ? Int((Double(stats.won) / Double(stats.played) * 100).rounded()) : 0
		let tries = stats.dist.dropLast().enumerated().reduce(0) { $0 + $1.element * ($1.offset + 1) }
		return VStack(alignment: .leading, spacing: 20) {
			VStack(spacing: 10) {
				if library.data.games.count > 1 {
					Picker("Playlist or mix", selection: Binding(get: { game.id }, set: { gameId = $0 })) {
						ForEach(library.data.games) { Text($0.name).tag($0.id) }
					}
					.pickerStyle(.menu)
					.frame(maxWidth: .infinity, alignment: .leading)
				}
				Picker("Mode", selection: Binding(get: { mode }, set: { self.mode = $0 })) {
					Text("Endless").tag(Mode.unlimited)
					Text("Today's Song").tag(Mode.daily)
				}
				.pickerStyle(.segmented)
				if tabs.count > 1 {
					Picker("Playlist", selection: Binding(get: { tab }, set: { self.tab = $0 })) {
						ForEach(tabs) { Text($0.label).tag($0.key) }
					}
					.pickerStyle(.menu)
					.frame(maxWidth: .infinity, alignment: .leading)
				}
			}

			LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
				tile("Played", "\(stats.played)")
				tile("Won", "\(winRate)", unit: "%")
				tile("Streak", "\(stats.streak)")
				tile("Best Streak", "\(stats.best)")
			}

			VStack(alignment: .leading, spacing: 10) {
				Text(stats.won > 0 ? "Tries to Get It · \(String(format: "%.1f", Double(tries) / Double(stats.won))) on average" : "Tries to Get It")
					.font(.headline)
				VStack(spacing: 10) {
					ForEach(stats.dist.indices, id: \.self) { i in
						let lost = i == stats.dist.count - 1
						let n = stats.dist[i]
						HStack(spacing: 10) {
							Text(lost ? "X" : "\(i + 1)").font(.subheadline.weight(.semibold)).fontDesign(.rounded).frame(width: 18)
							GeometryReader { geo in
								Capsule()
									.fill(Color(.tertiarySystemFill))
									.overlay(alignment: .leading) {
										Capsule()
											.fill(lost ? Color.bad : Color.brand)
											.frame(width: geo.size.width * (n == 0 ? 0 : max(0.04, Double(n) / Double(most))))
											.scaleEffect(x: grown ? 1 : 0, anchor: .leading)
											.animation(.spring(duration: 0.6, bounce: 0.2).delay(Double(i) * 0.04), value: grown)
									}
							}
							.frame(height: 12)
							Text("\(n)").font(.subheadline.monospacedDigit()).fontDesign(.rounded).frame(minWidth: 28, alignment: .trailing)
						}
						.accessibilityElement(children: .ignore)
						.accessibilityLabel(lost ? "Missed: \(n)" : "Won in \(formatSeconds(game.steps[safe: i] ?? 0)): \(n)")
					}
				}
				.padding(16)
				.background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
			}
		}
		.padding()
		.frame(maxWidth: 640)
		.frame(maxWidth: .infinity)
		.id("\(game.id):\(mode.rawValue):\(tab)")
		.onAppear { grown = true }
		.onChange(of: "\(game.id):\(mode.rawValue):\(tab)") {
			grown = false
			withAnimation { grown = true }
		}
	}

	private func tile(_ label: String, _ value: String, unit: String = "") -> some View {
		VStack(alignment: .leading, spacing: 4) {
			Text(label).font(.subheadline).foregroundStyle(.secondary)
			HStack(alignment: .firstTextBaseline, spacing: 1) {
				Text(value).font(.system(size: 34, weight: .bold, design: .rounded)).contentTransition(.numericText())
				if !unit.isEmpty { Text(unit).font(.title3.weight(.bold)).fontDesign(.rounded).foregroundStyle(.secondary) }
			}
		}
		.frame(maxWidth: .infinity, alignment: .leading)
		.padding(16)
		.background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
		.accessibilityElement(children: .combine)
	}
}

extension Array {
	subscript(safe i: Int) -> Element? { indices.contains(i) ? self[i] : nil }
}
