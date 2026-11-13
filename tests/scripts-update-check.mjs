import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { spawnSync } from "node:child_process";

// Run the real installer in Bash; only transport and privileged system commands are isolated.
const shell = process.env.TEST_BASH || "bash";
const tmp = fs.mkdtempSync(path.join(os.tmpdir(), "rels-update-test-"));
const shellPath = value => value.replaceAll("\\", "/").replace(/^([A-Za-z]):/, (_, drive) => `/${drive.toLowerCase()}`);
const installer = fs.readFileSync("scripts/installer/install.sh", "utf8");
const names = ["install.sh", "setup-relay.sh", "reload-relay-certificate.sh", "rels"];
const release = path.join(tmp, "release");
fs.mkdirSync(release);
const fixture = name => `#!/usr/bin/env bash\nprintf 'unexpected execution: ${name}\\n' >> "$SIDE_EFFECTS"\n`;
for (const name of names) fs.writeFileSync(path.join(release, name), fixture(name));
const sums = names.map(name => `${createHash("sha256").update(fixture(name)).digest("hex")}  ${name}\n`).join("");
const envFile = path.join(tmp, "environment.sh");
// Desktop's minimal Git omits install/sha256sum; Node supplies these only on Windows.
const helper = path.join(tmp, "commands.cjs");
fs.writeFileSync(helper, `const fs=require('fs'),crypto=require('crypto');
const [op,...args]=process.argv.slice(2);
const p=s=>process.platform==='win32'?s.replace(/^\\/([a-z])\\//i,(_,d)=>d+':/'):s;
if(op==='hash') console.log(crypto.createHash('sha256').update(fs.readFileSync(p(args[0]))).digest('hex')+'  '+args[0]);
if(op==='install'){fs.copyFileSync(p(args[2]),p(args[3]));fs.chmodSync(p(args[3]),parseInt(args[1],8));}
`);
fs.writeFileSync(envFile, `
set +o posix
bash() { "$TEST_BASH" "$@"; }
sudo() { "$@"; }
curl() {
  local url='' output='' arg
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      https://*) url="$1" ;;
      -o) shift; output="$1" ;;
    esac
    shift
  done
  local name="\${url##*/}"
  if [[ "$name" == "$FAIL_DOWNLOAD" ]]; then printf partial > "$output"; echo 'injected download failure' >&2; return 22; fi
  cp "$RELEASE_FIXTURE/$name" "$output"
}
mv() {
  if [[ "$FAIL_RENAME" == 1 && "$*" == *'/new '* && "$*" == *'setup-relay.sh' ]]; then echo 'injected rename failure' >&2; return 1; fi
  command mv "$@"
}
forbidden() { printf 'system command\\n' >> "$SIDE_EFFECTS"; return 99; }
apt-get() { forbidden; }
apk() { forbidden; }
systemctl() { forbidden; }
service() { forbidden; }
rc-update() { forbidden; }
uname() { forbidden; }
if [[ "$WINDOWS_ADAPTER" == 1 ]]; then
  sha256sum() { node "$COMMAND_HELPER" hash "$@"; }
  install() { node "$COMMAND_HELPER" install "$@"; }
fi
`);
try {
  for (const scenario of ["bad-hash", "download-failure", "missing-hash", "rename-failure", "success", "legacy-flag"]) {
    const dir = path.join(tmp, scenario);
    fs.mkdirSync(dir);
    const destinations = names.map(name => path.join(dir, name));
    for (const [i, file] of destinations.entries()) fs.writeFileSync(file, i === 0 ? installer : `original ${names[i]}\n`);
    const originals = destinations.map(file => fs.readFileSync(file));
    fs.writeFileSync(path.join(release, "SHA256SUMS"), scenario === "bad-hash" ? sums.replace(/([a-f0-9]{64})  rels/, `${"0".repeat(64)}  rels`) : scenario === "missing-hash" ? sums.split("\n").filter(line => !line.endsWith("  rels")).join("\n") : sums);
    const sentinel = path.join(dir, "side-effects");
    const env = {
      ...process.env, TEST_BASH: shell, TEST_ENV: shellPath(envFile), INSTALLER: shellPath(destinations[0]),
      INSTALL_DIR: shellPath(dir), CERT_RELOAD_PATH: shellPath(destinations[2]), RELS_PATH: shellPath(destinations[3]),
      CONFIG_DIR: shellPath(path.join(dir, "config")), RELEASE_FIXTURE: shellPath(release),
      RELEASE_BASE: "https://rels.jinfei.org/download", RELS_LANG: "en", FORCE_UPDATE_SCRIPTS: "0",
      FAIL_DOWNLOAD: scenario === "download-failure" ? "rels" : "", FAIL_RENAME: scenario === "rename-failure" ? "1" : "0",
      SIDE_EFFECTS: shellPath(sentinel), WINDOWS_ADAPTER: process.platform === "win32" ? "1" : "0", COMMAND_HELPER: shellPath(helper),
    };
    const result = spawnSync(shell, ["-c", 'source "$TEST_ENV"; source "$INSTALLER" "$@"', "_", scenario === "legacy-flag" ? "--update-scripts-only" : "--scripts-only"], { env, encoding: "utf8", timeout: 30000 });
    const success = scenario === "success" || scenario === "legacy-flag";
    assert.equal(result.status === 0, success, `${scenario}: ${result.error || ""}\n${result.stdout}\n${result.stderr}`);
    const expectedErrors = {
      "bad-hash": "SHA256 verification failed for rels",
      "download-failure": "injected download failure",
      "missing-hash": "SHA256 entry was not found for rels",
      "rename-failure": "injected rename failure",
    };
    if (!success) assert.ok(result.stderr.includes(expectedErrors[scenario]), `${scenario}: wrong failure: ${result.stderr}`);
    for (const [i, file] of destinations.entries()) assert.deepEqual(fs.readFileSync(file), success ? Buffer.from(fixture(names[i])) : originals[i], `${scenario}: ${names[i]}`);
    assert.equal(fs.existsSync(sentinel), false, `${scenario}: wizard/system commands executed`);
    assert.equal(fs.existsSync(path.join(dir, "config")), false);
    assert.deepEqual(fs.readdirSync(dir).sort(), [...names].sort(), `${scenario}: temporary files leaked`);
    console.log(`scripts-only ${scenario}: passed`);
  }
} finally {
  fs.rmSync(tmp, { recursive: true, force: true });
}
