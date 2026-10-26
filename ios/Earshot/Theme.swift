import EarshotCore
import SwiftUI

// Colours from the desktop app's src/app.css: the logo's yellow as the tint, and
// green/orange/red for results. Text colours are checked at 4.5:1 in both themes.

extension Color {
	init(hex: UInt32, opacity: Double = 1) {
		self.init(
			.sRGB, red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255,
			opacity: opacity
		)
	}

	/// A colour for light and dark mode. SwiftUI resolves it off the main thread
	/// while animating, so the provider must not be tied to the main actor.
	nonisolated static func dynamic(light: UInt32, dark: UInt32, opacity: Double = 1, darkOpacity: Double? = nil) -> Color {
		Color(UIColor { @Sendable traits in
			let isDark = traits.userInterfaceStyle == .dark
			let hex = isDark ? dark : light
			return UIColor(
				red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255,
				alpha: isDark ? darkOpacity ?? opacity : opacity
			)
		})
	}

	/// The logo's yellow, for filled buttons and highlights.
	static let brand = dynamic(light: 0xFFCC00, dark: 0xFFD60A)
	/// Text and symbols on the yellow.
	static let brandInk = Color(hex: 0x1D1D1F)
	static let brandWash = dynamic(light: 0xFFCC00, dark: 0xFFD60A, opacity: 0.18, darkOpacity: 0.16)

	static let good = dynamic(light: 0x1C7A33, dark: 0x30D158)
	static let near = dynamic(light: 0xC93400, dark: 0xFF9F0A)
	static let bad = dynamic(light: 0xD70015, dark: 0xFF6961)
	static let goodWash = dynamic(light: 0x34C759, dark: 0x30D158, opacity: 0.16, darkOpacity: 0.18)
	static let nearWash = dynamic(light: 0xFF9500, dark: 0xFF9F0A, opacity: 0.16, darkOpacity: 0.18)
	static let badWash = dynamic(light: 0xFF3B30, dark: 0xFF453A, opacity: 0.14, darkOpacity: 0.18)
}

extension GuessResult {
	var color: Color {
		switch self {
		case .correct: .good
		case .artist: .near
		case .wrong: .bad
		}
	}

	var wash: Color {
		switch self {
		case .correct: .goodWash
		case .artist: .nearWash
		case .wrong: .badWash
		}
	}

	var symbol: String {
		switch self {
		case .correct: "checkmark.circle.fill"
		case .artist: "person.crop.circle.fill"
		case .wrong: "xmark.circle.fill"
		}
	}

	var label: String {
		switch self {
		case .correct: "Correct"
		case .artist: "Right artist"
		case .wrong: "Wrong"
		}
	}
}

/// Capsule buttons, as in Apple Music: yellow for the main action, grey for the rest.
struct CapsuleButtonStyle: ButtonStyle {
	enum Kind {
		case prominent, quiet, destructive
	}

	var kind: Kind = .prominent
	var large = false

	func makeBody(configuration: Configuration) -> some View {
		CapsuleLabel(configuration: configuration, kind: kind, large: large)
	}

	private struct CapsuleLabel: View {
		let configuration: Configuration
		let kind: Kind
		let large: Bool
		@Environment(\.isEnabled) private var isEnabled

		var body: some View {
			configuration.label
				.font(large ? .headline : .subheadline.weight(.semibold))
				.labelStyle(.titleAndIcon)
				.lineLimit(1)
				.padding(.horizontal, large ? 24 : 16)
				.padding(.vertical, large ? 14 : 9)
				.frame(minHeight: 44)
				.foregroundStyle(kind == .prominent ? Color.brandInk : kind == .destructive ? Color.bad : Color.primary)
				.background(Capsule().fill(kind == .prominent ? AnyShapeStyle(Color.brand) : AnyShapeStyle(Color(.tertiarySystemFill))))
				.contentShape(Capsule())
				.scaleEffect(configuration.isPressed ? 0.96 : 1)
				.opacity(isEnabled ? 1 : 0.4)
				.animation(.snappy(duration: 0.2), value: configuration.isPressed)
		}
	}
}

extension ButtonStyle where Self == CapsuleButtonStyle {
	static var prominent: CapsuleButtonStyle { CapsuleButtonStyle(kind: .prominent) }
	static var quiet: CapsuleButtonStyle { CapsuleButtonStyle(kind: .quiet) }
	static var destructive: CapsuleButtonStyle { CapsuleButtonStyle(kind: .destructive) }
	static func prominent(large: Bool) -> CapsuleButtonStyle { CapsuleButtonStyle(kind: .prominent, large: large) }
	static func quiet(large: Bool) -> CapsuleButtonStyle { CapsuleButtonStyle(kind: .quiet, large: large) }
}

/// Small grey heading above a group, like Settings.
struct GroupTitle: View {
	let text: String
	var body: some View {
		Text(text)
			.font(.title3.weight(.bold))
			.frame(maxWidth: .infinity, alignment: .leading)
			.accessibilityAddTraits(.isHeader)
	}
}
