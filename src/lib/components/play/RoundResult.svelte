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
		spinning,
		onshare,
		onnext
	}: {
		song: Song;
		round: Round;
		steps: number[];
		/** The record turns while the preview plays. */
		spinning: boolean;
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

<section class="result" class:won aria-live="polite">
	<div class="record" class:spinning>
		<span class="disc" aria-hidden="true">
			{#if cover}<img class="label-art" src={cover} alt="" />{/if}
		</span>
		<span class="sleeve">
			{#if cover}
				<img src={cover} alt="" width="112" height="112" />
			{:else}
				<span class="sleeve-empty"><Icon name="music" size={32} /></span>
			{/if}
		</span>
		{#if won}
			<span class="burst" aria-hidden="true">
				{#each { length: 8 }, i (i)}<i style:--a="{i * 45}deg"></i>{/each}
			</span>
		{/if}
	</div>

	<div class="body">
		<p class="verdict">
			{#if won}
				Got it in {tries} · {formatSeconds(steps[tries - 1])}
			{:else}
				Out of tries. It was
			{/if}
		</p>
		<h2 class="title" title={song.title}>{song.title}</h2>
		<p class="artist">{song.artists.join(', ')}</p>

		<div class="actions">
			{#if onnext}
				<button class="btn" type="button" onclick={onnext}>
					Next song <Icon name="arrow-right" size={18} />
				</button>
			{/if}
			<button class="btn quiet" type="button" onclick={onshare}><Icon name="share" size={17} /> Share</button>
			{#if validSpotifyId(song.spotify)}
				<a class="btn ghost" href={spotifyTrackUrl(song.spotify)} target="_blank" rel="noopener noreferrer">
					Spotify <Icon name="external" size={15} />
				</a>
			{/if}
			<a class="btn ghost" href={deezerTrackUrl(song.id)} target="_blank" rel="noopener noreferrer">
				Deezer <Icon name="external" size={15} />
			</a>
		</div>
		{#if !onnext}
			<p class="wait"><Icon name="calendar" size={15} /> Next song of the day in {wait}</p>
		{/if}
	</div>
</section>

<style>
	.result {
		display: grid;
		grid-template-columns: auto 1fr;
		align-items: center;
		gap: 20px 64px;
		margin-top: 32px;
		padding: 24px 24px 24px 20px;
		overflow: hidden;
		border: 1px solid var(--line);
		border-radius: var(--r-xl);
		background:
			radial-gradient(400px 200px at 0% 0%, rgb(255 255 255 / 0.04), transparent 70%),
			var(--surface);
		animation: rise var(--t-slow) var(--ease-out) both;
	}

	.result.won {
		border-color: rgb(61 220 151 / 0.35);
	}

	@media (max-width: 560px) {
		.result {
			grid-template-columns: 1fr;
			justify-items: start;
			padding: 20px;
		}
	}

	/* The answer comes out like a record from its sleeve. */
	.record {
		position: relative;
		width: 112px;
		height: 112px;
	}

	.sleeve {
		position: relative;
		z-index: 2;
		display: block;
		width: 112px;
		height: 112px;
		overflow: hidden;
		border-radius: var(--r-sm);
		background: var(--surface-2);
		box-shadow: 6px 0 18px rgb(0 0 0 / 0.5);
	}

	.sleeve img {
		width: 100%;
		height: 100%;
		object-fit: cover;
	}

	.sleeve-empty {
		display: grid;
		place-items: center;
		height: 100%;
		color: var(--fg-4);
	}

	.disc {
		position: absolute;
		top: 4px;
		left: 4px;
		z-index: 1;
		display: grid;
		place-items: center;
		width: 104px;
		height: 104px;
		border-radius: var(--r-full);
		background:
			conic-gradient(
				from 20deg,
				transparent 0 8%,
				rgb(255 255 255 / 0.14) 13%,
				transparent 20% 55%,
				rgb(255 255 255 / 0.1) 61%,
				transparent 68%
			),
			radial-gradient(circle, transparent 0 17%, rgb(255 255 255 / 0.18) 17.5% 18.5%, transparent 19%),
			repeating-radial-gradient(circle, #121215 0 1.5px, #34343c 1.5px 3px);
		box-shadow:
			0 0 0 1px rgb(255 255 255 / 0.12),
			0 6px 16px rgb(0 0 0 / 0.5);
		animation: slide-out 700ms var(--ease-out) 250ms both;
	}

	.label-art {
		width: 38%;
		height: 38%;
		border-radius: var(--r-full);
		object-fit: cover;
	}

	.spinning .disc {
		animation:
			slide-out 700ms var(--ease-out) 250ms both,
			turn 1.8s linear 950ms infinite;
	}

	@keyframes slide-out {
		from {
			transform: translateX(0) rotate(0deg);
		}
		to {
			transform: translateX(52%) rotate(120deg);
		}
	}

	@keyframes turn {
		from {
			transform: translateX(52%) rotate(120deg);
		}
		to {
			transform: translateX(52%) rotate(480deg);
		}
	}

	/* A small yellow burst when you get it. */
	.burst {
		position: absolute;
		inset: 50%;
		z-index: 3;
	}

	.burst i {
		position: absolute;
		width: 6px;
		height: 6px;
		margin: -3px;
		border-radius: var(--r-full);
		background: var(--accent);
		opacity: 0;
		animation: burst 700ms var(--ease-out) 200ms;
	}

	@keyframes burst {
		from {
			opacity: 1;
			transform: rotate(var(--a)) translateY(0) scale(1);
		}
		to {
			opacity: 0;
			transform: rotate(var(--a)) translateY(-78px) scale(0.4);
		}
	}

	.body {
		min-width: 0;
		width: 100%;
	}

	.verdict {
		color: var(--fg-3);
		font-size: var(--fs-sm);
		font-weight: 600;
	}

	.won .verdict {
		color: var(--good);
	}

	.title {
		margin-top: 6px;
		overflow: hidden;
		font-size: clamp(22px, 4vw, 28px);
		text-overflow: ellipsis;
		white-space: nowrap;
	}

	.artist {
		overflow: hidden;
		color: var(--fg-2);
		text-overflow: ellipsis;
		white-space: nowrap;
	}

	.actions {
		display: flex;
		flex-wrap: wrap;
		gap: 8px;
		margin-top: 18px;
	}

	.wait {
		display: flex;
		align-items: center;
		gap: 6px;
		margin-top: 14px;
		color: var(--fg-3);
		font-size: var(--fs-sm);
	}

	@media (prefers-reduced-motion: reduce) {
		.disc,
		.spinning .disc {
			animation: none;
			transform: translateX(52%);
		}

		.burst {
			display: none;
		}
	}
</style>
