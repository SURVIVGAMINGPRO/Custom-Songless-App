<script lang="ts" module>
	import type { GuessPick } from '#lib/game/types.ts';

	/** A suggestion: a song from the playlist, with its cover for the list. */
	export interface GuessOption extends GuessPick {
		cover: string | null;
	}
</script>

<script lang="ts">
	import Icon from '#lib/components/Icon.svelte';

	let {
		search,
		onguess,
		onskip,
		guessed,
		guessKey = null
	}: {
		/** Songs of the playlist matching what was typed (instant, no network). */
		search: (q: string) => GuessOption[];
		onguess: (pick: GuessPick) => void;
		onskip: () => void;
		/** IDs already guessed this round. */
		guessed: number[];
		/** The Guess shortcut as shown to the player, for the "press again to skip" note. */
		guessKey?: string | null;
	} = $props();

	/** An Enter this soon after a guess is a second press out of habit, not a request to skip. */
	const AFTER_GUESS_MS = 900;
	/** How long "press again to skip" waits for the second press. */
	const ARM_MS = 2000;

	const uid = $props.id();
	let input: HTMLInputElement;
	let query = $state('');
	let results = $state<GuessOption[]>([]);
	let open = $state(false);
	let active = $state(-1);
	let picked = $state<GuessOption | null>(null);
	let skipArmed = $state(false);
	let armTimer: ReturnType<typeof setTimeout> | undefined;
	let lastGuessAt = 0;

	function disarm() {
		skipArmed = false;
		clearTimeout(armTimer);
	}

	function oninput() {
		disarm();
		picked = null;
		results = search(query);
		active = results.length ? 0 : -1;
		open = query.trim().length > 0;
	}

	function pick(option: GuessOption) {
		picked = option;
		query = `${option.title} – ${option.artist}`;
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
		disarm();
		if (picked) {
			if (guessed.includes(picked.id)) return;
			const { id, title, artist, artists, isrc } = picked;
			lastGuessAt = Date.now();
			onguess({ id, title, artist, artists, isrc });
		} else onskip();
		reset();
	}

	// Enter (or whatever Guess is set to) is handled by the play screen's shortcuts,
	// which call guessOrSkip() below. The list itself takes the arrow keys and Escape.
	function onkeydown(e: KeyboardEvent) {
		if (e.key === 'ArrowDown' || e.key === 'ArrowUp') {
			if (!results.length) return;
			e.preventDefault();
			open = true;
			const step = e.key === 'ArrowDown' ? 1 : -1;
			active = (active + step + results.length) % results.length;
			document.getElementById(`${uid}-opt-${active}`)?.scrollIntoView({ block: 'nearest' });
		} else if (e.key === 'Escape' && open) {
			e.preventDefault();
			open = false;
		}
	}

	let nudging = $state(false);

	/**
	 * The Guess shortcut (Enter): the first press picks the highlighted song, the
	 * next one guesses it. On an empty search it skips only when pressed twice in
	 * a row, so an extra press after a guess never skips by accident.
	 */
	export function guessOrSkip(): void {
		if (picked) return submit();
		const highlighted = open && active >= 0 ? results[active] : undefined;
		if (highlighted) return pick(highlighted);
		if (!query.trim()) {
			if (Date.now() - lastGuessAt < AFTER_GUESS_MS) return;
			if (skipArmed) return submit();
			skipArmed = true;
			armTimer = setTimeout(disarm, ARM_MS);
			return;
		}
		// Typed something that matches nothing: shake, don't guess.
		nudging = false;
		requestAnimationFrame(() => (nudging = true));
	}

	/** The Skip shortcut (Shift+Enter) and the Skip button skip at once. */
	export function skipNow(): void {
		disarm();
		onskip();
		reset();
	}

	export function focusSearch(): void {
		input.focus();
		input.select();
	}

	const already = $derived(!!picked && guessed.includes(picked.id));
</script>

