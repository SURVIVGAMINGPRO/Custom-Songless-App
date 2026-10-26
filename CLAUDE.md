# CLAUDE.md: Custom Songless App (Earshot)

A song guessing game built from the user's **own playlists** (shown as **Earshot**, `APP_NAME` in
`src/lib/config.ts`). Desktop app for macOS and Windows (Tauri 2) around a SvelteKit 3 + Svelte 5 +
TypeScript UI, which also runs as a web app. Public repo: never commit secrets, real names, emails or local paths.

## Hard rules

1. **The user's playlists are the point.** Home is their playlist library; pressing a cover plays that playlist.
   Endless is the main mode; "Today's song" is secondary. **Guess search only offers songs from the playlist (or
   mix) being played** (`searchSongs` in `src/lib/game/search.ts`), never Deezer's whole catalogue. Deezer search is
   only for adding songs to a playlist.
2. **No Spotify API, no scraping Spotify.** Spotify's developer policy bans games. Spotify playlists only come in
   as CSV files the user exports themselves (Exportify etc.). Links to `open.spotify.com/track/…` are fine.
3. **Audio is Deezer's 30 s previews only**, fetched fresh per round (links expire after ~15 min) and kept in
   memory, never saved. No downloading full songs, no YouTube.
4. **Deezer goes through `src/lib/sources/deezer-core.ts`**: an allowlist of paths, under 50 requests / 5 s, short
   cache. The web version calls it from a server route (`src/lib/server/deezer.ts`); the desktop app calls it in
   the page through Tauri's HTTP plugin (scope in `src-tauri/capabilities/default.json`). Add a path to both the
   allowlist and, for new hosts, the capability. Deezer's terms: private, non-commercial use.
5. Everything the user makes lives in IndexedDB (`src/lib/store`). No accounts, no telemetry.

## Game rules (from Songless's own code)

Clip steps `[0.13, 0.53, 2, 8, 15]` s (`DEFAULT_STEPS`), labelled with one decimal ("0.1 seconds"), one row per
step. A wrong guess or Skip unlocks the next step. Rows: green correct, orange right artist, red wrong, grey
skipped. Share grid 🟩🟧🟥⬜⬛. A guess is correct if it's the same Deezer ID, the same ISRC, or the same
normalized title by an overlapping artist (`judge` in `engine.ts`). Behind the scenes every playlist gets its
own single-playlist game (`gameForPlaylist`); games with 2+ playlists are shown as **Mixes**.

## Layout

```
src/lib/game/       types, engine (rounds, judging, stats, share), deck (no-repeat shuffle, daily pick), normalize,
                    search (guess search), translit (romanizing other alphabets for search)
src/lib/sources/    deezer (client), deezer-core (shared allowlist/limit/cache), csv, links, match, importer
src/lib/server/     deezer.ts: the web version's server-side client
src/lib/audio/      player.svelte.ts (Web Audio clips), silence.ts (skip leading quiet)
src/lib/store/      db.ts (IndexedDB), library.svelte.ts (all state + actions, autosave)
src/lib/components/ shared UI (Logo, Mosaic, PlaylistCard, Tabs, Dialog…); play/ holds the play screen pieces
src/lib/platform.ts desktop detection, opening links, saving files
src/lib/keys.ts     keyboard shortcuts: actions, defaults, matching, keycaps (changed ones live in settings.keys)
src/routes/         / library, /play/[id], /playlists/[id] (or new), /import (Add a playlist),
                    /games/[id] (mix editor, or new), /stats, /settings, /api/* (web version only)
src-tauri/          Tauri shell: plugins (http, opener, dialog), save_text_file command, icons, CSP
scripts/make-icons.mjs  renders the app icon from assets/logo.svg (npm run icons)
.github/workflows/build.yml  builds macOS + Windows; a v* tag publishes the release
```

## SvelteKit 3 notes

