<script lang="ts">
	import Icon from '#lib/components/Icon.svelte';

	let {
		playing,
		loading,
		label,
		onclick
	}: { playing: boolean; loading: boolean; label: string; onclick: () => void } = $props();
</script>

<div class="wrap" class:playing>
	<span class="ring" aria-hidden="true"></span>
	<span class="ring late" aria-hidden="true"></span>
	<button type="button" class="play" aria-label={playing ? 'Stop' : label} aria-busy={loading} {onclick}>
		{#if loading}
			<span class="spinner" aria-hidden="true"></span>
		{:else if playing}
			<span class="eq" aria-hidden="true"><i></i><i></i><i></i><i></i></span>
		{:else}
			<Icon name="play" size={30} />
		{/if}
	</button>
</div>

<style>
	.wrap {
		position: relative;
		display: grid;
		place-items: center;
		width: 72px;
		height: 72px;
		margin: 32px auto 0;
	}

	.play {
		position: relative;
		z-index: 1;
		display: grid;
		place-items: center;
		width: 72px;
		height: 72px;
		border: 0;
		border-radius: var(--r-full);
		background: var(--accent);
		color: var(--accent-ink);
		box-shadow: 0 10px 30px rgb(255 224 66 / 0.18);
		transition:
			background-color var(--t-fast),
			box-shadow var(--t-med),
			transform var(--t-med) var(--ease-pop);
	}

	.play :global(svg) {
		margin-left: 4px;
	}

	.play:hover {
		background: var(--accent-hover);
		box-shadow: 0 12px 40px var(--accent-glow);
		transform: scale(1.05);
	}

	.play:active {
		transform: scale(0.94);
	}

	/* While a clip plays, two rings ripple outwards. */
	.ring {
		position: absolute;
		inset: 0;
		border: 2px solid var(--accent);
		border-radius: var(--r-full);
		opacity: 0;
		pointer-events: none;
	}

	.playing .ring {
		animation: ripple 1.4s var(--ease-out) infinite;
	}

	.playing .ring.late {
		animation-delay: 0.7s;
	}

	@keyframes ripple {
		from {
			opacity: 0.55;
			transform: scale(1);
		}
		to {
			opacity: 0;
			transform: scale(1.7);
		}
	}

	.eq {
		display: flex;
		align-items: flex-end;
		gap: 3px;
		height: 24px;
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

	.spinner {
		width: 26px;
		height: 26px;
		border: 3px solid rgb(28 24 0 / 0.25);
		border-top-color: var(--accent-ink);
		border-radius: var(--r-full);
		animation: spin 0.8s linear infinite;
	}

	@keyframes spin {
		to {
			transform: rotate(360deg);
		}
	}

	@media (prefers-reduced-motion: reduce) {
		.playing .ring {
			animation: none;
			opacity: 0.4;
			transform: scale(1.25);
		}

		.playing .ring.late {
			opacity: 0;
		}

		.eq i {
			animation: none;
			transform: scaleY(0.7);
		}
	}
</style>
