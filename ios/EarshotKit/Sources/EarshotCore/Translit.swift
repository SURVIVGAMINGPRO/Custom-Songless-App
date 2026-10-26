import Foundation

// Romanize other alphabets so a player can type Latin letters: "bankomat" finds
// "Банкомат", "agapi" finds "Αγάπη", "saranghae" finds "사랑해", "sakura" finds
// "さくら", "qing tian" finds "晴天". A port of the desktop app's translit.ts, with
// the same tables and rules; Chinese uses Apple's built-in pinyin transform, and
// Japanese titles with kanji use Apple's Japanese reader (the desktop app can't
// read kanji).

private func table(_ pairs: String) -> [String: String] {
	var t: [String: String] = [:]
	// Split by scalars: as Characters, a space and a following combining mark (Thai ั) are one.
	for pair in pairs.unicodeScalars.split(whereSeparator: { $0.properties.isWhitespace }) {
		let parts = pair.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
		t[String(String.UnicodeScalarView(parts[0]))] = parts.count > 1 ? String(String.UnicodeScalarView(parts[1])) : ""
	}
	return t
}

private let cyrillic = table("""
	а=a б=b в=v г=g д=d е=e ё=yo ж=zh з=z и=i й=y к=k л=l м=m н=n о=o п=p р=r с=s т=t у=u ф=f х=kh ц=ts ч=ch
	ш=sh щ=shch ъ= ы=y ь= э=e ю=yu я=ya і=i ї=yi є=ye ґ=g ў=u ђ=dj ј=j љ=lj њ=nj ћ=c џ=dz ѓ=gj ќ=kj ѕ=dz ѝ=i
	ә=a ғ=g қ=q ң=ng ө=o ұ=u ү=u һ=h ӏ= ҳ=h ҷ=j
	""")

private let greek = table("""
	α=a ά=a β=v γ=g δ=d ε=e έ=e ζ=z η=i ή=i θ=th ι=i ί=i ϊ=i ΐ=i κ=k λ=l μ=m ν=n ξ=x ο=o ό=o π=p ρ=r σ=s ς=s
	τ=t υ=y ύ=y ϋ=y ΰ=y φ=f χ=ch ψ=ps ω=o ώ=o
	""")
private let greekPairs = table("ου=ou ού=ou αυ=av αύ=av ευ=ev εύ=ev γγ=ng γκ=gk μπ=b ντ=d τσ=ts τζ=tz")

private let armenian = table("""
	ա=a բ=b գ=g դ=d ե=e զ=z է=e ը=y թ=t ժ=zh ի=i լ=l խ=kh ծ=ts կ=k հ=h ձ=dz ղ=gh ճ=ch մ=m յ=y ն=n շ=sh
	ո=o չ=ch պ=p ջ=j ռ=r ս=s վ=v տ=t ր=r ց=ts ւ=v փ=p ք=k օ=o ֆ=f և=ev
	""")
private let armenianPairs = table("ու=u")

private let georgian = table("""
	ა=a ბ=b გ=g დ=d ე=e ვ=v ზ=z თ=t ი=i კ=k ლ=l მ=m ნ=n ო=o პ=p ჟ=zh რ=r ს=s ტ=t უ=u ფ=p ქ=k ღ=gh ყ=q
	შ=sh ჩ=ch ც=ts ძ=dz წ=ts ჭ=ch ხ=kh ჯ=j ჰ=h
	""")

// Hebrew and Arabic leave most vowels unwritten; matching also compares consonants only (see `consonants`).
private let hebrew = table("""
	א=a ג=g ד=d ה=h ז=z ח=h ט=t ך=kh ל=l מ=m ם=m נ=n ן=n ס=s ע=a ף=f צ=ts ץ=ts ק=k ר=r ש=sh ת=t
	""")
// These read differently at the start of a word.
private let hebrewStart: [String: String] = ["ב": "b", "כ": "k", "פ": "p", "ו": "v", "י": "y"]
private let hebrewInside: [String: String] = ["ב": "v", "כ": "kh", "פ": "f", "ו": "o", "י": "i"]

private let arabic = table("""
	ا=a أ=a إ=i آ=a ٱ=a ب=b ت=t ث=th ج=j ح=h خ=kh د=d ذ=dh ر=r ز=z س=s ش=sh ص=s ض=d ط=t ظ=z ع=a غ=gh ف=f ق=q
	ك=k ل=l م=m ن=n ه=h و=w ي=y ى=a ة=a ء= ئ=y ؤ=w پ=p چ=ch ژ=zh گ=g ک=k ی=y ٹ=t ڈ=d ڑ=r ں=n ے=e ۓ=e ھ=h ہ=h
	""")

