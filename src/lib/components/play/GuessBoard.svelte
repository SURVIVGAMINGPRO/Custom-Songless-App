<script lang="ts">
	import Icon from '#lib/components/Icon.svelte';
	import type { Attempt } from '#lib/game/types.ts';

	let { attempts, rows, active }: { attempts: Attempt[]; rows: number; active: boolean } = $props();

	const RESULT = {
		correct: { label: 'Correct', glyph: 'm7.5 12.5 3 3 6-6.5' },
		artist: { label: 'Right artist', glyph: 'M12 12.2a2.4 2.4 0 1 0 0-4.8 2.4 2.4 0 0 0 0 4.8ZM7.6 17c.6-2 2.3-3 4.4-3s3.8 1 4.4 3' },
		wrong: { label: 'Wrong', glyph: 'm8.8 8.8 6.4 6.4M15.2 8.8l-6.4 6.4' }
	} as const;
</script>

<ol class="group board" aria-label="Your guesses">
	{#each { length: rows }, i (i)}
		{@const a = attempts[i]}
		{#if !a}
			<li class="row" class:current={active && i === attempts.length}>
				<span class="lead n" aria-hidden="true">{i + 1}</span>
				<span class="text empty">{active && i === attempts.length ? 'Your guess' : ''}</span>
				<span class="visually-hidden">{active && i === attempts.length ? 'Next guess' : 'Empty'}</span>
			</li>
		{:else if a.kind === 'skip'}
			<li class="row filled skip">
				<span class="lead"><Icon name="forward" size={16} /></span>
				<span class="text">Skipped</span>
			</li>
		{:else}
			<li class="row filled {a.result}">
				<span class="lead">
					<svg class="badge" viewBox="0 0 24 24" aria-hidden="true">
						<circle cx="12" cy="12" r="10" />
						<path d={RESULT[a.result].glyph} />
					</svg>
				</span>
				<span class="text"><strong>{a.pick.title}</strong> <span class="by">{a.pick.artist}</span></span>
				<span class="visually-hidden">: {RESULT[a.result].label}</span>
			</li>
		{/if}
	{/each}
</ol>

<style>
	.board {
		display: grid;
		grid-template-columns: minmax(0, 1fr);
	}

	.row {
		position: relative;
		display: flex;
		align-items: center;
		gap: 12px;
		height: 44px;
		padding: 0 14px;
		transition: background-color var(--t-med);
	}

	/* Separators start after the leading icon, as in Apple's lists. */
	.board > li + li {
		box-shadow: none;
	}

	.board > li + li::before {
		content: '';
		position: absolute;
		top: 0;
		left: 46px;
		right: 0;
		height: 0.5px;
		background: var(--line-strong);
	}

	.lead {
		display: grid;
		flex: none;
		place-items: center;
		width: 22px;
		height: 22px;
		color: var(--fg-3);
	}

	.n {
		color: var(--fg-4);
		font-family: var(--font-rounded);
		font-size: var(--fs-sm);
		font-weight: 600;
	}

	.current .n {
		width: 22px;
		border-radius: var(--r-full);
		background: var(--accent);
		color: var(--accent-ink);
	}

	.text {
		min-width: 0;
		overflow: hidden;
		font-size: var(--fs-md);
		text-overflow: ellipsis;
		white-space: nowrap;
	}

	.text strong {
		font-weight: 600;
	}

	.by {
		color: var(--fg-3);
	}

	.empty {
		color: var(--fg-4);
	}

	.filled {
		animation: fill-in var(--t-slow) var(--ease-out);
	}

	.filled .lead {
		animation: pop var(--t-slow) var(--ease-pop);
	}

	.skip .text {
		color: var(--fg-3);
	}

	.badge {
		width: 22px;
		height: 22px;
	}

	.badge circle {
		fill: currentColor;
	}

	.badge path {
		fill: none;
		stroke: var(--on-color);
		stroke-width: 2;
		stroke-linecap: round;
		stroke-linejoin: round;
	}

	.correct {
		background: var(--good-wash);
	}

	.correct .lead {
		color: var(--good);
	}

	.artist {
		background: var(--near-wash);
	}

	.artist .lead {
		color: var(--near);
	}

	.wrong {
		background: var(--bad-wash);
		animation:
			fill-in var(--t-slow) var(--ease-out),
			nudge 320ms var(--ease-out) 120ms;
	}

	.wrong .lead {
		color: var(--bad);
	}

	@keyframes fill-in {
		from {
			background-color: transparent;
		}
	}

	@keyframes pop {
		from {
			transform: scale(0.4);
			opacity: 0;
		}
	}

	@keyframes nudge {
		25% {
			transform: translateX(-4px);
		}
		50% {
			transform: translateX(3px);
		}
		75% {
			transform: translateX(-1.5px);
		}
	}
</style>
