/**
 * Keyboard shortcuts for the play screen. Each action has one shortcut, which
 * the player can change in Settings. Shortcuts are stored as text like
 * "Enter", "Shift+Enter", "Space", "/" or "Meta+K".
 */

export type ActionId = 'guess' | 'skip' | 'play' | 'next' | 'search' | 'share' | 'mode' | 'help';

/** When an action can run: during a round, after it, or both. */
export type When = 'playing' | 'finished' | 'always';

export interface ShortcutAction {
	id: ActionId;
	label: string;
	detail: string;
	default: string | null;
	when: When;
}

export const ACTIONS: ShortcutAction[] = [
	{ id: 'guess', label: 'Guess or Skip', detail: 'Guesses the chosen song; skips when the search is empty', default: 'Enter', when: 'playing' },
	{ id: 'skip', label: 'Skip', detail: 'Skips to a longer clip, even with something typed', default: 'Shift+Enter', when: 'playing' },
	{ id: 'play', label: 'Play or Stop the Clip', detail: 'Space still types once the search has text', default: 'Space', when: 'always' },
	{ id: 'next', label: 'Next Song', detail: 'After a round ends', default: 'Enter', when: 'finished' },
	{ id: 'search', label: 'Search the Playlist', detail: 'Jumps to the search field', default: '/', when: 'playing' },
	{ id: 'share', label: 'Share Result', detail: 'After a round ends', default: 'S', when: 'finished' },
	{ id: 'mode', label: "Switch Endless / Today's Song", detail: '', default: 'M', when: 'always' },
	{ id: 'help', label: 'How to Play', detail: '', default: '?', when: 'always' }
];

export type Bindings = Record<ActionId, string | null>;

export function defaultBindings(): Bindings {
	return Object.fromEntries(ACTIONS.map((a) => [a.id, a.default])) as Bindings;
}

/** Saved shortcuts over the defaults; anything unknown is ignored. */
export function withDefaults(saved: Partial<Record<string, string | null>> | undefined): Bindings {
	const b = defaultBindings();
	for (const a of ACTIONS) {
		const v = saved?.[a.id];
		if (v === null || (typeof v === 'string' && v.length > 0 && v.length < 40)) b[a.id] = v;
	}
	return b;
}

const MODIFIER_KEYS = new Set(['Control', 'Shift', 'Alt', 'Meta', 'AltGraph', 'CapsLock', 'Fn', 'FnLock', 'OS', 'Hyper', 'Super']);

type KeyLike = Pick<KeyboardEvent, 'key' | 'ctrlKey' | 'altKey' | 'shiftKey' | 'metaKey'>;

/** The shortcut a key press makes, or null for a lone modifier. */
export function comboFromEvent(e: KeyLike): string | null {
	if (!e.key || MODIFIER_KEYS.has(e.key) || e.key === 'Dead' || e.key === 'Unidentified') return null;
	let key = e.key;
	if (key === ' ' || key === 'Spacebar') key = 'Space';
	else if (key === 'Esc') key = 'Escape';
	else if (key.length === 1) key = key.toUpperCase();
	// Shift is part of punctuation like "?" (Shift+/ on most keyboards), so it isn't named there.
	const punctuation = e.key.length === 1 && key !== 'Space' && !/^[A-Z0-9]$/.test(key);
	const parts: string[] = [];
	if (e.ctrlKey) parts.push('Ctrl');
	if (e.altKey) parts.push('Alt');
	if (e.shiftKey && !punctuation) parts.push('Shift');
	if (e.metaKey) parts.push('Meta');
	parts.push(key);
	return parts.join('+');
}

/** A shortcut that would type a character (a letter, digit, symbol or space, with or without Shift). */
export function typesText(combo: string): boolean {
	const parts = combo.split('+');
	const key = parts[parts.length - 1];
	const mods = parts.slice(0, -1);
	if (mods.some((m) => m !== 'Shift')) return false;
	return key === 'Space' || key.length === 1 || combo === '+';
}

function overlaps(a: When, b: When): boolean {
	return a === 'always' || b === 'always' || a === b;
}

/** The action a shortcut runs in this state, if any. */
export function actionFor(bindings: Bindings, combo: string, state: 'playing' | 'finished'): ActionId | null {
	for (const a of ACTIONS) {
		if (bindings[a.id] === combo && overlaps(a.when, state)) return a.id;
	}
	return null;
}

/** Another action that already uses this shortcut at the same time, if any. */
export function conflict(bindings: Bindings, id: ActionId, combo: string): ShortcutAction | null {
	const self = ACTIONS.find((a) => a.id === id)!;
	return ACTIONS.find((a) => a.id !== id && bindings[a.id] === combo && overlaps(a.when, self.when)) ?? null;
}

/** Keys that can't be shortcuts: Tab moves focus, Escape cancels. */
export function reserved(combo: string): boolean {
	return /(^|\+)(Tab|Escape)$/.test(combo);
}

const MAC_MODS: Record<string, string> = { Ctrl: '⌃', Alt: '⌥', Shift: '⇧', Meta: '⌘' };
const PC_MODS: Record<string, string> = { Ctrl: 'Ctrl', Alt: 'Alt', Shift: 'Shift', Meta: 'Win' };
const MAC_KEYS: Record<string, string> = {
	Enter: '↩',
	Backspace: '⌫',
	Delete: '⌦',
	ArrowLeft: '←',
	ArrowRight: '→',
	ArrowUp: '↑',
	ArrowDown: '↓',
	Space: 'Space'
};
const PC_KEYS: Record<string, string> = {
	Delete: 'Del',
	ArrowLeft: '←',
	ArrowRight: '→',
	ArrowUp: '↑',
	ArrowDown: '↓',
	Space: 'Space'
};

/** The keycaps to show for a shortcut: ["⇧", "↩"] on a Mac, ["Shift", "Enter"] elsewhere. */
export function keycaps(combo: string, mac: boolean): string[] {
	const parts = combo === '+' ? ['+'] : combo.split('+');
	const key = parts.pop()!;
	const mods = parts.map((m) => (mac ? MAC_MODS : PC_MODS)[m] ?? m);
	return [...mods, (mac ? MAC_KEYS : PC_KEYS)[key] ?? key];
}

/** A shortcut as plain text, for hints and tooltips. */
export function shortcutText(combo: string, mac: boolean): string {
	return keycaps(combo, mac).join(mac ? '' : '+');
}

export function isMac(): boolean {
	return typeof navigator !== 'undefined' && /Mac|iPhone|iPad/.test(navigator.userAgent);
}