// Indic scripts share one layout (by offset inside each 128-character block), so one table covers them all.
private let indicBlocks: [UInt32] = [0x0900, 0x0980, 0x0A00, 0x0A80, 0x0B00, 0x0B80, 0x0C00, 0x0C80, 0x0D00]
private let indicConsonants: [UInt32: String] = [
	0x15: "k", 0x16: "kh", 0x17: "g", 0x18: "gh", 0x19: "ng", 0x1A: "ch", 0x1B: "chh", 0x1C: "j", 0x1D: "jh",
	0x1E: "ny", 0x1F: "t", 0x20: "th", 0x21: "d", 0x22: "dh", 0x23: "n", 0x24: "t", 0x25: "th", 0x26: "d",
	0x27: "dh", 0x28: "n", 0x29: "n", 0x2A: "p", 0x2B: "ph", 0x2C: "b", 0x2D: "bh", 0x2E: "m", 0x2F: "y",
	0x30: "r", 0x31: "r", 0x32: "l", 0x33: "l", 0x34: "zh", 0x35: "v", 0x36: "sh", 0x37: "sh", 0x38: "s",
	0x39: "h", 0x58: "q", 0x59: "kh", 0x5A: "gh", 0x5B: "z", 0x5C: "r", 0x5D: "rh", 0x5E: "f", 0x5F: "y"
]
private let indicVowels: [UInt32: String] = [
	0x05: "a", 0x06: "a", 0x07: "i", 0x08: "i", 0x09: "u", 0x0A: "u", 0x0B: "ri", 0x0C: "li", 0x0D: "e",
	0x0E: "e", 0x0F: "e", 0x10: "ai", 0x11: "o", 0x12: "o", 0x13: "o", 0x14: "au", 0x50: "om", 0x60: "ri", 0x61: "li"
]
private let indicSigns: [UInt32: String] = [
	0x3E: "a", 0x3F: "i", 0x40: "i", 0x41: "u", 0x42: "u", 0x43: "ri", 0x44: "ri", 0x45: "e", 0x46: "e",
	0x47: "e", 0x48: "ai", 0x49: "o", 0x4A: "o", 0x4B: "o", 0x4C: "au", 0x57: "au", 0x62: "li", 0x63: "li"
]
private let indicMarks: [UInt32: String] = [0x01: "n", 0x02: "n", 0x03: "h", 0x70: "n", 0x71: "", 0x4E: "t"]
private let virama: UInt32 = 0x4D
private let nukta: UInt32 = 0x3C

private let thaiConsonants = table("""
	ก=k ข=kh ฃ=kh ค=kh ฅ=kh ฆ=kh ง=ng จ=ch ฉ=ch ช=ch ซ=s ฌ=ch ญ=y ฎ=d ฏ=t ฐ=th ฑ=th ฒ=th ณ=n ด=d ต=t ถ=th ท=th
	ธ=th น=n บ=b ป=p ผ=ph ฝ=f พ=ph ฟ=f ภ=ph ม=m ย=y ร=r ฤ=rue ล=l ฦ=lue ว=w ศ=s ษ=s ส=s ห=h ฬ=l อ= ฮ=h
	""")
private let thaiVowels = table("ะ=a ั=a า=a ำ=am ิ=i ี=i ึ=ue ื=ue ุ=u ู=u ๅ= ็= ่= ้= ๊= ๋= ์= ๆ= ฯ=")
// Written before the consonant they follow in speech.
private let thaiLeading = table("เ=e แ=ae โ=o ใ=ai ไ=ai")

private let hangulInitial = ["g", "kk", "n", "d", "tt", "r", "m", "b", "pp", "s", "ss", "", "j", "jj", "ch", "k", "t", "p", "h"]
private let hangulVowel = [
	"a", "ae", "ya", "yae", "eo", "e", "yeo", "ye", "o", "wa", "wae", "oe", "yo", "u", "wo", "we", "wi", "yu", "eu", "ui", "i"
]
private let hangulFinal = [
	"", "k", "k", "k", "n", "n", "n", "t", "l", "k", "m", "l", "l", "l", "p", "l", "m", "p", "p", "t", "t", "ng", "t", "t",
	"k", "t", "p", "t"
]

