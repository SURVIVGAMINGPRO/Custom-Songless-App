<script lang="ts">
	import type { Song } from '#lib/game/types.ts';
	import Icon from './Icon.svelte';
	import Mosaic from './Mosaic.svelte';

	let {
		title,
		meta,
		tag,
		songs,
		seed,
		editHref,
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
		editHref: string;
		/** Mixes look like a small stack of records. */
		stacked?: boolean;
		index?: number;
		onplay: () => void;
	} = $props();
</script>

<article class="pcard rise" class:stacked style:--i={index}>
	<button class="cover" type="button" onclick={onplay} aria-label="Play {title}">
		<span class="art"><Mosaic {songs} {seed} /></span>
		<span class="fab" aria-hidden="true"><Icon name="play" size={22} /></span>
	</button>
	<div class="info">
		<div class="names">
			<h3 class="name" title={title}>{title}</h3>
			<p class="meta">
				{meta}
				{#if tag}<span class="tag">{tag}</span>{/if}
			</p>
		</div>
		<a class="icon-btn edit" href={editHref} aria-label="Edit {title}" title="Edit">
			<Icon name="edit" size={18} />
		</a>
	</div>
</article>

<style>
	.pcard {
		display: grid;
		gap: 12px;
		min-width: 0;
	}

	.cover {
		position: relative;
		display: block;
		padding: 0;
		border: 0;
		border-radius: var(--r-lg);
		background: none;
		transition: transform var(--t-med) var(--ease-out);
	}

	.art {
		position: relative;
		z-index: 1;
		display: block;
		overflow: hidden;
		border-radius: var(--r-lg);
		box-shadow: var(--shadow-card);
		transition:
			box-shadow var(--t-med),
			transform var(--t-slow) var(--ease-out);
	}

	/* Mixes: two sleeves peek out behind the art. */
	.stacked .cover::before,
	.stacked .cover::after {
		content: '';
		position: absolute;
		inset: 0;
		border: 1px solid var(--line-lit);
		border-radius: var(--r-lg);
		background: var(--surface-3);
		transition: transform var(--t-slow) var(--ease-out);
	}

	.stacked .cover::before {
		transform: translate(12px, -12px) scale(0.92);
		opacity: 0.55;
	}

	.stacked .cover::after {
		transform: translate(6px, -6px) scale(0.96);
		opacity: 0.85;
	}

	.cover:hover .art,
	.cover:focus-visible .art {
		transform: translateY(-4px) rotate(-1deg);
		box-shadow: 0 20px 40px rgb(0 0 0 / 0.5);
	}

	.stacked .cover:hover::before {
		transform: translate(16px, -14px) scale(0.94) rotate(3deg);
	}

	.stacked .cover:hover::after {
		transform: translate(8px, -8px) scale(0.97) rotate(1.5deg);
	}

	.cover:hover :global(img) {
		transform: scale(1.04);
	}

	.cover:active .art {
		transform: translateY(-1px) scale(0.98);
	}

	.cover:focus-visible {
		outline-offset: 4px;
	}

	.fab {
		position: absolute;
		right: 12px;
		bottom: 12px;
		z-index: 2;
		display: grid;
		place-items: center;
		width: 52px;
		height: 52px;
		border-radius: var(--r-full);
		background: var(--accent);
		color: var(--accent-ink);
		box-shadow: 0 8px 24px rgb(0 0 0 / 0.45);
		opacity: 0;
		transform: translateY(10px) scale(0.85);
		transition:
			opacity var(--t-med) var(--ease-out),
			transform var(--t-med) var(--ease-pop);
	}

	.fab :global(svg) {
		margin-left: 3px;
	}

	.cover:hover .fab,
	.cover:focus-visible .fab {
		opacity: 1;
		transform: none;
	}

	/* Touch screens have no hover: keep the play button showing. */
	@media (hover: none) {
		.fab {
			opacity: 1;
			transform: none;
		}
	}

	.info {
		display: flex;
		align-items: flex-start;
		gap: 4px;
		min-width: 0;
	}

	.names {
		flex: 1;
		min-width: 0;
	}

	.name {
		overflow: hidden;
		font-size: var(--fs-lg);
		font-weight: 700;
		letter-spacing: -0.01em;
		text-overflow: ellipsis;
		white-space: nowrap;
	}

	.meta {
		color: var(--fg-3);
		font-size: var(--fs-sm);
	}

	.tag {
		display: inline-block;
		margin-left: 4px;
		padding: 0 8px;
		border-radius: var(--r-full);
		background: rgb(255 159 69 / 0.14);
		color: var(--near);
		font-size: var(--fs-xs);
		font-weight: 600;
		line-height: 20px;
	}

	.edit {
		width: 34px;
		height: 34px;
		margin-top: -4px;
		color: var(--fg-4);
	}

	.edit:hover {
		color: var(--fg);
	}
</style>
