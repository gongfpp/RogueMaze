import { execFileSync } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

export const SCHEMA_VERSION = 1;
export const PLATFORMS = new Set(["windows", "linux", "android", "ios"]);
export const CONFIGURATIONS = new Set(["release", "debug"]);

export function parseProjectVersion(projectText) {
  const match = projectText.match(/^config\/version="([^"]+)"$/m);
  if (!match || !match[1].trim()) {
    throw new Error("project.godot does not define application config/version.");
  }
  return match[1].trim();
}

export function normalizeCommit(value) {
  const commit = String(value ?? "").trim().toLowerCase();
  return /^[0-9a-f]{7,40}$/.test(commit) ? commit : "unknown";
}

export function createBuildInfo({
  version,
  commit,
  platform,
  configuration = "release",
  builtAtUtc,
  dirty = false,
}) {
  if (!PLATFORMS.has(platform)) {
    throw new Error(`Unsupported build platform: ${platform}`);
  }
  if (!CONFIGURATIONS.has(configuration)) {
    throw new Error(`Unsupported build configuration: ${configuration}`);
  }
  const normalizedCommit = normalizeCommit(commit);
  if (normalizedCommit === "unknown") {
    throw new Error("A 7-40 character Git commit is required for an export build.");
  }
  const timestamp = new Date(builtAtUtc);
  if (Number.isNaN(timestamp.getTime())) {
    throw new Error("builtAtUtc must be a valid date.");
  }
  return {
    schema_version: SCHEMA_VERSION,
    version,
    commit: normalizedCommit,
    commit_short: normalizedCommit.slice(0, 7),
    platform,
    configuration,
    built_at_utc: timestamp.toISOString(),
    dirty: Boolean(dirty),
  };
}

function parseArguments(args) {
  const result = {
    platform: "",
    configuration: "release",
    output: "assets/build/build_info.json",
  };
  for (let index = 0; index < args.length; index += 1) {
    const argument = args[index];
    if (argument === "--platform" || argument === "--configuration" || argument === "--output") {
      const value = args[index + 1];
      if (!value) throw new Error(`${argument} requires a value.`);
      result[argument.slice(2)] = value;
      index += 1;
    } else {
      throw new Error(`Unknown argument: ${argument}`);
    }
  }
  if (!result.platform) throw new Error("--platform is required.");
  return result;
}

function gitOutput(root, args) {
  return execFileSync("git", args, { cwd: root, encoding: "utf8" }).trim();
}

export function generateBuildInfo({ root, platform, configuration, output, now = new Date() }) {
  const projectText = fs.readFileSync(path.join(root, "project.godot"), "utf8");
  const environmentCommit = normalizeCommit(process.env.GITHUB_SHA);
  const commit = environmentCommit !== "unknown"
    ? environmentCommit
    : normalizeCommit(gitOutput(root, ["rev-parse", "HEAD"]));
  const dirty = gitOutput(root, ["status", "--porcelain"]) !== "";
  const info = createBuildInfo({
    version: parseProjectVersion(projectText),
    commit,
    platform,
    configuration,
    builtAtUtc: now,
    dirty,
  });
  const outputPath = path.resolve(root, output);
  const relativeOutput = path.relative(root, outputPath);
  if (relativeOutput.startsWith("..") || path.isAbsolute(relativeOutput)) {
    throw new Error("Build info output must stay inside the repository.");
  }
  fs.mkdirSync(path.dirname(outputPath), { recursive: true });
  fs.writeFileSync(outputPath, `${JSON.stringify(info, null, 2)}\n`, "utf8");
  return { info, outputPath };
}

const isMain = process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url);
if (isMain) {
  try {
    const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
    const options = parseArguments(process.argv.slice(2));
    const { info, outputPath } = generateBuildInfo({ root, ...options });
    process.stdout.write(
      `Build info: v${info.version} ${info.platform}/${info.configuration} ${info.commit_short}${info.dirty ? " dirty" : ""} -> ${outputPath}\n`,
    );
  } catch (error) {
    process.stderr.write(`Build info generation failed: ${error.message}\n`);
    process.exitCode = 1;
  }
}
