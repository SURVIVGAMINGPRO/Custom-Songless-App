import Foundation

// Small regular-expression helpers. NSRegularExpression uses ICU, whose syntax is
// close to JavaScript's, so patterns read the same as in the desktop app.

final class RegexCache: @unchecked Sendable {
	static let shared = RegexCache()
	private var cache: [String: NSRegularExpression] = [:]
	private let lock = NSLock()

	func regex(_ pattern: String, _ options: NSRegularExpression.Options = []) -> NSRegularExpression {
		let key = "\(options.rawValue)|\(pattern)"
		lock.lock()
		defer { lock.unlock() }
		if let r = cache[key] { return r }
		let r = try! NSRegularExpression(pattern: pattern, options: options)
		cache[key] = r
		return r
	}
}

extension String {
	/// Replace every match of `pattern` with `template` ($1 for groups).
	func replacing(regex pattern: String, with template: String, options: NSRegularExpression.Options = []) -> String {
		let r = RegexCache.shared.regex(pattern, options)
		return r.stringByReplacingMatches(in: self, range: NSRange(startIndex..., in: self), withTemplate: template)
	}

	func matches(regex pattern: String, options: NSRegularExpression.Options = []) -> Bool {
		RegexCache.shared.regex(pattern, options).firstMatch(in: self, range: NSRange(startIndex..., in: self)) != nil
	}

	/// The capture groups of the first match, or nil.
	func firstMatch(regex pattern: String, options: NSRegularExpression.Options = []) -> [String?]? {
		let r = RegexCache.shared.regex(pattern, options)
		guard let m = r.firstMatch(in: self, range: NSRange(startIndex..., in: self)) else { return nil }
		return (0..<m.numberOfRanges).map { i in
			let range = m.range(at: i)
			guard range.location != NSNotFound, let r = Range(range, in: self) else { return nil }
			return String(self[r])
		}
	}

	public func trimmed() -> String {
		trimmingCharacters(in: .whitespacesAndNewlines)
	}
}
