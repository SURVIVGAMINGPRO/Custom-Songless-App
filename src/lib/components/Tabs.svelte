<script lang="ts">
	import { tick } from 'svelte';

	let {
		tabs,
		value = $bindable(),
		label,
		size = 'normal'
	}: {
		tabs: { key: string; label: string }[];
		value: string;
		label: string;
		size?: 'normal' | 'small';
	} = $props();

	let list: HTMLDivElement;
	/** The pill behind the selected tab glides to it. */
	let pill = $state({ x: 0, w: 0, ready: false });

	async function place() {
		await tick();
		const el = list?.querySelector<HTMLButtonElement>('[aria-selected="true"]');
		if (!el) return;
		pill = { x: el.offsetLeft, w: el.offsetWidth, ready: true };
	}

	$effect(() => {
		void value;
		void tabs.length;
		place();
	});

	$effect(() => {
		const ro = new ResizeObserver(() => place());
		ro.observe(list);
		return () => ro.disconnect();
	});

	function onkeydown(e: KeyboardEvent) {
		const i = tabs.findIndex((t) => t.key === value);
		let next = i;
		if (e.key === 'ArrowRight') next = (i + 1) % tabs.length;
		else if (e.key === 'ArrowLeft') next = (i - 1 + tabs.length) % tabs.length;
		else if (e.key === 'Home') next = 0;
		else if (e.key === 'End') next = tabs.length - 1;
		else return;
		e.preventDefault();
		value = tabs[next].key;
		list.querySelectorAll<HTMLButtonElement>('[role="tab"]')[next]?.focus();
	}
</script>

<div class="tabs {size}" role="tablist" aria-label={label} bind:this={list} tabindex="-1" {onkeydown}>
	<span
		class="pill"
		class:ready={pill.ready}
		style:width="{pill.w}px"
		style:transform="translateX({pill.x}px)"
		aria-hidden="true"
	></span>
	{#each tabs as tab (tab.key)}
		<button
			type="button"
			role="tab"
			aria-selected={tab.key === value}
			tabindex={tab.key === value ? 0 : -1}
			title={tab.label}
			onclick={() => (value = tab.key)}
		>
			{tab.label}
		</button>
	{/each}
</div>

<style>
	.tabs {
		position: relative;
		display: flex;
		width: max-content;
		max-width: 100%;
		margin: 0 auto;
		padding: 4px;
		border: 1px solid var(--line);
		border-radius: var(--r-full);
		background: var(--surface);
		overflow-x: auto;
		scrollbar-width: none;
	}

	.tabs::-webkit-scrollbar {
		display: none;
	}

	.tabs:focus {
		outline: none;
	}

	.pill {
		position: absolute;
		top: 4px;
		bottom: 4px;
		left: 0;
		border-radius: var(--r-full);
		background: var(--surface-3);
		box-shadow: 0 1px 0 rgb(255 255 255 / 0.06) inset;
		opacity: 0;
	}

	.pill.ready {
		opacity: 1;
		transition:
			transform var(--t-med) var(--ease-out),
			width var(--t-med) var(--ease-out);
	}

	button {
		position: relative;
		flex: 1 0 auto;
		min-width: 96px;
		max-width: 220px;
		height: 36px;
		padding: 0 18px;
		border: 0;
		border-radius: var(--r-full);
		background: transparent;
		color: var(--fg-3);
		font-size: var(--fs-sm);
		font-weight: 600;
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
		transition: color var(--t-fast);
	}

	button:hover {
		color: var(--fg-2);
	}

	button[aria-selected='true'] {
		color: var(--fg);
	}

	.small {
		padding: 3px;
	}

	.small .pill {
		top: 3px;
		bottom: 3px;
	}

	.small button {
		min-width: 0;
		height: 30px;
		padding: 0 14px;
		font-size: var(--fs-xs);
	}
</style>
