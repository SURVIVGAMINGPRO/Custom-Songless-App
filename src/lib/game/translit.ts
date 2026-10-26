/**
 * Romanize other alphabets so a player can type Latin letters: "bankomat" finds
 * "Банкомат", "agapi" finds "Αγάπη", "saranghae" finds "사랑해", "sakura" finds
 * "さくら", "qing tian" finds "晴天" (once pinyin is loaded, see `loadPinyin`).
 *
 * Covers Cyrillic (Russian, Ukrainian, Belarusian, Serbian, Macedonian, Bulgarian,
 * Kazakh), Greek, Armenian, Georgian, Hebrew, Arabic, Persian and Urdu, nine
 * Indic scripts (Devanagari, Bengali, Gurmukhi, Gujarati, Odia, Tamil, Telugu,
 * Kannada, Malayalam), Thai, Hangul, Japanese kana and Chinese characters.
 * Kanji in Japanese titles can't be read without a dictionary and stay as they are.
 */

// --- Letter tables -----------------------------------------------------------

function table(pairs: string): Record<string, string> {
	const t: Record<string, string> = {};
	for (const pair of pairs.trim().split(/\s+/)) {
		const [from, to = ''] = pair.split('=');
		t[from] = to;
	}
	return t;
}

const CYRILLIC = table(`
а=a б=b в=v г=g д=d е=e ё=yo ж=zh з=z и=i й=y к=k л=l м=m н=n о=o п=p р=r с=s т=t у=u ф=f х=kh ц=ts ч=ch
ш=sh щ=shch ъ= ы=y ь= э=e ю=yu я=ya і=i ї=yi є=ye ґ=g ў=u ђ=dj ј=j љ=lj њ=nj ћ=c џ=dz ѓ=gj ќ=kj ѕ=dz ѝ=i
ә=a ғ=g қ=q ң=ng ө=o ұ=u ү=u һ=h ӏ= ҳ=h ҷ=j
`);

const GREEK = table(`
α=a ά=a β=v γ=g δ=d ε=e έ=e ζ=z η=i ή=i θ=th ι=i ί=i ϊ=i ΐ=i κ=k λ=l μ=m ν=n ξ=x ο=o ό=o π=p ρ=r σ=s ς=s
τ=t υ=y ύ=y ϋ=y ΰ=y φ=f χ=ch ψ=ps ω=o ώ=o
`);
const GREEK_PAIRS = table(`ου=ou ού=ou αυ=av αύ=av ευ=ev εύ=ev γγ=ng γκ=gk μπ=b ντ=d τσ=ts τζ=tz`);

const ARMENIAN = table(`
ա=a բ=b գ=g դ=d ե=e զ=z է=e ը=y թ=t ժ=zh ի=i լ=l խ=kh ծ=ts կ=k հ=h ձ=dz ղ=gh ճ=ch մ=m յ=y ն=n շ=sh
ո=o չ=ch պ=p ջ=j ռ=r ս=s վ=v տ=t ր=r ց=ts ւ=v փ=p ք=k օ=o ֆ=f և=ev
`);
const ARMENIAN_PAIRS = table(`ու=u`);

const GEORGIAN = table(`
ა=a ბ=b გ=g დ=d ე=e ვ=v ზ=z თ=t ი=i კ=k ლ=l მ=m ნ=n ო=o პ=p ჟ=zh რ=r ს=s ტ=t უ=u ფ=p ქ=k ღ=gh ყ=q
შ=sh ჩ=ch ც=ts ძ=dz წ=ts ჭ=ch ხ=kh ჯ=j ჰ=h
`);

// Hebrew and Arabic leave most vowels unwritten; matching also compares consonants only (see `consonants`).
const HEBREW = table(`
א=a ג=g ד=d ה=h ז=z ח=h ט=t ך=kh ל=l מ=m ם=m נ=n ן=n ס=s ע=a ף=f צ=ts ץ=ts ק=k ר=r ש=sh ת=t
`);
// These read differently at the start of a word.
const HEBREW_START: Record<string, string> = { ב: 'b', כ: 'k', פ: 'p', ו: 'v', י: 'y' };
const HEBREW_INSIDE: Record<string, string> = { ב: 'v', כ: 'kh', פ: 'f', ו: 'o', י: 'i' };

