import { goto } from '$app/navigation';
import { resolve } from '$app/paths';
import type { Game, Playlist } from './game/types.ts';
import { library } from './store/library.svelte.ts';

export function playGame(game: Game): Promise<void> {
	library.selectGame(game);
	return goto(resolve('/play/[id]', { id: game.id }));
}

/** Play one playlist on its own (its game is made the first time). */
export function playPlaylist(playlist: Playlist): Promise<void> {
	return playGame(library.gameForPlaylist(playlist));
}
