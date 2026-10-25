<script lang="ts">
	import { resolve } from '$app/paths';
	import { page } from '$app/state';
	import { untrack } from 'svelte';
	import { player } from '#lib/audio/player.svelte.ts';
	import Icon from '#lib/components/Icon.svelte';
	import Mosaic from '#lib/components/Mosaic.svelte';
	import GuessBoard from '#lib/components/play/GuessBoard.svelte';
	import GuessBox from '#lib/components/play/GuessBox.svelte';
	import PlayButton from '#lib/components/play/PlayButton.svelte';
	import RoundResult from '#lib/components/play/RoundResult.svelte';
	import Timeline from '#lib/components/play/Timeline.svelte';
	import Tabs from '#lib/components/Tabs.svelte';
	import { APP_NAME } from '#lib/config.ts';
	import { dayNumber } from '#lib/game/deck.ts';
	import { MAX_STEP, clipSeconds, formatSeconds, guess, shareText, skip, stepIndex } from '#lib/game/engine.ts';
	import { fold, normalizeArtist, normalizeTitle } from '#lib/game/normalize.ts';
	import type { GuessPick, Mode, Song } from '#lib/game/types.ts';
	import { search as deezerSearch } from '#lib/sources/deezer.ts';
	import { ALL, library } from '#lib/store/library.svelte.ts';
	import { toasts } from '#lib/toast.svelte.ts';
	import { ui } from '#lib/ui.svelte.ts';
	import { plural } from '#lib/util.ts';

	const MODES: { key: Mode; label: string }[] = [
		{ key: 'unlimited', label: 'Endless' },
		{ key: 'daily', label: "Today's song" }
	];

	/** Songs whose preview failed this session; left out of new rounds. */
	const broken = new Set<number>();

	let tab = $state(ALL);
	let day = $state(dayNumber());

	const game = $derived(library.game(page.params.id ?? ''));
	const mode = $derived(library.data.settings.mode);
	const tabs = $derived(game ? library.tabs(game) : []);
	const pool = $derived(game ? library.pool(game, tab) : []);
	const total = $derived(game ? library.pool(game, ALL).length : 0);
	const art = $derived(game ? library.songsOf(game.playlistIds, 8) : []);
	const editHref = $derived(
		game
			? game.playlistIds.length === 1
				? resolve('/playlists/[id]', { id: game.playlistIds[0] })
				: resolve('/games/[id]', { id: game.id })
			: resolve('/')
	);
	const round = $derived(game ? library.round(game, tab, mode, day) : undefined);
	const answer = $derived(round ? library.song(round.songId) : undefined);
	const steps = $derived(game?.steps ?? []);
	const playing = $derived(round?.status === 'playing');
	const clip = $derived(round ? clipSeconds(round, steps) : 0);
	const timelineSteps = $derived(playing || steps[steps.length - 1] >= MAX_STEP ? steps : [...steps, MAX_STEP]);
	const unlocked = $derived(round && playing ? stepIndex(round, steps) : timelineSteps.length - 1);

	// Remember this as the game to come back to.
	$effect(() => {
		if (game && library.data.settings.gameId !== game.id) untrack(() => library.selectGame(game));
	});

	// Keep the tab valid when the mix's playlists change.
	$effect(() => {
		if (tabs.length && !tabs.some((t) => t.key === tab)) tab = tabs[0].key;
	});

	// Deal a song when this tab has no round yet (or its song was removed).
	$effect(() => {
		if (!game || pool.length === 0 || (round && answer)) return;
		untrack(() => library.startRound(game, tab, mode, day, [...broken]));
	});

	// Stop the music when the song or view changes; fetch the clip early.
	const roundKey = $derived(`${game?.id}:${tab}:${mode}:${round?.songId}`);
	$effect(() => {
		void roundKey;
		untrack(() => player.stop());
	});
	$effect(() => {
		if (answer) player.preload(answer.id);
	});

	// Show How to play the first time.
	$effect(() => {
		if (game && !library.data.settings.seenHelp) {
			ui.helpOpen = true;
			untrack(() => library.markHelpSeen());
		}
	});

	function togglePlay() {
		if (!answer) return;
		if (player.playing || player.loading) player.stop();
		else player.play(answer.id, clip);
	}

	function onGuess(pick: GuessPick) {
		if (!game || !round || !answer) return;
		const next = guess(round, pick, answer, steps);
		library.putRound(game, tab, next);
		if (next.status !== 'playing') player.play(answer.id, MAX_STEP);
	}

	function onSkip() {
		if (!game || !round || !answer) return;
		const next = skip(round, steps);
		library.putRound(game, tab, next);
		if (next.status !== 'playing') player.play(answer.id, MAX_STEP);
	}

	function nextSong() {
		if (game) library.startRound(game, tab, mode, day, [...broken]);
	}

	/** Leave out a song whose preview won't load. Doesn't count as a round. */
	function skipBroken() {
		if (!game || !round) return;
		broken.add(round.songId);
		player.stop();
		player.error = null;
		library.startRound(game, tab, mode, day, [...broken]);
	}

	async function searchGuesses(q: string, signal: AbortSignal): Promise<GuessPick[]> {
		let songs: Song[];
		if (game?.guessScope === 'game') {
			const f = fold(q);
			songs = library
				.pool(game, ALL)
				.map((id) => library.song(id)!)
				.filter((s) => fold(`${s.title} ${s.artists.join(' ')}`).includes(f))
				.slice(0, 10);
		} else {
			songs = await deezerSearch(q, 20, signal);
		}
		const seen = new Set<string>();
		return songs
			.filter((s) => {
				const key = `${normalizeTitle(s.title)}|${normalizeArtist(s.artist)}`;
				return !seen.has(key) && !!seen.add(key);
			})
			.slice(0, 10)
			.map((s) => ({ id: s.id, title: s.title, artist: s.artist, artists: s.artists, isrc: s.isrc }));
	}

	async function share() {
		if (!game || !round) return;
		const tabLabel = tabs.length > 1 ? tabs.find((t) => t.key === tab)?.label : undefined;
		const text = shareText({ app: APP_NAME, game: game.name, tab: tabLabel, round, steps });
		try {
			await navigator.clipboard.writeText(text);
			toasts.show('Copied your result');
		} catch {
			toasts.show("Couldn't copy your result", 'error');
		}
	}

	function onkeydown(e: KeyboardEvent) {
		const el = e.target as HTMLElement;
		if (e.key !== ' ' || el.closest('input, textarea, button, a, [role="tab"], dialog')) return;
		e.preventDefault();
		togglePlay();
	}

	function refreshDay() {
		day = dayNumber();
	}