const ARABIC = table(`
ا=a أ=a إ=i آ=a ٱ=a ب=b ت=t ث=th ج=j ح=h خ=kh د=d ذ=dh ر=r ز=z س=s ش=sh ص=s ض=d ط=t ظ=z ع=a غ=gh ف=f ق=q
ك=k ل=l م=m ن=n ه=h و=w ي=y ى=a ة=a ء= ئ=y ؤ=w پ=p چ=ch ژ=zh گ=g ک=k ی=y ٹ=t ڈ=d ڑ=r ں=n ے=e ۓ=e ھ=h ہ=h
`);

// Indic scripts share one layout (by offset inside each 128-character block), so one table covers them all.
const INDIC_BLOCKS = [0x0900, 0x0980, 0x0a00, 0x0a80, 0x0b00, 0x0b80, 0x0c00, 0x0c80, 0x0d00];
const INDIC_CONSONANTS: Record<number, string> = {
	0x15: 'k', 0x16: 'kh', 0x17: 'g', 0x18: 'gh', 0x19: 'ng', 0x1a: 'ch', 0x1b: 'chh', 0x1c: 'j', 0x1d: 'jh',
	0x1e: 'ny', 0x1f: 't', 0x20: 'th', 0x21: 'd', 0x22: 'dh', 0x23: 'n', 0x24: 't', 0x25: 'th', 0x26: 'd',
	0x27: 'dh', 0x28: 'n', 0x29: 'n', 0x2a: 'p', 0x2b: 'ph', 0x2c: 'b', 0x2d: 'bh', 0x2e: 'm', 0x2f: 'y',
	0x30: 'r', 0x31: 'r', 0x32: 'l', 0x33: 'l', 0x34: 'zh', 0x35: 'v', 0x36: 'sh', 0x37: 'sh', 0x38: 's',
	0x39: 'h', 0x58: 'q', 0x59: 'kh', 0x5a: 'gh', 0x5b: 'z', 0x5c: 'r', 0x5d: 'rh', 0x5e: 'f', 0x5f: 'y'
};
const INDIC_VOWELS: Record<number, string> = {
	0x05: 'a', 0x06: 'a', 0x07: 'i', 0x08: 'i', 0x09: 'u', 0x0a: 'u', 0x0b: 'ri', 0x0c: 'li', 0x0d: 'e',
	0x0e: 'e', 0x0f: 'e', 0x10: 'ai', 0x11: 'o', 0x12: 'o', 0x13: 'o', 0x14: 'au', 0x50: 'om', 0x60: 'ri', 0x61: 'li'
};
const INDIC_SIGNS: Record<number, string> = {
	0x3e: 'a', 0x3f: 'i', 0x40: 'i', 0x41: 'u', 0x42: 'u', 0x43: 'ri', 0x44: 'ri', 0x45: 'e', 0x46: 'e',
	0x47: 'e', 0x48: 'ai', 0x49: 'o', 0x4a: 'o', 0x4b: 'o', 0x4c: 'au', 0x57: 'au', 0x62: 'li', 0x63: 'li'
};
const INDIC_MARKS: Record<number, string> = { 0x01: 'n', 0x02: 'n', 0x03: 'h', 0x70: 'n', 0x71: '', 0x4e: 't' };
const VIRAMA = 0x4d;
const NUKTA = 0x3c;

const THAI_CONSONANTS = table(`
ก=k ข=kh ฃ=kh ค=kh ฅ=kh ฆ=kh ง=ng จ=ch ฉ=ch ช=ch ซ=s ฌ=ch ญ=y ฎ=d ฏ=t ฐ=th ฑ=th ฒ=th ณ=n ด=d ต=t ถ=th ท=th
ธ=th น=n บ=b ป=p ผ=ph ฝ=f พ=ph ฟ=f ภ=ph ม=m ย=y ร=r ฤ=rue ล=l ฦ=lue ว=w ศ=s ษ=s ส=s ห=h ฬ=l อ= ฮ=h
`);
const THAI_VOWELS = table(`ะ=a ั=a า=a ำ=am ิ=i ี=i ึ=ue ื=ue ุ=u ู=u ๅ= ็= ่= ้= ๊= ๋= ์= ๆ= ฯ=`);
// Written before the consonant they follow in speech.
const THAI_LEADING = table(`เ=e แ=ae โ=o ใ=ai ไ=ai`);

