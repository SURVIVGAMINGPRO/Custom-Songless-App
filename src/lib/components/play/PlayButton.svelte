<script lang="ts">
	import Icon from '#lib/components/Icon.svelte';

	let {
		playing,
		loading,
		label,
		onclick
	}: { playing: boolean; loading: boolean; label: string; onclick: () => void } = $props();
</script>

<button type="button" class="play" class:playing aria-label={playing ? 'Stop' : label} aria-busy={loading} {onclick}>
	{#if loading}
		<span class="spinner" aria-hidden="true">
			{#each { length: 8 }, i (i)}<i style:--k={i}></i>{/each}
		</span>
	{:else if playing}
		<span class="eq" aria-hidden="true"><i></i><i></i><i></i><i></i></span>
	{:else}
		<Icon name="play" size={28} />
	{/if}
</button>

<style>
	.play {
		display: grid;
		place-items: center;
		width: 64px;
		height: 64px;
		margin: 0 auto;
		border: 0;
		border-radius: var(--r-full);
		background: var(--accent);
		color: var(--accent-ink);
		box-shadow: 0 4px 14px color-mix(in srgb, var(--accent) 35%, transparent);
		transition:
			background-color var(--t-fast),
			transform var(--t-med) var(--ease-pop),
			box-shadow var(--t-med);
	}

	.play :global(svg) {
		margin-left: 3px;
	}

	.play:hover {
		background: var(--accent-hover);
		transform: scale(1.04);
	}

	.play:active {
		transform: scale(0.94);
	}

	.playing {
		box-shadow: 0 6px 22px color-mix(in srgb, var(--accent) 50%, transparent);
	}

	/* Now-playing bars, as in Apple Music */
	.eq {
		display: flex;
		align-items: flex-end;
		gap: 3px;
		height: 22px;
	}

	.eq i {
		width: 4px;
		height: 100%;
		border-radius: 2px;
		background: currentColor;
		transform-origin: bottom;
		animation: bounce 0.9s ease-in-out infinite;
	}

	.eq i:nth-child(2) {
		animation-delay: -0.3s;
	}

	.eq i:nth-child(3) {
		animation-delay: -0.6s;
	}

	.eq i:nth-child(4) {
		animation-delay: -0.15s;
	}

	@keyframes bounce {
		0%,
		100% {
			transform: scaleY(0.3);
		}
		50% {
			transform: scaleY(1);
		}
	}

	/* Apple-style activity indicator: eight spokes fading in turn */
	.spinner {
		position: relative;
		width: 24px;
		height: 24px;
	}

	.spinner i {
		position: absolute;
		top: 0;
		left: 50%;
		width: 3px;
		height: 7px;
		margin-left: -1.5px;
		border-radius: 2px;
		background: currentColor;
		transform: rotate(calc(var(--k) * 45deg));
		transform-origin: 1.5px 12px;
		animation: spoke 0.8s linear infinite;
		animation-delay: calc(var(--k) * 0.1s - 0.8s);
	}

	@keyframes spoke {
		from {
			opacity: 1;
		}
		to {
			opacity: 0.2;
		}
	}

	@media (prefers-reduced-motion: reduce) {
		.eq i {
			animation: none;
			transform: scaleY(0.7);
		}

		.spinner i {
			animation: none;
			opacity: calc(0.2 + var(--k) * 0.1);
		}
	}
</style>
