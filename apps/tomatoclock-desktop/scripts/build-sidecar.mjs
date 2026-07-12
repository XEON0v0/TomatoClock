import { copyFileSync, mkdirSync } from "node:fs";
import { delimiter, dirname, join, resolve } from "node:path";
import { execFileSync } from "node:child_process";
import { fileURLToPath } from "node:url";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const tauriDir = join(root, "src-tauri");
const env = { ...process.env };
const cargoPath = findTool("cargo");
const rustcPath = findTool("rustc");

for (const tool of [cargoPath, rustcPath]) {
  const directory = dirname(tool);
  if (!env.PATH?.split(delimiter).includes(directory)) {
    env.PATH = `${directory}${delimiter}${env.PATH ?? ""}`;
  }
}

const target = process.env.BUILD_TARGET || hostTriple(env);
const release = process.env.PROFILE !== "debug";
const args = ["build", "--bin", "tomato-clock-mcp"];
if (release) args.push("--release");
if (target) args.push("--target", target);

execFileSync(cargoPath, args, {
  cwd: tauriDir,
  env,
  stdio: "inherit",
});

const exe = target.includes("windows") ? ".exe" : "";
const profileDir = release ? "release" : "debug";
const builtBinary = target
  ? join(tauriDir, "target", target, profileDir, `tomato-clock-mcp${exe}`)
  : join(tauriDir, "target", profileDir, `tomato-clock-mcp${exe}`);
const bundledBinary = join(tauriDir, "binaries", `tomato-clock-mcp-${target}${exe}`);

mkdirSync(dirname(bundledBinary), { recursive: true });
copyFileSync(builtBinary, bundledBinary);
console.log(`Bundled sidecar: ${bundledBinary}`);

function hostTriple(env) {
  const output = execFileSync(rustcPath, ["-vV"], { env, encoding: "utf8" });
  const match = output.match(/^host:\s*(.+)$/m);
  if (!match) throw new Error("Could not determine Rust host target triple.");
  return match[1].trim();
}

function findTool(name) {
  try {
    return execFileSync("rustup", ["which", name], { encoding: "utf8" }).trim();
  } catch {
    return name;
  }
}
