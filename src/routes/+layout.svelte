<script lang="ts">
	import '@fontsource-variable/bricolage-grotesque';
	import '@fontsource-variable/dm-sans';
	import '../app.css';
	import { onNavigate } from '$app/navigation';
	import { page } from '$app/state';
	import { onMount } from 'svelte';
	import { player } from '#lib/audio/player.svelte.ts';
	import favicon from '#lib/assets/favicon.svg';
	import Header from '#lib/components/Header.svelte';
	import HowToPlay from '#lib/components/HowToPlay.svelte';
	import Logo from '#lib/components/Logo.svelte';
	import Toasts from '#lib/components/Toasts.svelte';
	import { isDesktop, ms, openExternal } from '#lib/platform.ts';
	import { library } from '#lib/store/library.svelte.ts';
	import { ui } from '#lib/ui.svelte.ts';
	import type { LayoutProps } from './$types';

	let { children }: LayoutProps = $props();

	library.load().then(() => {
		player.volume = library.data.settings.volume;
	});

	// The logo shows for a beat when the app opens, then zooms towards you and
	// fades (VC Alert's launch, Animista slide-out-fwd-center). A timer removes
	// it, so it never lingers even if no animation ran.
	let splash = $state(true);
	onMount(() => {
		const t = setTimeout(() => (splash = false), ms('--t-launch-hold') + ms('--t-launch') + 100);
		return () => clearTimeout(t);
	});

	// Pages cross-fade (see ::view-transition in app.css).
	onNavigate((nav) => {
		if (!document.startViewTransition || nav.from?.url.pathname === nav.to?.url.pathname) return;
		return new Promise((done) => {
			document.startViewTransition(async () => {
				done();
				await nav.complete;
			});
		});
	});

	// Leaving the play screen stops the music.
	$effect(() => {
		if (page.route.id !== '/play/[id]') player.stop();
	});

	// The desktop app opens outside links in the browser.
	function onclick(e: MouseEvent) {
		if (!isDesktop()) return;
		const a = (e.target as Element | null)?.closest<HTMLAnchorElement>('a[target="_blank"]');
		if (!a) return;
		e.preventDefault();
		openExternal(a.href);
	}
</script>

<svelte:head>
	<link rel="icon" href={favicon} />
</svelte:head>
<svelte:document {onclick} />

<Header />

<main>
	{#if library.ready}
		{@render children()}
	{/if}
</main>

{#if library.saveError}
	<p class="save-error" role="alert">Your playlists aren't being saved (private window or storage full).</p>
{/if}

<HowToPlay bind:open={ui.helpOpen} />
<Toasts />

{#if splash}
	<div class="splash" aria-hidden="true">
		<div class="splash-logo"><Logo size={128} /></div>
	</div>
{/if}

<style>
	main {
		width: 100%;
		max-width: calc(var(--wide) + 2 * var(--gutter));
		margin: 0 auto;
		padding: 8px var(--gutter) 64px;
	}

	@media (min-width: 720px) {
		main {
			padding: 8px 32px 72px;
			max-width: calc(var(--wide) + 64px);
		}
	}

	.save-error {
		position: fixed;
		inset: auto 0 0;
		padding: 8px 16px;
		background: var(--bad);
		color: var(--row-ink);
		font-size: var(--fs-sm);
		text-align: center;
	}

	.splash {
		position: fixed;
		inset: 0;
		z-index: 90;
		display: grid;
		place-items: center;
		background: var(--bg);
		perspective: var(--launch-perspective);
		pointer-events: none;
		animation: splash-fade var(--t-launch) var(--ease-launch) var(--t-launch-hold) both;
	}

	.splash-logo {
		animation: slide-out-fwd-center var(--t-launch) var(--ease-launch) var(--t-launch-hold) both;
	}

	@keyframes slide-out-fwd-center {
		from {
			transform: translateZ(1px);
			opacity: 1;
		}
		to {
			transform: translateZ(var(--launch-depth));
			opacity: 0;
		}
	}

	@keyframes splash-fade {
		to {
			opacity: 0;
		}
	}
</style>
