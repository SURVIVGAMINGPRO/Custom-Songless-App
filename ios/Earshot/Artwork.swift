import EarshotCore
import SwiftUI

/// An album cover from Deezer, or a grey square with a note.
struct Cover: View {
	let song: Song?
	var size: CGFloat = 44
	var corner: CGFloat = 6

	var body: some View {
		AsyncImage(url: coverUrl(song)) { phase in
			if let image = phase.image {
				image.resizable().scaledToFill()
			} else {
				ZStack {
					Color(.tertiarySystemFill)
					Image(systemName: "music.note").font(.system(size: size * 0.38)).foregroundStyle(.secondary)
				}
			}
		}
		.frame(width: size, height: size)
		.clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
		.accessibilityHidden(true)
	}
}

/// A playlist's artwork: four album covers, one cover, or a colour field with the logo.
struct Mosaic: View {
	let songs: [Song]
	let seed: String
	var corner: CGFloat = 12

	private var covers: [URL] {
		var urls: [URL] = []
		for s in songs {
			if let url = coverUrl(s), !urls.contains(url) { urls.append(url) }
			if urls.count == 4 { break }
		}
		return urls.count >= 4 ? urls : Array(urls.prefix(1))
	}

	var body: some View {
		let covers = covers
		Color(.secondarySystemFill)
			.aspectRatio(1, contentMode: .fit)
			.overlay {
				if covers.count == 4 {
					Grid(horizontalSpacing: 0, verticalSpacing: 0) {
						GridRow { tile(covers[0]); tile(covers[1]) }
						GridRow { tile(covers[2]); tile(covers[3]) }
					}
				} else if let url = covers.first {
					tile(url)
				} else {
					blank
				}
			}
			.clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
			.accessibilityHidden(true)
	}

	private func tile(_ url: URL) -> some View {
		Color.clear
			.overlay {
				AsyncImage(url: url) { phase in
					if let image = phase.image { image.resizable().scaledToFill() } else { Color(.tertiarySystemFill) }
				}
			}
			.clipped()
	}

	/// No covers yet: a colour picked from the playlist's ID, and the logo.
	private var blank: some View {
		let hue = Double(hash(seed) % 360) / 360
		return GeometryReader { geo in
			ZStack {
				LinearGradient(
					colors: [Color(hue: hue, saturation: 0.45, brightness: 0.42), Color(hue: hue, saturation: 0.55, brightness: 0.22)],
					startPoint: .top, endPoint: .bottom
				)
				LogoMark(size: geo.size.width * 0.36)
			}
		}
	}
}

/// A song with its cover, title and artists.
struct SongRow<Trailing: View>: View {
	let song: Song
	var index: Int?
	@ViewBuilder var trailing: () -> Trailing

	var body: some View {
		HStack(spacing: 12) {
			HStack(spacing: 12) {
				if let index {
					Text("\(index)")
						.font(.subheadline.monospacedDigit())
						.foregroundStyle(.secondary)
						.frame(minWidth: 22, alignment: .trailing)
				}
				Cover(song: song, size: 44)
				VStack(alignment: .leading, spacing: 2) {
					Text(song.title).lineLimit(1)
					Text(song.artists.joined(separator: ", ")).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
				}
				.frame(maxWidth: .infinity, alignment: .leading)
			}
			.accessibilityElement(children: .combine)
			trailing()
		}
	}
}

extension SongRow where Trailing == EmptyView {
	init(song: Song, index: Int? = nil) {
		self.init(song: song, index: index) { EmptyView() }
	}
}
