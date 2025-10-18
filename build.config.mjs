// Browser target configurations
// Each browser has its own manifest and output directory

export const browsers = ["chrome", "firefox", "safari", "xcode"]

/** @type {Record<string, {outDir: string, manifest: string}>} */
export const browserTargets = {
  firefox: {
    outDir: "dist/firefox",
    manifest: "manifest/firefox-manifest.json",
  },
  chrome: {
    outDir: "dist/chrome",
    manifest: "manifest/chrome-manifest.json",
  },
  safari: {
    outDir: "dist/safari",
    manifest: "manifest/safari-manifest.json",
  },
  xcode: {
    outDir: "safari/Shared (Extension)/Resources",
    manifest: "src/manifest.json",
  },
}

/** @type {Array<{in: string, out: string}>} */
export const entryPoints = [
  {
    in: "src/background.js",
    out: "background",
  },
  {
    in: "src/popup.js",
    out: "popup",
  },
]

export const staticAssets = {
  dirs: ["assets"],
  files: ["options.html", "popup.html"],
}

