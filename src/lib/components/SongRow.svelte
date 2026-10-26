<script lang="ts">
	import type { Snippet } from 'svelte';
	import type { Song } from '#lib/game/types.ts';
	import { coverUrl } from '#lib/util.ts';
	import Icon from './Icon.svelte';

	/** A song in a list: number (optional), artwork, title and artist, then any controls. */
	let { song, index, end }: { song: Song; index?: number; end?: Snippet } = $props();
	const cover = $derived(coverUrl(song));
</script>

<div class="row">
	{#if index !== undefined}<span class="index">{index}</span>{/if}
	{#if cover}
		<img src={cover} alt="" width="36" height="36" loading="lazy" />
	{:else}
		<span class="cover"><Icon name="music" size={16} /></span>
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
		min-height: 52px;
		padding: 7px 10px 7px 14px;
		transition: background-color var(--t-fast);
	}

	.row:hover {
		background: var(--fill-3);
	}

	.index {
		width: 22px;
		flex: none;
		color: var(--fg-3);
		font-size: var(--fs-sm);
		font-variant-numeric: tabular-nums;
		text-align: right;
	}

	img,
	.cover {
		flex: none;
		width: 36px;
		height: 36px;
		border-radius: 5px;
		object-fit: cover;
		background: var(--fill-2);
	}

	.cover {
		display: grid;
		place-items: center;
		color: var(--fg-3);
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
		font-size: var(--fs-md);
		font-weight: 500;
	}

	.artist {
		color: var(--fg-3);
		font-size: var(--fs-sm);
	}

	.end {
		display: flex;
		flex: none;
		align-items: center;
		gap: 6px;
	}
</style>
