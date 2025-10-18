# Build Instructions

## Setup

Install dependencies with pnpm:
```bash
pnpm install
```

## Build Commands

Build for all browsers:
```bash
pnpm run build
```

Build for specific browser:
```bash
pnpm run build:firefox
pnpm run build:chrome
pnpm run build:safari
```

## Watch Mode

Watch and rebuild on file changes (all browsers):
```bash
pnpm run watch
```

Watch specific browser:
```bash
pnpm run watch:firefox
pnpm run watch:chrome
pnpm run watch:safari
```

Press `Ctrl+C` to stop watching.

## Output

Built extensions are placed in:
- `dist/firefox/` - Firefox extension
- `dist/chrome/` - Chrome extension
- `dist/safari/` - Safari extension

Each directory contains:
- Bundled `background.js` and `popup.js` with sourcemaps
- Static assets (icons, HTML, CSS)
- Browser-specific `manifest.json`

## Source Structure

- `src/` - Source files
  - `background.js` - Background service worker entry
  - `popup.js` - Popup UI entry
  - `options.js` - Options page entry
  - `popup.html` - Popup HTML
  - `options.html` - Options HTML
  - `lib/` - JavaScript libraries
    - `common.js` - Shared utilities and icon rendering
    - `iputil.js` - IP address parsing utilities
    - `safari.js` - Safari-specific DNS resolution
    - `logger.js` - Debug logging utility
  - `assets/` - Static assets (icons, images, HTML)
- `build.mjs` - Build script using esbuild
- `manifest/` - Browser-specific manifest templates

