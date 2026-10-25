<script lang="ts">
	import Icon from '#lib/components/Icon.svelte';

	let {
		steps,
		unlocked,
		position,
		label
	}: {
		/** Where each clip ends, in seconds. */
		steps: number[];
		/** Index of the longest clip the player may hear. */
		unlocked: number;
		/** Seconds played of the current clip. */
		position: number;
		label: string;
	} = $props();

	const total = $derived(steps[steps.length - 1]);
	const segments = $derived(
		steps.map((end, i) => {
			const start = i === 0 ? 0 : steps[i - 1];
			return { start, grow: end - start };
		})
	);
	/** The end of the unlocked clip, as a share of the bar. */
	const at = $derived((steps[Math.min(unlocked, steps.length - 1)] / total) * 100);
</script>

<div class="timeline" style:--at="{at}%">
	<p class="label">{label}</p>
	<span class="tri"><Icon name="marker" size={20} /></span>
	<div
		class="bar"
		role="progressbar"
		aria-label="Clip progress"
		aria-valuemin={0}
		aria-valuemax={total}
		aria-valuenow={Number(position.toFixed(1))}
	>
		{#each segments as seg, i (i)}
			{@const fill = Math.min(1, Math.max(0, (position - seg.start) / seg.grow))}
			<div class="seg" class:open={i <= unlocked} style:flex-grow={seg.grow}>
				<div class="fill" style:transform="scaleX({fill})"></div>
			</div>
		{/each}
	</div>
</div>

<style>
	.timeline {
		/* How far the label may hang past the ends of the bar. */
		--room: 12px;
		--label-w: 128px;
		position: relative;
		margin-top: 72px;
	}

	@media (min-width: 900px) {
		.timeline {
			--room: 120px;
		}
	}

	.label {
		position: absolute;
		bottom: calc(100% + 16px);
		left: clamp(calc(-1 * var(--room)), calc(var(--at) - var(--label-w) / 2), calc(100% - var(--label-w) + var(--room)));
		width: var(--label-w);
		font-family: var(--font-display);
		font-size: 18px;
		font-weight: 700;
		line-height: 27px;
		text-align: center;
		white-space: nowrap;
		transition: left var(--t-slow) var(--ease-out);
	}

	.tri {
		position: absolute;
		bottom: calc(100% - 4px);
		left: var(--at);
		display: flex;
		transform: translateX(-50%);
		color: var(--fg);
		transition: left var(--t-slow) var(--ease-out);
	}

	.bar {
		display: flex;
		gap: 3px;
		height: 22px;
	}

	.seg {
		position: relative;
		flex-basis: 0;
		min-width: 5px;
		overflow: hidden;
		border-radius: 3px;
		background: var(--surface-2);
		transition: background-color var(--t-med);
	}

	.seg:first-child {
		border-radius: var(--r-full) 3px 3px var(--r-full);
	}

	.seg:last-child {
		border-radius: 3px var(--r-full) var(--r-full) 3px;
	}

	.seg.open {
		background: var(--line-strong);
	}

	.fill {
		position: absolute;
		inset: 0;
		background: var(--accent);
		transform-origin: left;
	}

	@media (prefers-reduced-motion: reduce) {
		.label,
		.tri {
			transition: none;
		}
	}
</style>
