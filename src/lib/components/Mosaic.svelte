<script lang="ts">
	import { hash } from '#lib/game/deck.ts';
	import type { Song } from '#lib/game/types.ts';
	import { coverUrl } from '#lib/util.ts';
	import Logo from './Logo.svelte';

	/** A playlist's artwork: four album covers, one cover, or a colour field with the logo. */
	let { songs, seed, radius = 'var(--r-md)' }: { songs: Song[]; seed: string; radius?: string } = $props();

	const covers = $derived.by(() => {
		const urls: string[] = [];
		for (const s of songs) {
			const url = coverUrl(s);
			if (url && !urls.includes(url)) urls.push(url);
			if (urls.length === 4) break;
		}
		return urls.length >= 4 ? urls : urls.slice(0, 1);
	});
	const hue = $derived(hash(seed) % 360);
</script>

<div
	class="mosaic"
	class:quad={covers.length === 4}
	style:border-radius={radius}
	style:--h={hue}
	aria-hidden="true"
>
	{#if covers.length}
		{#each covers as url (url)}
			<img src={url} alt="" loading="lazy" draggable="false" />
		{/each}
	{:else}
		<span class="blank"><Logo size={40} /></span>
	{/if}
</div>

<style>
	.mosaic {
		display: grid;
		width: 100%;
		aspect-ratio: 1;
		overflow: hidden;
		background: var(--surface-2);
	}

	.quad {
		grid-template-columns: repeat(2, minmax(0, 1fr));
		grid-template-rows: repeat(2, minmax(0, 1fr));
	}

	img {
		width: 100%;
		height: 100%;
		min-height: 0;
		object-fit: cover;
		transition: transform var(--t-slow) var(--ease-out);
	}

	.blank {
		display: grid;
		place-items: center;
		background:
			radial-gradient(circle at 30% 20%, hsl(calc(var(--h) * 1deg) 70% 45% / 0.55), transparent 60%),
			linear-gradient(135deg, hsl(calc(var(--h) * 1deg) 45% 22%), hsl(calc((var(--h) + 50) * 1deg) 50% 12%));
	}

	.blank :global(.logo) {
		width: 36%;
		height: 36%;
		opacity: 0.9;
	}
</style>
