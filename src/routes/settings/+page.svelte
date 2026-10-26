<script lang="ts">
	import { player } from '#lib/audio/player.svelte.ts';
	import Confirm from '#lib/components/Confirm.svelte';
	import Icon from '#lib/components/Icon.svelte';
	import PageHead from '#lib/components/PageHead.svelte';
	import Tabs from '#lib/components/Tabs.svelte';
	import type { Appearance } from '#lib/game/types.ts';
	import { saveTextFile } from '#lib/platform.ts';
	import { library } from '#lib/store/library.svelte.ts';
	import { toasts } from '#lib/toast.svelte.ts';

	const APPEARANCES: { key: Appearance; label: string }[] = [
		{ key: 'system', label: 'Automatic' },
		{ key: 'light', label: 'Light' },
		{ key: 'dark', label: 'Dark' }
	];

	let volume = $state(Math.round(library.data.settings.volume * 100));
	let confirmReset = $state(false);
	let confirmRestore = $state(false);
	let pending = '';
	let fileInput: HTMLInputElement;

	function setVolume() {
		player.volume = volume / 100;
		library.setVolume(volume / 100);
	}

	async function backup() {
		const date = new Date().toISOString().slice(0, 10);
		try {
			if (await saveTextFile(`earshot-backup-${date}.json`, library.backup())) toasts.show('Saved a backup');
		} catch {
			toasts.show("Couldn't save the backup", 'error');
		}
	}

	async function pickRestore(file: File | undefined) {
		if (!file) return;
		if (file.size > 20 * 1024 * 1024) {
			toasts.show('That file is too big to be a backup', 'error');
			return;
		}
		pending = await file.text();
		confirmRestore = true;
	}

	function restore() {
		if (library.restore(pending)) {
			player.volume = library.data.settings.volume;
			volume = Math.round(library.data.settings.volume * 100);
			toasts.show('Restored your backup');
		} else toasts.show("That file isn't a backup from this app", 'error');
		pending = '';
	}

	function reset() {
		library.reset();
		toasts.show('Deleted everything');
	}
</script>

<div class="page">
	<PageHead title="Settings" />

	<section>
		<h2 class="group-title">Appearance</h2>
		<ul class="group">
			<li class="row">
				<span class="row-label">Theme</span>
				<Tabs
					size="small"
					label="Theme"
					tabs={APPEARANCES}
					bind:value={() => library.data.settings.appearance, (v) => library.setAppearance(v as Appearance)}
				/>
			</li>
		</ul>
		<p class="group-note">Automatic follows your system's light or dark setting.</p>
	</section>

	<section>
		<h2 class="group-title">Sound</h2>
		<ul class="group">
			<li class="row">
				<label class="row-label" for="volume">Volume</label>
				<span class="volume">
					<Icon name="speaker" size={16} />
					<input id="volume" type="range" min="0" max="100" step="1" bind:value={volume} oninput={setVolume} />
					<span class="value">{volume}%</span>
				</span>
			</li>
		</ul>
	</section>

	<section>
		<h2 class="group-title">Backup</h2>
		<ul class="group">
			<li>
				<button class="row action" type="button" onclick={backup}>
					<span class="row-label">Save a Backup…</span>
					<Icon name="chevron-right" size={16} />
				</button>
			</li>
			<li>
				<button class="row action" type="button" onclick={() => fileInput.click()}>
					<span class="row-label">Restore a Backup…</span>
					<Icon name="chevron-right" size={16} />
				</button>
			</li>
		</ul>
		<p class="group-note">Your playlists, mixes and stats are saved on this device only.</p>
		<input
			bind:this={fileInput}
			class="visually-hidden"
			type="file"
			accept=".json,application/json"
			tabindex="-1"
			aria-hidden="true"
			onchange={(e) => {
				pickRestore((e.currentTarget as HTMLInputElement).files?.[0]);
				(e.currentTarget as HTMLInputElement).value = '';
			}}
		/>
	</section>

	<section>
		<ul class="group">
			<li>
				<button class="row action destructive" type="button" onclick={() => (confirmReset = true)}>
					<span class="row-label">Delete Everything…</span>
				</button>
			</li>
		</ul>
	</section>

	<section>
		<h2 class="group-title">About</h2>
		<p class="about">
			Song clips and search come from Deezer's free previews and API. Spotify playlists come in through files you
			export yourself; this app never connects to Spotify. Not connected with Deezer, Spotify or Lessgames' Songless.
		</p>
	</section>
</div>

<Confirm
	bind:open={confirmRestore}
	title="Restore This Backup?"
	message="It replaces every playlist, mix and stat on this device."
	confirm="Replace"
	onconfirm={restore}
/>
<Confirm
	bind:open={confirmReset}
	title="Delete Everything?"
	message="Every playlist, mix and stat on this device is deleted. Save a backup first if you might want them back."
	confirm="Delete Everything"
	onconfirm={reset}
/>

<style>
	.page {
		max-width: 640px;
		margin: 0 auto;
	}

	section + section {
		margin-top: 26px;
	}

	.row {
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: 16px;
		width: 100%;
		min-height: 46px;
		padding: 7px 14px;
		border: 0;
		background: none;
		color: var(--fg);
		text-align: left;
	}

	.row-label {
		font-size: var(--fs-md);
	}

	.action {
		transition: background-color var(--t-fast);
	}

	.action:hover {
		background: var(--fill-3);
	}

	.action :global(svg) {
		color: var(--fg-4);
	}

	.destructive {
		color: var(--bad);
	}

	.volume {
		display: flex;
		align-items: center;
		gap: 10px;
		color: var(--fg-3);
	}

	input[type='range'] {
		width: min(220px, 40vw);
		accent-color: var(--accent);
	}

	.value {
		width: 40px;
		color: var(--fg-2);
		font-size: var(--fs-sm);
		font-variant-numeric: tabular-nums;
		text-align: right;
	}

	.about {
		margin: 0 14px;
		color: var(--fg-3);
		font-size: var(--fs-sm);
	}
</style>