const HANGUL_INITIAL = ['g', 'kk', 'n', 'd', 'tt', 'r', 'm', 'b', 'pp', 's', 'ss', '', 'j', 'jj', 'ch', 'k', 't', 'p', 'h'];
const HANGUL_VOWEL = ['a', 'ae', 'ya', 'yae', 'eo', 'e', 'yeo', 'ye', 'o', 'wa', 'wae', 'oe', 'yo', 'u', 'wo', 'we', 'wi', 'yu', 'eu', 'ui', 'i'];
const HANGUL_FINAL = ['', 'k', 'k', 'k', 'n', 'n', 'n', 't', 'l', 'k', 'm', 'l', 'l', 'l', 'p', 'l', 'm', 'p', 'p', 't', 't', 'ng', 't', 't', 'k', 't', 'p', 't'];

// Hepburn for hiragana (katakana is shifted onto these first).
const KANA = table(`
あ=a い=i う=u え=e お=o か=ka き=ki く=ku け=ke こ=ko さ=sa し=shi す=su せ=se そ=so た=ta ち=chi つ=tsu て=te
と=to な=na に=ni ぬ=nu ね=ne の=no は=ha ひ=hi ふ=fu へ=he ほ=ho ま=ma み=mi む=mu め=me も=mo や=ya ゆ=yu
よ=yo ら=ra り=ri る=ru れ=re ろ=ro わ=wa ゐ=i ゑ=e を=o ん=n が=ga ぎ=gi ぐ=gu げ=ge ご=go ざ=za じ=ji ず=zu
ぜ=ze ぞ=zo だ=da ぢ=ji づ=zu で=de ど=do ば=ba び=bi ぶ=bu べ=be ぼ=bo ぱ=pa ぴ=pi ぷ=pu ぺ=pe ぽ=po ゔ=vu
ぁ=a ぃ=i ぅ=u ぇ=e ぉ=o ゃ=ya ゅ=yu ょ=yo ゎ=wa ゕ=ka ゖ=ke
`);
const KANA_PAIRS = table(`
きゃ=kya きゅ=kyu きょ=kyo しゃ=sha しゅ=shu しょ=sho ちゃ=cha ちゅ=chu ちょ=cho にゃ=nya にゅ=nyu にょ=nyo
ひゃ=hya ひゅ=hyu ひょ=hyo みゃ=mya みゅ=myu みょ=myo りゃ=rya りゅ=ryu りょ=ryo ぎゃ=gya ぎゅ=gyu ぎょ=gyo
じゃ=ja じゅ=ju じょ=jo ぢゃ=ja ぢゅ=ju ぢょ=jo びゃ=bya びゅ=byu びょ=byo ぴゃ=pya ぴゅ=pyu ぴょ=pyo
ふぁ=fa ふぃ=fi ふぇ=fe ふぉ=fo てぃ=ti でぃ=di とぅ=tu どぅ=du うぃ=wi うぇ=we うぉ=wo ゔぁ=va ゔぃ=vi ゔぇ=ve
ゔぉ=vo しぇ=she じぇ=je ちぇ=che つぁ=tsa つぃ=tsi つぇ=tse つぉ=tso いぇ=ye
`);

const LATIN_EXTRA = table(`ß=ss æ=ae œ=oe ø=o ł=l đ=d ð=d þ=th ı=i ħ=h ŋ=ng ĸ=k ſ=s ŀ=l ŧ=t ƒ=f ə=e ɛ=e ɔ=o`);

const MAP = { ...CYRILLIC, ...GREEK, ...ARMENIAN, ...GEORGIAN, ...HEBREW, ...ARABIC, ...LATIN_EXTRA };
const PAIRS = { ...GREEK_PAIRS, ...ARMENIAN_PAIRS };

// --- Chinese --------------------------------------------------------------------

type HanReader = (text: string) => string[];
let hanReader: HanReader | null = null;
let loading: Promise<void> | null = null;

const HAN = /\p{Script=Han}/u;
const KANA_RE = /[぀-ヿ]/;