// Hepburn for hiragana (katakana is shifted onto these first).
private let kana = table("""
	あ=a い=i う=u え=e お=o か=ka き=ki く=ku け=ke こ=ko さ=sa し=shi す=su せ=se そ=so た=ta ち=chi つ=tsu て=te
	と=to な=na に=ni ぬ=nu ね=ne の=no は=ha ひ=hi ふ=fu へ=he ほ=ho ま=ma み=mi む=mu め=me も=mo や=ya ゆ=yu
	よ=yo ら=ra り=ri る=ru れ=re ろ=ro わ=wa ゐ=i ゑ=e を=o ん=n が=ga ぎ=gi ぐ=gu げ=ge ご=go ざ=za じ=ji ず=zu
	ぜ=ze ぞ=zo だ=da ぢ=ji づ=zu で=de ど=do ば=ba び=bi ぶ=bu べ=be ぼ=bo ぱ=pa ぴ=pi ぷ=pu ぺ=pe ぽ=po ゔ=vu
	ぁ=a ぃ=i ぅ=u ぇ=e ぉ=o ゃ=ya ゅ=yu ょ=yo ゎ=wa ゕ=ka ゖ=ke
	""")
private let kanaPairs = table("""
	きゃ=kya きゅ=kyu きょ=kyo しゃ=sha しゅ=shu しょ=sho ちゃ=cha ちゅ=chu ちょ=cho にゃ=nya にゅ=nyu にょ=nyo
	ひゃ=hya ひゅ=hyu ひょ=hyo みゃ=mya みゅ=myu みょ=myo りゃ=rya りゅ=ryu りょ=ryo ぎゃ=gya ぎゅ=gyu ぎょ=gyo
	じゃ=ja じゅ=ju じょ=jo ぢゃ=ja ぢゅ=ju ぢょ=jo びゃ=bya びゅ=byu びょ=byo ぴゃ=pya ぴゅ=pyu ぴょ=pyo
	ふぁ=fa ふぃ=fi ふぇ=fe ふぉ=fo てぃ=ti でぃ=di とぅ=tu どぅ=du うぃ=wi うぇ=we うぉ=wo ゔぁ=va ゔぃ=vi ゔぇ=ve
	ゔぉ=vo しぇ=she じぇ=je ちぇ=che つぁ=tsa つぃ=tsi つぇ=tse つぉ=tso いぇ=ye
	""")

private let latinExtra = table("ß=ss æ=ae œ=oe ø=o ł=l đ=d ð=d þ=th ı=i ħ=h ŋ=ng ĸ=k ſ=s ŀ=l ŧ=t ƒ=f ə=e ɛ=e ɔ=o")

private let letterMap: [String: String] = [cyrillic, greek, armenian, georgian, hebrew, arabic, latinExtra]
	.reduce(into: [:]) { $0.merge($1) { a, _ in a } }
private let pairMap: [String: String] = greekPairs.merging(armenianPairs) { a, _ in a }

// --- Script tests ----------------------------------------------------------------

private func isHan(_ v: UInt32) -> Bool {
	(0x3400...0x4DBF).contains(v) || (0x4E00...0x9FFF).contains(v) || (0xF900...0xFAFF).contains(v)
		|| (0x20000...0x3134F).contains(v) || (0x2E80...0x2FDF).contains(v) || v == 0x3005 || v == 0x3007
		|| (0x3021...0x3029).contains(v) || (0x3038...0x303B).contains(v)
}

private func isKana(_ v: UInt32) -> Bool { (0x3040...0x30FF).contains(v) }

private func isHebrewLetter(_ v: UInt32) -> Bool { (0x05D0...0x05EA).contains(v) }

private func isLetter(_ u: Unicode.Scalar) -> Bool {
	switch u.properties.generalCategory {
	case .uppercaseLetter, .lowercaseLetter, .titlecaseLetter, .modifierLetter, .otherLetter: return true
	default: return false
	}
}

private func indicOffset(_ v: UInt32) -> UInt32? {
	for start in indicBlocks where v >= start && v < start + 0x80 { return v - start }
	return nil
}

public func containsHan(_ text: String) -> Bool { text.unicodeScalars.contains { isHan($0.value) } }
public func containsKana(_ text: String) -> Bool { text.unicodeScalars.contains { isKana($0.value) } }

// --- Chinese and Japanese readings ------------------------------------------------

