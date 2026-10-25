<script lang="ts">
	import { resolve } from '$app/paths';
	import PageHead from '#lib/components/PageHead.svelte';
	import Tabs from '#lib/components/Tabs.svelte';
	import { formatSeconds } from '#lib/game/engine.ts';
	import type { Mode } from '#lib/game/types.ts';
	import { ALL, library } from '#lib/store/library.svelte.ts';

	let gameId = $state(library.currentGame?.id ?? '');
	let mode = $state<Mode>(library.data.settings.mode);
	let tab = $state(ALL);

	const game = $derived(library.game(gameId));
	const tabs = $derived(game ? library.tabs(game) : []);
	const stats = $derived(game ? library.stats(game, mode, tab) : undefined);
	const most = $derived(stats ? Math.max(1, ...stats.dist) : 1);
	const winRate = $derived(stats && stats.played ? Math.round((stats.won / stats.played) * 100) : 0);
	const average = $derived.by(() => {
		if (!stats || !stats.won) return null;
		const tries = stats.dist.slice(0, -1).reduce((sum, n, i) => sum + n * (i + 1), 0);
		return (tries / stats.won).toFixed(1);
	});

	$effect(() => {
		if (tabs.length && !tabs.some((t) => t.key === tab)) tab = tabs[0].key;
	});
</script>

<PageHead title="Stats" />

{#if library.data.games.length === 0}
	<p class="muted">Play a game and your stats show up here. <a href={resolve('/')}>Start playing</a>.</p>
{:else}
	<div class="filters">
		{#if library.data.games.length > 1}
			<select class="field" aria-label="Game" bind:value={gameId}>
				{#each library.data.games as g (g.id)}
					<option value={g.id}>{g.name}</option>
				{/each}
			</select>
		{/if}
		<Tabs
			size="small"
			label="Mode"
			tabs={[
				{ key: 'unlimited', label: 'Unlimited' },
				{ key: 'daily', label: 'Daily' }
			]}
			bind:value={() => mode, (v) => (mode = v as Mode)}
		/>
	</div>
	{#if tabs.length > 1}
		<div class="tabs"><Tabs label="Playlist" {tabs} bind:value={tab} /></div>
	{/if}

	{#if game && stats}
		<dl class="tiles">
			<div><dt>Played</dt><dd>{stats.played}</dd></div>
			<div><dt>Won</dt><dd>{winRate}%</dd></div>
			<div><dt>Streak</dt><dd>{stats.streak}</dd></div>
			<div><dt>Best streak</dt><dd>{stats.best}</dd></div>
		</dl>

		<h2>Tries to get it {#if average}<span class="muted avg">· {average} on average</span>{/if}</h2>
		<ol class="dist">
			{#each stats.dist as n, i (i)}
				{@const lost = i === stats.dist.length - 1}
				<li>
					<span class="try">{lost ? 'X' : i + 1}</span>
					<span class="bar-wrap">
						<span class="bar" class:lost class:empty={n === 0} style:width="{Math.max(n === 0 ? 0 : 8, (n / most) * 100)}%"
						></span>
					</span>
					<span class="n">{n}</span>
					<span class="visually-hidden">{lost ? 'missed' : `won in ${formatSeconds(game.steps[i] ?? 0)}`}</span>
				</li>
			{/each}
		</ol>
	{/if}
{/if}

<style>
	.filters {
		display: flex;
		flex-wrap: wrap;
		align-items: center;
		gap: 12px;
	}

	.filters :global(.tabs) {
		margin: 0;
	}

	select.field {
		width: auto;
		max-width: 100%;
		min-width: 180px;
		height: 34px;
	}

	.tabs {
		margin-top: 16px;
	}

	.tiles {
		display: grid;
		grid-template-columns: repeat(4, 1fr);
		gap: 8px;
		margin: 24px 0 32px;
	}

	@media (max-width: 520px) {
		.tiles {
			grid-template-columns: repeat(2, 1fr);
		}
	}

	.tiles div {
		padding: 14px 16px;
		border: 1px solid var(--line);
		border-radius: var(--r-lg);
		background: var(--surface);
	}

	dt {
		color: var(--fg-3);
		font-size: 13px;
	}

	dd {
		margin: 2px 0 0;
		font-family: var(--font-display);
		font-size: 28px;
		font-weight: 600;
	}

	h2 {
		margin-bottom: 12px;
		font-size: 18px;
		font-weight: 500;
	}

	.avg {
		font-family: var(--font-body);
		font-size: 14px;
		font-weight: 400;
	}

	.dist {
		display: grid;
		gap: 6px;
		margin: 0;
		padding: 0;
		list-style: none;
	}

	.dist li {
		display: grid;
		grid-template-columns: 20px 1fr 40px;
		align-items: center;
		gap: 10px;
	}

	.try {
		color: var(--fg-3);
		font-family: var(--font-display);
		font-weight: 500;
		text-align: center;
	}

	.bar-wrap {
		height: 24px;
	}

	.bar {
		display: block;
		height: 100%;
		border-radius: var(--r-sm);
		background: var(--good);
		transition: width var(--t-slow) var(--ease-out);
	}

	.bar.lost {
		background: var(--bad);
	}

	.n {
		color: var(--fg-2);
		font-size: 14px;
		text-align: right;
	}
</style>
