<script lang="ts">
	import { resolve } from '$app/paths';
	import Icon, { type IconName } from '#lib/components/Icon.svelte';
	import Logo from '#lib/components/Logo.svelte';
	import Mosaic from '#lib/components/Mosaic.svelte';
	import PageHead from '#lib/components/PageHead.svelte';
	import PlaylistCard from '#lib/components/PlaylistCard.svelte';
	import { SAMPLE_PLAYLIST } from '#lib/config.ts';
	import { playGame, playPlaylist } from '#lib/nav.ts';
	import { playlist as deezerPlaylist } from '#lib/sources/deezer.ts';
	import { ALL, library } from '#lib/store/library.svelte.ts';
	import { toasts } from '#lib/toast.svelte.ts';
	import { plural } from '#lib/util.ts';

	const SOURCE = { spotify: 'From Spotify', deezer: 'From Deezer', built: 'Made here' } as const;

	const playlists = $derived(library.data.playlists);
	const mixes = $derived(library.mixes);
	const last = $derived.by(() => {
		const g = library.currentGame;
		return g && library.pool(g, ALL).length > 0 ? g : undefined;
	});

	const ways: { icon: IconName; title: string; text: string; href: string }[] = [
		{
			icon: 'file',
			title: 'From Spotify',
			text: 'Export it as a file with Exportify, then drop it in.',
			href: resolve('/import')
		},
		{ icon: 'link', title: 'From Deezer', text: 'Paste a playlist or album link.', href: resolve('/import') },
		{
			icon: 'plus',
			title: 'Make One Here',
			text: 'Search for songs and add them.',
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

{#if playlists.length === 0}
	<PageHead title="Playlists" />
	<section class="empty">
		<div class="empty-art"><Logo size={56} /></div>
		<h2>No Playlists Yet</h2>
		<p class="muted">Every playlist you add becomes its own song guessing game.</p>
		<ul class="group ways">
			{#each ways as w (w.title)}
				<li>
					<a class="way" href={w.href}>
						<span class="way-icon"><Icon name={w.icon} size={18} /></span>
						<span class="way-text">
							<span class="way-title">{w.title}</span>
							<span class="muted">{w.text}</span>
						</span>
						<Icon name="chevron-right" size={16} />
					</a>
				</li>
			{/each}
		</ul>
		<button class="btn quiet" type="button" disabled={loadingSample} onclick={trySample}>
			<Icon name="sparkle" size={16} />
			{loadingSample ? 'Loading…' : `Try Deezer's ${SAMPLE_PLAYLIST.name}`}
		</button>
	</section>
{:else}
	<PageHead title="Playlists" sub="Press a playlist to play it.">
		{#snippet actions()}
			<a class="btn" href={resolve('/import')}><Icon name="plus" size={16} weight={2.2} /> Add Playlist</a>
		{/snippet}
	</PageHead>

	{#if last}
		<button class="jump rise" type="button" onclick={() => playGame(last)}>
			<span class="jump-art"><Mosaic songs={library.songsOf(last.playlistIds, 4)} seed={last.id} radius="var(--r-sm)" /></span>
			<span class="jump-text">
				<span class="eyebrow">Jump Back In</span>
				<span class="jump-name">{last.name}</span>
			</span>
			<span class="jump-play" aria-hidden="true"><Icon name="play" size={16} /></span>
		</button>
	{/if}

	<section>
		<h2 class="section-title">All Playlists</h2>
		<div class="grid">
			{#each playlists as p, i (p.id)}
				<PlaylistCard
					title={p.name}
					meta="{plural(p.songIds.length, 'song')} · {SOURCE[p.source]}"
					tag={p.unmatched.length ? `${p.unmatched.length} to check` : undefined}
					songs={library.songsOf([p.id], 8)}
					seed={p.id}
					href={resolve('/playlists/[id]', { id: p.id })}
					index={i}
					onplay={() => (p.songIds.length ? playPlaylist(p) : toasts.show('Add some songs to this playlist first'))}
				/>
			{/each}
		</div>
	</section>

	{#if playlists.length > 1}
		<section>
			<div class="section-head">
				<h2 class="section-title">Mixes</h2>
				<a class="btn small quiet" href={resolve('/games/[id]', { id: 'new' })}>
					<Icon name="plus" size={14} weight={2.2} /> New Mix
				</a>
			</div>
			{#if mixes.length === 0}
				<p class="muted note">Put several playlists in one game, each with its own tab.</p>
			{:else}
				<div class="grid">
					{#each mixes as g, i (g.id)}
						<PlaylistCard
							title={g.name}
							meta="{g.playlistIds.length} playlists · {plural(library.pool(g, ALL).length, 'song')}"
							songs={library.songsOf(g.playlistIds, 8)}
							seed={g.id}
							href={resolve('/games/[id]', { id: g.id })}
							stacked
							index={i}
							onplay={() => playGame(g)}
						/>
					{/each}
				</div>
			{/if}
		</section>
	{/if}
{/if}

<style>
	section + section {
		margin-top: 40px;
	}

	.section-head {
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: 12px;
		margin-bottom: 14px;
	}

	.section-title {
		margin-bottom: 14px;
		font-size: var(--fs-xl);
	}

	.section-head .section-title {
		margin-bottom: 0;
	}

	.note {
		font-size: var(--fs-sm);
	}

	.grid {
		display: grid;
		grid-template-columns: repeat(auto-fill, minmax(150px, 1fr));
		gap: 28px 20px;
	}

	@media (min-width: 900px) {
		.grid {
			grid-template-columns: repeat(auto-fill, minmax(180px, 1fr));
		}
	}

	/* Jump Back In: a wide row, like Apple Music's Up Next card */
	.jump {
		display: flex;
		align-items: center;
		gap: 14px;
		width: min(440px, 100%);
		margin-bottom: 36px;
		padding: 10px 14px 10px 10px;
		border: 0;
		border-radius: var(--r-lg);
		background: var(--surface);
		text-align: left;
		transition:
			background-color var(--t-fast),
			transform var(--t-fast) var(--ease-out);
	}

	.jump:hover {
		background: var(--surface-2);
	}

	.jump:active {
		transform: scale(0.99);
	}

	.jump-art {
		width: 52px;
		flex: none;
		border-radius: var(--r-sm);
		box-shadow: var(--shadow-card);
	}

	.jump-text {
		display: grid;
		flex: 1;
		min-width: 0;
	}

	.jump-name {
		overflow: hidden;
		font-size: var(--fs-lg);
		font-weight: 600;
		text-overflow: ellipsis;
		white-space: nowrap;
	}

	.jump-play {
		display: grid;
		flex: none;
		place-items: center;
		width: 34px;
		height: 34px;
		border-radius: var(--r-full);
		background: var(--accent);
		color: var(--accent-ink);
		transition: transform var(--t-med) var(--ease-pop);
	}

	.jump:hover .jump-play {
		transform: scale(1.08);
	}

	/* Empty library */
	.empty {
		display: grid;
		justify-items: center;
		gap: 10px;
		max-width: 460px;
		margin: 24px auto 0;
		text-align: center;
	}

	.empty-art {
		display: grid;
		place-items: center;
		width: 96px;
		height: 96px;
		margin-bottom: 6px;
		border-radius: 22px;
		background: var(--surface);
		box-shadow: var(--shadow-card);
	}

	.empty h2 {
		font-size: var(--fs-xl);
	}

	.ways {
		width: 100%;
		margin: 16px 0 8px;
		text-align: left;
	}

	.way {
		display: flex;
		align-items: center;
		gap: 12px;
		padding: 12px 14px;
		color: var(--fg-3);
		text-decoration: none;
		transition: background-color var(--t-fast);
	}

	.way:hover {
		background: var(--fill-3);
	}

	.way-icon {
		display: grid;
		flex: none;
		place-items: center;
		width: 30px;
		height: 30px;
		border-radius: 7px;
		background: var(--accent);
		color: var(--accent-ink);
	}

	.way-text {
		display: grid;
		flex: 1;
		min-width: 0;
		font-size: var(--fs-sm);
	}

	.way-title {
		color: var(--fg);
		font-size: var(--fs-md);
		font-weight: 600;
	}
</style>
