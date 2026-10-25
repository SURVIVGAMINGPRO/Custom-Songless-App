<script lang="ts">
	import { goto } from '$app/navigation';
	import { resolve } from '$app/paths';
	import { page } from '$app/state';
	import Confirm from '#lib/components/Confirm.svelte';
	import Icon from '#lib/components/Icon.svelte';
	import PageHead from '#lib/components/PageHead.svelte';
	import { DEFAULT_STEPS, parseSteps } from '#lib/game/engine.ts';
	import type { GuessScope } from '#lib/game/types.ts';
	import { playGame } from '#lib/nav.ts';
	import { library } from '#lib/store/library.svelte.ts';
	import { toasts } from '#lib/toast.svelte.ts';
	import { plural } from '#lib/util.ts';

	const gid = $derived(page.params.id ?? '');
	const isNew = $derived(gid === 'new');
	const game = $derived(isNew ? undefined : library.game(gid));

	let name = $derived(game?.name ?? '');
	let chosen = $derived<string[]>(game ? [...game.playlistIds] : []);
	let scope = $derived<GuessScope>(game?.guessScope ?? 'catalog');
	let stepsText = $derived((game?.steps ?? DEFAULT_STEPS).join(', '));
	let confirmDelete = $state(false);

	const steps = $derived(parseSteps(stepsText));
	const stepsError = $derived(typeof steps === 'string' ? steps : '');
	const canSave = $derived(chosen.length >= 2 && !stepsError);

	function toggle(id: string, on: boolean) {
		chosen = on ? [...chosen, id] : chosen.filter((x) => x !== id);
	}

	function save(e: SubmitEvent) {
		e.preventDefault();
		if (!canSave || typeof steps === 'string') return;
		const fallback = chosen.map((id) => library.playlist(id)?.name).filter(Boolean).slice(0, 2).join(' + ') || 'New mix';
		if (game) {
			library.updateGame(game, { name: name.trim() || game.name, playlistIds: chosen, steps, guessScope: scope });
			toasts.show('Saved the mix');
		} else {
			const g = library.createGame({ name: name.trim() || fallback, playlistIds: chosen, steps, guessScope: scope });
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

{#if !isNew && !game}
	<PageHead title="Mix not found" />
	<a class="btn quiet" href={resolve('/')}>Back to your playlists</a>
{:else}
	<PageHead title={isNew ? 'New mix' : 'Edit mix'} sub="Put several playlists in one game. Each gets its own tab, plus All.">
		{#snippet actions()}
			{#if game}
				<button class="btn danger" type="button" onclick={() => (confirmDelete = true)}>
					<Icon name="trash" size={18} /> Delete
				</button>
			{/if}
		{/snippet}
	</PageHead>

	<form onsubmit={save}>
		<div>
			<label class="label" for="g-name">Name</label>
			<input id="g-name" class="field" maxlength="60" placeholder="Road trip" bind:value={name} />
		</div>

		<fieldset>
			<legend class="label">Playlists</legend>
			{#if library.data.playlists.length === 0}
				<p class="muted">No playlists yet. <a href={resolve('/import')}>Import one</a> first.</p>
			{:else}
				<p class="muted hint">Pick two or more.</p>
				<div class="choices">
					{#each library.data.playlists as p (p.id)}
						<label class="choice">
							<input
								type="checkbox"
								checked={chosen.includes(p.id)}
								onchange={(e) => toggle(p.id, (e.currentTarget as HTMLInputElement).checked)}
							/>
							<span class="choice-name">{p.name}</span>
							<span class="muted">{plural(p.songIds.length, 'song')}</span>
						</label>
					{/each}
				</div>
			{/if}
		</fieldset>

		<fieldset>
			<legend class="label">Guesses come from</legend>
			<div class="choices">
				<label class="choice">
					<input type="radio" name="scope" value="catalog" bind:group={scope} />
					<span class="choice-name">All of Deezer</span>
					<span class="muted">Like Songless: the answer isn't given away</span>
				</label>
				<label class="choice">
					<input type="radio" name="scope" value="game" bind:group={scope} />
					<span class="choice-name">Only this mix's songs</span>
					<span class="muted">Easier</span>
				</label>
			</div>
		</fieldset>

		<div>
			<label class="label" for="g-steps">Clip lengths (seconds)</label>
			<input
				id="g-steps"
				class="field"
				bind:value={stepsText}
				aria-invalid={!!stepsError}
				aria-describedby="g-steps-help"
			/>
			<p id="g-steps-help" class="hint" class:error={!!stepsError}>
				{stepsError || `One per try. Songless uses ${DEFAULT_STEPS.join(', ')}.`}
			</p>
		</div>

		<div class="row">
			<button class="btn" type="submit" disabled={!canSave}>{isNew ? 'Make the mix and play' : 'Save'}</button>
			<a class="btn quiet" href={resolve('/')}>Cancel</a>
		</div>
	</form>

	{#if game}
		<Confirm
			bind:open={confirmDelete}
			title="Delete this mix?"
			message="Its stats go with it. The playlists stay."
			confirm="Delete mix"
			onconfirm={remove}
		/>
	{/if}
{/if}

<style>
	form {
		display: grid;
		gap: 24px;
	}

	fieldset {
		margin: 0;
		padding: 0;
		border: 0;
	}

	.choices {
		display: grid;
		gap: 6px;
	}

	.choice {
		display: flex;
		align-items: center;
		flex-wrap: wrap;
		gap: 4px 12px;
		min-height: 48px;
		padding: 10px 14px;
		border: 1px solid var(--line);
		border-radius: var(--r-md);
		background: var(--surface);
		cursor: pointer;
		transition: border-color var(--t-fast);
	}

	.choice:hover {
		border-color: var(--line-strong);
	}

	.choice:has(input:checked) {
		border-color: var(--fg-3);
	}

	.choice input {
		width: 18px;
		height: 18px;
		margin: 0;
		accent-color: var(--accent);
	}

	.choice-name {
		flex: 1;
		min-width: 0;
		font-weight: 500;
	}

	.choice .muted {
		font-size: 13px;
	}

	.hint {
		margin: 6px 0 0;
		color: var(--fg-3);
		font-size: 13px;
	}

	fieldset .hint {
		margin: 0 0 8px;
	}

	.error {
		color: var(--bad-soft);
	}

	.row {
		display: flex;
		gap: 8px;
	}
</style>
