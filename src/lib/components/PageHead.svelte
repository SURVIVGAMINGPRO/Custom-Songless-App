<script lang="ts">
	import type { Snippet } from 'svelte';
	import { APP_NAME } from '#lib/config.ts';

	/** A large title, as at the top of Apple's apps. */
	let { title, sub, actions }: { title: string; sub?: string; actions?: Snippet } = $props();
</script>

<svelte:head>
	<title>{title} · {APP_NAME}</title>
</svelte:head>

<header class="head">
	<div class="titles">
		<h1>{title}</h1>
		{#if sub}<p class="sub">{sub}</p>{/if}
	</div>
	{#if actions}
		<div class="actions">{@render actions()}</div>
	{/if}
</header>

<style>
	.head {
		display: flex;
		flex-wrap: wrap;
		align-items: flex-end;
		justify-content: space-between;
		gap: 12px 16px;
		margin: 12px 0 24px;
	}

	.titles {
		min-width: 0;
	}

	h1 {
		font-size: var(--fs-hero);
		letter-spacing: -0.025em;
		overflow-wrap: anywhere;
	}

	.sub {
		margin-top: 4px;
		color: var(--fg-3);
		font-size: var(--fs-md);
	}

	.actions {
		display: flex;
		flex-wrap: wrap;
		gap: 8px;
	}
</style>
