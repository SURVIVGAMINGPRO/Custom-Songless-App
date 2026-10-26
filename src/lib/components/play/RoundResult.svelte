<script lang="ts">
	import Icon from '#lib/components/Icon.svelte';
	import { formatSeconds } from '#lib/game/engine.ts';
	import type { Round, Song } from '#lib/game/types.ts';
	import { deezerTrackUrl, spotifyTrackUrl } from '#lib/sources/links.ts';
	import { coverUrl, untilMidnight, validSpotifyId } from '#lib/util.ts';

	let {
		song,
		round,
		steps,
		playing,
		onshare,
		onnext
	}: {
		song: Song;
		round: Round;
		steps: number[];
		/** The artwork grows while the preview plays, as in Apple Music. */
		playing: boolean;
		onshare: () => void;
		/** Endless mode only. */
		onnext?: () => void;
	} = $props();

	const won = $derived(round.status === 'won');
	const tries = $derived(round.attempts.length);
	const cover = $derived(coverUrl(song));
	let wait = $state(untilMidnight());

	$effect(() => {
		if (round.mode !== 'daily') return;
		const t = setInterval(() => (wait = untilMidnight()), 30_000);
		return () => clearInterval(t);
	});
</script>

<section class="result" aria-live="polite">
	<div class="art" class:playing>
		{#if cover}
			<img src={cover} alt="" width="168" height="168" />
		{:else}
			<span class="art-empty"><Icon name="music" size={40} /></span>
		{/if}
	</div>

	<div class="body">
		<p class="verdict" class:won>
			<svg viewBox="0 0 24 24" aria-hidden="true">
				<circle cx="12" cy="12" r="10" />
				<path d={won ? 'm7.5 12.5 3 3 6-6.5' : 'm8.8 8.8 6.4 6.4M15.2 8.8l-6.4 6.4'} />
			</svg>
			{#if won}
				Got it in {tries} · {formatSeconds(steps[tries - 1])}
			{:else}
				Out of tries
			{/if}
		</p>
		<h2 class="title" title={song.title}>{song.title}</h2>
		<p class="artist">{song.artists.join(', ')}</p>

		<div class="actions">
			{#if onnext}
				<button class="btn" type="button" onclick={onnext}>
					Next Song <Icon name="forward" size={14} />
				</button>
			{/if}
			<button class="btn quiet" type="button" onclick={onshare}><Icon name="share" size={16} /> Share</button>
			{#if validSpotifyId(song.spotify)}
				<a class="btn quiet" href={spotifyTrackUrl(song.spotify)} target="_blank" rel="noopener noreferrer">
					Spotify <Icon name="external" size={14} />
				</a>
			{/if}
			<a class="btn quiet" href={deezerTrackUrl(song.id)} target="_blank" rel="noopener noreferrer">
				Deezer <Icon name="external" size={14} />
			</a>
		</div>
		{#if !onnext}
			<p class="wait"><Icon name="calendar" size={14} /> Next song of the day in {wait}</p>
		{/if}
	</div>
</section>

<style>
	.result {
		display: grid;
		grid-template-columns: auto minmax(0, 1fr);
		align-items: center;
		gap: 20px 28px;
		padding: 20px;
		border-radius: var(--r-xl);
		background: var(--surface);
		animation: rise var(--t-slow) var(--ease-out) both;
	}

	@media (max-width: 560px) {
		.result {
			grid-template-columns: minmax(0, 1fr);
			justify-items: center;
			text-align: center;
		}

		.actions {
			justify-content: center;
		}
	}

	/* The artwork is full size while the preview plays and settles back when it stops. */
	.art {
		width: 168px;
		height: 168px;
		overflow: hidden;
		border-radius: var(--r-md);
		background: var(--fill-2);
		box-shadow: var(--shadow-art);
		transform: scale(0.88);
		transition:
			transform 600ms var(--ease-pop),
			box-shadow 600ms var(--ease-out);
	}

	.art.playing {
		transform: none;
		box-shadow: 0 14px 40px rgb(0 0 0 / 0.35);
	}

	.art img {
		width: 100%;
		height: 100%;
		object-fit: cover;
	}

	.art-empty {
		display: grid;
		place-items: center;
		height: 100%;
		color: var(--fg-3);
	}

	.verdict {
		display: inline-flex;
		align-items: center;
		gap: 6px;
		color: var(--bad);
		font-size: var(--fs-sm);
		font-weight: 600;
	}

	.verdict.won {
		color: var(--good);
	}

	.verdict svg {
		width: 18px;
		height: 18px;
		animation: pop var(--t-slow) var(--ease-pop) 150ms both;
	}

	.verdict circle {
		fill: currentColor;
	}

	.verdict path {
		fill: none;
		stroke: var(--on-color);
		stroke-width: 2;
		stroke-linecap: round;
		stroke-linejoin: round;
	}

	@keyframes pop {
		from {
			transform: scale(0.3);
			opacity: 0;
		}
	}

	.title {
		margin-top: 6px;
		overflow: hidden;
		font-size: var(--fs-xl);
		text-overflow: ellipsis;
		white-space: nowrap;
	}

	.artist {
		overflow: hidden;
		color: var(--fg-3);
		font-size: var(--fs-lg);
		text-overflow: ellipsis;
		white-space: nowrap;
	}

	.actions {
		display: flex;
		flex-wrap: wrap;
		gap: 8px;
		margin-top: 16px;
	}

	.wait {
		display: flex;
		align-items: center;
		gap: 6px;
		margin-top: 12px;
		color: var(--fg-3);
		font-size: var(--fs-sm);
	}
</style>
