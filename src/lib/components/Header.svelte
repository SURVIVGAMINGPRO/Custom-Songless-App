<script lang="ts">
	import { resolve } from '$app/paths';
	import { page } from '$app/state';
	import { APP_NAME } from '#lib/config.ts';
	import Icon from './Icon.svelte';
	import Logo from './Logo.svelte';

	const at = $derived(page.route.id ?? '');
</script>

<header>
	<a class="brand" href={resolve('/')} aria-label="{APP_NAME}, your playlists">
		<Logo size={30} />
		<span class="wordmark">{APP_NAME}</span>
	</a>
	<nav aria-label="Main">
		<a class="icon-btn" href={resolve('/stats')} aria-label="Stats" aria-current={at === '/stats' ? 'page' : undefined}>
			<Icon name="chart" size={20} />
		</a>
		<a
			class="icon-btn"
			href={resolve('/settings')}
			aria-label="Settings"
			aria-current={at === '/settings' ? 'page' : undefined}
		>
			<Icon name="settings" size={20} />
		</a>
		<a class="btn add" href={resolve('/import')} aria-current={at === '/import' ? 'page' : undefined}>
			<Icon name="plus" size={18} /><span class="add-text">Add playlist</span>
		</a>
	</nav>
</header>

<style>
	header {
		position: sticky;
		top: 0;
		z-index: 20;
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: 12px;
		max-width: var(--wide);
		margin: 0 auto;
		padding: 14px var(--gutter);
		background: linear-gradient(var(--bg) 60%, rgb(16 16 18 / 0));
	}

	@media (min-width: 720px) {
		header {
			padding: 18px 32px;
		}
	}

	.brand {
		display: inline-flex;
		align-items: center;
		gap: 10px;
		padding: 4px 6px 4px 2px;
		border-radius: var(--r-md);
		text-decoration: none;
	}

	.brand :global(.logo) {
		transition: transform var(--t-med) var(--ease-pop);
	}

	.brand:hover :global(.logo) {
		transform: rotate(-8deg) scale(1.06);
	}

	.wordmark {
		font-family: var(--font-display);
		font-size: 26px;
		font-weight: 800;
		font-variation-settings: 'wdth' 85;
		letter-spacing: -0.03em;
		line-height: 1;
	}

	nav {
		display: flex;
		align-items: center;
		gap: 4px;
	}

	nav [aria-current='page']:not(.btn) {
		color: var(--accent);
	}

	.add {
		margin-left: 6px;
	}

	@media (max-width: 480px) {
		.add {
			width: 40px;
			padding: 0;
		}

		.add-text {
			display: none;
		}
	}
</style>
