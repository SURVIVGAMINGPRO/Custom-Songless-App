<script lang="ts">
	import { toasts } from '#lib/toast.svelte.ts';
	import { fly } from 'svelte/transition';
</script>

<div class="toasts" role="status" aria-live="polite">
	{#each toasts.items as t (t.id)}
		<div class="toast" class:error={t.kind === 'error'} transition:fly={{ y: 12, duration: 220 }}>
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

	.toast {
		padding: 10px 16px;
		border: 1px solid var(--line-strong);
		border-radius: var(--r-md);
		background: var(--surface-2);
		color: var(--fg);
		font-size: 14px;
		box-shadow: 0 12px 32px rgb(0 0 0 / 0.4);
	}

	.error {
		border-color: var(--bad);
	}
</style>
