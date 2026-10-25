<script lang="ts">
	import Icon from '#lib/components/Icon.svelte';
	import type { GuessPick } from '#lib/game/types.ts';

	let {
		search,
		onguess,
		onskip,
		guessed
	}: {
		search: (q: string, signal: AbortSignal) => Promise<GuessPick[]>;
		onguess: (pick: GuessPick) => void;
		onskip: () => void;
		/** IDs already guessed this round. */
		guessed: number[];
	} = $props();

	const uid = $props.id();
	let input: HTMLInputElement;
	let query = $state('');
	let results = $state<GuessPick[]>([]);
	let open = $state(false);
	let active = $state(-1);
	let picked = $state<GuessPick | null>(null);
	let searching = $state(false);
	let failed = $state(false);
	let timer: ReturnType<typeof setTimeout> | undefined;
	let controller: AbortController | undefined;

	function oninput() {
		picked = null;
		clearTimeout(timer);
		controller?.abort();
		const q = query.trim();
		if (q.length < 2) {
			results = [];
			open = false;
			searching = false;
			return;
		}
		searching = true;
		open = true;
		timer = setTimeout(async () => {
			controller = new AbortController();
			const signal = controller.signal;
			try {
				const found = await search(q, signal);
				if (signal.aborted) return;
				results = found;
				failed = false;
				active = found.length ? 0 : -1;
			} catch {
				if (signal.aborted) return;
				results = [];
				failed = true;
			}
			searching = false;
		}, 350);
	}

	function pick(option: GuessPick) {
		picked = option;
		query = `${option.title} - ${option.artist}`;
		open = false;
		input.focus();
	}

	function reset() {
		query = '';
		results = [];
		picked = null;
		open = false;
		active = -1;
	}

	function submit() {
		if (picked) {
			if (guessed.includes(picked.id)) return;
			onguess(picked);
		} else onskip();
		reset();
	}

	function onkeydown(e: KeyboardEvent) {
		if (e.key === 'ArrowDown' || e.key === 'ArrowUp') {
			if (!results.length) return;
			e.preventDefault();
			open = true;
			const step = e.key === 'ArrowDown' ? 1 : -1;
			active = (active + step + results.length) % results.length;
			document.getElementById(`${uid}-opt-${active}`)?.scrollIntoView({ block: 'nearest' });
		} else if (e.key === 'Enter') {
			e.preventDefault();
			if (open && active >= 0 && results[active]) pick(results[active]);
			else if (picked) submit();
		} else if (e.key === 'Escape' && open) {
			e.preventDefault();
			open = false;
		}
	}

	const already = $derived(!!picked && guessed.includes(picked.id));
</script>

<div class="guess">
	<div class="search">
		<span class="icon"><Icon name="search" size={20} /></span>
		<input
			bind:this={input}
			bind:value={query}
			{oninput}
			{onkeydown}
			onblur={() => setTimeout(() => (open = false), 120)}
			onfocus={() => (open = results.length > 0 && !picked)}
			type="text"
			role="combobox"
			placeholder="Name that song…"
			autocomplete="off"
			spellcheck="false"
			aria-label="Search a song"
			aria-expanded={open}
			aria-controls="{uid}-list"
			aria-autocomplete="list"
			aria-activedescendant={open && active >= 0 ? `${uid}-opt-${active}` : undefined}
		/>
		{#if query}
			<button class="clear" type="button" aria-label="Clear" onclick={() => (reset(), input.focus())}>
				<Icon name="x" size={18} />
			</button>
		{/if}
		{#if open}
			<ul id="{uid}-list" class="list" role="listbox" aria-label="Songs">
				{#if searching && results.length === 0}
					<li class="note">Searching…</li>
				{:else if failed}
					<li class="note">Can't search right now. Check your connection.</li>
				{:else if results.length === 0}
					<li class="note">No songs found</li>
				{:else}
					{#each results as r, i (r.id)}
						<!-- Options are chosen with the arrow keys and Enter in the search box. -->
						<!-- svelte-ignore a11y_click_events_have_key_events -->
						<li
							id="{uid}-opt-{i}"
							role="option"
							aria-selected={i === active}
							class:active={i === active}
							class:used={guessed.includes(r.id)}
							onpointerdown={(e) => e.preventDefault()}
							onclick={() => pick(r)}
							onpointermove={() => (active = i)}
						>
							<span class="opt-title">{r.title}</span> <span class="opt-artist">{r.artist}</span>
						</li>
					{/each}
				{/if}
			</ul>
		{/if}
	</div>
	<button class="btn action" class:ghost={!picked} type="button" disabled={already} onclick={submit}>
		{picked ? (already ? 'Guessed' : 'Submit') : 'Skip'}
	</button>
</div>

<style>
	.guess {
		display: flex;
		gap: 8px;
		margin-top: 32px;
	}

	.search {
		position: relative;
		flex: 1;
		min-width: 0;
	}

	.icon {
		position: absolute;
		top: 50%;
		left: 16px;
		display: flex;
		color: var(--fg-3);
		transform: translateY(-50%);
		pointer-events: none;
		transition: color var(--t-fast);
	}

	.search:focus-within .icon {
		color: var(--accent);
	}

	input {
		width: 100%;
		height: 48px;
		padding: 0 44px 0 48px;
		border: 1px solid var(--line-strong);
		border-radius: var(--r-full);
		background: var(--surface);
		color: var(--fg);
		font-size: 16px;
		font-weight: 500;
		text-overflow: ellipsis;
		transition:
			border-color var(--t-fast),
			box-shadow var(--t-fast);
	}

	input:hover {
		border-color: var(--line-lit);
	}

	input:focus-visible {
		outline: none;
		border-color: var(--accent);
		box-shadow: 0 0 0 4px var(--accent-wash);
	}

	.clear {
		position: absolute;
		top: 50%;
		right: 8px;
		display: grid;
		place-items: center;
		width: 32px;
		height: 32px;
		border: 0;
		border-radius: var(--r-full);
		background: transparent;
		color: var(--fg-3);
		transform: translateY(-50%);
	}

	.clear:hover {
		background: var(--surface-2);
		color: var(--fg);
	}

	.list {
		position: absolute;
		left: 0;
		right: 0;
		bottom: calc(100% + 8px);
		z-index: 10;
		max-height: min(340px, 50dvh);
		margin: 0;
		padding: 6px;
		overflow-y: auto;
		border: 1px solid var(--line-strong);
		border-radius: var(--r-lg);
		background: var(--surface);
		box-shadow: var(--shadow-pop);
		list-style: none;
		transform-origin: bottom center;
		animation: list-in var(--t-med) var(--ease-out);
	}

	@keyframes list-in {
		from {
			opacity: 0;
			transform: translateY(6px) scale(0.98);
		}
	}

	.list li {
		padding: 9px 12px;
		border-radius: var(--r-sm);
		font-size: var(--fs-md);
		line-height: 1.35;
	}

	[role='option'] {
		cursor: pointer;
	}

	.opt-title {
		font-weight: 600;
	}

	.opt-artist {
		color: var(--fg-3);
	}

	.active {
		background: var(--surface-2);
		box-shadow: inset 3px 0 0 var(--accent);
	}

	.used {
		opacity: 0.45;
	}

	.note {
		color: var(--fg-3);
	}

	.action {
		width: 104px;
		height: 48px;
		flex: none;
	}

	@media (max-width: 480px) {
		.action {
			width: 84px;
		}
	}
</style>
