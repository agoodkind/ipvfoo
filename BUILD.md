# Build Instructions

## Setup

Install dependencies:
```bash
make install
```

## Build Commands

Build all browsers:
```bash
make all
```

Build specific browser:
```bash
make firefox
make chrome
make safari
```

Safari Xcode builds:
```bash
make safari-ios          # Release build for iOS
make safari-macos        # Release build for macOS
make safari-ios-debug    # Debug build for iOS
make safari-macos-debug  # Debug build for macOS
```

Run Safari apps:
```bash
make safari-run-ios      # Run iOS app in simulator
make safari-run-macos    # Run macOS app
```

Archive for App Store submission:
```bash
make safari-archive-ios
make safari-archive-macos
```

Clean build artifacts:
```bash
make clean         # Clean all build artifacts
make safari-clean  # Clean Safari build artifacts only
```

## Watch Mode

Watch and rebuild on file changes (all browsers):
```bash
make watch
```

Watch specific browser:
```bash
make watch-firefox
make watch-chrome
make watch-safari
```

Watch with maximum verbosity:
```bash
make watch-debug
```

Press `Ctrl+C` to stop watching.

## Environment Variables

Control build behavior with environment variables:

### DEBUG
Enable debug mode with sourcemaps and verbose logging:
```bash
DEBUG=1 make all
```

### RELEASE
Build production-ready minified bundles:
```bash
RELEASE=1 make all
```

### LOG_VERBOSITY
Control verbosity level (0-5):
- `LOG_VERBOSITY=0` - Drop all verbose logs
- `LOG_VERBOSITY=1` - Drop VERBOSE2-5 logs
- `LOG_VERBOSITY=2` - Drop VERBOSE3-5 logs
- `LOG_VERBOSITY=3` - Drop VERBOSE4-5 logs
- `LOG_VERBOSITY=4` - Drop VERBOSE5 logs
- `LOG_VERBOSITY=5` - Keep all verbose logs

Example:
```bash
LOG_VERBOSITY=3 make firefox
```

Combine environment variables:
```bash
CONFIGURATION=Debug LOG_VERBOSITY=5 make watch
```

## Output

Built extensions are placed in:
- `dist/firefox/` - Firefox extension
- `dist/chrome/` - Chrome extension
- `dist/safari/` - Safari extension
- `safari/Shared (Extension)/Resources/` - Safari Xcode project (when using `make safari`)

Each directory contains:
- Bundled `background.js` and `popup.js` with sourcemaps
- Static assets (icons, HTML, CSS)
- Browser-specific `manifest.json`

### Xcode Build

The `make safari` command outputs directly to the Safari Xcode project directory:
- Outputs to `safari/Shared (Extension)/Resources/`
- Automatically converts manifest to Safari Web Extension format
- Used for building the Safari app with Xcode
- Watch mode (`make watch-safari`) enables live reloading during development

**Important:** Run `make safari` before opening the Xcode project for the first time. Generated files need target membership in both iOS and macOS extension targets. See `safari/README.md` for details.

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
  - `Shared (Extension)/Resources/` - Built extension files (via `make safari`)

