import type { Appearance } from './game/types.ts';

const dark = typeof window !== 'undefined' ? matchMedia('(prefers-color-scheme: dark)') : null;
let current: Appearance = 'system';

function paint() {
	const isDark = current === 'dark' || (current === 'system' && !!dark?.matches);
	document.documentElement.dataset.theme = isDark ? 'dark' : 'light';
}

dark?.addEventListener('change', () => current === 'system' && paint());

/** Light, dark, or follow the system. Remembered for src/app.html so the next launch draws right away. */
export function applyAppearance(appearance: Appearance): void {
	current = appearance;
	try {
		localStorage.setItem('appearance', appearance);
	} catch {
		// Private windows may refuse; the setting still applies now.
	}
	paint();
}