/// Pinyin is typed with any spacing ("yue liang", "yueliang", "daibiao"), so every
/// syllable starts a word that runs to the end: yueliangdaibiao liangdaibiao daibiao biao.
private func suffixJoins(_ parts: [String]) -> String {
	parts.indices.map { parts[$0...].joined() }.joined(separator: " ")
}

/// Mandarin pinyin for a run of Chinese characters, through Apple's transform.
private func pinyin(_ run: String) -> [String] {
	let latin = run.applyingTransform(.mandarinToLatin, reverse: false) ?? run
	return fold(latin).split(separator: " ").map(String.init)
}

/// Romaji for Japanese text with kanji, through Apple's Japanese tokenizer.
private func japaneseRomaji(_ text: String) -> String? {
	let cf = text as CFString
	let range = CFRange(location: 0, length: CFStringGetLength(cf))
	guard let tokenizer = CFStringTokenizerCreate(nil, cf, range, kCFStringTokenizerUnitWord, Locale(identifier: "ja") as CFLocale)
	else { return nil }
	var words: [String] = []
	while !CFStringTokenizerAdvanceToNextToken(tokenizer).isEmpty {
		if let latin = CFStringTokenizerCopyCurrentTokenAttribute(tokenizer, kCFStringTokenizerAttributeLatinTranscription) as? String {
			words.append(contentsOf: fold(latin).split(separator: " ").map(String.init))
		} else {
			let r = CFStringTokenizerGetCurrentTokenRange(tokenizer)
			words.append((text as NSString).substring(with: NSRange(location: r.location, length: r.length)))
		}
	}
	return words.isEmpty ? nil : suffixJoins(words)
}

// --- Romanizing -----------------------------------------------------------------

/// Latin letters for every letter this knows; anything else passes through unchanged. Lowercase.
public func toLatin(_ input: String) -> String {
	let s = input.precomposedStringWithCanonicalMapping.lowercased()
	let japanese = containsKana(s)
	// Kanji need a dictionary: let Apple's Japanese reader handle the whole title.
	if japanese, containsHan(s), let romaji = japaneseRomaji(s) { return romaji }

	let chars = Array(s.unicodeScalars)
	var out = ""
	// Indic: a consonant carries an "a" unless a vowel sign or virama follows.
	var inherent = false
	// Thai: a vowel written before its consonant.
	var thaiLead = ""
	// Japanese: small tsu doubles the next consonant.
	var geminate = false
	var hanRun = ""

	func flushIndic(_ wordEnds: Bool) {
		// Hindi and most north Indian scripts drop the final "a" of a word.
		if inherent, !wordEnds { out += "a" }
		inherent = false
	}
	func flushHan() {
		guard !hanRun.isEmpty else { return }
		if japanese {
			out += hanRun
		} else {
			out += " \(suffixJoins(pinyin(hanRun))) "
		}
		hanRun = ""
	}
	func str(_ v: UInt32) -> String { String(Unicode.Scalar(v).map(Character.init) ?? " ") }

	var i = 0
	while i < chars.count {
		defer { i += 1 }
		let ch = chars[i]
		let c = String(ch)
		var cp = ch.value

		if isHan(cp) {
			flushIndic(false)
			hanRun += c
			continue
		}
		flushHan()

		if let offset = indicOffset(cp) {
			if offset == virama {
				inherent = false
			} else if offset == nukta {
				continue
			} else if let sign = indicSigns[offset] {
				inherent = false
				out += sign
			} else if let consonant = indicConsonants[offset] {
				flushIndic(false)
				out += consonant
				inherent = true
			} else if let vowel = indicVowels[offset] {
				flushIndic(false)
				out += vowel
			} else if let mark = indicMarks[offset] {
				flushIndic(false)
				out += mark
			} else if (0x66...0x6F).contains(offset) {
				flushIndic(true)
				out += String(offset - 0x66)
			} else {
				flushIndic(true)
			}
			continue
		}
		if inherent { flushIndic(!isLetter(ch)) }

		// Hangul syllables: initial + vowel + final.
		if (0xAC00...0xD7A3).contains(cp) {
			let n = Int(cp - 0xAC00)
			var final = hangulFinal[n % 28]
			// A final k/t/p before n or m is said (and romanized) as ng/n/m: 합니다 → hamnida.
			if i + 1 < chars.count, (0xAC00...0xD7A3).contains(chars[i + 1].value), ["k", "t", "p"].contains(final) {
				let nextInitial = hangulInitial[Int(chars[i + 1].value - 0xAC00) / 588]
				if nextInitial == "n" || nextInitial == "m" { final = ["k": "ng", "t": "n", "p": "m"][final]! }
			}
			out += hangulInitial[n / 588] + hangulVowel[(n % 588) / 28] + final
			continue
		}

		// Japanese kana (katakana shifted onto hiragana).
		if (0x30A1...0x30F6).contains(cp) { cp -= 0x60 }
		if (0x3041...0x3096).contains(cp) || c == "ー" {
			if c == "ー" { continue } // long vowel mark
			let k = str(cp)
			if k == "っ" {
				geminate = true
				continue
			}
			var next = ""
			if i + 1 < chars.count {
				let n = chars[i + 1].value
				next = (0x30A1...0x30F6).contains(n) ? str(n - 0x60) : String(chars[i + 1])
			}
			var roman: String
			if let pair = kanaPairs[k + next] {
				roman = pair
				i += 1
			} else {
				roman = kana[k] ?? k
			}
			if geminate {
				roman = (roman.hasPrefix("ch") ? "t" : String(roman.prefix(1))) + roman
				geminate = false
			}
			out += roman
			continue
		}

		// Thai: put leading vowels after their consonant.
		if let lead = thaiLeading[c] {
			thaiLead = lead
			continue
		}
		if let consonant = thaiConsonants[c] {
			out += consonant + thaiLead
			thaiLead = ""
			continue
		}
		if let vowel = thaiVowels[c] {
			out += vowel
			continue
		}

		// Hebrew letters whose sound depends on their place in the word.
		if let start = hebrewStart[c] {
			let atStart = i == 0 || !isHebrewLetter(chars[i - 1].value)
			out += atStart ? start : hebrewInside[c]!
			continue
		}

		if i + 1 < chars.count, let pair = pairMap[c + String(chars[i + 1])] {
			out += pair
			i += 1
			continue
		}
		out += letterMap[c] ?? c
	}
	flushHan()
	if inherent { flushIndic(true) }
	out += thaiLead
	return out
}

