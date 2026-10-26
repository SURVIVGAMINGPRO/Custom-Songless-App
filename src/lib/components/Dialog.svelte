<script lang="ts">
	import type { Snippet } from 'svelte';
	import Icon from './Icon.svelte';

	/** A sheet in the middle of the window, after macOS alerts and sheets. */
	let {
		open = $bindable(false),
		title,
		children,
		actions
	}: {
		open?: boolean;
		title: string;
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
				<Icon name="x" size={14} weight={2.4} />
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
		width: min(420px, calc(100vw - 32px));
		margin: auto;
		padding: 0;
		border: 0;
		background: transparent;
		color: var(--fg);
		max-height: none;
		overflow: visible;
		opacity: 0;
		transform: scale(1.04);
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
			transform: scale(1.04);
		}
		dialog[open]::backdrop {
			background: rgb(0 0 0 / 0);
		}
	}

	.panel {
		display: flex;
		flex-direction: column;
		max-height: calc(100dvh - 48px);
		border-radius: var(--r-xl);
		background: var(--material);
		-webkit-backdrop-filter: saturate(180%) blur(30px);
		backdrop-filter: saturate(180%) blur(30px);
		box-shadow: var(--shadow-pop);
	}

	header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: 12px;
		padding: 18px 16px 6px 22px;
	}

	h2 {
		font-size: var(--fs-lg);
	}

	.close {
		display: grid;
		place-items: center;
		width: 26px;
		height: 26px;
		border: 0;
		border-radius: var(--r-full);
		background: var(--fill-2);
		color: var(--fg-3);
	}

	.close:hover {
		background: var(--fill);
		color: var(--fg);
	}

	.body {
		padding: 6px 22px 20px;
		overflow-y: auto;
	}

	footer {
		display: flex;
		justify-content: flex-end;
		gap: 8px;
		padding: 0 22px 20px;
	}

	@media (prefers-reduced-motion: reduce) {
		dialog,
		dialog[open] {
			transform: none;
		}
	}
</style>
