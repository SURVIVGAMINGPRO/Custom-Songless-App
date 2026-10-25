import adapterAuto from '@sveltejs/adapter-auto';
import adapterStatic from '@sveltejs/adapter-static';
import { sveltekit } from '@sveltejs/kit/vite';
import { defineConfig } from 'vite';

// The desktop app (Tauri sets TAURI_ENV_PLATFORM while building) ships the
// pages as static files and talks to Deezer itself; the web version keeps its
// small server route and lets adapter-auto pick the host.
const desktop = !!process.env.TAURI_ENV_PLATFORM;

export default defineConfig({
	clearScreen: false,
	server: {
		port: 5173,
		strictPort: true,
		watch: { ignored: ['**/src-tauri/**'] }
	},
	plugins: [
		sveltekit({
			compilerOptions: {
				// Force runes mode for the project, except for libraries. Can be removed in svelte 6.
				runes: ({ filename }) => (filename.split(/[/\\]/).includes('node_modules') ? undefined : true)
			},
			adapter: desktop ? adapterStatic({ pages: 'build', assets: 'build', fallback: 'index.html' }) : adapterAuto()
		})
	]
});
