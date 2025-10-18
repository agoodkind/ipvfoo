import {build, context} from "esbuild";
import {mkdir, rm, cp, readFile, writeFile} from "fs/promises";
import {resolve, dirname} from "path";
import {fileURLToPath} from "url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const root = __dirname;
const srcDir = resolve(root, "src");
const distDir = resolve(root, "dist");

const targets = {
  firefox: {
    outDir: resolve(distDir, "firefox"),
    manifest: resolve(root, "manifest", "firefox-manifest.json"),
    background: "background.js",
    popup: "popup.js"
  },
  chrome: {
    outDir: resolve(distDir, "chrome"),
    manifest: resolve(root, "manifest", "chrome-manifest.json"),
    background: "background.js",
    popup: "popup.js"
  },
  safari: {
    outDir: resolve(distDir, "safari"),
    manifest: resolve(root, "src", "manifest.json"),
    background: "background.js",
    popup: "popup.js"
  }
};

const args = process.argv.slice(2);
const watchMode = args.includes("--watch") || args.includes("-w");
const targetArgs = args.filter(arg => !arg.startsWith("-"));
const selected = targetArgs.length ? targetArgs : Object.keys(targets);

async function bundleTarget(name, watch = false) {
  const target = targets[name];
  if (!target) {
    console.error(`Unknown target ${name}`);
    process.exitCode = 1;
    return;
  }
  await rm(target.outDir, {recursive: true, force: true});
  await mkdir(target.outDir, {recursive: true});
  const entryBackground = resolve(srcDir, "background.js");
  const entryPopup = resolve(srcDir, "popup.js");
  const sharedOptions = {
    bundle: true,
    format: "esm",
    sourcemap: true,
    target: "es2020",
    loader: {
      ".png": "file"
    }
  };
  
  if (watch) {
    const bgCtx = await context({
      ...sharedOptions,
      entryPoints: [entryBackground],
      outfile: resolve(target.outDir, target.background),
      define: {"process.env.TARGET": JSON.stringify(name)}
    });
    const popupCtx = await context({
      ...sharedOptions,
      entryPoints: [entryPopup],
      outfile: resolve(target.outDir, target.popup),
      define: {"process.env.TARGET": JSON.stringify(name)}
    });
    await bgCtx.watch();
    await popupCtx.watch();
    console.log(`👀 Watching ${name}...`);
    return {bgCtx, popupCtx};
  } else {
    await build({
      ...sharedOptions,
      entryPoints: [entryBackground],
      outfile: resolve(target.outDir, target.background),
      define: {"process.env.TARGET": JSON.stringify(name)}
    });
    await build({
      ...sharedOptions,
      entryPoints: [entryPopup],
      outfile: resolve(target.outDir, target.popup),
      define: {"process.env.TARGET": JSON.stringify(name)}
    });
    await copyStatic(target);
    console.log(`Built ${name}`);
  }
}

async function copyStatic(target) {
  // Copy all assets
  const assetsDir = resolve(srcDir, "assets");
  const targetAssetsDir = resolve(target.outDir, "assets");
  await cp(assetsDir, targetAssetsDir, {recursive: true});
  
  // Copy HTML files
  const htmlFiles = ["options.html", "popup.html"];
  for (const file of htmlFiles) {
    await cp(resolve(srcDir, file), resolve(target.outDir, file));
  }
  
  // Copy manifest
  const manifest = JSON.parse(await readFile(target.manifest, "utf-8"));
  await writeFile(resolve(target.outDir, "manifest.json"), JSON.stringify(manifest, null, 2));
}

(async function run() {
  if (watchMode) {
    const contexts = [];
    for (const target of selected) {
      await copyStatic(targets[target]);
      const ctx = await bundleTarget(target, true);
      if (ctx) contexts.push(ctx);
    }
    
    console.log("\n✨ Watch mode enabled. Press Ctrl+C to stop.\n");
    
    // Keep the process alive
    process.on("SIGINT", async () => {
      console.log("\n\n🛑 Stopping watchers...");
      for (const {bgCtx, popupCtx} of contexts) {
        await bgCtx.dispose();
        await popupCtx.dispose();
      }
      process.exit(0);
    });
  } else {
    for (const target of selected) {
      await bundleTarget(target);
    }
  }
})();
