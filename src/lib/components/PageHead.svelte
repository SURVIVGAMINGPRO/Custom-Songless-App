<script lang="ts">
	import type { Snippet } from 'svelte';
	import { APP_NAME } from '#lib/config.ts';

	let { title, sub, actions }: { title: string; sub?: string; actions?: Snippet } = $props();
</script>

<svelte:head>
	<title>{title} · {APP_NAME}</title>
</svelte:head>

<div class="head">
	<div class="titles">
		<h1>{title}</h1>
		{#if sub}<p class="muted">{sub}</p>{/if}
	</div>
	{#if actions}
		<div class="actions">{@render actions()}</div>
	{/if}
</div>

<style>
	.head {
		display: flex;
		flex-wrap: wrap;
		align-items: flex-end;
		justify-content: space-between;
		gap: 16px;
		margin: 32px 0 24px;
	}

	.titles {
		min-width: 0;
	}

	h1 {
		font-size: 32px;
		letter-spacing: -0.01em;
		overflow-wrap: anywhere;
	}

	.muted {
		margin-top: 4px;
		font-size: 14px;
	}

	.actions {
		display: flex;
		flex-wrap: wrap;
		gap: 8px;
	}
</style>
