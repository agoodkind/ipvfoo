# Safari Extension Build Setup

## Initial Setup

After cloning the repository, run these commands:

```bash
pnpm install
pnpm run build:xcode
```

This generates the required JavaScript and resource files in `Shared (Extension)/Resources/`.

## Xcode Target Membership

The following files in `Shared (Extension)/Resources/` must have target membership for both iOS and macOS extension targets:

### Generated Files (via `build:xcode`)
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

1. Run `pnpm run build:xcode` to generate extension files
2. Open `ipvfoo-safari.xcodeproj` in Xcode
3. Build and run the iOS or macOS target

## Development

Use watch mode to rebuild on file changes:

```bash
pnpm run watch:xcode
```

The Xcode project will automatically pick up file changes after rebuilding.

