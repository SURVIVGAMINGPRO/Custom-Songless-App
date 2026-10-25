<script lang="ts">
	import { resolve } from '$app/paths';
	import Icon, { type IconName } from '#lib/components/Icon.svelte';
	import PlaylistCard from '#lib/components/PlaylistCard.svelte';
	import { APP_NAME, SAMPLE_PLAYLIST } from '#lib/config.ts';
	import { playGame, playPlaylist } from '#lib/nav.ts';
	import { playlist as deezerPlaylist } from '#lib/sources/deezer.ts';
	import { library } from '#lib/store/library.svelte.ts';
	import { toasts } from '#lib/toast.svelte.ts';
	import { plural } from '#lib/util.ts';

	const SOURCE = { spotify: 'from Spotify', deezer: 'from Deezer', built: 'made here' } as const;

	const playlists = $derived(library.data.playlists);
	const mixes = $derived(library.mixes);
	const last = $derived.by(() => {
		const g = library.currentGame;
		return g && library.pool(g, 'all').length > 0 ? g : undefined;
	});

	const ways: { icon: IconName; title: string; text: string; href: string }[] = [
		{
			icon: 'file',
			title: 'From Spotify',
			text: 'Export your playlist as a file with Exportify, then drop it in.',
			href: resolve('/import')
		},
		{ icon: 'link', title: 'From Deezer', text: 'Paste a playlist or album link.', href: resolve('/import') },
		{
			icon: 'plus',
			title: 'Make one here',
			text: 'Search for songs and build your own list.',
			href: resolve('/playlists/[id]', { id: 'new' })
		}
	];

	let loadingSample = $state(false);

	async function trySample() {
		loadingSample = true;
		try {
			const c = await deezerPlaylist(SAMPLE_PLAYLIST.id);
			const p = library.createPlaylist({
				name: c.name,
				source: 'deezer',
				sourceUrl: `https://www.deezer.com/playlist/${SAMPLE_PLAYLIST.id}`,
				songs: c.songs
			});
			await playPlaylist(p);
		} catch (e) {
			toasts.show(e instanceof Error ? e.message : "Couldn't load the chart", 'error');
		}
		loadingSample = false;
	}
</script>

<svelte:head>
	<title>{APP_NAME}</title>
</svelte:head>

