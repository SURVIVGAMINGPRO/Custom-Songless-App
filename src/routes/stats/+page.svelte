<script lang="ts">
	import { resolve } from '$app/paths';
	import Icon from '#lib/components/Icon.svelte';
	import PageHead from '#lib/components/PageHead.svelte';
	import Tabs from '#lib/components/Tabs.svelte';
	import { formatSeconds } from '#lib/game/engine.ts';
	import type { Mode } from '#lib/game/types.ts';
	import { ALL, library } from '#lib/store/library.svelte.ts';

	let gameId = $state(library.currentGame?.id ?? library.data.games[0]?.id ?? '');
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

<div class="page">
	<PageHead title="Stats" />

	{#if library.data.games.length === 0}
		<p class="muted">Play a playlist and your stats show up here. <a href={resolve('/')}>Your playlists</a></p>
	{:else}
		<div class="filters">
			{#if library.data.games.length > 1}
				<label class="popup">
					<span class="visually-hidden">Playlist or mix</span>
					<select bind:value={gameId}>
						{#each library.data.games as g (g.id)}
							<option value={g.id}>{g.name}</option>
						{/each}
					</select>
					<Icon name="chevron-down" size={14} weight={2.2} />
				</label>
			{/if}
			<Tabs
				size="small"
				label="Mode"
				tabs={[
					{ key: 'unlimited', label: 'Endless' },
					{ key: 'daily', label: "Today's Song" }
				]}
				bind:value={() => mode, (v) => (mode = v as Mode)}
			/>
			{#if tabs.length > 1}
				<Tabs size="small" label="Playlist" {tabs} bind:value={tab} />
			{/if}
		</div>

		{#if game && stats}
			{#key `${gameId}:${mode}:${tab}`}
				<dl class="tiles">
					<div class="tile rise" style:--i={0}><dt>Played</dt><dd>{stats.played}</dd></div>
					<div class="tile rise" style:--i={1}><dt>Won</dt><dd>{winRate}<small>%</small></dd></div>
					<div class="tile rise" style:--i={2}><dt>Streak</dt><dd>{stats.streak}</dd></div>
					<div class="tile rise" style:--i={3}><dt>Best Streak</dt><dd>{stats.best}</dd></div>
				</dl>

				<h2 class="group-title">
					Tries to Get It{#if average}<span class="avg"> · {average} on average</span>{/if}
				</h2>
				<ol class="group dist">
					{#each stats.dist as n, i (i)}
						{@const lost = i === stats.dist.length - 1}
						<li>
							<span class="try">{lost ? 'X' : i + 1}</span>
							<span class="track">
								<span
									class="bar"
									class:lost
									style:transform="scaleX({n === 0 ? 0 : Math.max(0.04, n / most)})"
									style:--i={i}
								></span>
							</span>
							<span class="n">{n}</span>
							<span class="visually-hidden">{lost ? 'missed' : `won in ${formatSeconds(game.steps[i] ?? 0)}`}</span>
						</li>
					{/each}
				</ol>
			{/key}
		{/if}
	{/if}
</div>

<style>
	.page {
		max-width: var(--content);
		margin: 0 auto;
	}

	.filters {
		display: flex;
		flex-wrap: wrap;
		align-items: center;
		gap: 10px;
	}

	/* A macOS pop-up button */
	.popup {
		position: relative;
		display: inline-flex;
		align-items: center;
	}

	.popup select {
		height: 30px;
		max-width: 240px;
		padding: 0 30px 0 12px;
		border: 0;
		border-radius: 8px;
		background: var(--fill-2);
		color: var(--fg);
		font-size: var(--fs-sm);
		font-weight: 500;
		appearance: none;
		cursor: pointer;
	}

	.popup select:hover {
		background: var(--fill);
	}

	.popup :global(svg) {
		position: absolute;
		right: 10px;
		color: var(--fg-3);
		pointer-events: none;
	}

	.tiles {
		display: grid;
		grid-template-columns: repeat(4, 1fr);
		gap: 10px;
		margin: 22px 0 28px;
	}

	@media (max-width: 560px) {
		.tiles {
			grid-template-columns: repeat(2, 1fr);
		}
	}

	.tile {
		padding: 14px 16px;
		border-radius: var(--r-lg);
		background: var(--surface);
	}

	dt {
		color: var(--fg-3);
		font-size: var(--fs-sm);
		font-weight: 500;
	}

	dd {
		margin: 2px 0 0;
		font-family: var(--font-rounded);
		font-size: 34px;
		font-weight: 700;
		letter-spacing: -0.02em;
		font-variant-numeric: tabular-nums;
	}

	dd small {
		font-size: 20px;
		font-weight: 600;
		color: var(--fg-3);
	}

	.avg {
		font-weight: 400;
	}

	.dist li {
		display: grid;
		grid-template-columns: 22px 1fr 36px;
		align-items: center;
		gap: 12px;
		min-height: 40px;
		padding: 6px 14px;
	}

	.try {
		color: var(--fg-3);
		font-family: var(--font-rounded);
		font-weight: 700;
		text-align: center;
	}

	.track {
		height: 14px;
		overflow: hidden;
		border-radius: var(--r-full);
		background: var(--fill-3);
	}

	.bar {
		display: block;
		height: 100%;
		border-radius: var(--r-full);
		background: var(--accent);
		transform-origin: left;
		animation: grow 600ms var(--ease-out) both;
		animation-delay: calc(var(--i) * 50ms + 120ms);
	}

	.bar.lost {
		background: var(--bad);
	}

	@keyframes grow {
		from {
			transform: scaleX(0);
		}
	}

	.n {
		color: var(--fg-2);
		font-size: var(--fs-sm);
		font-variant-numeric: tabular-nums;
		text-align: right;
	}
</style>
