import Foundation

/// The name on screen and in share text.
public let appName = "Earshot"

/// Deezer's "Top Worldwide" chart, offered as a first playlist to try.
public let samplePlaylist = (id: "3155776842", name: "Top Worldwide")

public let exportifyUrl = URL(string: "https://exportify.app/")!

/// A song's cover, only from Deezer's image servers (restored backups are untrusted).
public func coverUrl(_ song: Song?) -> URL? {
	guard let text = song?.cover, !text.isEmpty, let url = URL(string: text), url.scheme == "https", let host = url.host?.lowercased()
	else { return nil }
	return host.hasSuffix(".dzcdn.net") || host == "api.deezer.com" ? url : nil
}

/// "1 song", "1,204 songs".
public func plural(_ n: Int, _ one: String, _ many: String? = nil) -> String {
	"\(n.formatted()) \(n == 1 ? one : many ?? "\(one)s")"
}

/// "5 h 12 min" until the next local midnight.
public func untilMidnight(_ now: Date = Date()) -> String {
	let cal = Calendar.current
	let next = cal.startOfDay(for: cal.date(byAdding: .day, value: 1, to: now)!)
	let mins = max(1, Int((next.timeIntervalSince(now) / 60).rounded(.up)))
	let h = mins / 60
	return h > 0 ? "\(h) h \(mins % 60) min" : "\(mins) min"
}

/// "3:05".
public func songLength(_ seconds: Int) -> String {
	"\(seconds / 60):\(String(format: "%02d", seconds % 60))"
}
