<script lang="ts">
	let {
		steps,
		unlocked,
		position,
		label,
		detail
	}: {
		/** Where each clip ends, in seconds. */
		steps: number[];
		/** Index of the longest clip the player may hear. */
		unlocked: number;
		/** Seconds played of the current clip. */
		position: number;
		/** The clip length, like "0.1 seconds". */
		label: string;
		/** Right-hand note, like "Try 1 of 5". */
		detail: string;
	} = $props();

	const total = $derived(steps[steps.length - 1]);
	const segments = $derived(
		steps.map((end, i) => {
			const start = i === 0 ? 0 : steps[i - 1];
			return { start, grow: end - start };
		})
	);
</script>

<div class="timeline">
	<div class="labels">
		<p class="clip">{label}</p>
		<p class="detail">{detail}</p>
	</div>
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
	.labels {
		display: flex;
		align-items: baseline;
		justify-content: space-between;
		gap: 12px;
		margin-bottom: 8px;
	}

	.clip {
		font-family: var(--font-rounded);
		font-size: var(--fs-lg);
		font-weight: 700;
		letter-spacing: -0.01em;
		font-variant-numeric: tabular-nums;
	}

	.detail {
		color: var(--fg-3);
		font-size: var(--fs-sm);
		font-variant-numeric: tabular-nums;
	}

	.bar {
		display: flex;
		gap: 3px;
		height: 8px;
	}

	.seg {
		position: relative;
		flex-basis: 0;
		min-width: 6px;
		overflow: hidden;
		border-radius: 2px;
		background: var(--fill-3);
		transition: background-color var(--t-med);
	}

	.seg:first-child {
		border-radius: var(--r-full) 2px 2px var(--r-full);
	}

	.seg:last-child {
		border-radius: 2px var(--r-full) var(--r-full) 2px;
	}

	.seg.open {
		background: var(--fill);
	}

	.fill {
		position: absolute;
		inset: 0;
		background: var(--accent);
		transform-origin: left;
	}
</style>
