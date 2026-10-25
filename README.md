<p align="center">
  <img src="src-tauri/icons/128x128@2x.png" width="112" height="112" alt="">
</p>

<h1 align="center">Earshot</h1>

<p align="center">Your own playlists as a song guessing game.<br>Hear a tenth of a second, guess, and get a longer clip after every miss.</p>

<p align="center">
  <a href="https://github.com/SURVIVGAMINGPRO/Custom-Songless-App/releases/latest/download/Earshot-macOS.dmg"><b>Download for macOS</b></a>
  &nbsp;·&nbsp;
  <a href="https://github.com/SURVIVGAMINGPRO/Custom-Songless-App/releases/latest/download/Earshot-Windows-setup.exe"><b>Download for Windows</b></a>
</p>

Both links always download the newest version. Every version is on the
[Releases page](https://github.com/SURVIVGAMINGPRO/Custom-Songless-App/releases).

- **macOS** (Apple Silicon and Intel, macOS 10.15 or newer): open `Earshot-macOS.dmg` and drag Earshot to
  Applications. The app isn't signed with an Apple Developer ID, so the first time macOS blocks it: open
  **System Settings → Privacy & Security**, scroll down and choose **Open Anyway**.
- **Windows** (10 and 11): run `Earshot-Windows-setup.exe`, or use the
  [MSI](https://github.com/SURVIVGAMINGPRO/Custom-Songless-App/releases/latest/download/Earshot-Windows.msi) or the
  [portable .exe](https://github.com/SURVIVGAMINGPRO/Custom-Songless-App/releases/latest/download/Earshot-Windows-portable.exe).
  Windows may say "Windows protected your PC": choose **More info → Run anyway**.

## How it works

Inspired by [Songless](https://lessgames.com/songless), but the songs are yours.

1. **Add a playlist.** Drop a Spotify playlist exported as a CSV file, paste a Deezer playlist or album link, or
   build one in the app by searching for songs.
2. **Press Play on its cover.** You hear 0.1 seconds of a song. Guess it, or skip for a longer clip:
   0.1 s, 0.5 s, 2 s, 8 s, 15 s, five tries in all.
3. **Rows light up:** green for the right song, orange for the right artist, red for a miss.

- **Endless** deals a new song every round, with no repeats until every song in the playlist has played.
  **Today's song** is one song a day per playlist.
- **Mixes** put several playlists in one game, each with its own tab.
- **Stats** keep your streaks and how many tries each win took. Share a result as an emoji grid.

Everything you make stays on your computer. Settings has a backup button.

## Where the songs come from

- **Clips:** each song's 30-second preview from Deezer's free API. Previews often start partway into the
  song, so the first clip isn't always the song's very first tenth of a second.
- **Spotify:** Spotify's developer rules don't allow games, so Earshot never connects to Spotify. Export a
  playlist with [Exportify](https://exportify.app/) (or TuneMyMusic / Soundiiz) and drop the CSV on the
  Add a playlist page. Songs are matched to Deezer by ISRC, then by title, artist and length; anything unsure
  is listed for you to check.
- Deezer's API terms allow private, non-commercial use only.

Not connected with Deezer, Spotify or Lessgames. The logo is Google's Material Symbols
`library_music` icon (Apache 2.0); fonts are Bricolage Grotesque and DM Sans (SIL Open Font License).

## Building it yourself

Needs Node 22.17 or newer, and [Rust](https://rustup.rs) for the desktop app.

```sh
npm install
npm run dev            # the web version at http://localhost:5173
npx tauri dev          # the desktop app with hot reload
npx tauri build        # this computer's app (add --target universal-apple-darwin on a Mac for both chips)
npm test               # unit tests
npm run check          # svelte-check
```

Pushing a tag like `v1.0.1` makes GitHub build the macOS and Windows apps and publish them as a release
(`.github/workflows/build.yml`).
