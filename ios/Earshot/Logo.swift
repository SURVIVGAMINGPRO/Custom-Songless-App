import SwiftUI

/// The app's logo (assets/logo.svg), drawn from its SVG path so it stays sharp at any size.
struct LogoShape: Shape {
	func path(in rect: CGRect) -> Path {
		let side = min(rect.width, rect.height)
		return Self.unit.applying(
			CGAffineTransform(scaleX: side, y: side).concatenating(
				CGAffineTransform(translationX: rect.midX - side / 2, y: rect.midY - side / 2)
			)
		)
	}

	/// The logo in a 1 × 1 square. Its SVG view box is 0 -960 960 960.
	private static let unit: Path = svgPath(source).applying(
		CGAffineTransform(translationX: 0, y: 960).concatenating(CGAffineTransform(scaleX: 1 / 960, y: 1 / 960))
	)

	private static let source = "M530.01-379q42.3 0 71.64-28.57Q631-436.13 631-477.5V-663h73q21.67 0 36.34-14.61 14.66-14.6 14.66-36.2 0-21.59-14.66-36.39Q725.67-765 704-765h-73q-20.37 0-35.19 14.66Q581-735.67 581-714v145q-12.12-5-24.71-9-12.59-4-26.07-4-42.42 0-72.32 29.86-29.9 29.86-29.9 72.15 0 42.3 29.86 71.64Q487.72-379 530.01-379ZM350-217q-52.43 0-90.21-37.79Q222-292.57 222-345v-460q0-52.42 37.79-90.21Q297.57-933 350-933h460q52.42 0 89.71 37.79Q937-857.42 937-805v460q0 52.43-37.29 90.21Q862.42-217 810-217H350Zm0-128h460v-460H350v460ZM150-18q-52.42 0-89.71-37.29Q23-92.58 23-145v-524q0-25.9 18.29-44.95Q59.58-733 86.29-733t45.21 19.05Q150-694.9 150-669v524h524q25.9 0 44.95 18.29 19.05 18.29 19.05 45T718.95-36.5Q699.9-18 674-18H150Zm200-787v460-460Z"
}

/// The logo in its yellow.
struct LogoMark: View {
	var size: CGFloat = 48
	var body: some View {
		LogoShape()
			.fill(Color(hex: 0xFFE042))
			.frame(width: size, height: size)
			.accessibilityHidden(true)
	}
}

/// Read an SVG path's data (M, L, H, V, C, S, Q, T and Z, absolute or relative).
nonisolated func svgPath(_ d: String) -> Path {
	var path = Path()
	var tokens: [String] = []
	var number = ""
	func flush() {
		if !number.isEmpty { tokens.append(number) }
		number = ""
	}
	for c in d {
		if c.isLetter, c != "e", c != "E" {
			flush()
			tokens.append(String(c))
		} else if c == "-" || c == "+" {
			if let last = number.last, last == "e" || last == "E" {
				number.append(c)
			} else {
				flush()
				number.append(c)
			}
		} else if c == "." {
			// "1.5.5" is two numbers: 1.5 and .5.
			if number.contains(".") { flush() }
			number.append(c)
		} else if c.isNumber || c == "e" || c == "E" {
			number.append(c)
		} else {
			flush()
		}
	}
	flush()

	var i = 0
	var command: Character = "M"
	var current = CGPoint.zero
	var start = CGPoint.zero
	var lastControl: CGPoint?
	func next() -> CGFloat {
		defer { i += 1 }
		return i < tokens.count ? CGFloat(Double(tokens[i]) ?? 0) : 0
	}
	while i < tokens.count {
		if let c = tokens[i].first, c.isLetter {
			command = c
			i += 1
			if c == "Z" || c == "z" {
				path.closeSubpath()
				current = start
				lastControl = nil
				continue
			}
		}
		let relative = command.isLowercase
		func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
			relative ? CGPoint(x: current.x + x, y: current.y + y) : CGPoint(x: x, y: y)
		}
		switch command.uppercased() {
		case "M":
			let p = point(next(), next())
			path.move(to: p)
			current = p
			start = p
			lastControl = nil
			// Further pairs after a move are lines.
			command = relative ? "l" : "L"
		case "L":
			let p = point(next(), next())
			path.addLine(to: p)
			current = p
			lastControl = nil
		case "H":
			let x = next()
			let p = CGPoint(x: relative ? current.x + x : x, y: current.y)
			path.addLine(to: p)
			current = p
			lastControl = nil
		case "V":
			let y = next()
			let p = CGPoint(x: current.x, y: relative ? current.y + y : y)
			path.addLine(to: p)
			current = p
			lastControl = nil
		case "C":
			let c1 = point(next(), next())
			let c2 = point(next(), next())
			let p = point(next(), next())
			path.addCurve(to: p, control1: c1, control2: c2)
			current = p
			lastControl = c2
		case "S":
			let c1 = lastControl.map { CGPoint(x: 2 * current.x - $0.x, y: 2 * current.y - $0.y) } ?? current
			let c2 = point(next(), next())
			let p = point(next(), next())
			path.addCurve(to: p, control1: c1, control2: c2)
			current = p
			lastControl = c2
		case "Q":
			let c = point(next(), next())
			let p = point(next(), next())
			path.addQuadCurve(to: p, control: c)
			current = p
			lastControl = c
		case "T":
			let c = lastControl.map { CGPoint(x: 2 * current.x - $0.x, y: 2 * current.y - $0.y) } ?? current
			let p = point(next(), next())
			path.addQuadCurve(to: p, control: c)
			current = p
			lastControl = c
		default:
			i += 1
		}
	}
	return path
}
