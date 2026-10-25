<script lang="ts">
	import { DEFAULT_STEPS, formatSeconds } from '#lib/game/engine.ts';
	import Dialog from './Dialog.svelte';
	import Icon from './Icon.svelte';

	let { open = $bindable(false) }: { open?: boolean } = $props();

	const ladder = DEFAULT_STEPS.map((s) => formatSeconds(s, true)).join(', ');
</script>

<Dialog bind:open title="How to play">
	<p class="lead">Listen to a tiny clip and guess the song. Each wrong guess or skip unlocks a longer clip.</p>

	<div class="demo">
		<div class="bar" aria-hidden="true">
			<span class="lit"></span><span class="lit"></span><span></span><span></span><span></span>
		</div>
		<div class="row">
			<span class="play"><Icon name="play" size={14} /></span>
			<span>Play the current clip</span>
		</div>
		<div class="row">
			<span class="skip">Skip</span>
			<span>Move on to a longer clip</span>
		</div>
		<hr />
		<div class="row"><span class="swatch bad"></span><span>Wrong artist and song</span></div>
		<div class="row"><span class="swatch near"></span><span>Right artist, wrong song</span></div>
		<div class="row"><span class="swatch good"></span><span>Got it</span></div>
	</div>

	<p class="small muted">
		Clips are {ladder} long, five tries in all. They come from each song's 30-second Deezer preview,
		which often starts partway into the song.
	</p>
</Dialog>

<style>
	.lead {
		color: var(--fg-2);
		margin-bottom: 16px;
	}

	.demo {
		display: grid;
		gap: 12px;
		padding: 16px;
		border: 1px solid var(--line);
		border-radius: var(--r-lg);
		background: var(--bg);
	}

	.bar {
		display: grid;
		grid-template-columns: 1fr 1fr 2fr 4fr 6fr;
		gap: 2px;
		height: 14px;
	}

	.bar span {
		background: var(--line);
	}

	.bar span {
		border-radius: 3px;
	}

	.bar span:first-child {
		border-radius: var(--r-full) 3px 3px var(--r-full);
	}

	.bar span:last-child {
		border-radius: 3px var(--r-full) var(--r-full) 3px;
	}

	.bar .lit {
		background: var(--accent);
	}

	.row {
		display: flex;
		align-items: center;
		gap: 12px;
		font-size: 15px;
	}

	.play {
		display: grid;
		place-items: center;
		width: 28px;
		height: 28px;
		border-radius: var(--r-full);
		background: var(--accent);
		color: var(--accent-ink);
	}

	.skip {
		display: grid;
		place-items: center;
		width: 48px;
		height: 28px;
		border: 1px solid var(--line-strong);
		border-radius: var(--r-full);
		color: var(--fg-2);
		font-size: 12px;
		font-weight: 600;
	}

	.swatch {
		width: 28px;
		height: 28px;
		border-radius: var(--r-sm);
	}

	.bad {
		background: var(--bad);
	}

	.near {
		background: var(--near);
	}

	.good {
		background: var(--good);
	}

	hr {
		width: 100%;
		margin: 0;
		border: 0;
		border-top: 1px solid var(--line);
	}

	.small {
		margin-top: 16px;
		font-size: 13px;
	}
</style>
