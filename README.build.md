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
pnpm run build:xcode
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
pnpm run watch:xcode
```

Press `Ctrl+C` to stop watching.

## Output

Built extensions are placed in:
- `dist/firefox/` - Firefox extension
- `dist/chrome/` - Chrome extension
- `dist/safari/` - Safari extension
- `safari/Shared (Extension)/Resources/` - Safari Xcode project (when using `build:xcode`)

Each directory contains:
- Bundled `background.js` and `popup.js` with sourcemaps
- Static assets (icons, HTML, CSS)
- Browser-specific `manifest.json`

### Xcode Build

The `build:xcode` command outputs directly to the Safari Xcode project directory:
- Outputs to `safari/Shared (Extension)/Resources/`
- Automatically converts manifest to Safari Web Extension format
- Used for building the Safari app with Xcode
- Watch mode (`watch:xcode`) enables live reloading during development

**Important:** Run `build:xcode` before opening the Xcode project for the first time. Generated files need target membership in both iOS and macOS extension targets. See `safari/README.md` for details.

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
- `build.config.mjs` - Build configuration with browser targets and entry points
- `manifest/` - Browser-specific manifest templates
- `safari/` - Safari Xcode project directory
  - `Shared (Extension)/Resources/` - Built extension files (via `build:xcode`)

