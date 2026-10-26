<script lang="ts">
	import '../app.css';
	import { onNavigate } from '$app/navigation';
	import { page } from '$app/state';
	import { onMount } from 'svelte';
	import { player } from '#lib/audio/player.svelte.ts';
	import favicon from '#lib/assets/favicon.svg';
	import HowToPlay from '#lib/components/HowToPlay.svelte';
	import Icon from '#lib/components/Icon.svelte';
	import Logo from '#lib/components/Logo.svelte';
	import Sidebar from '#lib/components/Sidebar.svelte';
	import Toasts from '#lib/components/Toasts.svelte';
	import { APP_NAME } from '#lib/config.ts';
	import { isDesktop, ms, openExternal } from '#lib/platform.ts';
	import { library } from '#lib/store/library.svelte.ts';
	import { applyAppearance } from '#lib/theme.ts';
	import { ui } from '#lib/ui.svelte.ts';
	import type { LayoutProps } from './$types';

	let { children }: LayoutProps = $props();

	let sidebarOpen = $state(false);
	let scrolled = $state(false);

	library.load().then(() => {
		player.volume = library.data.settings.volume;
	});

	$effect(() => {
		applyAppearance(library.data.settings.appearance);
	});

	// The logo shows for a beat when the app opens, then zooms towards you and
	// fades (VC Alert's launch, Animista slide-out-fwd-center). A timer removes
	// it, so it never lingers even if no animation ran.
	let splash = $state(true);
	onMount(() => {
		// The Mac app hides its title bar; leave room for the window buttons.
		if (isDesktop() && /Mac/.test(navigator.userAgent)) document.documentElement.classList.add('mac-app');
		const t = setTimeout(() => (splash = false), ms('--t-launch-hold') + ms('--t-launch') + 100);
		return () => clearTimeout(t);
	});

	// Pages cross-fade (see ::view-transition in app.css). The fade waits for a
	// drawn frame, so never hold the page change for it longer than a moment
	// (a hidden or minimised window draws no frames).
	onNavigate((nav) => {
		sidebarOpen = false;
		if (!document.startViewTransition || nav.from?.url.pathname === nav.to?.url.pathname) return;
		return new Promise((done) => {
			const fallback = setTimeout(done, 150);
			document.startViewTransition(async () => {
				clearTimeout(fallback);
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

	function onkeydown(e: KeyboardEvent) {
		if (e.key === 'Escape' && sidebarOpen) sidebarOpen = false;
	}
</script>

<svelte:head>
	<link rel="icon" href={favicon} />
</svelte:head>
<svelte:document {onclick} />
<svelte:window {onkeydown} onscroll={() => (scrolled = scrollY > 4)} />

<div class="app">
	<Sidebar bind:open={sidebarOpen} />
	{#if sidebarOpen}
		<button class="scrim" type="button" aria-label="Hide sidebar" onclick={() => (sidebarOpen = false)}></button>
	{/if}

	<div class="content">
		<div class="toolbar" class:scrolled data-tauri-drag-region>
			<button
				class="icon-btn toggle"
				type="button"
				aria-label="Show sidebar"
				aria-expanded={sidebarOpen}
				onclick={() => (sidebarOpen = true)}
			>
				<Icon name="sidebar" size={20} />
			</button>
			<span class="toolbar-title" data-tauri-drag-region><Logo size={18} /> {APP_NAME}</span>
		</div>
		<main>
			{#if library.ready}
				{@render children()}
			{/if}
		</main>
	</div>
</div>

{#if library.saveError}
	<p class="save-error" role="alert">Your playlists aren't being saved (private window or storage full).</p>
{/if}

<HowToPlay bind:open={ui.helpOpen} />
<Toasts />

{#if splash}
	<div class="splash" aria-hidden="true">
		<div class="splash-logo"><Logo size={120} /></div>
	</div>
{/if}

<style>
	:global(html.mac-app) {
		--titlebar: 44px;
	}

	.app {
		display: grid;
		grid-template-columns: var(--sidebar-w) minmax(0, 1fr);
		min-height: 100dvh;
	}

	.content {
		min-width: 0;
	}

	.toolbar {
		position: sticky;
		top: 0;
		z-index: 20;
		display: flex;
		align-items: center;
		gap: 8px;
		height: max(var(--titlebar), 16px);
		padding: 0 12px;
		transition:
			background-color var(--t-med),
			box-shadow var(--t-med);
	}

	.toolbar.scrolled {
		background: var(--material);
		-webkit-backdrop-filter: saturate(180%) blur(20px);
		backdrop-filter: saturate(180%) blur(20px);
		box-shadow: 0 0.5px 0 var(--line-strong);
	}

	.toggle,
	.toolbar-title {
		display: none;
	}

	main {
		width: 100%;
		max-width: calc(var(--wide) + 2 * var(--gutter));
		margin: 0 auto;
		padding: 8px var(--gutter) 64px;
		view-transition-name: main;
	}

	@media (min-width: 1000px) {
		main {
			padding: 8px 40px 72px;
		}
	}

	.scrim {
		display: none;
	}

	@media (max-width: 759px) {
		.app {
			grid-template-columns: minmax(0, 1fr);
		}

		.toolbar {
			height: max(var(--titlebar), 52px);
			padding-left: max(12px, calc(var(--titlebar) * 1.8));
		}

		.toggle {
			display: grid;
		}

		.toolbar-title {
			display: inline-flex;
			align-items: center;
			gap: 6px;
			font-family: var(--font-display);
			font-weight: 700;
		}

		.scrim {
			position: fixed;
			inset: 0;
			z-index: 35;
			display: block;
			border: 0;
			background: var(--scrim);
			animation: fade-in var(--t-med) var(--ease-out);
		}
	}

	@keyframes fade-in {
		from {
			opacity: 0;
		}
	}

	.save-error {
		position: fixed;
		inset: auto 0 0;
		z-index: 60;
		padding: 8px 16px;
		background: var(--bad);
		color: #fff;
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
