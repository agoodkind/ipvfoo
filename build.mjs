import { Command } from "@commander-js/extra-typings"
import { build, context } from "esbuild"
import { cp, mkdir, readFile, rm, writeFile } from "node:fs/promises"
import { dirname, resolve } from "node:path"
import process from "node:process"
import { fileURLToPath } from "node:url"
import {
  browsers,
  browserTargets,
  entryPoints,
  staticAssets,
} from "./build.config.mjs"

const __filename = fileURLToPath(import.meta.url)
const __dirname = dirname(__filename)

const isDev = process.env.BUILD_ENV === "development"

/**
 * Get the current Git commit SHA
 */
export const getGitCommitSha = async () => {
  const { exec } = await import("node:child_process")
  return new Promise((resolve) => {
    exec("git rev-parse HEAD", (err, stdout) => {
      resolve(err ? "" : stdout.trim())
    })
  })
}

/**
 * Load path aliases from jsconfig.json
 */
async function loadJsconfigAliases() {
  try {
    const raw = await readFile(resolve(__dirname, "jsconfig.json"), "utf8")
    const stripped = raw
      .replace(/\/\/[^\n]*$/gm, "")
      .replace(/\/\*[\s\S]*?\*\//g, "")
    const json = JSON.parse(stripped)
    const paths = json?.compilerOptions?.paths

    if (!paths) {
      return {}
    }

    /** @type {Record<string,string>} */
    const alias = {}
    for (const [key, arr] of Object.entries(paths)) {
      if (!Array.isArray(arr) || !arr.length) {
        continue
      }
      const bareKey = key.endsWith("/*") ? key.slice(0, -2) : key
      let target = arr[0]
      if (target.endsWith("/*")) {
        target = target.slice(0, -2)
      }
      if (target.startsWith("./")) {
        target = target.slice(2)
      }
      alias[bareKey] = resolve(__dirname, target)
    }
    return alias
  } catch (_err) {
    return {}
  }
}

/**
 * Copy static assets to target directory
 */
async function copyStatic(browserName) {
  const target = browserTargets[browserName]
  const srcDir = resolve(__dirname, "src")
  const outDir = resolve(__dirname, target.outDir)

  // Copy asset directories
  for (const dir of staticAssets.dirs) {
    const srcPath = resolve(srcDir, dir)
    const destPath = resolve(outDir, dir)
    await cp(srcPath, destPath, { recursive: true })
  }

  // Copy HTML files
  for (const file of staticAssets.files) {
    await cp(resolve(srcDir, file), resolve(outDir, file))
  }

  // Copy and format manifest
  const manifestPath = resolve(__dirname, target.manifest)
  const manifest = JSON.parse(await readFile(manifestPath, "utf-8"))
  await writeFile(
    resolve(outDir, "manifest.json"),
    JSON.stringify(manifest, null, 2),
  )
}

/**
 * Create esbuild BuildOptions for a specific browser
 * @param {string} browserName
 * @returns {Promise<import('esbuild').BuildOptions>}
 */
const createBuildOptions = async (browserName) => {
  const target = browserTargets[browserName]
  const dynamicAlias = await loadJsconfigAliases()
  const commitSha = await getGitCommitSha()

  return {
    entryPoints,
    bundle: true,
    outdir: target.outDir,
    outbase: "src",
    minify: !isDev,
    sourcemap: isDev ? "inline" : true,
    logLevel: isDev ? "debug" : "info",
    alias: dynamicAlias,
    define: {
      "process.env.TARGET": JSON.stringify(browserName),
      "process.env.BUILD_ENV": JSON.stringify(
        process.env.BUILD_ENV || "production",
      ),
      "process.env.BUILD_TS": JSON.stringify(new Date().toString()),
      "process.env.COMMIT_SHA": JSON.stringify(commitSha),
    },
    format: "esm",
    platform: "browser",
    target: ["es2020"],
    loader: {
      ".png": "file",
    },
  }
}

/**
 * Build a specific browser target
 */
async function buildBrowser(browserName, watch = false) {
  const target = browserTargets[browserName]
  if (!target) {
    console.error(`Unknown browser target: ${browserName}`)
    process.exitCode = 1
    return null
  }

  const outDir = resolve(__dirname, target.outDir)

  // Clean and create output directory
  await rm(outDir, { recursive: true, force: true })
  await mkdir(outDir, { recursive: true })

  // Copy static assets first
  await copyStatic(browserName)

  const options = await createBuildOptions(browserName)

  if (watch) {
    const ctx = await context(options)
    await ctx.watch()
    console.log(`👀 Watching ${browserName}...`)
    return ctx
  }

  await build(options)
  console.log(`✅ Built ${browserName}`)
  return null
}

/**
 * Execute build pipeline
 * @param {{ watch?: boolean; targets?: string[] }} opts
 */
export async function execute({ watch = false, targets }) {
  const selectedTargets = targets && targets.length ? targets : browsers

  // Validate targets
  for (const target of selectedTargets) {
    if (!browserTargets[target]) {
      console.error(`Unknown target: ${target}`)
      console.error(`Available targets: ${browsers.join(", ")}`)
      process.exit(1)
    }
  }

  if (watch) {
    const contexts = []
    for (const browserName of selectedTargets) {
      const ctx = await buildBrowser(browserName, true)
      if (ctx) contexts.push(ctx)
    }

    console.log("\n✨ Watch mode enabled - Press Ctrl+C to stop\n")

    // Keep process alive
    process.on("SIGINT", async () => {
      console.log("\n🛑 Stopping watchers...")
      for (const ctx of contexts) {
        await ctx.dispose()
      }
      process.exit(0)
    })

    return { mode: "watch", contexts }
  }

  for (const browserName of selectedTargets) {
    await buildBrowser(browserName, false)
  }

  console.log("\n✨ Build complete")
  return { mode: "build" }
}

/**
 * @param {string[]} argv
 */
async function main(argv = process.argv) {
  const program = new Command()
  program
    .name("build")
    .version("1.0.0")
    .description("Build ipvfoo extension for multiple browsers")
    .option("-w, --watch", "Watch mode")
    .option(
      "-t, --targets <browsers...>",
      `Build specific browsers (${browsers.join(", ")})`,
    )
    .action(async (options) => {
      await execute(options)
    })

  await program.parseAsync(argv)
}

if (import.meta.url === `file://${process.argv[1]}`) {
  main().catch((err) => {
    console.error(err)
    process.exit(1)
  })
}
