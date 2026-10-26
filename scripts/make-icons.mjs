// Renders the app icon from assets/logo.svg: the yellow glyph on a dark
// rounded square. Run `npm run icons` (it also runs `tauri icon`).
import { Resvg } from '@resvg/resvg-js';
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';

const path = readFileSync('assets/logo.svg', 'utf8').match(/ d="([^"]+)"/)[1];

const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#2a2a30"/>
      <stop offset="1" stop-color="#0e0e10"/>
    </linearGradient>
    <radialGradient id="glow" cx="0.5" cy="0.32" r="0.62">
      <stop offset="0" stop-color="#ffe042" stop-opacity="0.24"/>
      <stop offset="1" stop-color="#ffe042" stop-opacity="0"/>
    </radialGradient>
  </defs>
  <rect x="100" y="100" width="824" height="824" rx="185" fill="url(#bg)"/>
  <rect x="100" y="100" width="824" height="824" rx="185" fill="url(#glow)"/>
  <rect x="101" y="101" width="822" height="822" rx="184" fill="none" stroke="#ffffff" stroke-opacity="0.09" stroke-width="2"/>
  <g transform="translate(512 512) scale(0.58) translate(-480 480)">
    <path d="${path}" fill="#ffe042"/>
  </g>
</svg>`;

mkdirSync('src-tauri/icons', { recursive: true });
writeFileSync('src-tauri/icons/app-icon.png', new Resvg(svg, { fitTo: { mode: 'width', value: 1024 } }).render().asPng());
console.log('wrote src-tauri/icons/app-icon.png');

// iPhone: full-bleed squares (iOS rounds the corners itself), plus the dark and
// tinted versions iOS shows when the home screen uses them.
const glyph = (fill) => `<g transform="translate(512 512) scale(0.7) translate(-480 480)"><path d="${path}" fill="${fill}"/></g>`;
const square = (body) => `<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">${body}</svg>`;
const ios = {
	'icon.png': square(`
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#2a2a30"/>
      <stop offset="1" stop-color="#0e0e10"/>
    </linearGradient>
    <radialGradient id="glow" cx="0.5" cy="0.32" r="0.7">
      <stop offset="0" stop-color="#ffe042" stop-opacity="0.24"/>
      <stop offset="1" stop-color="#ffe042" stop-opacity="0"/>
    </radialGradient>
  </defs>
  <rect width="1024" height="1024" fill="url(#bg)"/>
  <rect width="1024" height="1024" fill="url(#glow)"/>
  ${glyph('#ffe042')}`),
	'icon-dark.png': square(glyph('#ffe042')),
	'icon-tinted.png': square(`<rect width="1024" height="1024" fill="#000"/>${glyph('#ffffff')}`)
};
const iosDir = 'ios/Earshot/Assets.xcassets/AppIcon.appiconset';
mkdirSync(iosDir, { recursive: true });
for (const [name, body] of Object.entries(ios)) {
	writeFileSync(`${iosDir}/${name}`, new Resvg(body, { fitTo: { mode: 'width', value: 1024 } }).render().asPng());
	console.log(`wrote ${iosDir}/${name}`);
}
