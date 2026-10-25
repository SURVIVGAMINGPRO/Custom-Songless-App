<script lang="ts">
	import type { Snippet } from 'svelte';
	import type { Song } from '#lib/game/types.ts';
	import { coverUrl } from '#lib/util.ts';
	import Icon from './Icon.svelte';

	let { song, end }: { song: Song; end?: Snippet } = $props();
	const cover = $derived(coverUrl(song));
</script>

<div class="row">
	{#if cover}
		<img src={cover} alt="" width="40" height="40" loading="lazy" />
	{:else}
		<span class="cover"><Icon name="music" size={18} /></span>
	{/if}
	<div class="names">
		<p class="title">{song.title}</p>
		<p class="artist">{song.artists.join(', ')}</p>
	</div>
	{#if end}<div class="end">{@render end()}</div>{/if}
</div>

<style>
	.row {
		display: flex;
		align-items: center;
		gap: 12px;
		min-height: 56px;
		padding: 8px 12px;
	}

	img,
	.cover {
		flex: none;
		width: 40px;
		height: 40px;
		border-radius: var(--r-sm);
		background: var(--surface-2);
	}

	.cover {
		display: grid;
		place-items: center;
		color: var(--fg-4);
	}

	.names {
		flex: 1;
		min-width: 0;
	}

	.title,
	.artist {
		overflow: hidden;
		text-overflow: ellipsis;
		white-space: nowrap;
	}

	.title {
		font-size: 15px;
		font-weight: 500;
	}

	.artist {
		color: var(--fg-3);
		font-size: 13px;
	}

	.end {
		display: flex;
		flex: none;
		align-items: center;
		gap: 4px;
	}
</style>
