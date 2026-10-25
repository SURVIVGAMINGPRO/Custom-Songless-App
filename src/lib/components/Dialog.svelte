<script lang="ts">
	import type { Snippet } from 'svelte';
	import Icon from './Icon.svelte';

	let {
		open = $bindable(false),
		title,
		variant = 'center',
		children,
		actions
	}: {
		open?: boolean;
		title: string;
		variant?: 'center' | 'drawer';
		children: Snippet;
		actions?: Snippet;
	} = $props();

	const uid = $props.id();
	let dialog: HTMLDialogElement;

	$effect(() => {
		if (open && !dialog.open) dialog.showModal();
		else if (!open && dialog.open) dialog.close();
	});
</script>

<!-- Clicking the backdrop (the dialog element itself, outside its panel) closes it. -->
<!-- svelte-ignore a11y_click_events_have_key_events, a11y_no_noninteractive_element_interactions -->
<dialog
	bind:this={dialog}
	class={variant}
	aria-labelledby="{uid}-title"
	onclose={() => (open = false)}
	onclick={(e) => {
		if (e.target === dialog) open = false;
	}}
>
	<div class="panel">
		<header>
			<h2 id="{uid}-title">{title}</h2>
			<button class="close" type="button" aria-label="Close" onclick={() => (open = false)}>
				<Icon name="x" size={20} />
			</button>
		</header>
		<div class="body">
			{@render children()}
		</div>
		{#if actions}
			<footer>{@render actions()}</footer>
		{/if}
	</div>
</dialog>

<style>
	dialog {
		padding: 0;
		border: 0;
		background: transparent;
		color: var(--fg);
		max-width: none;
		max-height: none;
		overflow: visible;
		opacity: 0;
		transition:
			opacity var(--t-med) var(--ease-out),
			transform var(--t-med) var(--ease-out),
			overlay var(--t-med) allow-discrete,
			display var(--t-med) allow-discrete;
	}

	dialog[open] {
		opacity: 1;
		transform: none;
	}

	dialog::backdrop {
		background: rgb(0 0 0 / 0);
		transition:
			background var(--t-med),
			overlay var(--t-med) allow-discrete,
			display var(--t-med) allow-discrete;
	}

	dialog[open]::backdrop {
		background: var(--scrim);
	}

	@starting-style {
		dialog[open] {
			opacity: 0;
		}
		dialog[open]::backdrop {
			background: rgb(0 0 0 / 0);
		}
	}

	.center {
		width: min(440px, calc(100vw - 2 * var(--gutter)));
		margin: auto;
		transform: translateY(8px) scale(0.98);
	}

	@starting-style {
		.center[open] {
			transform: translateY(8px) scale(0.98);
		}
	}

	.drawer {
		width: min(320px, 86vw);
		height: 100dvh;
		margin: 0;
		transform: translateX(-24px);
	}

	@starting-style {
		.drawer[open] {
			transform: translateX(-24px);
		}
	}

	.panel {
		display: flex;
		flex-direction: column;
		max-height: calc(100dvh - 48px);
		border: 1px solid var(--line);
		border-radius: var(--r-xl);
		background: var(--surface);
		box-shadow: 0 24px 64px rgb(0 0 0 / 0.5);
	}

	.drawer .panel {
		height: 100%;
		max-height: none;
		border-width: 0 1px 0 0;
		border-radius: 0 var(--r-xl) var(--r-xl) 0;
	}

	header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: 12px;
		padding: 16px 16px 8px 24px;
	}

	h2 {
		font-size: 22px;
		font-weight: 600;
	}

	.close {
		display: grid;
		place-items: center;
		width: 36px;
		height: 36px;
		border: 0;
		border-radius: var(--r-full);
		background: transparent;
		color: var(--fg-3);
	}

	.close:hover {
		background: var(--surface-2);
		color: var(--fg);
	}

	.body {
		padding: 8px 24px 24px;
		overflow-y: auto;
	}

	.drawer .body {
		padding: 8px 12px 24px;
		flex: 1;
	}

	footer {
		display: flex;
		justify-content: flex-end;
		gap: 8px;
		padding: 0 24px 24px;
	}

	@media (prefers-reduced-motion: reduce) {
		.center,
		.drawer,
		.center[open],
		.drawer[open] {
			transform: none;
		}
	}
</style>
