<script lang="ts">
	import type { Attempt } from '#lib/game/types.ts';

	let { attempts, rows, active }: { attempts: Attempt[]; rows: number; active: boolean } = $props();

	const RESULT_LABEL = { correct: 'Correct', artist: 'Right artist', wrong: 'Wrong' } as const;
</script>

<ol class="board" aria-label="Your guesses">
	{#each { length: rows }, i (i)}
		{@const a = attempts[i]}
		{#if !a}
			<li class="row" class:current={active && i === attempts.length}>
				<span class="n" aria-hidden="true">{i + 1}</span>
				<span class="visually-hidden">{active && i === attempts.length ? 'Next guess' : 'Empty'}</span>
			</li>
		{:else if a.kind === 'skip'}
			<li class="row filled skip">
				<span class="n" aria-hidden="true">{i + 1}</span>
				<span class="text">Skipped</span>
			</li>
		{:else}
			<li class="row filled {a.result}">
				<span class="n" aria-hidden="true">{i + 1}</span>
				<span class="text">{a.pick.title} <span class="by">· {a.pick.artist}</span></span>
				<span class="visually-hidden">: {RESULT_LABEL[a.result]}</span>
			</li>
		{/if}
	{/each}
</ol>

<style>
	.board {
		display: grid;
		grid-template-columns: minmax(0, 1fr);
		gap: 8px;
		margin: 0;
		padding: 0;
		list-style: none;
		perspective: 700px;
	}

	.row {
		position: relative;
		display: flex;
		align-items: center;
		justify-content: center;
		height: 46px;
		padding: 0 44px;
		border: 1px solid var(--line);
		border-radius: var(--r-md);
		background: rgb(255 255 255 / 0.015);
		transition:
			border-color var(--t-med),
			box-shadow var(--t-med);
	}

	.n {
		position: absolute;
		left: 16px;
		color: var(--fg-4);
		font-family: var(--font-display);
		font-size: var(--fs-sm);
		font-weight: 700;
	}

	.row.current {
		border-color: rgb(255 224 66 / 0.55);
		box-shadow: 0 0 0 3px var(--accent-wash);
	}

	.row.current .n {
		color: var(--accent);
	}

	.filled {
		border-color: transparent;
		color: var(--row-ink);
		animation: flip var(--t-slow) var(--ease-out) both;
	}

	.filled .n {
		color: rgb(16 16 18 / 0.5);
	}

	.text {
		min-width: 0;
		overflow: hidden;
		font-family: var(--font-display);
		font-size: 16px;
		font-weight: 700;
		text-overflow: ellipsis;
		white-space: nowrap;
	}

	.by {
		font-weight: 500;
		opacity: 0.75;
	}

	@media (min-width: 720px) {
		.text {
			font-size: 17px;
		}
	}

	.skip {
		background: var(--surface-2);
		color: var(--fg-3);
	}

	.skip .n {
		color: var(--fg-4);
	}

	.wrong {
		background: var(--bad);
		animation:
			flip var(--t-slow) var(--ease-out) both,
			shake 360ms var(--ease-out) var(--t-slow);
	}

	.artist {
		background: var(--near);
	}

	.correct {
		background: var(--good);
		animation:
			flip var(--t-slow) var(--ease-out) both,
			pop 420ms var(--ease-pop) var(--t-slow);
	}

	@keyframes flip {
		from {
			transform: rotateX(-90deg);
			opacity: 0.4;
		}
	}

	@keyframes shake {
		20% {
			transform: translateX(-6px);
		}
		40% {
			transform: translateX(5px);
		}
		60% {
			transform: translateX(-3px);
		}
		80% {
			transform: translateX(2px);
		}
	}

	@keyframes pop {
		40% {
			transform: scale(1.03);
			box-shadow: 0 0 0 6px rgb(61 220 151 / 0.25);
		}
	}
</style>