/// True when romanizing changes the text, so a looser match is worth trying.
public func hasOtherScript(_ text: String) -> Bool {
	toLatin(text) != text.precomposedStringWithCanonicalMapping.lowercased()
}

/// Collapse spellings that romanizations disagree on, applied to both sides of a
/// search: ya/ja/ia, kh/h, ch/tch/č, sh/sch, zh/ž, doubled letters, and
/// voiced/unvoiced pairs. "ou" is read as "o" (Japanese arigatou/arigato) or as
/// "u" (Greek mou/mu); search tries both. Takes already-folded text.
public func loose(_ s: String, ou: String = "o") -> String {
	s.replacing(regex: "shch|sch|tsch", with: "sh")
		.replacing(regex: "tch", with: "ch")
		.replacing(regex: "dj", with: "d")
		.replacing(regex: "ch|ts|tz|cz", with: "c")
		.replacing(regex: "sh|sz", with: "s")
		.replacing(regex: "zh", with: "z")
		.replacing(regex: "kh", with: "h")
		.replacing(regex: "ph", with: "f")
		.replacing(regex: "th", with: "t")
		.replacing(regex: "dh", with: "d")
		.replacing(regex: "gh", with: "g")
		.replacing(regex: "bh", with: "b")
		.replacing(regex: "jh", with: "j")
		.replacing(regex: "ck|q", with: "k")
		.replacing(regex: "w", with: "v")
		.replacing(regex: "j(?=[aeiou])", with: "y")
		.replacing(regex: "y", with: "i")
		.replacing(regex: "ie", with: "e")
		.replacing(regex: "ou", with: ou)
		.replacing(regex: "eo", with: "o")
		.replacing(regex: "eu", with: "u")
		.replacing(regex: "g", with: "k")
		.replacing(regex: "d", with: "t")
		.replacing(regex: "b", with: "p")
		.replacing(regex: #"(\p{L})\1+"#, with: "$1")
}

/// Only the consonants, for scripts that don't write most vowels (Hebrew, Arabic).
public func consonants(_ s: String) -> String {
	s.replacing(regex: "[aeiouv]", with: "")
}

public func writesFewVowels(_ text: String) -> Bool {
	text.unicodeScalars.contains { (0x0590...0x06FF).contains($0.value) || (0x0750...0x077F).contains($0.value) }
}