<section class="hero">
	<p class="eyebrow">Your playlists, by ear</p>
	<h1>Name the song<br />in a split second.</h1>
	<p class="lede">
		Every playlist you add becomes its own guessing game. Hear a tenth of a second, guess, and get a longer clip
		after every miss.
	</p>
	{#if last}
		<button class="continue" type="button" onclick={() => playGame(last)}>
			<span class="pulse" aria-hidden="true"></span>
			Continue <strong>{last.name}</strong>
			<Icon name="arrow-right" size={18} />
		</button>
	{/if}
</section>

{#if playlists.length === 0}
	<section class="start">
		<h2>Add your first playlist</h2>
		<div class="ways">
			{#each ways as w, i (w.title)}
				<a class="way rise" style:--i={i} href={w.href}>
					<span class="way-icon"><Icon name={w.icon} size={22} /></span>
					<span class="way-title">{w.title}</span>
					<span class="way-text">{w.text}</span>
				</a>
			{/each}
		</div>
		<button class="sample" type="button" disabled={loadingSample} onclick={trySample}>
			<Icon name="sparkle" size={16} />
			{loadingSample ? 'Loading the chart…' : `No playlist handy? Try Deezer's ${SAMPLE_PLAYLIST.name} chart`}
		</button>
	</section>
{:else}
	<section>
		<div class="section-head">
			<h2>Playlists <span class="count">{playlists.length}</span></h2>
		</div>
		<div class="grid">
			{#each playlists as p, i (p.id)}
				<PlaylistCard
					title={p.name}
					meta="{plural(p.songIds.length, 'song')} · {SOURCE[p.source]}"
					tag={p.unmatched.length ? `${p.unmatched.length} to check` : undefined}
					songs={library.songsOf([p.id], 8)}
					seed={p.id}
					editHref={resolve('/playlists/[id]', { id: p.id })}
					index={i}
					onplay={() => (p.songIds.length ? playPlaylist(p) : toasts.show('Add some songs to this playlist first'))}
				/>
			{/each}
			<a class="add-card rise" style:--i={playlists.length} href={resolve('/import')}>
				<span class="add-icon"><Icon name="plus" size={28} /></span>
				Add a playlist
			</a>
		</div>
	</section>

	{#if playlists.length > 1}
		<section>
			<div class="section-head">
				<h2>Mixes <span class="count">{mixes.length}</span></h2>
				<p class="muted">Several playlists in one game, each with its own tab.</p>
			</div>
			<div class="grid">
				{#each mixes as g, i (g.id)}
					<PlaylistCard
						title={g.name}
						meta="{g.playlistIds.length} playlists · {plural(library.pool(g, 'all').length, 'song')}"
						songs={library.songsOf(g.playlistIds, 8)}
						seed={g.id}
						editHref={resolve('/games/[id]', { id: g.id })}
						stacked
						index={i}
						onplay={() => playGame(g)}
					/>
				{/each}
				<a class="add-card small rise" style:--i={mixes.length} href={resolve('/games/[id]', { id: 'new' })}>
					<span class="add-icon"><Icon name="layers" size={26} /></span>
					New mix
				</a>
			</div>
		</section>
	{/if}
{/if}

<style>
	.hero {
		max-width: 680px;
		margin: 32px 0 48px;
	}

	@media (min-width: 720px) {
		.hero {
			margin: 48px 0 64px;
		}
	}

	.hero h1 {
		margin-top: 12px;
		font-size: var(--fs-hero);
		font-weight: 800;
		font-variation-settings: 'wdth' 80;
		letter-spacing: -0.035em;
		line-height: 0.98;
		animation: rise var(--t-slow) var(--ease-out) both;
	}

	.lede {
		max-width: 52ch;
		margin-top: 18px;
		color: var(--fg-2);
		font-size: 17px;
		animation: rise var(--t-slow) var(--ease-out) 80ms both;
	}

	.continue {
		display: inline-flex;
		align-items: center;
		gap: 10px;
		margin-top: 28px;
		padding: 12px 18px 12px 16px;
		border: 1px solid var(--line-strong);
		border-radius: var(--r-full);
		background: var(--surface);
		color: var(--fg-2);
		font-size: var(--fs-md);
		animation: rise var(--t-slow) var(--ease-out) 160ms both;
		transition:
			border-color var(--t-fast),
			transform var(--t-fast) var(--ease-out);
	}

	.continue strong {
		max-width: 22ch;
		overflow: hidden;
		color: var(--fg);
		font-weight: 600;
		text-overflow: ellipsis;
		white-space: nowrap;
	}

	.continue:hover {
		border-color: var(--accent);
	}

	.continue:hover :global(svg) {
		transform: translateX(3px);
	}

	.continue :global(svg) {
		color: var(--accent);
		transition: transform var(--t-fast) var(--ease-out);
	}

	.pulse {
		position: relative;
		width: 8px;
		height: 8px;
		border-radius: var(--r-full);
		background: var(--accent);
	}

	.pulse::after {
		content: '';
		position: absolute;
		inset: 0;
		border-radius: inherit;
		background: var(--accent);
		animation: ping 1.8s var(--ease-out) infinite;
	}

	@keyframes ping {
		to {
			transform: scale(3);
			opacity: 0;
		}
	}

	section + section {
		margin-top: 56px;
	}

	.section-head {
		display: flex;
		flex-wrap: wrap;
		align-items: baseline;
		gap: 4px 14px;
		margin-bottom: 20px;
	}

	.section-head h2 {
		font-size: var(--fs-xl);
	}

	.section-head .muted {
		font-size: var(--fs-sm);
	}

	.count {
		margin-left: 2px;
		color: var(--fg-4);
		font-weight: 500;
	}

	.grid {
		display: grid;
		grid-template-columns: repeat(auto-fill, minmax(160px, 1fr));
		gap: 28px 20px;
	}

	@media (min-width: 720px) {
		.grid {
			grid-template-columns: repeat(auto-fill, minmax(196px, 1fr));
		}
	}

	.add-card {
		display: grid;
		align-content: center;
		justify-items: center;
		gap: 12px;
		aspect-ratio: 1;
		border: 1.5px dashed var(--line-strong);
		border-radius: var(--r-lg);
		color: var(--fg-3);
		font-weight: 600;
		text-decoration: none;
		transition:
			border-color var(--t-med),
			color var(--t-med),
			background-color var(--t-med);
	}

	.add-icon {
		display: grid;
		place-items: center;
		width: 56px;
		height: 56px;
		border-radius: var(--r-full);
		background: var(--surface-2);
		transition:
			background-color var(--t-med),
			color var(--t-med),
			transform var(--t-med) var(--ease-pop);
	}

	.add-card:hover {
		border-color: var(--accent);
		background: var(--accent-wash);
		color: var(--fg);
	}

	.add-card:hover .add-icon {
		background: var(--accent);
		color: var(--accent-ink);
		transform: rotate(90deg);
	}

	.add-card.small:hover .add-icon {
		transform: scale(1.08);
	}

	.start h2 {
		margin-bottom: 20px;
		font-size: var(--fs-xl);
	}

	.ways {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
		gap: 14px;
	}

	.way {
		display: grid;
		gap: 6px;
		padding: 22px;
		border: 1px solid var(--line);
		border-radius: var(--r-lg);
		background: var(--surface);
		text-decoration: none;
		transition:
			border-color var(--t-med),
			transform var(--t-med) var(--ease-out),
			box-shadow var(--t-med);
	}

	.way:hover {
		border-color: var(--accent);
		box-shadow: 0 16px 40px rgb(0 0 0 / 0.4);
		transform: translateY(-3px);
	}

	.way-icon {
		display: grid;
		place-items: center;
		width: 44px;
		height: 44px;
		margin-bottom: 8px;
		border-radius: var(--r-md);
		background: var(--accent-wash);
		color: var(--accent);
	}

	.way-title {
		font-family: var(--font-display);
		font-size: var(--fs-lg);
		font-weight: 700;
	}

	.way-text {
		color: var(--fg-3);
		font-size: var(--fs-sm);
	}

	.sample {
		display: inline-flex;
		align-items: center;
		gap: 8px;
		margin-top: 20px;
		padding: 8px 4px;
		border: 0;
		background: none;
		color: var(--fg-3);
		font-size: var(--fs-sm);
	}

	.sample:hover:not(:disabled) {
		color: var(--fg);
	}

	.sample :global(svg) {
		color: var(--accent);
	}
</style>
