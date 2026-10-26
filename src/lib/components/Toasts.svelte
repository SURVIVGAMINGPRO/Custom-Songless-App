<script lang="ts">
	import { toasts } from '#lib/toast.svelte.ts';
	import { fly } from 'svelte/transition';
</script>

<div class="toasts" role="status" aria-live="polite">
	{#each toasts.items as t (t.id)}
		<div class="toast" class:error={t.kind === 'error'} transition:fly={{ y: 16, duration: 250 }}>
			{t.text}
		</div>
	{/each}
</div>

<style>
	.toasts {
		position: fixed;
		left: 50%;
		bottom: 24px;
		z-index: 50;
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 8px;
		width: max-content;
		max-width: calc(100vw - 32px);
		transform: translateX(-50%);
		pointer-events: none;
	}

	/* A HUD capsule, as macOS shows for volume and copy confirmations. */
	.toast {
		padding: 10px 18px;
		border-radius: var(--r-full);
		background: var(--material);
		-webkit-backdrop-filter: saturate(180%) blur(24px);
		backdrop-filter: saturate(180%) blur(24px);
		color: var(--fg);
		font-size: var(--fs-sm);
		font-weight: 500;
		box-shadow: var(--shadow-pop);
	}

	.error {
		color: var(--bad);
	}
</style>
