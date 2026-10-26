<script lang="ts">
	import { DEFAULT_STEPS, formatSeconds } from '#lib/game/engine.ts';
	import Dialog from './Dialog.svelte';
	import Icon from './Icon.svelte';

	let { open = $bindable(false) }: { open?: boolean } = $props();

	const ladder = DEFAULT_STEPS.map((s) => formatSeconds(s, true)).join(', ');
	const rows = [
		{ kind: 'bad', glyph: 'm8.8 8.8 6.4 6.4M15.2 8.8l-6.4 6.4', text: 'Wrong artist and song' },
		{
			kind: 'near',
			glyph: 'M12 12.2a2.4 2.4 0 1 0 0-4.8 2.4 2.4 0 0 0 0 4.8ZM7.6 17c.6-2 2.3-3 4.4-3s3.8 1 4.4 3',
			text: 'Right artist, wrong song'
		},
		{ kind: 'good', glyph: 'm7.5 12.5 3 3 6-6.5', text: 'Got it' }
	];
</script>

<Dialog bind:open title="How to Play">
	<p class="lead">
		Listen to a tiny clip from your playlist and guess the song. Each wrong guess or skip plays a longer clip.
	</p>

	<ul class="group">
		<li class="row">
			<span class="play"><Icon name="play" size={12} /></span>
			<span class="text">Play the current clip</span>
		</li>
		<li class="row">
			<span class="skip"><Icon name="forward" size={13} /></span>
			<span class="text">Skip to a longer clip</span>
		</li>
		{#each rows as r (r.kind)}
			<li class="row {r.kind}">
				<svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="12" r="10" /><path d={r.glyph} /></svg>
				<span class="text">{r.text}</span>
			</li>
		{/each}
	</ul>

	<p class="small">
		Search shows only songs from the playlist you're playing. Clips are {ladder} long, five tries in all, taken from
		each song's 30-second Deezer preview (which often starts partway into the song).
	</p>
</Dialog>

<style>
	.lead {
		margin-bottom: 14px;
		color: var(--fg-2);
	}

	.group {
		background: var(--fill-3);
	}

	.row {
		display: flex;
		align-items: center;
		gap: 12px;
		padding: 10px 14px;
		font-size: var(--fs-md);
	}

	.play,
	.skip,
	svg {
		display: grid;
		flex: none;
		place-items: center;
		width: 24px;
		height: 24px;
		border-radius: var(--r-full);
	}

	.play {
		background: var(--accent);
		color: var(--accent-ink);
	}

	.play :global(svg) {
		margin-left: 1px;
	}

	.skip {
		background: var(--fill);
		color: var(--fg-2);
	}

	circle {
		fill: currentColor;
	}

	path {
		fill: none;
		stroke: var(--on-color);
		stroke-width: 2;
		stroke-linecap: round;
		stroke-linejoin: round;
	}

	.bad {
		color: var(--bad);
	}

	.near {
		color: var(--near);
	}

	.good {
		color: var(--good);
	}

	.text {
		color: var(--fg);
	}

	.small {
		margin-top: 14px;
		color: var(--fg-3);
		font-size: var(--fs-sm);
	}
</style>
