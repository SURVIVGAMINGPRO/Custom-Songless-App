<script lang="ts">
	import { resolve } from '$app/paths';
	import { page } from '$app/state';
	import { APP_NAME } from '#lib/config.ts';
	import { library } from '#lib/store/library.svelte.ts';
	import { coverUrl } from '#lib/util.ts';
	import Icon, { type IconName } from './Icon.svelte';
	import Logo from './Logo.svelte';

	/** On narrow windows the sidebar slides over the content; `open` shows it. */
	let { open = $bindable(false) }: { open?: boolean } = $props();

	const route = $derived(page.route.id ?? '');
	const param = $derived(page.params.id ?? '');
	/** On the play screen, light up the playlist or mix being played. */
	const playing = $derived(route === '/play/[id]' ? library.game(param) : undefined);

	const main: { href: string; label: string; icon: IconName; route: string }[] = [
		{ href: resolve('/'), label: 'Playlists', icon: 'library', route: '/' },
		{ href: resolve('/import'), label: 'Add Playlist', icon: 'plus-circle', route: '/import' },
		{ href: resolve('/stats'), label: 'Stats', icon: 'chart', route: '/stats' }
	];

	function isPlaylist(id: string): boolean {
		if (route === '/playlists/[id]') return param === id;
		return !!playing && playing.playlistIds.length === 1 && playing.playlistIds[0] === id;
	}

	function isMix(id: string): boolean {
		return (route === '/games/[id]' && param === id) || playing?.id === id;
	}

	function cover(playlistId: string): string | null {
		for (const sid of library.playlist(playlistId)?.songIds.slice(0, 6) ?? []) {
			const url = coverUrl(library.song(sid));
			if (url) return url;
		}
		return null;
	}
</script>

<nav class="sidebar" class:open aria-label="Sidebar">
	<div class="titlebar" data-tauri-drag-region></div>

	<a class="brand" href={resolve('/')} onclick={() => (open = false)}>
		<Logo size={22} />
		<span>{APP_NAME}</span>
	</a>

	<ul>
		{#each main as item (item.href)}
			<li>
				<a
					class="item"
					href={item.href}
					aria-current={route === item.route ? 'page' : undefined}
					onclick={() => (open = false)}
				>
					<span class="glyph"><Icon name={item.icon} size={18} /></span>
					<span class="text">{item.label}</span>
				</a>
			</li>
		{/each}
	</ul>

	{#if library.data.playlists.length}
		<p class="section">Playlists</p>
		<ul>
			{#each library.data.playlists as p (p.id)}
				{@const art = cover(p.id)}
				<li>
					<a
						class="item"
						href={resolve('/playlists/[id]', { id: p.id })}
						aria-current={isPlaylist(p.id) ? 'page' : undefined}
						onclick={() => (open = false)}
					>
						{#if art}
							<img class="mini" src={art} alt="" width="20" height="20" loading="lazy" />
						{:else}
							<span class="glyph"><Icon name="music" size={17} /></span>
						{/if}
						<span class="text">{p.name}</span>
					</a>
				</li>
			{/each}
		</ul>
	{/if}

	{#if library.data.playlists.length > 1}
		<p class="section">Mixes</p>
		<ul>
			{#each library.mixes as g (g.id)}
				<li>
					<a
						class="item"
						href={resolve('/play/[id]', { id: g.id })}
						aria-current={isMix(g.id) ? 'page' : undefined}
						onclick={() => (open = false)}
					>
						<span class="glyph"><Icon name="layers" size={17} /></span>
						<span class="text">{g.name}</span>
					</a>
				</li>
			{/each}
			<li>
				<a
					class="item dim"
					href={resolve('/games/[id]', { id: 'new' })}
					aria-current={route === '/games/[id]' && param === 'new' ? 'page' : undefined}
					onclick={() => (open = false)}
				>
					<span class="glyph"><Icon name="plus" size={17} /></span>
					<span class="text">New Mix</span>
				</a>
			</li>
		</ul>
	{/if}

	<div class="foot">
		<a
			class="item"
			href={resolve('/settings')}
			aria-current={route === '/settings' ? 'page' : undefined}
			onclick={() => (open = false)}
		>
			<span class="glyph"><Icon name="settings" size={18} /></span>
			<span class="text">Settings</span>
		</a>
	</div>
</nav>

<style>
	.sidebar {
		position: sticky;
		top: 0;
		display: flex;
		flex-direction: column;
		height: 100dvh;
		padding: 0 10px 10px;
		overflow-y: auto;
		border-right: 0.5px solid var(--line-strong);
		background: var(--sidebar);
		-webkit-backdrop-filter: saturate(180%) blur(30px);
		backdrop-filter: saturate(180%) blur(30px);
		scrollbar-width: thin;
	}

	.titlebar {
		flex: none;
		height: max(var(--titlebar), 10px);
	}

	.brand {
		display: flex;
		align-items: center;
		gap: 8px;
		margin: 4px 0 14px;
		padding: 6px 10px;
		border-radius: var(--r-sm);
		font-family: var(--font-display);
		font-size: var(--fs-lg);
		font-weight: 700;
		letter-spacing: -0.02em;
		text-decoration: none;
	}

	ul {
		display: grid;
		gap: 1px;
		margin: 0;
		padding: 0;
		list-style: none;
	}

	.section {
		margin: 18px 10px 4px;
		color: var(--fg-3);
		font-size: var(--fs-xs);
		font-weight: 600;
	}

	.item {
		display: flex;
		align-items: center;
		gap: 9px;
		min-height: 30px;
		padding: 4px 10px;
		border-radius: var(--r-sm);
		color: var(--fg);
		font-size: var(--fs-sm);
		font-weight: 500;
		text-decoration: none;
		transition: background-color var(--t-fast);
	}

	.item:hover {
		background: var(--fill-3);
	}

	.item[aria-current='page'] {
		background: var(--fill);
	}

	.item.dim {
		color: var(--fg-3);
	}

	.glyph {
		display: grid;
		flex: none;
		place-items: center;
		width: 20px;
		height: 20px;
		color: var(--accent-text);
	}

	.dim .glyph {
		color: var(--fg-3);
	}

	.mini {
		flex: none;
		width: 20px;
		height: 20px;
		border-radius: 4px;
		object-fit: cover;
	}

	.text {
		min-width: 0;
		overflow: hidden;
		text-overflow: ellipsis;
		white-space: nowrap;
	}

	.foot {
		margin-top: auto;
		padding-top: 12px;
	}

	/* Narrow windows: the sidebar slides in over the content. */
	@media (max-width: 759px) {
		.sidebar {
			position: fixed;
			inset: 0 auto 0 0;
			z-index: 40;
			width: min(280px, 84vw);
			border-right: 0;
			box-shadow: var(--shadow-pop);
			transform: translateX(-104%);
			transition: transform var(--t-med) var(--ease-out);
			visibility: hidden;
		}

		.sidebar.open {
			transform: none;
			visibility: visible;
		}
	}

	@media (max-width: 759px) and (prefers-reduced-motion: no-preference) {
		.sidebar {
			transition:
				transform var(--t-med) var(--ease-out),
				visibility 0s linear var(--t-med);
		}

		.sidebar.open {
			transition: transform var(--t-med) var(--ease-out);
		}
	}
</style>