<div class="guess">
	<div class="search" class:nudging onanimationend={() => (nudging = false)}>
		<span class="icon"><Icon name="search" size={17} /></span>
		<input
			bind:this={input}
			bind:value={query}
			{oninput}
			{onkeydown}
			onblur={() => setTimeout(() => (open = false), 120)}
			onfocus={() => (open = query.trim().length > 0 && !picked)}
			type="text"
			role="combobox"
			data-guess-input
			placeholder="Search this playlist"
			autocomplete="off"
			spellcheck="false"
			aria-label="Search this playlist for your guess"
			aria-expanded={open}
			aria-controls="{uid}-list"
			aria-autocomplete="list"
			aria-activedescendant={open && active >= 0 ? `${uid}-opt-${active}` : undefined}
		/>
		{#if query}
			<button class="clear" type="button" aria-label="Clear" onclick={() => (reset(), input.focus())}>
				<svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="12" r="9" /><path d="m9 9 6 6M15 9l-6 6" /></svg>
			</button>
		{/if}
		{#if open}
			<ul id="{uid}-list" class="list" role="listbox" aria-label="Songs in this playlist">
				{#if results.length === 0}
					<li class="note">
						<strong>No song in this playlist matches “{query.trim()}”.</strong>
						<span>Try part of the title or the artist, or press Skip.</span>
					</li>
				{:else}
					{#each results as r, i (r.id)}
						<!-- Options are chosen with the arrow keys and Enter in the search field. -->
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
							{#if r.cover}
								<img src={r.cover} alt="" width="32" height="32" loading="lazy" />
							{:else}
								<span class="no-cover"><Icon name="music" size={15} /></span>
							{/if}
							<span class="opt-text">
								<span class="opt-title">{r.title}</span>
								<span class="opt-artist">{r.artist}{guessed.includes(r.id) ? ' · already guessed' : ''}</span>
							</span>
						</li>
					{/each}
				{/if}
			</ul>
		{/if}
	</div>
	<!-- Clicking doesn't take focus from the search, so typing and shortcuts carry on. -->
	<div class="action-wrap">
		{#if skipArmed}
			<p class="armed-note" role="status">Press <kbd>{guessKey ?? 'Enter'}</kbd> again to skip</p>
		{/if}
		<button
			class="btn large action"
			class:quiet={!picked && !skipArmed}
			class:armed={skipArmed}
			type="button"
			disabled={already}
			onpointerdown={(e) => e.preventDefault()}
			onclick={() => (picked ? submit() : skipNow())}
		>
			{#if picked}
				{already ? 'Guessed' : 'Guess'}
			{:else}
				Skip <Icon name="forward" size={14} />
			{/if}
		</button>
	</div>
</div>

<style>
	.guess {
		display: flex;
		gap: 10px;
	}

	.search {
		position: relative;
		flex: 1;
		min-width: 0;
	}

	.nudging {
		animation: nudge 360ms var(--ease-out);
	}

	@keyframes nudge {
		25% {
			transform: translateX(-5px);
		}
		50% {
			transform: translateX(4px);
		}
		75% {
			transform: translateX(-2px);
		}
	}

	.icon {
		position: absolute;
		top: 50%;
		left: 14px;
		display: flex;
		color: var(--fg-3);
		transform: translateY(-50%);
		pointer-events: none;
	}

	input {
		width: 100%;
		height: 44px;
		padding: 0 40px;
		border: 0;
		border-radius: var(--r-md);
		background: var(--fill-2);
		color: var(--fg);
		font-size: var(--fs-lg);
		text-overflow: ellipsis;
		transition:
			background-color var(--t-fast),
			box-shadow var(--t-fast);
	}

	input:hover {
		background: var(--fill);
	}

	input:focus-visible {
		outline: none;
		background: var(--bg);
		box-shadow:
			0 0 0 1px var(--line-strong),
			0 0 0 4px color-mix(in srgb, var(--accent) 45%, transparent);
	}

	.clear {
		position: absolute;
		top: 50%;
		right: 10px;
		display: grid;
		place-items: center;
		width: 24px;
		height: 24px;
		padding: 0;
		border: 0;
		background: none;
		transform: translateY(-50%);
	}

	.clear svg {
		width: 18px;
		height: 18px;
	}

	.clear circle {
		fill: var(--fg-4);
	}

	.clear path {
		fill: none;
		stroke: var(--bg);
		stroke-width: 2;
		stroke-linecap: round;
	}

	.list {
		position: absolute;
		left: 0;
		right: 0;
		bottom: calc(100% + 8px);
		z-index: 10;
		max-height: min(360px, 50dvh);
		margin: 0;
		padding: 5px;
		overflow-y: auto;
		border-radius: var(--r-lg);
		background: var(--material);
		-webkit-backdrop-filter: saturate(180%) blur(24px);
		backdrop-filter: saturate(180%) blur(24px);
		box-shadow: var(--shadow-pop);
		list-style: none;
		transform-origin: bottom center;
		animation: pop-in var(--t-med) var(--ease-out);
	}

	@keyframes pop-in {
		from {
			opacity: 0;
			transform: scale(0.97) translateY(4px);
		}
	}

	[role='option'] {
		display: flex;
		align-items: center;
		gap: 10px;
		padding: 6px 8px;
		border-radius: var(--r-sm);
		cursor: pointer;
	}

	[role='option'] img,
	.no-cover {
		flex: none;
		width: 32px;
		height: 32px;
		border-radius: 4px;
		object-fit: cover;
		background: var(--fill-2);
	}

	.no-cover {
		display: grid;
		place-items: center;
		color: var(--fg-3);
	}

	.opt-text {
		display: grid;
		min-width: 0;
	}

	.opt-title,
	.opt-artist {
		overflow: hidden;
		text-overflow: ellipsis;
		white-space: nowrap;
	}

	.opt-title {
		font-size: var(--fs-md);
		font-weight: 500;
	}

	.opt-artist {
		color: var(--fg-3);
		font-size: var(--fs-sm);
	}

	.active {
		background: var(--fill-2);
	}

	.used {
		opacity: 0.5;
	}

	.note {
		display: grid;
		gap: 2px;
		padding: 10px 10px 12px;
		color: var(--fg-3);
		font-size: var(--fs-sm);
	}

	.note strong {
		color: var(--fg);
		font-size: var(--fs-md);
		font-weight: 600;
	}

	.action-wrap {
		position: relative;
		flex: none;
	}

	.action {
		min-width: 104px;
	}

	.armed {
		animation: armed 1s var(--ease-out) infinite;
	}

	@keyframes armed {
		50% {
			box-shadow: 0 0 0 5px color-mix(in srgb, var(--accent) 35%, transparent);
		}
	}

	.armed-note {
		position: absolute;
		right: 0;
		bottom: calc(100% + 8px);
		z-index: 5;
		padding: 6px 10px;
		border-radius: var(--r-md);
		background: var(--material);
		-webkit-backdrop-filter: saturate(180%) blur(20px);
		backdrop-filter: saturate(180%) blur(20px);
		box-shadow: var(--shadow-pop);
		color: var(--fg);
		font-size: var(--fs-sm);
		white-space: nowrap;
		animation: pop-in var(--t-med) var(--ease-out);
	}

	.armed-note kbd {
		padding: 1px 5px;
		border-radius: 4px;
		background: var(--fill-2);
		font-family: var(--font-body);
		font-size: var(--fs-xs);
		font-weight: 600;
	}

	@media (max-width: 480px) {
		.action {
			min-width: 84px;
			padding: 0 14px;
		}
	}
</style>