- Config lives in `vite.config.ts` (`sveltekit({...})`); there is no `svelte.config.js`. With
  `TAURI_ENV_PLATFORM` set (Tauri's build) it uses adapter-static into `build/`; otherwise adapter-auto.
- Import from `#lib/...` with the file extension (`#lib/game/engine.ts`), not `$lib`.
- `$app/state` (not `$app/stores`), `resolve()` from `$app/paths` for links, `Response.json()` not `json()`.
- `ssr = false` for the whole app (`src/routes/+layout.ts`): pages render in the browser.

## Design (after Apple's apps)

Modelled on Music for macOS and Apple's HIG ("Liquid Glass": translucent material only for navigation and
controls, content on a plain layer, colour used sparingly). A sidebar (`Sidebar.svelte`) with Playlists, Add
Playlist, Stats, the user's playlists and mixes, and Settings; it slides over the content below 760 px. Large
titles, inset grouped lists (`.group`), segmented controls (`Tabs.svelte`), capsule buttons, the system font
(SF Pro on Mac, Segoe UI on Windows; `ui-rounded` for numbers). Light and dark come from Apple's system colours;
`src/app.html` picks the theme before the page draws, Settings → Appearance can override it. The logo's yellow is
the tint (`--accent`; `--accent-text` for yellow text). Results: green/orange/red tints plus an icon in each row.
Every colour, size and duration is a token in `src/app.css`; text tokens are checked at 4.5:1 in both themes.
Motion: the VC Alert launch logo (hold, then slide-out-fwd-center), page cross-fades (View Transitions), `.rise`
entrances, a gliding segmented thumb, rows that pop/nudge, equalizer bars while a clip plays, and the answer's
artwork growing while the preview plays. Reduced motion and reduced transparency are respected.
The Mac app hides its title bar (`src-tauri/tauri.macos.conf.json`); `html.mac-app` sets `--titlebar` so the
sidebar and toolbar leave room for the window buttons, and those strips are `data-tauri-drag-region`.
Check 375 px wide and 1100 px, light and dark.

## Searching other alphabets

`translit.ts` romanizes Cyrillic, Greek, Armenian, Georgian, Hebrew, Arabic/Persian/Urdu, nine Indic scripts (one
offset table), Thai, Hangul (with nasal assimilation), Japanese kana (Hepburn) and Chinese (pinyin-pro, loaded on
demand by `prepareSearch` only when a playlist has Chinese titles). `search.ts` matches the query against the
title as written, its romanization after `loose()` (which merges spellings romanizations disagree on: ya/ja/ia,
kh/h, ch/ts, sh/sch, voiced/unvoiced, doubles; "ou" is tried as both o and u), and for Hebrew/Arabic consonants
only. Kanji in Japanese titles need a dictionary and aren't romanized. Every case is in `translit.test.ts`.

## Keyboard shortcuts

Actions and defaults are in `src/lib/keys.ts` (Enter pick then guess, Shift+Enter skip, Space play, Enter next song
after a round, / search, S share, M mode, ? help); the play screen's `onkeydown` runs them and Settings records
new ones (`ShortcutSettings.svelte`). Enter: the first press picks the highlighted song, the second guesses it; on an empty search it skips only on a
second press within 2 s, and is ignored for 0.9 s after a guess (habitual double presses). Rules: letters, symbols
and Space don't fire while typing (Space does while
the guess search is empty); a keyboard-focused button keeps its own Enter and Space; Play, Skip and the segmented
controls don't take focus on click, so typing and Enter carry on. Clashes are refused only between actions that
can run at the same time (Guess and Next Song both use Enter). Tab and Escape can't be shortcuts.

## Versioning and releases

Bump the version in `package.json`, `src-tauri/Cargo.toml` and `src-tauri/tauri.conf.json` together, add a
user-facing entry at the top of `CHANGELOG.md`, then push a tag `vX.Y.Z`. The workflow publishes
`Earshot-macOS.dmg`, `Earshot-Windows-setup.exe`, `Earshot-Windows.msi` and `Earshot-Windows-portable.exe`;
the README links to `releases/latest/download/<name>`, so never rename them.

## Commands

```
npm run dev             # web version, http://localhost:5173 (launch config "app" in .claude/launch.json)
npx tauri dev           # desktop app
CI=true npx tauri build --target universal-apple-darwin   # macOS .app + .dmg
npm test                # vitest
npm run check           # must be 0 errors, 0 warnings
npm run icons           # app icon from assets/logo.svg
```

Rust was installed with rustup without touching the shell profile: prefix cargo/tauri commands with
`export PATH="$HOME/.cargo/bin:$PATH"`.

## Verified vs not

Verified in a browser (web version): library home, playlist cards, importing Deezer's Top Worldwide chart, a CSV
import (ISRC and search matching, review list), the playlist builder, playing clips, guesses, skips, win and
loss, endless and daily rounds, mixes with tabs, stats, 375 px and 1180 px layouts.

Not verified: listening for the exact clip length by ear, a real Exportify export (the test used Exportify's
column names), Deezer share links (`link.deezer.com`), the Windows app on Windows, Safari and Firefox.
