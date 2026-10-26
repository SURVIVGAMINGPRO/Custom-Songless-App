<script lang="ts">
	import { tick } from 'svelte';

	/** A segmented control, as in macOS and iOS: a thumb glides to the chosen segment. */
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
	let thumb = $state({ x: 0, w: 0, ready: false });

	async function place() {
		await tick();
		const el = list?.querySelector<HTMLButtonElement>('[aria-selected="true"]');
		if (!el) return;
		thumb = { x: el.offsetLeft, w: el.offsetWidth, ready: true };
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

<div class="seg {size}" role="tablist" aria-label={label} bind:this={list} tabindex="-1" {onkeydown}>
	<span
		class="thumb"
		class:ready={thumb.ready}
		style:width="{thumb.w}px"
		style:transform="translateX({thumb.x}px)"
		aria-hidden="true"
	></span>
	{#each tabs as tab, i (tab.key)}
		{#if i > 0}<span class="divider" class:hidden={tab.key === value || tabs[i - 1].key === value} aria-hidden="true"></span>{/if}
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
	.seg {
		position: relative;
		display: inline-flex;
		align-items: center;
		max-width: 100%;
		padding: 2px;
		border-radius: 9px;
		background: var(--fill-2);
		overflow-x: auto;
		scrollbar-width: none;
	}

	.seg::-webkit-scrollbar {
		display: none;
	}

	.seg:focus {
		outline: none;
	}

	.thumb {
		position: absolute;
		top: 2px;
		bottom: 2px;
		left: 0;
		border-radius: 7px;
		background: var(--thumb);
		box-shadow:
			0 0 0 0.5px rgb(0 0 0 / 0.04),
			0 2px 6px rgb(0 0 0 / 0.12);
		opacity: 0;
	}

	.thumb.ready {
		opacity: 1;
		transition:
			transform var(--t-med) var(--ease-out),
			width var(--t-med) var(--ease-out);
	}

	.divider {
		flex: none;
		width: 1px;
		height: 14px;
		background: var(--line-strong);
		transition: opacity var(--t-fast);
	}

	.divider.hidden {
		opacity: 0;
	}

	button {
		position: relative;
		flex: 1 0 auto;
		min-width: 88px;
		max-width: 220px;
		height: 30px;
		padding: 0 14px;
		border: 0;
		border-radius: 7px;
		background: transparent;
		color: var(--fg);
		font-size: var(--fs-sm);
		font-weight: 500;
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
	}

	button[aria-selected='true'] {
		font-weight: 600;
	}

	.small button {
		min-width: 0;
		height: 26px;
		padding: 0 12px;
		font-size: var(--fs-sm);
	}
</style>
