import Testing

@testable import EarshotCore

// Ported from the desktop app's src/lib/game/translit.test.ts and search.test.ts.

private func song(_ title: String, _ artist: String = "Someone") -> Song {
	Song(id: Int.random(in: 1...Int.max), title: title, artist: artist, artists: [artist], duration: 200)
}

/// Does typing `query` find a song called `title`?
private func finds(_ title: String, _ query: String, artist: String = "Someone") -> Bool {
	searchSongs([song(title, artist)], query).count == 1
}

@Suite struct ToLatinTests {
	@Test func romanizesCyrillic() {
		#expect(toLatin("Банкомат") == "bankomat")
		#expect(toLatin("Жизнь") == "zhizn")
		#expect(toLatin("Щедрик") == "shchedrik")
		#expect(toLatin("Їжак") == "yizhak")
	}

	@Test func romanizesGreekArmenianAndGeorgian() {
		#expect(toLatin("Αγάπη") == "agapi")
		#expect(toLatin("Σε θέλω") == "se thelo")
		#expect(toLatin("Սեր") == "ser")
		#expect(toLatin("სიყვარული") == "siqvaruli")
	}

	@Test func romanizesKoreanJapaneseKanaAndThai() {
		#expect(toLatin("사랑해") == "saranghae")
		#expect(toLatin("さくら") == "sakura")
		#expect(toLatin("カタオモイ") == "kataomoi")
		#expect(toLatin("がっこう") == "gakkou")
		#expect(toLatin("รัก") == "rak")
	}

	@Test func romanizesIndicScriptsDroppingTheFinalInherentVowel() {
		#expect(toLatin("दिल") == "dil")
		#expect(toLatin("तुम ही हो") == "tum hi ho")
		#expect(toLatin("गंगा") == "ganga")
		#expect(toLatin("காதல்") == "katal")
	}

	@Test func leavesLatinTextAloneApartFromSpecialLetters() {
		#expect(toLatin("Hello World") == "hello world")
		#expect(toLatin("Straße") == "strasse")
		#expect(toLatin("Øresund") == "oresund")
	}

