<script lang="ts">
	import { goto } from '$app/navigation';
	import { resolve } from '$app/paths';
	import { page } from '$app/state';
	import Confirm from '#lib/components/Confirm.svelte';
	import Icon from '#lib/components/Icon.svelte';
	import PageHead from '#lib/components/PageHead.svelte';
	import { DEFAULT_STEPS, parseSteps } from '#lib/game/engine.ts';
	import { playGame } from '#lib/nav.ts';
	import { library } from '#lib/store/library.svelte.ts';
	import { toasts } from '#lib/toast.svelte.ts';
	import { coverUrl, plural } from '#lib/util.ts';

	const gid = $derived(page.params.id ?? '');
	const isNew = $derived(gid === 'new');
	const game = $derived(isNew ? undefined : library.game(gid));

	let name = $derived(game?.name ?? '');
	let chosen = $derived<string[]>(game ? [...game.playlistIds] : []);
	let stepsText = $derived((game?.steps ?? DEFAULT_STEPS).join(', '));
	let confirmDelete = $state(false);

	const steps = $derived(parseSteps(stepsText));
	const stepsError = $derived(typeof steps === 'string' ? steps : '');
	const canSave = $derived(chosen.length >= 2 && !stepsError);

	function toggle(id: string, on: boolean) {
		chosen = on ? [...chosen, id] : chosen.filter((x) => x !== id);
	}

	function cover(playlistId: string): string | null {
		for (const sid of library.playlist(playlistId)?.songIds.slice(0, 6) ?? []) {
			const url = coverUrl(library.song(sid));
			if (url) return url;
		}
		return null;
	}

	function save(e: SubmitEvent) {
		e.preventDefault();
		if (!canSave || typeof steps === 'string') return;
		const fallback = chosen.map((id) => library.playlist(id)?.name).filter(Boolean).slice(0, 2).join(' + ') || 'New Mix';
		if (game) {
			library.updateGame(game, { name: name.trim() || game.name, playlistIds: chosen, steps });
			toasts.show('Saved the mix');
		} else {
			const g = library.createGame({ name: name.trim() || fallback, playlistIds: chosen, steps, guessScope: 'game' });
			playGame(g);
		}
	}

	function remove() {
		if (!game) return;
		library.deleteGame(game);
		toasts.show('Deleted the mix');
		goto(resolve('/'));
	}
</script>

<div class="page">
	{#if !isNew && !game}
		<PageHead title="Mix Not Found" />
		<a class="btn quiet" href={resolve('/')}>Back to Playlists</a>
	{:else}
		<PageHead title={isNew ? 'New Mix' : 'Edit Mix'} sub="Several playlists in one game. Each gets its own tab, plus All.">
			{#snippet actions()}
				{#if game}
					<button class="btn" type="button" onclick={() => playGame(game)}><Icon name="play" size={14} /> Play</button>
				{/if}
			{/snippet}
		</PageHead>

		<form onsubmit={save}>
			<section>
				<label class="group-title" for="g-name">Name</label>
				<input id="g-name" class="field big" maxlength="60" placeholder="Road Trip" bind:value={name} />
			</section>

			<fieldset>
				<legend class="group-title">Playlists</legend>
				{#if library.data.playlists.length === 0}
					<p class="muted">No playlists yet. <a href={resolve('/import')}>Add one</a> first.</p>
				{:else}
					<ul class="group">
						{#each library.data.playlists as p (p.id)}
							{@const art = cover(p.id)}
							<li>
								<label class="choice">
									{#if art}
										<img src={art} alt="" width="32" height="32" loading="lazy" />
									{:else}
										<span class="no-art"><Icon name="music" size={15} /></span>
									{/if}
									<span class="choice-text">
										<span class="choice-name">{p.name}</span>
										<span class="muted small">{plural(p.songIds.length, 'song')}</span>
									</span>
									<input
										class="switch"
										type="checkbox"
										role="switch"
										checked={chosen.includes(p.id)}
										onchange={(e) => toggle(p.id, (e.currentTarget as HTMLInputElement).checked)}
									/>
								</label>
							</li>
						{/each}
					</ul>
					<p class="group-note">Pick two or more. Guesses come only from the songs in these playlists.</p>
				{/if}
			</fieldset>

			<section>
				<label class="group-title" for="g-steps">Clip Lengths (Seconds)</label>
				<input
					id="g-steps"
					class="field big"
					bind:value={stepsText}
					aria-invalid={!!stepsError}
					aria-describedby="g-steps-help"
				/>
				<p id="g-steps-help" class="group-note" class:error={!!stepsError}>
					{stepsError || `One per try. Songless uses ${DEFAULT_STEPS.join(', ')}.`}
				</p>
			</section>

			<div class="buttons">
				{#if game}
					<button class="btn danger" type="button" onclick={() => (confirmDelete = true)}>
						<Icon name="trash" size={15} /> Delete Mix
					</button>
				{/if}
				<span class="spacer"></span>
				<a class="btn quiet" href={resolve('/')}>Cancel</a>
				<button class="btn" type="submit" disabled={!canSave}>{isNew ? 'Create and Play' : 'Save'}</button>
			</div>
		</form>

		{#if game}
			<Confirm
				bind:open={confirmDelete}
				title="Delete “{game.name}”?"
				message="Its stats go with it. The playlists stay."
				confirm="Delete"
				onconfirm={remove}
			/>
		{/if}
	{/if}
</div>

<style>
	.page {
		max-width: var(--content);
		margin: 0 auto;
	}

	form {
		display: grid;
		gap: 26px;
	}

	fieldset {
		margin: 0;
		padding: 0;
		border: 0;
	}

	legend {
		padding: 0;
	}

	.group-title {
		display: block;
	}

	.big {
		height: 40px;
		background: var(--surface);
	}

	.choice {
		display: flex;
		align-items: center;
		gap: 12px;
		min-height: 52px;
		padding: 8px 14px;
		cursor: pointer;
		transition: background-color var(--t-fast);
	}

	.choice:hover {
		background: var(--fill-3);
	}

	.choice img,
	.no-art {
		flex: none;
		width: 32px;
		height: 32px;
		border-radius: 5px;
		object-fit: cover;
		background: var(--fill-2);
	}

	.no-art {
		display: grid;
		place-items: center;
		color: var(--fg-3);
	}

	.choice-text {
		display: grid;
		flex: 1;
		min-width: 0;
	}

	.choice-name {
		overflow: hidden;
		font-weight: 500;
		text-overflow: ellipsis;
		white-space: nowrap;
	}

	.small {
		font-size: var(--fs-sm);
	}

	/* An Apple-style switch */
	.switch {
		position: relative;
		flex: none;
		width: 42px;
		height: 26px;
		margin: 0;
		border-radius: var(--r-full);
		background: var(--fill);
		appearance: none;
		cursor: pointer;
		transition: background-color var(--t-med) var(--ease-out);
	}

	.switch::after {
		content: '';
		position: absolute;
		top: 2px;
		left: 2px;
		width: 22px;
		height: 22px;
		border-radius: var(--r-full);
		background: var(--on-color);
		box-shadow: 0 2px 4px rgb(0 0 0 / 0.2);
		transition: transform var(--t-med) var(--ease-pop);
	}

	.switch:checked {
		background: var(--good);
	}

	.switch:checked::after {
		transform: translateX(16px);
	}

	.error {
		color: var(--bad);
	}

	.buttons {
		display: flex;
		flex-wrap: wrap;
		align-items: center;
		gap: 8px;
	}

	.spacer {
		flex: 1;
	}
</style>
