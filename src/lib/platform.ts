/** True inside the desktop app (Tauri), false in a normal browser. */
export function isDesktop(): boolean {
	return typeof window !== 'undefined' && '__TAURI_INTERNALS__' in window;
}

/** Open a web page in the user's browser (the desktop app can't open new windows itself). */
export async function openExternal(url: string): Promise<void> {
	if (!/^https:\/\//.test(url)) return;
	if (isDesktop()) {
		const { openUrl } = await import('@tauri-apps/plugin-opener');
		await openUrl(url);
	} else {
		window.open(url, '_blank', 'noopener,noreferrer');
	}
}

/** Save text to a file the user picks (desktop) or through a download (browser). */
export async function saveTextFile(name: string, text: string): Promise<boolean> {
	if (isDesktop()) {
		const { save } = await import('@tauri-apps/plugin-dialog');
		const path = await save({ defaultPath: name, filters: [{ name: 'Backup', extensions: ['json'] }] });
		if (!path) return false;
		const { invoke } = await import('@tauri-apps/api/core');
		await invoke('save_text_file', { path, contents: text });
		return true;
	}
	const url = URL.createObjectURL(new Blob([text], { type: 'application/json' }));
	const a = document.createElement('a');
	a.href = url;
	a.download = name;
	a.click();
	setTimeout(() => URL.revokeObjectURL(url), 1000);
	return true;
}

/** A duration token from app.css ("400ms") in milliseconds. */
export function ms(token: string): number {
	const v = getComputedStyle(document.documentElement).getPropertyValue(token).trim();
	const n = parseFloat(v);
	return Number.isFinite(n) ? (v.endsWith('ms') ? n : n * 1000) : 0;
}
