<script lang="ts">
	import { ACTIONS, type ActionId, comboFromEvent, conflict, isMac, keycaps, reserved } from '#lib/keys.ts';
	import { library } from '#lib/store/library.svelte.ts';

	const mac = isMac();
	const keys = $derived(library.keys);
	const changed = $derived(Object.keys(library.data.settings.keys ?? {}).length > 0);

	/** The action waiting for a new shortcut, if any. */
	let recording = $state<ActionId | null>(null);
	let problem = $state<{ id: ActionId; text: string } | null>(null);

	function start(id: ActionId) {
		problem = null;
		recording = recording === id ? null : id;
	}

	// While recording, the next key press becomes the shortcut. Escape cancels;
	// Backspace or Delete removes the shortcut.
	function onkeydown(e: KeyboardEvent) {
		if (!recording) return;
		const id = recording;
		if (e.key === 'Tab') {
			recording = null;
			return;
		}
		e.preventDefault();
		e.stopPropagation();
		if (e.key === 'Escape') {
			recording = null;
			return;
		}
		if ((e.key === 'Backspace' || e.key === 'Delete') && !e.metaKey && !e.ctrlKey && !e.altKey) {
			library.setKey(id, null);
			recording = null;
			return;
		}
		const combo = comboFromEvent(e);
		if (!combo) return;
		if (reserved(combo)) {
			problem = { id, text: 'Tab and Escape are kept for moving around and cancelling.' };
			return;
		}
		const clash = conflict(keys, id, combo);
		if (clash) {
			problem = { id, text: `${keycaps(combo, mac).join(mac ? '' : '+')} is already used for “${clash.label}”.` };
			return;
		}
		library.setKey(id, combo);
		recording = null;
		problem = null;
	}
</script>

<svelte:window onkeydowncapture={onkeydown} />

<ul class="group">
	{#each ACTIONS as a (a.id)}
		{@const combo = keys[a.id]}
		<li class="row">
			<span class="text">
				<span class="label">{a.label}</span>
				{#if problem?.id === a.id}
					<span class="problem" role="alert">{problem.text}</span>
				{:else if a.detail}
					<span class="detail">{a.detail}</span>
				{/if}
			</span>
			<button
				type="button"
				class="shortcut"
				class:recording={recording === a.id}
				aria-label="{a.label} shortcut: {combo ? keycaps(combo, mac).join(' ') : 'none'}. Press to change."
				onclick={() => start(a.id)}
			>
				{#if recording === a.id}
					<span class="prompt">Type a shortcut</span>
				{:else if combo}
					{#each keycaps(combo, mac) as cap, i (i)}<kbd>{cap}</kbd>{/each}
				{:else}
					<span class="none">None</span>
				{/if}
			</button>
		</li>
	{/each}
</ul>
<div class="foot">
	<p class="group-note">
		Click a shortcut, then press the new keys. Escape cancels; Delete removes it. Letters and Space work when you're
		not typing (Space also plays while the search is empty).
	</p>
	<button class="btn small quiet" type="button" disabled={!changed} onclick={() => library.resetKeys()}>
		Restore Defaults
	</button>
</div>

<style>
	.row {
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: 16px;
		min-height: 50px;
		padding: 7px 10px 7px 14px;
	}

	.text {
		display: grid;
		min-width: 0;
	}

	.label {
		font-size: var(--fs-md);
	}

	.detail {
		color: var(--fg-3);
		font-size: var(--fs-sm);
	}

	.problem {
		color: var(--bad);
		font-size: var(--fs-sm);
	}

	.shortcut {
		display: inline-flex;
		flex: none;
		align-items: center;
		justify-content: center;
		gap: 4px;
		min-width: 92px;
		height: 30px;
		padding: 0 8px;
		border: 0;
		border-radius: 8px;
		background: var(--fill-2);
		color: var(--fg);
		transition:
			background-color var(--t-fast),
			box-shadow var(--t-fast);
	}

	.shortcut:hover {
		background: var(--fill);
	}

	.recording {
		background: var(--bg);
		box-shadow:
			0 0 0 1px var(--line-strong),
			0 0 0 4px color-mix(in srgb, var(--accent) 45%, transparent);
	}

	kbd {
		min-width: 22px;
		padding: 1px 6px;
		border-radius: 5px;
		background: var(--bg);
		box-shadow: 0 0.5px 0 1px var(--line-strong);
		font-family: var(--font-body);
		font-size: var(--fs-sm);
		font-weight: 600;
		text-align: center;
	}

	.prompt {
		color: var(--accent-text);
		font-size: var(--fs-sm);
		font-weight: 600;
		animation: blink 1.2s ease-in-out infinite;
	}

	@keyframes blink {
		50% {
			opacity: 0.45;
		}
	}

	.none {
		color: var(--fg-4);
		font-size: var(--fs-sm);
	}

	.foot {
		display: flex;
		flex-wrap: wrap;
		align-items: flex-start;
		justify-content: space-between;
		gap: 8px 16px;
	}

	.foot .group-note {
		flex: 1;
		min-width: 220px;
	}

	.foot .btn {
		margin-top: 6px;
	}
</style>
