<script lang="ts">
	import { resolve } from '$app/paths';
	import Icon from '#lib/components/Icon.svelte';
	import PageHead from '#lib/components/PageHead.svelte';
	import Progress from '#lib/components/Progress.svelte';
	import { EXPORTIFY_URL } from '#lib/config.ts';
	import type { Playlist } from '#lib/game/types.ts';
	import { playPlaylist } from '#lib/nav.ts';
	import { itemsFromCsv } from '#lib/sources/csv.ts';
	import { type DzCollection, album, playlist as deezerPlaylist, resolveShortLink } from '#lib/sources/deezer.ts';
	import { matchAll } from '#lib/sources/importer.ts';
	import { type ParsedLink, parseLink } from '#lib/sources/links.ts';
	import { library } from '#lib/store/library.svelte.ts';
	import { plural } from '#lib/util.ts';

	/** Exports bigger than this are surely not a playlist CSV. */
	const MAX_FILE = 5 * 1024 * 1024;
	const MAX_ROWS = 2000;

	let link = $state('');
	let spotify = $state<{ url: string } | null>(null);
	let error = $state('');
	let busy = $state<{ label: string; done: number; total: number } | null>(null);
	let done = $state<{ playlist: Playlist; added: number; check: number; skipped: number } | null>(null);
	let dragging = $state(false);
	let fileInput = $state<HTMLInputElement>();
	let controller: AbortController | undefined;

	const parsed = $derived(link.trim() ? parseLink(link) : null);

	function start(label: string) {
		error = '';
		done = null;
		controller = new AbortController();
		busy = { label, done: 0, total: 0 };
		return controller.signal;
	}

	async function importLink() {
		let target: ParsedLink | null = parsed;
		if (!target) {
			error = "That doesn't look like a Spotify or Deezer playlist link.";
			return;
		}
		if (target.kind === 'spotify-playlist') {
			spotify = { url: target.url };
			error = '';
			return;
		}
		spotify = null;
		const signal = start('Reading the playlist from Deezer');
		try {
			if (target.kind === 'deezer-short') target = parseLink(await resolveShortLink(target.url, signal));
			let c: DzCollection;
			let sourceUrl: string;
			if (target?.kind === 'deezer-playlist') {
				c = await deezerPlaylist(target.id, signal, (n) => (busy = { label: 'Reading the playlist from Deezer', done: n, total: n }));
				sourceUrl = `https://www.deezer.com/playlist/${target.id}`;
			} else if (target?.kind === 'deezer-album') {
				c = await album(target.id, signal);
				sourceUrl = `https://www.deezer.com/album/${target.id}`;
			} else throw new Error("That share link didn't lead to a playlist.");
			if (c.songs.length === 0) throw new Error('This playlist has no songs with previews.');
			const p = library.createPlaylist({ name: c.name, source: 'deezer', sourceUrl, songs: c.songs });
			done = { playlist: p, added: c.songs.length, check: 0, skipped: c.skipped };
			link = '';
		} catch (e) {
			if (!signal.aborted) error = e instanceof Error ? e.message : "Couldn't import that playlist.";
		}
		busy = null;
	}

	async function importFile(file: File) {
		error = '';
		if (file.size > MAX_FILE) {
			error = 'That file is too big to be a playlist export.';
			return;
		}
		const parsedCsv = itemsFromCsv(await file.text());
		if (!parsedCsv.ok) {
			error = parsedCsv.error;
			return;
		}
		const items = parsedCsv.items.slice(0, MAX_ROWS);
		const signal = start('Finding songs on Deezer');
		busy = { label: 'Finding songs on Deezer', done: 0, total: items.length };
		try {
			const r = await matchAll(items, {
				signal,
				onProgress: (p) => (busy = { label: 'Finding songs on Deezer', ...p })
			});
			const name = file.name.replace(/\.csv$/i, '').replace(/[_-]+/g, ' ').trim();
			const p = library.createPlaylist({
				name: name || 'Spotify Playlist',
				source: 'spotify',
				sourceUrl: spotify?.url,
				songs: r.songs,
				unmatched: r.unmatched
			});
			done = { playlist: p, added: r.songs.length, check: r.unmatched.length, skipped: 0 };
			spotify = null;
		} catch (e) {
			if (!signal.aborted) error = e instanceof Error ? e.message : "Couldn't import that file.";
		}
		busy = null;
	}

	function onFiles(files: FileList | null | undefined) {
		const file = files?.[0];
		if (file) importFile(file);
	}
