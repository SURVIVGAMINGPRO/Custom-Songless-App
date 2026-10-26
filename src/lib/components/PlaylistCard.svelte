<script lang="ts">
	import type { Song } from '#lib/game/types.ts';
	import Icon from './Icon.svelte';
	import Mosaic from './Mosaic.svelte';

	/** An artwork tile like Apple Music's: press the art to play, the name to open. */
	let {
		title,
		meta,
		tag,
		songs,
		seed,
		href,
		stacked = false,
		index = 0,
		onplay
	}: {
		title: string;
		meta: string;
		/** A short note under the name, like "3 to check". */
		tag?: string;
		songs: Song[];
		seed: string;
		/** Where the name leads (the playlist page or the mix editor). */
		href: string;
		/** Mixes look like a small stack. */
		stacked?: boolean;
		index?: number;
		onplay: () => void;
	} = $props();
</script>

<article class="tile rise" class:stacked style:--i={index}>
	<div class="art-wrap">
		<button class="art" type="button" onclick={onplay} aria-label="Play {title}">
			<Mosaic {songs} {seed} radius="var(--r-md)" />
			<span class="shade" aria-hidden="true"></span>
			<span class="play" aria-hidden="true"><Icon name="play" size={18} /></span>
		</button>
	</div>
	<a class="name" {href} title={title}>{title}</a>
	<p class="meta">
		{meta}
		{#if tag}<span class="tag">{tag}</span>{/if}
	</p>
</article>

<style>
	.tile {
		display: grid;
		align-content: start;
		gap: 2px;
		min-width: 0;
	}

	.art-wrap {
		position: relative;
		margin-bottom: 8px;
	}

	/* Mixes: two sleeves peek out above the art. */
	.stacked .art-wrap::before,
	.stacked .art-wrap::after {
		content: '';
		position: absolute;
		left: 8%;
		right: 8%;
		height: 10px;
		border-radius: var(--r-md) var(--r-md) 0 0;
		background: var(--surface-3);
	}

	.stacked .art-wrap::before {
		top: -10px;
		left: 14%;
		right: 14%;
		opacity: 0.6;
	}

	.stacked .art-wrap::after {
		top: -5px;
		opacity: 0.9;
	}

	.art {
		position: relative;
		z-index: 1;
		display: block;
		width: 100%;
		padding: 0;
		border: 0;
		border-radius: var(--r-md);
		background: none;
		box-shadow: var(--shadow-art);
		transition: transform var(--t-med) var(--ease-out);
	}

	.art :global(.mosaic) {
		box-shadow: inset 0 0 0 0.5px rgb(0 0 0 / 0.1);
	}

	.shade {
		position: absolute;
		inset: 0;
		border-radius: var(--r-md);
		background: linear-gradient(to top, rgb(0 0 0 / 0.35), transparent 55%);
		opacity: 0;
		transition: opacity var(--t-med) var(--ease-out);
	}

	.play {
		position: absolute;
		left: 10px;
		bottom: 10px;
		display: grid;
		place-items: center;
		width: 36px;
		height: 36px;
		border-radius: var(--r-full);
		background: var(--glass);
		color: var(--glass-ink);
		box-shadow: 0 2px 10px rgb(0 0 0 / 0.25);
		-webkit-backdrop-filter: blur(10px);
		backdrop-filter: blur(10px);
		opacity: 0;
		transform: scale(0.85);
		transition:
			opacity var(--t-med) var(--ease-out),
			transform var(--t-med) var(--ease-pop),
			background-color var(--t-fast);
	}

	.art:hover .shade,
	.art:focus-visible .shade,
	.art:hover .play,
	.art:focus-visible .play {
		opacity: 1;
	}

	.art:hover .play,
	.art:focus-visible .play {
		transform: none;
	}

	.play:hover {
		background: var(--accent);
	}

	.art:active {
		transform: scale(0.98);
	}

	@media (hover: none) {
		.play {
			opacity: 1;
			transform: none;
		}
	}

	.name {
		overflow: hidden;
		font-size: var(--fs-md);
		font-weight: 600;
		text-decoration: none;
		text-overflow: ellipsis;
		white-space: nowrap;
	}

	.name:hover {
		text-decoration: underline;
		text-underline-offset: 2px;
	}

	.meta {
		color: var(--fg-3);
		font-size: var(--fs-sm);
	}

	.tag {
		display: inline-block;
		margin-left: 4px;
		padding: 0 7px;
		border-radius: var(--r-full);
		background: var(--near-wash);
		color: var(--near);
		font-size: var(--fs-xs);
		font-weight: 600;
		line-height: 18px;
	}
</style>