	/// Title, toLatin, loose (ou → o), loose (ou → u): values from running the desktop's translit.ts.
	static let desktop: [(String, String, String, String)] = [
		("Банкомат", "bankomat", "pankomat", "pankomat"),
		("Группа крови", "gruppa krovi", "krupa krovi", "krupa krovi"),
		("Звезда по имени Солнце", "zvezda po imeni solntse", "zvezta po imeni solnce", "zvezta po imeni solnce"),
		("Їжак", "yizhak", "izak", "izak"),
		("Щедрик", "shchedrik", "setrik", "setrik"),
		("Ђорђе Балашевић", "djordje balashevic", "torte palasevic", "torte palasevic"),
		("Хочешь", "khochesh", "hoces", "hoces"),
		("Подъезд", "podezd", "potezt", "potezt"),
		("Ёлка", "yolka", "iolka", "iolka"),
		("Αγάπη μου", "agapi mou", "akapi mo", "akapi mu"),
		("Σε θέλω", "se thelo", "se telo", "se telo"),
		("Ευτυχία", "evtychia", "evticia", "evticia"),
		("Μπαμπάς", "babas", "papas", "papas"),
		("Ντροπή", "dropi", "tropi", "tropi"),
		("Γκρεμός", "gkremos", "kremos", "kremos"),
		("Αυγή", "avgi", "avki", "avki"),
		("Սեր", "ser", "ser", "ser"),
		("Ուրախ", "urakh", "urah", "urah"),
		("Երազ", "eraz", "eraz", "eraz"),
		("სიყვარული", "siqvaruli", "sikvaruli", "sikvaruli"),
		("ჩიტო", "chito", "cito", "cito"),
		("שלום", "shlom", "slom", "slom"),
		("אהבה", "ahvh", "ahvh", "ahvh"),
		("ירושלים של זהב", "yroshlim shl zhv", "iroslim sl zv", "iroslim sl zv"),
		("حبيبي", "hbyby", "hpipi", "hpipi"),
		("نور", "nwr", "nvr", "nvr"),
		("عشق", "ashq", "ask", "ask"),
		("یار", "yar", "iar", "iar"),
		("دل دیوانه", "dl dywanh", "tl tivanh", "tl tivanh"),
		("محبت", "mhbt", "mhpt", "mhpt"),
		("तुम ही हो", "tum hi ho", "tum hi ho", "tum hi ho"),
		("दिल", "dil", "til", "til"),
		("गंगा", "ganga", "kanka", "kanka"),
		("क्षमा", "kshama", "ksama", "ksama"),
		("प्यार", "pyar", "piar", "piar"),
		("காதல்", "katal", "katal", "katal"),
		("வணக்கம்", "vanakkam", "vanakam", "vanakam"),
		("ప్రేమ", "prem", "prem", "prem"),
		("ಪ್ರೀತಿ", "priti", "priti", "priti"),
		("സ്നേഹം", "snehan", "snehan", "snehan"),
		("ভালোবাসা", "bhalobasa", "palopasa", "palopasa"),
		("ਪਿਆਰ", "piar", "piar", "piar"),
		("પ્રેમ", "prem", "prem", "prem"),
		("ପ୍ରେମ", "prem", "prem", "prem"),
		("รัก", "rak", "rak", "rak"),
		("เธอ", "the", "te", "te"),
		("ใจ", "chai", "cai", "cai"),
		("สวัสดี", "swasdi", "svasti", "svasti"),
		("사랑해", "saranghae", "sarankae", "sarankae"),
		("강남스타일", "gangnamseutail", "kanknamsutail", "kanknamsutail"),
		("감사합니다", "gamsahamnida", "kamsahamnita", "kamsahamnita"),
		("서울", "seoul", "sol", "sul"),
		("봄날", "bomnal", "pomnal", "pomnal"),
		("작은 것들을 위한 시", "jakeun geotdeuleul wihan si", "iakun kotulul vihan si", "iakun kotulul vihan si"),
		("신라면", "sinramyeon", "sinramon", "sinramon"),
		("さくら", "sakura", "sakura", "sakura"),
		("カタオモイ", "kataomoi", "kataomoi", "kataomoi"),
		("がっこう", "gakkou", "kako", "kaku"),
		("ありがとう", "arigatou", "arikato", "arikatu"),
		("ちょっと", "chotto", "coto", "coto"),
		("シャンティ", "shanti", "santi", "santi"),
		("ヴァイオリン", "vaiorin", "vaiorin", "vaiorin"),
		("ファンファーレ", "fanfare", "fanfare", "fanfare"),
		("きっと", "kitto", "kito", "kito"),
		("ラーメン", "ramen", "ramen", "ramen"),
		("Straße", "strasse", "strase", "strase"),
		("Øresund", "oresund", "oresunt", "oresunt"),
		("Ærø", "aero", "aero", "aero"),
		("Łódź", "lódź", "lotz", "lotz"),
		("Þór", "thór", "tor", "tor"),
		("Hello World", "hello world", "helo vorlt", "helo vorlt"),
		("Mix: Ελληνικά & English", "mix: ellinika & english", "mix elinika ant enklis", "mix elinika ant enklis"),
	]

	@Test func matchesTheDesktopApp() {
		for (title, latin, looseO, looseU) in Self.desktop {
			#expect(toLatin(title) == latin, "\(title)")
			#expect(loose(fold(toLatin(title))) == looseO, "\(title)")
			#expect(loose(fold(toLatin(title)), ou: "u") == looseU, "\(title)")
		}
	}

	@Test func romanizesJapaneseTitlesWithKanji() {
		// The desktop app can't read kanji; the iPhone uses Apple's Japanese tokenizer.
		#expect(toLatin("夜に駆ける").contains("yoru"))
		#expect(finds("夜に駆ける", "yoru ni"))
	}
}

@Suite struct OtherAlphabetSearchTests {
	@Test func findsRussianUkrainianAndSerbianTitlesHoweverTheyAreSpelled() {
		#expect(finds("Банкомат", "Bankomat"))
		#expect(finds("Банкомат", "bank"))
		#expect(finds("Группа крови", "gruppa krovi", artist: "Кино"))
		#expect(finds("Группа крови", "kino", artist: "Кино"))
		#expect(finds("Звезда по имени Солнце", "zvezda po imeni solntse"))
		#expect(finds("Звезда по имени Солнце", "solnce"))
		#expect(finds("Песня", "pesnya"))
		#expect(finds("Песня", "pesnja"))
		#expect(finds("Песня", "pesnia"))
		#expect(finds("Хочешь", "khochesh"))
		#expect(finds("Хочешь", "hochesh"))
		#expect(finds("Щедрик", "schedryk"))
		#expect(finds("Ђорђе", "djordje"))
		#expect(finds("Ђорђе", "đorđe"))
	}

