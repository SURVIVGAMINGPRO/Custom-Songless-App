<script lang="ts">
	import { goto } from '$app/navigation';
	import { resolve } from '$app/paths';
	import { page } from '$app/state';
	import { untrack } from 'svelte';
	import Confirm from '#lib/components/Confirm.svelte';
	import Icon from '#lib/components/Icon.svelte';
	import Mosaic from '#lib/components/Mosaic.svelte';
	import PageHead from '#lib/components/PageHead.svelte';
	import Progress from '#lib/components/Progress.svelte';
	import SongRow from '#lib/components/SongRow.svelte';
	import { APP_NAME } from '#lib/config.ts';
	import { fold } from '#lib/game/normalize.ts';
	import type { Song } from '#lib/game/types.ts';
	import { playPlaylist } from '#lib/nav.ts';
	import { itemsFromLines } from '#lib/sources/csv.ts';
	import { search } from '#lib/sources/deezer.ts';
	import { matchAll } from '#lib/sources/importer.ts';
	import { searchQuery } from '#lib/sources/match.ts';
	import { library } from '#lib/store/library.svelte.ts';
	import { toasts } from '#lib/toast.svelte.ts';
	import { plural } from '#lib/util.ts';

	const SOURCE = { spotify: 'From Spotify', deezer: 'From Deezer', built: 'Made here' } as const;

	const pid = $derived(page.params.id ?? '');

	// "/playlists/new" makes an empty playlist and moves to it.
	$effect(() => {
		if (pid !== 'new') return;
		const p = untrack(() => library.createPlaylist({ name: 'New Playlist', source: 'built' }));
		goto(resolve('/playlists/[id]', { id: p.id }), { replace: true });
	});

	const playlist = $derived(library.playlist(pid));
	const songs = $derived((playlist?.songIds ?? []).map((id) => library.song(id)).filter((s): s is Song => !!s));
	const inList = $derived(new Set(playlist?.songIds ?? []));
	const minutes = $derived(Math.round(songs.reduce((t, s) => t + s.duration, 0) / 60));

	let name = $derived(playlist?.name ?? '');
	let renaming = $state(false);
	let confirmDelete = $state(false);

	// Search Deezer to add songs
	let query = $state('');
	let results = $state<Song[]>([]);
	let searching = $state(false);
	let searchInput = $state<HTMLInputElement>();
	let timer: ReturnType<typeof setTimeout> | undefined;
	let searchCtl: AbortController | undefined;

	function runSearch() {
		clearTimeout(timer);
		searchCtl?.abort();
		const q = query.trim();
		if (q.length < 2) {
			results = [];
			searching = false;
			return;
		}
		searching = true;
		timer = setTimeout(async () => {
			searchCtl = new AbortController();
			const signal = searchCtl.signal;
			try {
				const found = await search(q, 15, signal);
				if (!signal.aborted) results = found;
			} catch (e) {
				if (!signal.aborted) toasts.show(e instanceof Error ? e.message : "Couldn't search", 'error');
			}
			if (!signal.aborted) searching = false;
		}, 300);
	}

	function add(song: Song) {
		if (playlist) library.addToPlaylist(playlist, [song]);
	}

	// Paste a list
	let pasteText = $state('');
	let pasting = $state<{ done: number; total: number } | null>(null);
	let pasteCtl: AbortController | undefined;

	async function findPasted() {
		if (!playlist) return;
		const items = itemsFromLines(pasteText).slice(0, 500);
		if (items.length === 0) return;
		pasteCtl = new AbortController();
		pasting = { done: 0, total: items.length };
		try {
			const r = await matchAll(items, { signal: pasteCtl.signal, onProgress: (p) => (pasting = p) });
			const added = library.addToPlaylist(playlist, r.songs);
			library.addUnmatched(playlist, r.unmatched);
			pasteText = '';
			toasts.show(`Added ${plural(added, 'song')}${r.unmatched.length ? `. ${r.unmatched.length} need a look` : ''}`);
		} catch (e) {
			if (!pasteCtl.signal.aborted) toasts.show(e instanceof Error ? e.message : "Couldn't find the songs", 'error');
		}
		pasting = null;
	}

	// Filter the list
	let filter = $state('');
	const shown = $derived.by(() => {
		const f = fold(filter);
		return f ? songs.filter((s) => fold(`${s.title} ${s.artists.join(' ')}`).includes(f)) : songs;
	});

	function play() {
		if (playlist) playPlaylist(playlist);
	}

	function remove() {
		if (!playlist) return;
		library.deletePlaylist(playlist);
		toasts.show('Deleted the playlist');
		goto(resolve('/'));
	}

	function rename() {
		if (playlist) library.renamePlaylist(playlist, name);
		renaming = false;
	}

	function lookFor(text: string) {
		query = text;
		runSearch();
		searchInput?.focus();
		searchInput?.scrollIntoView({ block: 'center' });
	}

	function length(s: Song): string {
		return `${Math.floor(s.duration / 60)}:${String(s.duration % 60).padStart(2, '0')}`;
	}