</script>

<div class="page">
	<PageHead title="Add Playlist" sub="Each playlist you add becomes its own guessing game." />

	{#if busy}
		<section class="card panel" aria-live="polite">
			<Progress done={busy.done} total={busy.total} label={busy.label} />
			<button class="btn small quiet" type="button" onclick={() => controller?.abort()}>Stop</button>
		</section>
	{:else}
		{#if done}
			<section class="card panel done" aria-live="polite">
				<p class="done-title">
					<svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="12" r="10" /><path d="m7.5 12.5 3 3 6-6.5" /></svg>
					Added {plural(done.added, 'song')} to “{done.playlist.name}”
				</p>
				{#if done.check}
					<p class="muted">{plural(done.check, 'song')} couldn't be matched for sure. You can check them on the playlist page.</p>
				{/if}
				{#if done.skipped}
					<p class="muted">{plural(done.skipped, 'song')} had no preview on Deezer and were left out.</p>
				{/if}
				<div class="row">
					<button class="btn" type="button" disabled={done.added === 0} onclick={() => playPlaylist(done!.playlist)}>
						<Icon name="play" size={14} /> Play
					</button>
					<a class="btn quiet" href={resolve('/playlists/[id]', { id: done.playlist.id })}>Open Playlist</a>
				</div>
			</section>
		{/if}

		<section>
			<h2 class="group-title">Paste a Link</h2>
			<form
				class="card link-form"
				onsubmit={(e) => {
					e.preventDefault();
					importLink();
				}}
			>
				<label class="visually-hidden" for="link">Playlist link</label>
				<input
					id="link"
					class="field"
					type="text"
					inputmode="url"
					autocomplete="off"
					spellcheck="false"
					placeholder="Spotify or Deezer playlist link"
					bind:value={link}
					oninput={() => (error = '')}
				/>
				<button class="btn" type="submit" disabled={!link.trim()}>Add</button>
			</form>
			{#if error}
				<p class="error" role="alert">{error}</p>
			{:else}
				<p class="group-note">Deezer playlists and albums come straight in. Spotify links show you how to export.</p>
			{/if}
		</section>

		{#if spotify}
			<section class="card panel spotify">
				<h2>Bring This Spotify Playlist In as a File</h2>
				<p class="muted">
					Spotify doesn't let apps read playlists for games, so export it with Exportify (a free tool that uses your own
					Spotify login), then drop the file below.
				</p>
				<ol>
					<li>
						Open <a href={EXPORTIFY_URL} target="_blank" rel="noopener noreferrer">exportify.app <Icon name="external" size={13} /></a>
						and sign in with Spotify.
					</li>
					<li>Find this playlist and press <strong>Export</strong>.</li>
					<li>Drop the <strong>.csv</strong> file below.</li>
				</ol>
				<p class="muted small">
					If the playlist isn't yours and Exportify can't see it, add its songs to a playlist of your own in Spotify first.
				</p>
			</section>
		{/if}

		<section>
			<h2 class="group-title">Drop a Spotify Export</h2>
			<button
				type="button"
				class="drop"
				class:dragging
				onclick={() => fileInput?.click()}
				ondragover={(e) => {
					e.preventDefault();
					dragging = true;
				}}
				ondragleave={() => (dragging = false)}
				ondrop={(e) => {
					e.preventDefault();
					dragging = false;
					onFiles(e.dataTransfer?.files);
				}}
			>
				<span class="drop-icon"><Icon name="file" size={26} /></span>
				<span class="drop-title">Drop a .csv file here</span>
				<span class="muted small">or click to choose one. Exportify, TuneMyMusic and Soundiiz files work.</span>
			</button>
			<input
				bind:this={fileInput}
				class="visually-hidden"
				type="file"
				accept=".csv,text/csv"
				tabindex="-1"
				aria-hidden="true"
				onchange={(e) => {
					onFiles((e.currentTarget as HTMLInputElement).files);
					(e.currentTarget as HTMLInputElement).value = '';
				}}
			/>
		</section>

		<section>
			<h2 class="group-title">Or Build One</h2>
			<ul class="group">
				<li>
					<a class="build" href={resolve('/playlists/[id]', { id: 'new' })}>
						<span class="build-icon"><Icon name="plus" size={16} weight={2.4} /></span>
						<span class="build-text">
							<span class="build-title">New Playlist</span>
							<span class="muted small">Search for songs and add them, or paste a list.</span>
						</span>
						<Icon name="chevron-right" size={16} />
					</a>
				</li>
			</ul>
		</section>
	{/if}
</div>

<style>
	.page {
		max-width: var(--content);
		margin: 0 auto;
	}

	section {
		margin-top: 24px;
	}

	.panel {
		display: grid;
		gap: 10px;
		padding: 18px 20px;
		animation: rise var(--t-slow) var(--ease-out) both;
	}

	.panel .btn {
		justify-self: start;
	}

	.done-title {
		display: flex;
		align-items: center;
		gap: 8px;
		font-size: var(--fs-lg);
		font-weight: 600;
	}

	.done-title svg {
		width: 22px;
		height: 22px;
		flex: none;
		color: var(--good);
	}

	.done-title circle {
		fill: currentColor;
	}

	.done-title path {
		fill: none;
		stroke: var(--on-color);
		stroke-width: 2;
		stroke-linecap: round;
		stroke-linejoin: round;
	}

	.row {
		display: flex;
		flex-wrap: wrap;
		gap: 8px;
		margin-top: 4px;
	}

	.link-form {
		display: flex;
		gap: 8px;
		padding: 10px;
	}

	.link-form .field {
		flex: 1;
		min-width: 0;
		background: var(--bg);
	}

	.error {
		margin: 6px 14px 0;
		color: var(--bad);
		font-size: var(--fs-sm);
	}

	.spotify h2 {
		font-size: var(--fs-lg);
	}

	.spotify ol {
		display: grid;
		gap: 4px;
		margin: 0;
		padding-left: 20px;
	}

	.spotify a {
		display: inline-flex;
		align-items: center;
		gap: 2px;
		color: var(--accent-text);
		font-weight: 600;
		text-decoration: none;
	}

	.spotify a:hover {
		text-decoration: underline;
	}

	.small {
		font-size: var(--fs-sm);
	}

	.drop {
		display: grid;
		justify-items: center;
		gap: 4px;
		width: 100%;
		padding: 30px 16px;
		border: 1.5px dashed var(--line-strong);
		border-radius: var(--r-lg);
		background: var(--surface);
		text-align: center;
		transition:
			border-color var(--t-fast),
			background-color var(--t-fast),
			transform var(--t-med) var(--ease-out);
	}

	.drop:hover,
	.drop.dragging {
		border-color: var(--accent);
		background: var(--accent-wash);
	}

	.drop.dragging {
		transform: scale(1.01);
	}

	.drop-icon {
		margin-bottom: 4px;
		color: var(--accent-text);
	}

	.drop-title {
		font-weight: 600;
	}

	.build {
		display: flex;
		align-items: center;
		gap: 12px;
		padding: 12px 14px;
		color: var(--fg-3);
		text-decoration: none;
		transition: background-color var(--t-fast);
	}

	.build:hover {
		background: var(--fill-3);
	}

	.build-icon {
		display: grid;
		flex: none;
		place-items: center;
		width: 30px;
		height: 30px;
		border-radius: 7px;
		background: var(--accent);
		color: var(--accent-ink);
	}

	.build-text {
		display: grid;
		flex: 1;
		min-width: 0;
	}

	.build-title {
		color: var(--fg);
		font-weight: 600;
	}
</style>
