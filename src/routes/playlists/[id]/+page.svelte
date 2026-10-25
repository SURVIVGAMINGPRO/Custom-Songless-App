<script lang="ts">
	import { goto } from '$app/navigation';
	import { resolve } from '$app/paths';
	import { page } from '$app/state';
	import { untrack } from 'svelte';
	import Confirm from '#lib/components/Confirm.svelte';
	import Icon from '#lib/components/Icon.svelte';
	import Mosaic from '#lib/components/Mosaic.svelte';
	import PageHead from '#lib/components/PageHead.svelte';
	import { APP_NAME } from '#lib/config.ts';
	import Progress from '#lib/components/Progress.svelte';
	import SongRow from '#lib/components/SongRow.svelte';
	import { fold } from '#lib/game/normalize.ts';
	import type { Song } from '#lib/game/types.ts';
	import { itemsFromLines } from '#lib/sources/csv.ts';
	import { search } from '#lib/sources/deezer.ts';
	import { matchAll } from '#lib/sources/importer.ts';
	import { searchQuery } from '#lib/sources/match.ts';
	import { playPlaylist } from '#lib/nav.ts';
	import { library } from '#lib/store/library.svelte.ts';
	import { toasts } from '#lib/toast.svelte.ts';
	import { plural } from '#lib/util.ts';

	const SOURCE = { spotify: 'from Spotify', deezer: 'from Deezer', built: 'made here' } as const;

	const pid = $derived(page.params.id ?? '');

	// "/playlists/new" makes an empty playlist and moves to it.
	$effect(() => {
		if (pid !== 'new') return;
		const p = untrack(() => library.createPlaylist({ name: 'New playlist', source: 'built' }));
		goto(resolve('/playlists/[id]', { id: p.id }), { replace: true });
	});

	const playlist = $derived(library.playlist(pid));
	const songs = $derived((playlist?.songIds ?? []).map((id) => library.song(id)).filter((s): s is Song => !!s));
	const inList = $derived(new Set(playlist?.songIds ?? []));

	let name = $derived(playlist?.name ?? '');
	let confirmDelete = $state(false);

	// Search to add
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
		}, 350);
	}

	function add(song: Song) {
		if (!playlist) return;
		library.addToPlaylist(playlist, [song]);
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

	function lookFor(text: string) {
		query = text;
		runSearch();
		searchInput?.focus();
		searchInput?.scrollIntoView({ block: 'center' });
	}
</script>

<svelte:head>
	<title>{playlist?.name ?? 'Playlist'} · {APP_NAME}</title>
</svelte:head>

<div class="page">
{#if pid === 'new'}
	<p class="muted loading">Making a playlist…</p>
{:else if !playlist}
	<PageHead title="Playlist not found" />
	<a class="btn quiet" href={resolve('/')}>Back to your playlists</a>
{:else}
	<a class="back" href={resolve('/')}><Icon name="arrow-left" size={18} /> Playlists</a>
	<header class="ed-hero">
		<div class="ed-art"><Mosaic songs={songs.slice(0, 8)} seed={playlist.id} radius="var(--r-lg)" /></div>
		<div class="ed-text">
			<p class="eyebrow">Playlist · {SOURCE[playlist.source]}</p>
			<h1 title={playlist.name}>{playlist.name}</h1>
			<p class="muted">{plural(songs.length, 'song')}</p>
			<div class="ed-actions">
				<button class="btn" type="button" disabled={songs.length === 0} onclick={play}>
					<Icon name="play" size={16} /> Play
				</button>
				<button class="btn danger small" type="button" onclick={() => (confirmDelete = true)}>
					<Icon name="trash" size={16} /> Delete
				</button>
			</div>
		</div>
	</header>

	<section>
		<label class="label" for="pl-name">Name</label>
		<input
			id="pl-name"
			class="field"
			maxlength="60"
			bind:value={name}
			onchange={() => library.renamePlaylist(playlist, name)}
			onkeydown={(e) => e.key === 'Enter' && (e.currentTarget as HTMLInputElement).blur()}
		/>
	</section>

	<section>
		<h2>Add songs</h2>
		<input
			bind:this={searchInput}
			class="field"
			type="search"
			placeholder="Search for a song or artist"
			aria-label="Search for a song or artist"
			bind:value={query}
			oninput={runSearch}
		/>
		{#if searching && results.length === 0}
			<p class="muted note">Searching…</p>
		{:else if query.trim().length >= 2 && !searching && results.length === 0}
			<p class="muted note">No songs found</p>
		{/if}
		{#if results.length}
			<ul class="songs card">
				{#each results as s (s.id)}
					<li>
						<SongRow song={s}>
							{#snippet end()}
								{#if inList.has(s.id)}
									<span class="added"><Icon name="check" size={18} /> Added</span>
								{:else}
									<button class="btn small quiet" type="button" onclick={() => add(s)}>
										<Icon name="plus" size={16} /> Add
									</button>
								{/if}
							{/snippet}
						</SongRow>
					</li>
				{/each}
			</ul>
		{/if}

		<details class="paste">
			<summary>Paste a list of songs</summary>
			<p class="muted small">One song per line, like <span class="example">Queen - Bohemian Rhapsody</span>.</p>
			<textarea class="field" bind:value={pasteText} aria-label="Songs, one per line" disabled={!!pasting}></textarea>
			{#if pasting}
				<Progress done={pasting.done} total={pasting.total} label="Finding songs on Deezer" />
				<button class="btn small ghost" type="button" onclick={() => pasteCtl?.abort()}>Stop</button>
			{:else}
				<button class="btn quiet" type="button" disabled={!pasteText.trim()} onclick={findPasted}>Find these songs</button>
			{/if}
		</details>
	</section>

	{#if playlist.unmatched.length}
		<section>
			<h2>Needs a look <span class="count">{playlist.unmatched.length}</span></h2>
			<p class="muted small">These couldn't be matched for sure. Pick the right song, search for it, or drop it.</p>
			<ul class="review">
				{#each playlist.unmatched as u, i (i)}
					<li class="card">
						<div class="wanted">
							<div>
								<p class="title">{u.title}</p>
								<p class="muted small">
									{u.artists.join(', ') || 'Unknown artist'} · {u.reason === 'unsure' ? 'Not sure which one' : 'Not found on Deezer'}
								</p>
							</div>
							<div class="wanted-actions">
								<button class="btn small ghost" type="button" onclick={() => lookFor(searchQuery(u))}>Search</button>
								<button class="btn small ghost" type="button" onclick={() => library.resolveUnmatched(playlist, i, null)}>
									Drop
								</button>
							</div>
						</div>
						{#each u.candidates as c (c.id)}
							<SongRow song={c}>
								{#snippet end()}
									<button class="btn small quiet" type="button" onclick={() => library.resolveUnmatched(playlist, i, c)}>
										Use this
									</button>
								{/snippet}
							</SongRow>
						{/each}
					</li>
				{/each}
			</ul>
		</section>
	{/if}

	<section>
		<div class="list-head">
			<h2>Songs <span class="count">{songs.length}</span></h2>
			{#if songs.length > 8}
				<input class="field filter" type="search" placeholder="Filter" aria-label="Filter songs" bind:value={filter} />
			{/if}
		</div>
		{#if songs.length === 0}
			<p class="muted">No songs yet. Search above to add some.</p>
		{:else}
			<ul class="songs card">
				{#each shown as s (s.id)}
					<li>
						<SongRow song={s}>
							{#snippet end()}
								<button
									class="icon-btn"
									type="button"
									aria-label="Remove {s.title}"
									title="Remove"
									onclick={() => library.removeFromPlaylist(playlist, s.id)}
								>
									<Icon name="x" size={18} />
								</button>
							{/snippet}
						</SongRow>
					</li>
				{/each}
			</ul>
		{/if}
	</section>

	<Confirm
		bind:open={confirmDelete}
		title="Delete this playlist?"
		message="“{playlist.name}” and its songs will be removed. Mixes that only used this playlist are removed too."
		confirm="Delete playlist"
		onconfirm={remove}
	/>
{/if}
</div>

<style>
	.page {
		max-width: var(--content);
		margin: 0 auto;
	}

	.back {
		display: inline-flex;
		align-items: center;
		gap: 6px;
		margin: 0 0 16px -8px;
		padding: 6px 10px;
		border-radius: var(--r-full);
		color: var(--fg-3);
		font-size: var(--fs-sm);
		font-weight: 500;
		text-decoration: none;
	}

	.back:hover {
		background: var(--surface-2);
		color: var(--fg);
	}

	.ed-hero {
		display: flex;
		align-items: flex-end;
		gap: 24px;
		animation: rise var(--t-slow) var(--ease-out) both;
	}

	.ed-art {
		width: clamp(120px, 28vw, 180px);
		flex: none;
		border-radius: var(--r-lg);
		box-shadow: var(--shadow-card);
	}

	.ed-text {
		display: grid;
		gap: 4px;
		min-width: 0;
	}

	.ed-text h1 {
		overflow: hidden;
		font-size: clamp(28px, 6vw, 44px);
		font-weight: 800;
		text-overflow: ellipsis;
		white-space: nowrap;
	}

	.ed-actions {
		display: flex;
		flex-wrap: wrap;
		gap: 8px;
		margin-top: 12px;
	}

	@media (max-width: 480px) {
		.ed-hero {
			flex-direction: column;
			align-items: flex-start;
		}
	}

	.loading {
		margin-top: 48px;
		text-align: center;
	}

	section {
		margin-top: 32px;
	}

	h2 {
		margin-bottom: 12px;
		font-size: 20px;
		font-weight: 500;
	}

	.count {
		margin-left: 4px;
		color: var(--fg-4);
	}

	.note {
		margin-top: 12px;
		font-size: 14px;
	}

	.small {
		font-size: 13px;
	}

	.songs {
		margin: 12px 0 0;
		padding: 4px 0;
		list-style: none;
	}

	.songs li + li {
		border-top: 1px solid var(--line);
	}

	.added {
		display: inline-flex;
		align-items: center;
		gap: 4px;
		padding: 0 8px;
		color: var(--good);
		font-size: 13px;
		font-weight: 500;
	}

	.paste {
		margin-top: 16px;
	}

	.paste summary {
		width: fit-content;
		color: var(--fg-2);
		font-size: 14px;
		cursor: pointer;
	}

	.paste[open] {
		display: grid;
		gap: 12px;
	}

	.paste[open] summary {
		margin-bottom: 4px;
	}

	.paste .btn {
		justify-self: start;
	}

	.example {
		color: var(--fg-2);
	}

	.review {
		display: grid;
		gap: 8px;
		margin: 12px 0 0;
		padding: 0;
		list-style: none;
	}

	.wanted {
		display: flex;
		flex-wrap: wrap;
		align-items: center;
		justify-content: space-between;
		gap: 8px;
		padding: 12px;
		border-bottom: 1px solid var(--line);
	}

	.wanted:last-child {
		border-bottom: 0;
	}

	.title {
		font-weight: 500;
	}

	.wanted-actions {
		display: flex;
		gap: 6px;
	}

	.list-head {
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: 12px;
	}

	.list-head h2 {
		margin-bottom: 0;
	}

	.filter {
		width: min(220px, 50%);
		height: 34px;
	}

	.icon-btn {
		display: grid;
		place-items: center;
		width: 34px;
		height: 34px;
		border: 0;
		border-radius: var(--r-full);
		background: transparent;
		color: var(--fg-4);
	}

	.icon-btn:hover {
		background: var(--surface-2);
		color: var(--bad-soft);
	}
</style>