</script>

<svelte:head>
	<title>{game ? `${game.name} · ${APP_NAME}` : APP_NAME}</title>
</svelte:head>
<svelte:window {onkeydown} onfocus={refreshDay} />
<svelte:document onvisibilitychange={refreshDay} />

<div class="stage">
	{#if !game}
		<section class="missing">
			<h1>This game is gone</h1>
			<p class="muted">Its playlist may have been deleted.</p>
			<a class="btn" href={resolve('/')}>Back to your playlists</a>
		</section>
	{:else}
		<div class="top">
			<a class="back" href={resolve('/')}><Icon name="arrow-left" size={18} /> Playlists</a>
			<button class="icon-btn" type="button" aria-label="How to play" onclick={() => (ui.helpOpen = true)}>
				<Icon name="help" size={20} />
			</button>
		</div>

		<header class="hero">
			<div class="hero-art"><Mosaic songs={art} seed={game.id} radius="var(--r-md)" /></div>
			<div class="hero-text">
				<p class="eyebrow">{game.playlistIds.length > 1 ? 'Mix' : 'Your playlist'}</p>
				<h1 title={game.name}>{game.name}</h1>
				<p class="muted meta">
					{plural(total, 'song')} · <a href={editHref}>Edit</a>
				</p>
			</div>
		</header>

		<div class="modes">
			<Tabs size="small" label="Mode" tabs={MODES} bind:value={() => mode, (v) => library.setMode(v as Mode)} />
			<p class="mode-note">
				{mode === 'daily' ? 'One song a day from this playlist' : 'A new song every round, no repeats'}
			</p>
		</div>

		{#if tabs.length > 1}
			<div class="lists"><Tabs label="Playlist" {tabs} bind:value={tab} /></div>
		{/if}

		{#if pool.length === 0}
			<section class="missing">
				<p>No songs to play yet.</p>
				<a class="btn quiet" href={editHref}>Add songs</a>
			</section>
		{:else if round && answer}
			{#key `${round.songId}:${tab}:${mode}`}
				<div class="round">
					<GuessBoard attempts={round.attempts} rows={steps.length} active={playing} />

					<Timeline
						steps={timelineSteps}
						{unlocked}
						position={player.position}
						label={playing ? formatSeconds(clip) : 'Full preview'}
					/>

					<PlayButton
						playing={player.playing}
						loading={player.loading}
						label={playing ? `Play ${formatSeconds(clip)}` : 'Play the preview'}
						onclick={togglePlay}
					/>

					{#if player.error}
						<p class="error" role="alert">
							{player.error}
							<button class="link" type="button" onclick={skipBroken}>Skip this song</button>
						</p>
					{/if}

					{#if playing}
						<GuessBox
							search={searchGuesses}
							onguess={onGuess}
							onskip={onSkip}
							guessed={round.attempts.flatMap((a) => (a.kind === 'guess' ? [a.pick.id] : []))}
						/>
						<p class="hint">Space plays the clip</p>
					{:else}
						<RoundResult
							song={answer}
							{round}
							{steps}
							spinning={player.playing}
							onshare={share}
							onnext={mode === 'unlimited' ? nextSong : undefined}
						/>
					{/if}
				</div>
			{/key}
		{/if}
	{/if}
</div>

<style>
	.stage {
		max-width: var(--content);
		margin: 0 auto;
	}

	.top {
		display: flex;
		align-items: center;
		justify-content: space-between;
		margin-bottom: 12px;
	}

	.back {
		display: inline-flex;
		align-items: center;
		gap: 6px;
		margin-left: -8px;
		padding: 6px 10px;
		border-radius: var(--r-full);
		color: var(--fg-3);
		font-size: var(--fs-sm);
		font-weight: 500;
		text-decoration: none;
		transition:
			color var(--t-fast),
			background-color var(--t-fast);
	}

	.back:hover {
		background: var(--surface-2);
		color: var(--fg);
	}

	.hero {
		display: flex;
		align-items: center;
		gap: 18px;
		min-width: 0;
		animation: rise var(--t-slow) var(--ease-out) both;
	}

	.hero-art {
		width: 84px;
		flex: none;
		border-radius: var(--r-md);
		box-shadow: var(--shadow-card);
	}

	.hero-text {
		min-width: 0;
	}

	.hero h1 {
		overflow: hidden;
		font-size: clamp(26px, 5vw, var(--fs-2xl));
		text-overflow: ellipsis;
		white-space: nowrap;
	}

	.meta {
		margin-top: 4px;
		font-size: var(--fs-sm);
	}

	.meta a {
		color: var(--fg-2);
		text-underline-offset: 3px;
	}

	.modes {
		display: flex;
		flex-wrap: wrap;
		align-items: center;
		gap: 8px 14px;
		margin: 24px 0 16px;
	}

	.modes :global(.tabs) {
		margin: 0;
	}

	.mode-note {
		color: var(--fg-4);
		font-size: var(--fs-sm);
	}

	.lists {
		margin-bottom: 16px;
	}

	.lists :global(.tabs) {
		margin: 0;
	}

	.round {
		animation: rise var(--t-slow) var(--ease-out) both;
	}

	.error {
		margin-top: 12px;
		color: var(--bad-soft);
		font-size: var(--fs-sm);
		text-align: center;
	}

	.link {
		margin-left: 8px;
		padding: 0;
		border: 0;
		background: none;
		color: var(--fg-2);
		font-size: var(--fs-sm);
		text-decoration: underline;
		text-underline-offset: 3px;
	}

	.link:hover {
		color: var(--fg);
	}

	.hint {
		margin-top: 12px;
		color: var(--fg-4);
		font-size: var(--fs-xs);
		text-align: center;
	}

	@media (hover: none) {
		.hint {
			display: none;
		}
	}

	.missing {
		display: grid;
		justify-items: center;
		gap: 12px;
		margin-top: 64px;
		text-align: center;
	}
</style>