	@Test func findsGreekArmenianAndGeorgianTitles() {
		#expect(finds("Αγάπη μου", "agapi mou"))
		#expect(finds("Αγάπη μου", "agapi mu"))
		#expect(finds("Σε θέλω", "se thelo"))
		#expect(finds("Սեր", "ser"))
		#expect(finds("სიყვარული", "siqvaruli"))
	}

	@Test func findsHebrewAndArabicTitlesFromTheirUsualSpellings() {
		#expect(finds("שלום", "shalom"))
		#expect(finds("אהבה", "ahava"))
		#expect(finds("حبيبي", "habibi"))
		#expect(finds("نور", "nour"))
		#expect(finds("عشق", "eshgh"))
	}

	@Test func findsHindiTamilAndThaiTitles() {
		#expect(finds("तुम ही हो", "tum hi ho"))
		#expect(finds("दिल", "dil"))
		#expect(finds("காதல்", "kadhal"))
		#expect(finds("காதல்", "kaathal"))
		#expect(finds("รัก", "rak"))
	}

	@Test func findsKoreanTitlesInRevisedOrOlderRomanization() {
		#expect(finds("사랑해", "saranghae"))
		#expect(finds("강남스타일", "gangnam"))
		#expect(finds("감사합니다", "kamsahamnida"))
		#expect(finds("서울", "seoul"))
	}

	@Test func findsJapaneseKanaTitlesWithOrWithoutLongVowels() {
		#expect(finds("ありがとう", "arigatou"))
		#expect(finds("ありがとう", "arigato"))
		#expect(finds("カタオモイ", "kataomoi"))
	}

	@Test func findsChineseTitlesByPinyinJoinedOrSpaced() {
		let songs = [song("晴天", "周杰伦"), song("月亮代表我的心", "邓丽君")]
		#expect(searchSongs(songs, "qing tian").first?.title == "晴天")
		#expect(searchSongs(songs, "qingtian").first?.title == "晴天")
		#expect(searchSongs(songs, "zhou jie lun").first?.title == "晴天")
		#expect(searchSongs(songs, "yueliang").first?.title == "月亮代表我的心")
		#expect(searchSongs(songs, "yue liang daibiao").first?.title == "月亮代表我的心")
		#expect(searchSongs(songs, "daibiao").first?.title == "月亮代表我的心")
	}

	@Test func stillMatchesTheOriginalAlphabetAndKeepsLatinSearchesExact() {
		#expect(finds("Банкомат", "банкомат"))
		#expect(finds("Hello", "hel"))
		#expect(!finds("Hello", "xyz"))
		#expect(!finds("Банкомат", "zz"))
	}
}

@Suite struct GuessSearchTests {
	let songs = [
		song("Hey Jude", "The Beatles"),
		song("Hello", "Adele"),
		song("Hello (Live)", "Adele"),
		song("Someone Like You", "Adele"),
		song("Say Hello", "Other Band"),
		song("Come Together", "The Beatles"),
		song("Señorita", "Shawn Mendes")
	]

	func titles(_ q: String, limit: Int = 8) -> [String] { searchSongs(songs, q, limit: limit).map(\.title) }

	@Test func onlyFindsSongsFromTheGivenList() {
		#expect(titles("bohemian").isEmpty)
		#expect(titles("").isEmpty)
	}

	@Test func putsTitlesThatStartWithTheQueryFirstAndLeavesOutRepeats() {
		#expect(titles("hel") == ["Hello", "Say Hello"])
	}

	@Test func matchesArtistsAndWordsInAnyOrder() {
		#expect(titles("adele") == ["Hello", "Someone Like You"])
		#expect(titles("beatles come") == ["Come Together"])
	}

	@Test func matchesTheStartsOfWordsIgnoringAccentsAndCase() {
		#expect(titles("senor") == ["Señorita"])
		#expect(titles("ude").isEmpty)
	}

	@Test func stopsAtTheLimit() {
		#expect(titles("e", limit: 2).isEmpty)
		#expect(titles("the", limit: 1).count == 1)
	}
}
