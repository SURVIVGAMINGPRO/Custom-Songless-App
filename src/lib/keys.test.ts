import { describe, expect, it } from 'vitest';
import {
	actionFor,
	comboFromEvent,
	conflict,
	defaultBindings,
	keycaps,
	reserved,
	shortcutText,
	typesText,
	withDefaults
} from './keys.ts';

const key = (k: string, mods: Partial<Record<'ctrlKey' | 'altKey' | 'shiftKey' | 'metaKey', boolean>> = {}) => ({
	key: k,
	ctrlKey: false,
	altKey: false,
	shiftKey: false,
	metaKey: false,
	...mods
});

describe('comboFromEvent', () => {
	it('names keys and modifiers', () => {
		expect(comboFromEvent(key('Enter'))).toBe('Enter');
		expect(comboFromEvent(key('Enter', { shiftKey: true }))).toBe('Shift+Enter');
		expect(comboFromEvent(key(' '))).toBe('Space');
		expect(comboFromEvent(key('s'))).toBe('S');
		expect(comboFromEvent(key('S', { shiftKey: true }))).toBe('Shift+S');
		expect(comboFromEvent(key('k', { metaKey: true }))).toBe('Meta+K');
		expect(comboFromEvent(key('k', { ctrlKey: true, altKey: true }))).toBe('Ctrl+Alt+K');
	});
	it("leaves Shift out of punctuation, since it's part of the character", () => {
		expect(comboFromEvent(key('?', { shiftKey: true }))).toBe('?');
		expect(comboFromEvent(key('/'))).toBe('/');
	});
	it('ignores a modifier pressed on its own', () => {
		expect(comboFromEvent(key('Shift', { shiftKey: true }))).toBeNull();
		expect(comboFromEvent(key('Meta', { metaKey: true }))).toBeNull();
	});
});

describe('bindings', () => {
	it('fills in defaults and keeps cleared shortcuts', () => {
		const b = withDefaults({ skip: null, play: 'P', bogus: 'X' });
		expect(b.skip).toBeNull();
		expect(b.play).toBe('P');
		expect(b.guess).toBe('Enter');
		expect('bogus' in b).toBe(false);
	});
	it('runs the action for the current state', () => {
		const b = defaultBindings();
		expect(actionFor(b, 'Enter', 'playing')).toBe('guess');
		expect(actionFor(b, 'Enter', 'finished')).toBe('next');
		expect(actionFor(b, 'Space', 'finished')).toBe('play');
		expect(actionFor(b, 'S', 'playing')).toBeNull();
	});
	it('spots clashes only when both actions can run at once', () => {
		const b = defaultBindings();
		expect(conflict(b, 'skip', 'Enter')?.id).toBe('guess');
		expect(conflict(b, 'next', 'Enter')).toBeNull();
		expect(conflict(b, 'help', 'S')?.id).toBe('share');
	});
	it('keeps Tab and Escape free', () => {
		expect(reserved('Tab')).toBe(true);
		expect(reserved('Shift+Tab')).toBe(true);
		expect(reserved('Escape')).toBe(true);
		expect(reserved('Enter')).toBe(false);
	});
	it('knows which shortcuts would type text', () => {
		expect(typesText('S')).toBe(true);
		expect(typesText('Shift+S')).toBe(true);
		expect(typesText('Space')).toBe(true);
		expect(typesText('/')).toBe(true);
		expect(typesText('Enter')).toBe(false);
		expect(typesText('Meta+K')).toBe(false);
	});
});

describe('display', () => {
	it('uses Mac symbols on a Mac and words elsewhere', () => {
		expect(keycaps('Shift+Enter', true)).toEqual(['⇧', '↩']);
		expect(keycaps('Shift+Enter', false)).toEqual(['Shift', 'Enter']);
		expect(shortcutText('Meta+K', true)).toBe('⌘K');
		expect(shortcutText('Ctrl+Alt+K', false)).toBe('Ctrl+Alt+K');
	});
});
