# Safari Extension Build Setup

## Initial Setup

After cloning the repository:

```bash
make install  # Install dependencies
make safari   # Build extension files
```

**First time only:** After first build, open `safari/ipvfoo-safari.xcodeproj` in Xcode:
1. In project navigator, expand `Shared (Extension)/Resources/`
2. Select the generated files: `background.js`, `popup.js`, `manifest.json`, `options.html`, `popup.html`
3. In the File Inspector (right panel), under "Target Membership", check both:
   - `ipvfoo-safari Extension (iOS)`
   - `ipvfoo-safari Extension (macOS)`
4. Save and close Xcode

Asset files already have target membership configured. Only generated files need manual addition.

## Xcode Target Membership

The following files in `Shared (Extension)/Resources/` must have target membership for both iOS and macOS extension targets:

### Generated Files (via `make safari`)
- `background.js`
- `background.js.map`
- `popup.js`
- `popup.js.map`
- `manifest.json`
- `options.html`
- `popup.html`

### Asset Files
- `assets/1x1_808080.png`
- `assets/cached_arrow.png`
- `assets/detectdarkmode.html`
- `assets/detectdarkmode.js`
- `assets/gray_lock.png`
- `assets/gray_schrodingers_lock.png`
- `assets/gray_unlock.png`
- `assets/icon128.png`
- `assets/icon16.png`
- `assets/icon16_transparent.png`
- `assets/serviceworker.png`
- `assets/snip.png`
- `assets/sprites16.png`
- `assets/sprites32.png`
- `assets/websocket.png`

### Swift Files (already in target)
- `DNSResolver.swift`
- `SafariWebExtensionHandler.swift`

## Building

1. Run `make safari` to generate extension files
2. Open `ipvfoo-safari.xcodeproj` in Xcode
3. Build and run the iOS or macOS target

## Development

Use watch mode to rebuild on file changes:

```bash
make watch-safari
```

The Xcode project will automatically pick up file changes after rebuilding.

