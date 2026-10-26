<script lang="ts">
	import { resolve } from '$app/paths';
	import { page } from '$app/state';
	import { untrack } from 'svelte';
	import { player } from '#lib/audio/player.svelte.ts';
	import Icon from '#lib/components/Icon.svelte';
	import Mosaic from '#lib/components/Mosaic.svelte';
	import GuessBoard from '#lib/components/play/GuessBoard.svelte';
	import GuessBox, { type GuessOption } from '#lib/components/play/GuessBox.svelte';
	import PlayButton from '#lib/components/play/PlayButton.svelte';
	import RoundResult from '#lib/components/play/RoundResult.svelte';
	import Timeline from '#lib/components/play/Timeline.svelte';
	import Tabs from '#lib/components/Tabs.svelte';
	import { APP_NAME } from '#lib/config.ts';
	import { dayNumber } from '#lib/game/deck.ts';
	import { MAX_STEP, clipSeconds, formatSeconds, guess, shareText, skip, stepIndex } from '#lib/game/engine.ts';
	import { searchSongs } from '#lib/game/search.ts';
	import type { GuessPick, Mode, Song } from '#lib/game/types.ts';
	import { ALL, library } from '#lib/store/library.svelte.ts';
	import { toasts } from '#lib/toast.svelte.ts';
	import { ui } from '#lib/ui.svelte.ts';
	import { coverUrl, plural } from '#lib/util.ts';

	const MODES: { key: Mode; label: string }[] = [
		{ key: 'unlimited', label: 'Endless' },
		{ key: 'daily', label: "Today's Song" }
	];

	/** Songs whose preview failed this session; left out of new rounds. */
	const broken = new Set<number>();

	let tab = $state(ALL);
	let day = $state(dayNumber());

	const game = $derived(library.game(page.params.id ?? ''));
	const mode = $derived(library.data.settings.mode);
	const tabs = $derived(game ? library.tabs(game) : []);
	const pool = $derived(game ? library.pool(game, tab) : []);
	/** Every song in the game: guesses can only be one of these. */
	const gameSongs = $derived(game ? library.pool(game, ALL).map((id) => library.song(id)).filter((s): s is Song => !!s) : []);
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

	/** Guesses come only from the songs in this playlist (or mix). */
	function searchGuesses(q: string): GuessOption[] {
		return searchSongs(gameSongs, q, 8).map((s) => ({
			id: s.id,
			title: s.title,
			artist: s.artist,
			artists: s.artists,
			isrc: s.isrc,
			cover: coverUrl(s)
		}));
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
			<h1>This Game Is Gone</h1>
			<p class="muted">Its playlist may have been deleted.</p>
			<a class="btn" href={resolve('/')}>Back to Playlists</a>
		</section>
	{:else}
		<header class="hero">
			<div class="hero-art"><Mosaic songs={art} seed={game.id} radius="var(--r-sm)" /></div>
			<div class="hero-text">
				<p class="eyebrow">{game.playlistIds.length > 1 ? 'Mix' : 'Playlist'}</p>
				<h1 title={game.name}>{game.name}</h1>
				<p class="meta">{plural(gameSongs.length, 'song')} · <a href={editHref}>Edit</a></p>
			</div>
			<button class="icon-btn help" type="button" aria-label="How to play" onclick={() => (ui.helpOpen = true)}>
				<Icon name="help" size={20} />
			</button>
		</header>

		<div class="controls">
			<Tabs size="small" label="Mode" tabs={MODES} bind:value={() => mode, (v) => library.setMode(v as Mode)} />
			{#if tabs.length > 1}
				<Tabs size="small" label="Playlist" {tabs} bind:value={tab} />
			{/if}
		</div>

		{#if pool.length === 0}
			<section class="missing">
				<p>No songs to play yet.</p>
				<a class="btn quiet" href={editHref}>Add Songs</a>
			</section>
		{:else if round && answer}
			{#key `${round.songId}:${tab}:${mode}`}
				<div class="round">
					<GuessBoard attempts={round.attempts} rows={steps.length} active={playing} />

					<section class="player" aria-label="Player">
						<Timeline
							steps={timelineSteps}
							{unlocked}
							position={player.position}
							label={playing ? formatSeconds(clip) : 'Full preview'}
							detail={playing ? `Try ${round.attempts.length + 1} of ${steps.length}` : `${round.attempts.length} of ${steps.length} tries used`}
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
								<button class="link" type="button" onclick={skipBroken}>Skip This Song</button>
							</p>
						{/if}
					</section>

					{#if playing}
						<GuessBox
							search={searchGuesses}
							onguess={onGuess}
							onskip={onSkip}
							guessed={round.attempts.flatMap((a) => (a.kind === 'guess' ? [a.pick.id] : []))}
						/>
						<p class="hint">Guesses come from this {game.playlistIds.length > 1 ? 'mix' : 'playlist'}. Space plays the clip.</p>
					{:else}
						<RoundResult
							song={answer}
							{round}
							{steps}
							playing={player.playing}
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

	.hero {
		display: flex;
		align-items: center;
		gap: 16px;
		min-width: 0;
		margin: 12px 0 20px;
		animation: rise var(--t-slow) var(--ease-out) both;
	}

	.hero-art {
		width: 76px;
		flex: none;
		border-radius: var(--r-sm);
		box-shadow: var(--shadow-art);
	}

	.hero-text {
		flex: 1;
		min-width: 0;
	}

	.hero h1 {
		overflow: hidden;
		font-size: var(--fs-hero);
		text-overflow: ellipsis;
		white-space: nowrap;
	}

	.meta {
		color: var(--fg-3);
		font-size: var(--fs-sm);
	}

	.meta a {
		color: var(--accent-text);
		font-weight: 500;
		text-decoration: none;
	}

	.meta a:hover {
		text-decoration: underline;
	}

	.help {
		align-self: flex-start;
	}

	.controls {
		display: flex;
		flex-wrap: wrap;
		gap: 10px;
		margin-bottom: 20px;
	}

	.round {
		display: grid;
		gap: 20px;
		animation: rise var(--t-slow) var(--ease-out) both;
	}

	.player {
		display: grid;
		gap: 22px;
		padding: 18px 20px 22px;
		border-radius: var(--r-xl);
		background: var(--surface);
	}

	.error {
		margin-top: -8px;
		color: var(--bad);
		font-size: var(--fs-sm);
		text-align: center;
	}

	.link {
		margin-left: 8px;
		padding: 0;
		border: 0;
		background: none;
		color: var(--accent-text);
		font-size: var(--fs-sm);
		font-weight: 600;
	}

	.link:hover {
		text-decoration: underline;
	}

	.hint {
		margin-top: -10px;
		color: var(--fg-3);
		font-size: var(--fs-sm);
		text-align: center;
	}

	.missing {
		display: grid;
		justify-items: center;
		gap: 12px;
		margin-top: 64px;
		text-align: center;
	}
</style>