/** Load the pinyin reader (about 300 KB) the first time a playlist has Chinese titles. */
export function loadPinyin(): Promise<void> {
	loading ??= import('pinyin-pro')
		.then(({ pinyin }) => {
			hanReader = (text) => pinyin(text, { toneType: 'none', type: 'array', nonZh: 'removed' });
		})
		.catch(() => {
			loading = null;
		});
	return loading;
}

export function needsPinyin(text: string): boolean {
	return HAN.test(text) && !KANA_RE.test(text);
}

// --- Romanizing ---------------------------------------------------------------

function indicOffset(cp: number): number | null {
	for (const start of INDIC_BLOCKS) if (cp >= start && cp < start + 0x80) return cp - start;
	return null;
}

const KATAKANA_START = 0x30a1;
const KATAKANA_END = 0x30f6;

/** Latin letters for every letter this knows; anything else passes through unchanged. Lowercase. */
export function toLatin(input: string): string {
	const s = input.normalize('NFC').toLowerCase();
	const chars = Array.from(s);
	let out = '';
	// Indic: a consonant carries an "a" unless a vowel sign or virama follows.
	let inherent = false;
	// Thai: a vowel written before its consonant.
	let thaiLead = '';
	// Japanese: small tsu doubles the next consonant.
	let geminate = false;
	const japanese = KANA_RE.test(s);
	let hanRun = '';

	const flushIndic = (wordEnds: boolean) => {
		// Hindi and most north Indian scripts drop the final "a" of a word.
		if (inherent && !wordEnds) out += 'a';
		inherent = false;
	};
	const flushHan = () => {
		if (!hanRun) return;
		if (hanReader && !japanese) {
			// Pinyin is typed with any spacing ("yue liang", "yueliang", "daibiao"), so every
			// syllable starts a word that runs to the end: yueliangdaibiao liangdaibiao daibiao biao.
			const syllables = hanReader(hanRun).filter(Boolean);
			out += ` ${syllables.map((_, k) => syllables.slice(k).join('')).join(' ')} `;
		} else out += hanRun;
		hanRun = '';
	};

	for (let i = 0; i < chars.length; i++) {
		const ch = chars[i];
		let cp = ch.codePointAt(0)!;

		if (HAN.test(ch)) {
			flushIndic(false);
			hanRun += ch;
			continue;
		}
		flushHan();

		const offset = indicOffset(cp);
		if (offset !== null) {
			if (offset === VIRAMA) inherent = false;
			else if (offset === NUKTA) continue;
			else if (INDIC_SIGNS[offset] !== undefined) {
				inherent = false;
				out += INDIC_SIGNS[offset];
			} else if (INDIC_CONSONANTS[offset] !== undefined) {
				flushIndic(false);
				out += INDIC_CONSONANTS[offset];
				inherent = true;
			} else if (INDIC_VOWELS[offset] !== undefined) {
				flushIndic(false);
				out += INDIC_VOWELS[offset];
			} else if (INDIC_MARKS[offset] !== undefined) {
				flushIndic(false);
				out += INDIC_MARKS[offset];
			} else if (offset >= 0x66 && offset <= 0x6f) {
				flushIndic(true);
				out += String(offset - 0x66);
			} else flushIndic(true);
			continue;
		}
		if (inherent) flushIndic(!/\p{L}/u.test(ch));

		// Hangul syllables: initial + vowel + final.
		if (cp >= 0xac00 && cp <= 0xd7a3) {
			const n = cp - 0xac00;
			let final = HANGUL_FINAL[n % 28];
			// A final k/t/p before n or m is said (and romanized) as ng/n/m: 합니다 → hamnida.
			const after = chars[i + 1]?.codePointAt(0) ?? 0;
			if (after >= 0xac00 && after <= 0xd7a3 && /^[ktp]$/.test(final)) {
				const nextInitial = HANGUL_INITIAL[Math.floor((after - 0xac00) / 588)];
				if (nextInitial === 'n' || nextInitial === 'm') final = { k: 'ng', t: 'n', p: 'm' }[final as 'k' | 't' | 'p'];
			}
			out += HANGUL_INITIAL[Math.floor(n / 588)] + HANGUL_VOWEL[Math.floor((n % 588) / 28)] + final;
			continue;
		}

		// Japanese kana (katakana shifted onto hiragana).
		if (cp >= KATAKANA_START && cp <= KATAKANA_END) cp -= 0x60;
		if ((cp >= 0x3041 && cp <= 0x3096) || ch === 'ー' || ch === 'ッ' || ch === 'っ') {
			if (ch === 'ー') continue; // long vowel mark
			const kana = String.fromCodePoint(cp);
			if (kana === 'っ') {
				geminate = true;
				continue;
			}
			const nextCp = chars[i + 1]?.codePointAt(0);
			const next = nextCp && nextCp >= KATAKANA_START && nextCp <= KATAKANA_END ? String.fromCodePoint(nextCp - 0x60) : chars[i + 1];
			let roman = KANA_PAIRS[kana + next];
			if (roman) i++;
			else roman = KANA[kana] ?? kana;
			if (geminate) {
				roman = (roman.startsWith('ch') ? 't' : roman[0]) + roman;
				geminate = false;
			}
			out += roman;
			continue;
		}

		// Thai: put leading vowels after their consonant.
		if (THAI_LEADING[ch] !== undefined) {
			thaiLead = THAI_LEADING[ch];
			continue;
		}
		if (THAI_CONSONANTS[ch] !== undefined) {
			out += THAI_CONSONANTS[ch] + thaiLead;
			thaiLead = '';
			continue;
		}
		if (THAI_VOWELS[ch] !== undefined) {
			out += THAI_VOWELS[ch];
			continue;
		}

		// Hebrew letters whose sound depends on their place in the word.
		if (HEBREW_START[ch] !== undefined) {
			const atStart = !/[א-ת]/.test(chars[i - 1] ?? '');
			out += atStart ? HEBREW_START[ch] : HEBREW_INSIDE[ch];
			continue;
		}

		const pair = PAIRS[ch + (chars[i + 1] ?? '')];
		if (pair !== undefined) {
			out += pair;
			i++;
			continue;
		}
		out += MAP[ch] ?? ch;
	}
	flushHan();
	if (inherent) flushIndic(true);
	if (thaiLead) out += thaiLead;
	return out;
}