</script>

<svelte:head>
	<title>{playlist?.name ?? 'Playlist'} · {APP_NAME}</title>
</svelte:head>

<div class="page">
	{#if pid === 'new'}
		<p class="muted loading">Making a playlist…</p>
	{:else if !playlist}
		<PageHead title="Playlist Not Found" />
		<a class="btn quiet" href={resolve('/')}>Back to Playlists</a>
	{:else}
		<header class="hero">
			<div class="art"><Mosaic songs={songs.slice(0, 8)} seed={playlist.id} radius="var(--r-md)" /></div>
			<div class="hero-text">
				{#if renaming}
					<!-- svelte-ignore a11y_autofocus -->
					<input
						class="field name-field"
						maxlength="60"
						aria-label="Playlist name"
						bind:value={name}
						autofocus
						onblur={rename}
						onkeydown={(e) => {
							if (e.key === 'Enter') rename();
							if (e.key === 'Escape') {
								name = playlist.name;
								renaming = false;
							}
						}}
					/>
				{:else}
					<h1>
						<button class="name" type="button" title="Rename" onclick={() => (renaming = true)}>{playlist.name}</button>
					</h1>
				{/if}
				<p class="meta">{SOURCE[playlist.source]} · {plural(songs.length, 'song')}{minutes ? ` · ${minutes} min` : ''}</p>
				<div class="actions">
					<button class="btn" type="button" disabled={songs.length === 0} onclick={play}>
						<Icon name="play" size={14} /> Play
					</button>
					<button class="btn quiet" type="button" onclick={() => (renaming = true)}>
						<Icon name="edit" size={15} /> Rename
					</button>
					<button class="btn danger" type="button" onclick={() => (confirmDelete = true)}>
						<Icon name="trash" size={15} /> Delete
					</button>
				</div>
			</div>
		</header>

		{#if playlist.unmatched.length}
			<section>
				<h2 class="group-title">Needs a Look · {playlist.unmatched.length}</h2>
				<ul class="group review">
					{#each playlist.unmatched as u, i (i)}
						<li>
							<div class="wanted">
								<div class="wanted-text">
									<p class="wanted-title">{u.title}</p>
									<p class="muted small">
										{u.artists.join(', ') || 'Unknown artist'} · {u.reason === 'unsure' ? 'Not sure which one' : 'Not found on Deezer'}
									</p>
								</div>
								<button class="btn small quiet" type="button" onclick={() => lookFor(searchQuery(u))}>Search</button>
								<button class="btn small quiet" type="button" onclick={() => library.resolveUnmatched(playlist, i, null)}>
									Drop
								</button>
							</div>
							{#each u.candidates as c (c.id)}
								<SongRow song={c}>
									{#snippet end()}
										<button class="btn small" type="button" onclick={() => library.resolveUnmatched(playlist, i, c)}>
											Use This
										</button>
									{/snippet}
								</SongRow>
							{/each}
						</li>
					{/each}
				</ul>
				<p class="group-note">These couldn't be matched for sure. Pick the right song, search for it, or drop it.</p>
			</section>
		{/if}

		<section>
			<div class="list-head">
				<h2 class="group-title">Songs</h2>
				{#if songs.length > 8}
					<input class="field filter" type="search" placeholder="Filter" aria-label="Filter songs" bind:value={filter} />
				{/if}
			</div>
			{#if songs.length === 0}
				<p class="muted empty">No songs yet. Search below to add some.</p>
			{:else}
				<ol class="group table">
					{#each shown as s, i (s.id)}
						<li>
							<SongRow song={s} index={filter ? undefined : i + 1}>
								{#snippet end()}
									<span class="time">{length(s)}</span>
									<button
										class="icon-btn remove"
										type="button"
										aria-label="Remove {s.title}"
										title="Remove"
										onclick={() => library.removeFromPlaylist(playlist, s.id)}
									>
										<Icon name="x" size={15} weight={2.2} />
									</button>
								{/snippet}
							</SongRow>
						</li>
					{/each}
				</ol>
			{/if}
		</section>

		<section>
			<h2 class="group-title">Add Songs</h2>
			<div class="search">
				<span class="search-icon"><Icon name="search" size={16} /></span>
				<input
					bind:this={searchInput}
					class="field search-field"
					type="search"
					placeholder="Search Deezer for a song or artist"
					aria-label="Search Deezer for a song or artist"
					bind:value={query}
					oninput={runSearch}
				/>
			</div>
			{#if searching && results.length === 0}
				<p class="muted note">Searching…</p>
			{:else if query.trim().length >= 2 && !searching && results.length === 0}
				<p class="muted note">No songs found. Try the title and the artist.</p>
			{/if}
			{#if results.length}
				<ul class="group table results">
					{#each results as s (s.id)}
						<li>
							<SongRow song={s}>
								{#snippet end()}
									{#if inList.has(s.id)}
										<span class="added"><Icon name="check" size={16} weight={2.4} /> Added</span>
									{:else}
										<button class="btn small quiet" type="button" onclick={() => add(s)}>
											<Icon name="plus" size={13} weight={2.4} /> Add
										</button>
									{/if}
								{/snippet}
							</SongRow>
						</li>
					{/each}
				</ul>
			{/if}

			<details class="paste">
				<summary>Paste a List of Songs</summary>
				<p class="muted small">One song per line, like “Queen - Bohemian Rhapsody”.</p>
				<textarea class="field" bind:value={pasteText} aria-label="Songs, one per line" disabled={!!pasting}></textarea>
				{#if pasting}
					<Progress done={pasting.done} total={pasting.total} label="Finding songs on Deezer" />
					<button class="btn small quiet" type="button" onclick={() => pasteCtl?.abort()}>Stop</button>
				{:else}
					<button class="btn quiet" type="button" disabled={!pasteText.trim()} onclick={findPasted}>Find These Songs</button>
				{/if}
			</details>
		</section>

		<Confirm
			bind:open={confirmDelete}
			title="Delete “{playlist.name}”?"
			message="The playlist and its songs are removed. Mixes that only used this playlist are removed too."
			confirm="Delete"
			onconfirm={remove}
		/>
	{/if}
</div>

<style>
	.page {
		max-width: var(--content);
		margin: 0 auto;
	}

	.loading {
		margin-top: 48px;
		text-align: center;
	}

	.hero {
		display: flex;
		align-items: flex-end;
		gap: 24px;
		margin: 12px 0 32px;
		animation: rise var(--t-slow) var(--ease-out) both;
	}

	.art {
		width: clamp(132px, 26vw, 200px);
		flex: none;
		border-radius: var(--r-md);
		box-shadow: var(--shadow-art);
	}

	.hero-text {
		display: grid;
		gap: 4px;
		min-width: 0;
	}

	h1 {
		min-width: 0;
		font-size: var(--fs-hero);
	}

	.name {
		max-width: 100%;
		padding: 0;
		overflow: hidden;
		border: 0;
		background: none;
		font: inherit;
		letter-spacing: inherit;
		text-align: left;
		text-overflow: ellipsis;
		white-space: nowrap;
		cursor: text;
	}

	.name-field {
		height: 44px;
		font-family: var(--font-display);
		font-size: var(--fs-xl);
		font-weight: 700;
	}

	.meta {
		color: var(--fg-3);
		font-size: var(--fs-sm);
	}

	.actions {
		display: flex;
		flex-wrap: wrap;
		gap: 8px;
		margin-top: 14px;
	}

	@media (max-width: 520px) {
		.hero {
			flex-direction: column;
			align-items: flex-start;
		}
	}

	section {
		margin-top: 28px;
	}

	.list-head {
		display: flex;
		align-items: flex-end;
		justify-content: space-between;
		gap: 12px;
		margin-bottom: 6px;
	}

	.list-head .group-title {
		margin-bottom: 0;
	}

	.filter {
		width: min(200px, 45%);
		height: 30px;
		font-size: var(--fs-sm);
	}

	.empty {
		margin-left: 14px;
	}

	.time {
		color: var(--fg-3);
		font-size: var(--fs-sm);
		font-variant-numeric: tabular-nums;
	}

	.remove {
		width: 28px;
		height: 28px;
		color: var(--fg-4);
	}

	.remove:hover {
		color: var(--bad);
	}

	.search {
		position: relative;
	}

	.search-icon {
		position: absolute;
		top: 50%;
		left: 11px;
		display: flex;
		color: var(--fg-3);
		transform: translateY(-50%);
		pointer-events: none;
	}

	.search-field {
		padding-left: 34px;
	}

	.note {
		margin: 10px 0 0 14px;
		font-size: var(--fs-sm);
	}

	.results {
		margin-top: 10px;
	}

	.added {
		display: inline-flex;
		align-items: center;
		gap: 4px;
		padding: 0 8px;
		color: var(--good);
		font-size: var(--fs-sm);
		font-weight: 600;
	}

	.paste {
		margin-top: 16px;
	}

	.paste summary {
		width: fit-content;
		color: var(--accent-text);
		font-size: var(--fs-sm);
		font-weight: 600;
		cursor: pointer;
	}

	.paste[open] {
		display: grid;
		gap: 10px;
	}

	.paste .btn {
		justify-self: start;
	}

	.small {
		font-size: var(--fs-sm);
	}

	.wanted {
		display: flex;
		flex-wrap: wrap;
		align-items: center;
		gap: 8px;
		padding: 10px 14px;
	}

	.wanted-text {
		flex: 1;
		min-width: 160px;
	}

	.wanted-title {
		font-weight: 600;
	}
</style>
