<script lang="ts">
	import { player } from '#lib/audio/player.svelte.ts';
	import Confirm from '#lib/components/Confirm.svelte';
	import Icon from '#lib/components/Icon.svelte';
	import PageHead from '#lib/components/PageHead.svelte';
	import { library } from '#lib/store/library.svelte.ts';
	import { toasts } from '#lib/toast.svelte.ts';
	import { saveTextFile } from '#lib/platform.ts';

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
			toasts.show("That file is too big to be a backup", 'error');
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

<PageHead title="Settings" />

<section>
	<label class="label" for="volume">Volume <span class="value">{volume}%</span></label>
	<input id="volume" type="range" min="0" max="100" step="1" bind:value={volume} oninput={setVolume} />
</section>

<section>
	<h2>Backup</h2>
	<p class="muted">Your playlists, mixes and stats are saved on this device only. Save a backup to move them or keep them safe.</p>
	<div class="row">
		<button class="btn quiet" type="button" onclick={backup}><Icon name="share" size={18} /> Save a backup</button>
		<button class="btn quiet" type="button" onclick={() => fileInput.click()}>
			<Icon name="upload" size={18} /> Restore a backup
		</button>
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
	</div>
</section>

<section>
	<h2>Start over</h2>
	<p class="muted">Delete every playlist, mix and stat on this device.</p>
	<div class="row">
		<button class="btn danger" type="button" onclick={() => (confirmReset = true)}>Delete everything</button>
	</div>
</section>

<section>
	<h2>About</h2>
	<p class="muted">
		Song clips and search come from Deezer's free previews and API. Spotify playlists come in through files you
		export yourself; this app never connects to Spotify. Not connected with Deezer, Spotify or Lessgames' Songless.
	</p>
</section>

<Confirm
	bind:open={confirmRestore}
	title="Restore this backup?"
	message="It replaces every playlist, mix and stat on this device."
	confirm="Replace with backup"
	onconfirm={restore}
/>
<Confirm
	bind:open={confirmReset}
	title="Delete everything?"
	message="Every playlist, mix and stat on this device is deleted. Save a backup first if you might want them back."
	confirm="Delete everything"
	onconfirm={reset}
/>

<style>
	section {
		margin-top: 32px;
	}

	section:first-of-type {
		margin-top: 0;
	}

	h2 {
		margin-bottom: 8px;
		font-size: 20px;
		font-weight: 500;
	}

	.value {
		margin-left: 6px;
		color: var(--fg-2);
	}

	input[type='range'] {
		width: min(360px, 100%);
		accent-color: var(--accent);
	}

	.row {
		display: flex;
		flex-wrap: wrap;
		gap: 8px;
		margin-top: 12px;
	}

	.muted {
		max-width: 60ch;
		font-size: 14px;
	}
</style>