/** True when romanizing changes the text, so a looser match is worth trying. */
export function hasOtherScript(text: string): boolean {
	return toLatin(text) !== text.normalize('NFC').toLowerCase();
}

/**
 * Collapse spellings that romanizations disagree on, applied to both sides of a
 * search: ya/ja/ia, kh/h, ch/tch/č, sh/sch, zh/ž, doubled letters, and
 * voiced/unvoiced pairs. "ou" is read as "o" (Japanese arigatou/arigato) or, with
 * `ou: 'u'`, as "u" (Greek mou/mu); search tries both. Takes already-folded text.
 */
export function loose(s: string, { ou = 'o' }: { ou?: 'o' | 'u' } = {}): string {
	return s
		.replace(/shch|sch|tsch/g, 'sh')
		.replace(/tch/g, 'ch')
		.replace(/dj/g, 'd')
		.replace(/ch|ts|tz|cz/g, 'c')
		.replace(/sh|sz/g, 's')
		.replace(/zh/g, 'z')
		.replace(/kh/g, 'h')
		.replace(/ph/g, 'f')
		.replace(/th/g, 't')
		.replace(/dh/g, 'd')
		.replace(/gh/g, 'g')
		.replace(/bh/g, 'b')
		.replace(/jh/g, 'j')
		.replace(/ck|q/g, 'k')
		.replace(/w/g, 'v')
		.replace(/j(?=[aeiou])/g, 'y')
		.replace(/y/g, 'i')
		.replace(/ie/g, 'e')
		.replace(/ou/g, ou)
		.replace(/eo/g, 'o')
		.replace(/eu/g, 'u')
		.replace(/g/g, 'k')
		.replace(/d/g, 't')
		.replace(/b/g, 'p')
		.replace(/(\p{L})\1+/gu, '$1');
}

/** Only the consonants, for scripts that don't write most vowels (Hebrew, Arabic). */
export function consonants(s: string): string {
	return s.replace(/[aeiouv]/g, '');
}

const ABJAD = /[֐-׿؀-ۿݐ-ݿ]/;

export function writesFewVowels(text: string): boolean {
	return ABJAD.test(text);
}
