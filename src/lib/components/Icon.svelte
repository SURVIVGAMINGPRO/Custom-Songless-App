<script lang="ts" module>
	/** 24×24 outline icons (stroke), except the filled ones marked below. */
	const PATHS = {
		menu: 'M4 7h16M4 12h16M4 17h16',
		user: 'M12 12a4 4 0 1 0 0-8 4 4 0 0 0 0 8ZM5 20c.8-3.4 3.6-5 7-5s6.2 1.6 7 5',
		search: 'M11 18a7 7 0 1 0 0-14 7 7 0 0 0 0 14ZM20 20l-4-4',
		x: 'M6 6l12 12M18 6 6 18',
		plus: 'M12 5v14M5 12h14',
		check: 'm5 12.5 4.5 4.5L19 7.5',
		'chevron-down': 'm6 9 6 6 6-6',
		'chevron-right': 'm9 6 6 6-6 6',
		'arrow-right': 'M5 12h14M13 6l6 6-6 6',
		share: 'M12 15V4M8 8l4-4 4 4M5 13v5a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2v-5',
		external: 'M14 5h5v5M19 5l-8 8M18 14v4a1 1 0 0 1-1 1H6a1 1 0 0 1-1-1V7a1 1 0 0 1 1-1h4',
		trash: 'M5 7h14M10 7V5h4v2M7 7l1 12h8l1-12',
		upload: 'M12 16V4M7 9l5-5 5 5M5 20h14',
		music: 'M9 18V6l10-2v12M9 18a3 3 0 1 1-6 0 3 3 0 0 1 6 0ZM19 16a3 3 0 1 1-6 0 3 3 0 0 1 6 0Z',
		help: 'M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18ZM9.5 9.5a2.5 2.5 0 1 1 3.5 2.3c-.6.3-1 .9-1 1.6v.6M12 17.2v.1',
		settings:
			'M12 15a3 3 0 1 0 0-6 3 3 0 0 0 0 6ZM19.4 13.5a7.6 7.6 0 0 0 0-3l2-1.6-2-3.4-2.4 1a7.4 7.4 0 0 0-2.6-1.5L14 2.5h-4l-.4 2.5A7.4 7.4 0 0 0 7 6.5l-2.4-1-2 3.4 2 1.6a7.6 7.6 0 0 0 0 3l-2 1.6 2 3.4 2.4-1a7.4 7.4 0 0 0 2.6 1.5l.4 2.5h4l.4-2.5a7.4 7.4 0 0 0 2.6-1.5l2.4 1 2-3.4-2-1.6Z',
		chart: 'M5 20V10M12 20V4M19 20v-7',
		list: 'M9 6h11M9 12h11M9 18h11M4.5 6h.01M4.5 12h.01M4.5 18h.01',
		grid: 'M4 4h7v7H4zM13 4h7v7h-7zM4 13h7v7H4zM13 13h7v7h-7z',
		sidebar: 'M4 5h16a1 1 0 0 1 1 1v12a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1V6a1 1 0 0 1 1-1ZM9.5 5v14',
		'chevron-left': 'm15 6-6 6 6 6',
		ellipsis: 'M6 12h.01M12 12h.01M18 12h.01',
		library: 'M8 3.5h8M5.5 7h13M5 10.5h14a1 1 0 0 1 1 1v8a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1v-8a1 1 0 0 1 1-1Z',
		sun: 'M12 16a4 4 0 1 0 0-8 4 4 0 0 0 0 8ZM12 2.5v2M12 19.5v2M2.5 12h2M19.5 12h2M5.3 5.3l1.4 1.4M17.3 17.3l1.4 1.4M5.3 18.7l1.4-1.4M17.3 6.7l1.4-1.4',
		moon: 'M20 14.5A8 8 0 0 1 9.5 4a8 8 0 1 0 10.5 10.5Z',
		display: 'M4 4.5h16a1 1 0 0 1 1 1v10a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1v-10a1 1 0 0 1 1-1ZM9 20.5h6M12 16.5v4',
		forward: 'M4.5 6.5v11l7-5.5-7-5.5ZM12.5 6.5v11l7-5.5-7-5.5Z',
		speaker: 'M4 9.5h3.5L12 5.5v13l-4.5-4H4v-5ZM16 9a4 4 0 0 1 0 6M18.5 6.5a7.5 7.5 0 0 1 0 11',
		'plus-circle': 'M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18ZM12 8v8M8 12h8',
		'refresh': 'M20 11a8 8 0 1 0-2.3 5.7M20 4v7h-7',
		edit: 'M4 20h4L19 9l-4-4L4 16v4ZM13.5 6.5l4 4',
		'arrow-left': 'M19 12H5M11 6l-6 6 6 6',
		calendar: 'M8 3v3M16 3v3M4 9h16M5 5h14a1 1 0 0 1 1 1v13a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1V6a1 1 0 0 1 1-1Z',
		infinity: 'M7.5 8.5C5.6 8.5 4 10.1 4 12s1.6 3.5 3.5 3.5c3.5 0 5.5-7 9-7 1.9 0 3.5 1.6 3.5 3.5s-1.6 3.5-3.5 3.5c-3.5 0-5.5-7-9-7Z',
		layers: 'M12 4 3 9l9 5 9-5-9-5ZM3 14l9 5 9-5',
		file: 'M14 3H7a1 1 0 0 0-1 1v16a1 1 0 0 0 1 1h10a1 1 0 0 0 1-1V7l-4-4ZM14 3v4h4M9 13h6M9 17h4',
		link: 'M10 14a4 4 0 0 0 5.7 0l3-3a4 4 0 0 0-5.7-5.7l-1 1M14 10a4 4 0 0 0-5.7 0l-3 3a4 4 0 0 0 5.7 5.7l1-1',
		sparkle: 'M12 3l1.8 5.2L19 10l-5.2 1.8L12 17l-1.8-5.2L5 10l5.2-1.8L12 3ZM19 17l.7 1.8 1.8.7-1.8.7L19 22l-.7-1.8-1.8-.7 1.8-.7L19 17Z',
		// Filled. The play triangle's centre of mass sits at the middle of the box, so it looks centred.
		play: 'M8 5.5v13a1 1 0 0 0 1.5.9l10.4-6.5a1 1 0 0 0 0-1.8L9.5 4.6A1 1 0 0 0 8 5.5Z',
		stop: 'M7 6h10a1 1 0 0 1 1 1v10a1 1 0 0 1-1 1H7a1 1 0 0 1-1-1V7a1 1 0 0 1 1-1Z',
		marker: 'M5 8h14l-7 9z'
	} as const;

	const FILLED = new Set(['play', 'stop', 'marker', 'forward']);

	export type IconName = keyof typeof PATHS;
</script>

<script lang="ts">
	let { name, size = 24, label, weight = 1.8 }: { name: IconName; size?: number; label?: string; weight?: number } = $props();
	const filled = $derived(FILLED.has(name));
</script>

<svg
	width={size}
	height={size}
	viewBox="0 0 24 24"
	fill={filled ? 'currentColor' : 'none'}
	stroke={filled ? 'none' : 'currentColor'}
	stroke-width={weight}
	stroke-linecap="round"
	stroke-linejoin="round"
	role={label ? 'img' : undefined}
	aria-label={label}
	aria-hidden={label ? undefined : 'true'}
>
	<path d={PATHS[name]} />
</svg>
