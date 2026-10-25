<script lang="ts">
	let { done, total, label }: { done: number; total: number; label: string } = $props();
	const share = $derived(total > 0 ? done / total : 0);
</script>

<div class="progress">
	<p>{label} <span class="muted">{done.toLocaleString()} of {total.toLocaleString()}</span></p>
	<div class="track" role="progressbar" aria-label={label} aria-valuemin={0} aria-valuemax={total} aria-valuenow={done}>
		<div class="fill" style:transform="scaleX({share})"></div>
	</div>
</div>

<style>
	.progress {
		display: grid;
		gap: 8px;
	}

	p {
		font-size: 14px;
	}

	.track {
		height: 6px;
		overflow: hidden;
		border-radius: var(--r-full);
		background: var(--line);
	}

	.fill {
		height: 100%;
		background: var(--good);
		transform-origin: left;
		transition: transform var(--t-med) var(--ease-out);
	}
</style>
