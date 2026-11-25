import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { spawnSync } from "node:child_process";

const shell = process.env.TEST_BASH || "bash";
const tmp = fs.mkdtempSync(path.join(os.tmpdir(), "alma-online-test-"));
const shellPath = value => value.replaceAll("\\", "/").replace(/^([A-Za-z]):/, (_, drive) => `/${drive.toLowerCase()}`);

const almaAssets = [
  ["alma-relay.cjs", "packaging/alma-relay/alma-relay.cjs"],
  ["alma-relay.service", "packaging/alma-relay/alma-relay.service"],
  ["alma-relay.openrc", "packaging/alma-relay/alma-relay.openrc"],
];

const release = path.join(tmp, "release");
fs.mkdirSync(release);
const sumsLines = [];
for (const [name, src] of almaAssets) {
  const buf = fs.readFileSync(src);
  fs.writeFileSync(path.join(release, name), buf);
  sumsLines.push(`${createHash("sha256").update(buf).digest("hex")}  ${name}`);
}
const validSums = sumsLines.join("\n") + "\n";

const helper = path.join(tmp, "commands.cjs");
fs.writeFileSync(helper, `const fs=require('fs'),crypto=require('crypto');
const [op,...args]=process.argv.slice(2);
const p=s=>process.platform==='win32'?s.replace(/^\\/([a-z])\\//i,(_,d)=>d+':/'):s;
if(op==='hash') console.log(crypto.createHash('sha256').update(fs.readFileSync(p(args[0]))).digest('hex')+'  '+args[0]);
if(op==='install'){
  const src=args[args.length-2], dst=args[args.length-1];
  fs.copyFileSync(p(src),p(dst));
}
`);

try {
  // 1. Test install_alma_relay_files success + bad-hash failure
  for (const scenario of ["success", "bad-hash"]) {
    const dir = path.join(tmp, `install-${scenario}`);
    fs.mkdirSync(dir);
    const isolatedInstaller = path.join(dir, "install.sh");
    fs.copyFileSync("scripts/installer/install.sh", isolatedInstaller);
    const sumsFile = path.join(dir, "SHA256SUMS");
    fs.writeFileSync(
      sumsFile,
      scenario === "bad-hash"
        ? validSums.replace(/([a-f0-9]{64})  alma-relay\.cjs/, `${"0".repeat(64)}  alma-relay.cjs`)
        : validSums,
    );

    const almaBin = path.join(dir, "lib", "alma-relay.cjs");
    const almaSvc = path.join(dir, "systemd", "alma-relay.service");
    const almaOpenrc = path.join(dir, "init.d", "alma-relay");

    const script = `
      set +o posix
      set -euo pipefail
      sudo() { "$@"; }
      curl() {
        local url='' output=''
        while [[ "$#" -gt 0 ]]; do
          case "$1" in
            https://*) url="$1" ;;
            -o) shift; output="$1" ;;
          esac
          shift
        done
        cp "$RELEASE_FIXTURE/\${url##*/}" "$output"
      }
      if [[ "$WINDOWS_ADAPTER" == 1 ]]; then
        sha256sum() { node "$COMMAND_HELPER" hash "$@"; }
        install() { node "$COMMAND_HELPER" install "$@"; }
      fi
      INSTALL_SH_NO_MAIN=1 source "$ISOLATED_INSTALLER"
      install_alma_relay_files "$SUMS_FILE"
    `;

    const res = spawnSync(shell, ["-c", script], {
      env: {
        ...process.env,
        ISOLATED_INSTALLER: shellPath(isolatedInstaller),
        SUMS_FILE: shellPath(sumsFile),
        RELEASE_FIXTURE: shellPath(release),
        RELEASE_BASE: "https://rels.jinfei.org/download",
        ALMA_RELAY_PATH: shellPath(almaBin),
        ALMA_SYSTEMD_PATH: shellPath(almaSvc),
        ALMA_OPENRC_PATH: shellPath(almaOpenrc),
        WINDOWS_ADAPTER: process.platform === "win32" ? "1" : "0",
        COMMAND_HELPER: shellPath(helper),
      },
      encoding: "utf8",
      timeout: 30000,
    });

    if (scenario === "success") {
      assert.equal(res.status, 0, `install_alma_relay_files failed: ${res.stderr}`);
      assert.deepEqual(fs.readFileSync(almaBin), fs.readFileSync("packaging/alma-relay/alma-relay.cjs"));
      assert.deepEqual(fs.readFileSync(almaSvc), fs.readFileSync("packaging/alma-relay/alma-relay.service"));
      assert.deepEqual(fs.readFileSync(almaOpenrc), fs.readFileSync("packaging/alma-relay/alma-relay.openrc"));
    } else {
      assert.notEqual(res.status, 0, "bad-hash must fail");
      assert.ok(res.stderr.includes("SHA256 verification failed for alma-relay.cjs"), res.stderr);
      assert.equal(fs.existsSync(almaBin), false, "corrupted alma-relay.cjs must not be installed");
    }
    console.log(`alma-relay install ${scenario}: passed`);
  }

  // 2. Test setup-relay.sh configure_alma_relay on systemd, openrc, and failure cases
  for (const mode of ["systemd-ok", "openrc-ok", "systemd-start-fail", "missing-bundle"]) {
    const dir = path.join(tmp, `setup-${mode}`);
    fs.mkdirSync(dir);
    const isolatedSetup = path.join(dir, "setup-relay.sh");
    fs.copyFileSync("scripts/installer/setup-relay.sh", isolatedSetup);
    const logFile = path.join(dir, "calls.log");
    const almaBin = path.join(dir, "alma-relay.cjs");
    const almaSvc = path.join(dir, "alma-relay.service");
    const almaOpenrc = path.join(dir, "alma-relay.openrc");
    const almaConfigDir = path.join(dir, "etc-alma");
    const almaEnv = path.join(almaConfigDir, "relay.env");

    if (mode !== "missing-bundle") {
      fs.copyFileSync("packaging/alma-relay/alma-relay.cjs", almaBin);
      fs.copyFileSync("packaging/alma-relay/alma-relay.service", almaSvc);
      fs.copyFileSync("packaging/alma-relay/alma-relay.openrc", almaOpenrc);
      fs.chmodSync(almaOpenrc, 0o755);
    }

    const script = `
      set +o posix
      set -euo pipefail
      sudo() { "$@"; }
      getent() { return 0; }
      id() { return 0; }
      usermod() { echo "usermod $*" >> "$CALL_LOG"; }
      chown() { echo "chown $*" >> "$CALL_LOG"; }
      if [[ "$WINDOWS_ADAPTER" == 1 ]]; then
        install() { node "$COMMAND_HELPER" install "$@"; }
        chmod() { return 0; }
      fi
      if [[ "$TEST_MODE" == systemd-* ]]; then
        systemctl() {
          echo "systemctl $*" >> "$CALL_LOG"
          if [[ "$TEST_MODE" == "systemd-start-fail" && "$1" == "restart" ]]; then
            return 1
          fi
          return 0
        }
        command() {
          if [[ "$1" == "-v" && "$2" == "node" ]]; then echo "/usr/bin/node"; return 0; fi
          if [[ "$1" == "-v" && "$2" == "systemctl" ]]; then echo "/usr/bin/systemctl"; return 0; fi
          builtin command "$@"
        }
      elif [[ "$TEST_MODE" == "openrc-ok" ]]; then
        rc-update() { echo "rc-update $*" >> "$CALL_LOG"; }
        service() { echo "service $*" >> "$CALL_LOG"; }
        command() {
          if [[ "$1" == "-v" && "$2" == "node" ]]; then echo "/usr/bin/node"; return 0; fi
          if [[ "$1" == "-v" && "$2" == "systemctl" ]]; then return 1; fi
          if [[ "$1" == "-v" && "$2" == "rc-update" ]]; then echo "/sbin/rc-update"; return 0; fi
          builtin command "$@"
        }
      else
        command() {
          if [[ "$1" == "-v" && "$2" == "node" ]]; then echo "/usr/bin/node"; return 0; fi
          builtin command "$@"
        }
      fi
      source "$ISOLATED_SETUP"
      configure_alma_relay 8787 "test-secret" "/etc/netbird-relay/certs/fullchain.pem" "/etc/netbird-relay/certs/privkey.pem"
    `;

    const res = spawnSync(shell, ["-c", script], {
      env: {
        ...process.env,
        CALL_LOG: shellPath(logFile),
        ISOLATED_SETUP: shellPath(isolatedSetup),
        TEST_MODE: mode,
        ALMA_RELAY_PATH: shellPath(almaBin),
        ALMA_SYSTEMD_PATH: shellPath(almaSvc),
        ALMA_OPENRC_PATH: shellPath(almaOpenrc),
        ALMA_CONFIG_DIR: shellPath(almaConfigDir),
        ALMA_ENV_FILE: shellPath(almaEnv),
        WINDOWS_ADAPTER: process.platform === "win32" ? "1" : "0",
        COMMAND_HELPER: shellPath(helper),
      },
      encoding: "utf8",
      timeout: 30000,
    });

    if (mode === "systemd-ok" || mode === "openrc-ok") {
      assert.equal(res.status, 0, `${mode} failed: ${res.stderr}`);
      const envText = fs.readFileSync(almaEnv, "utf8");
      assert.ok(envText.includes("PORT=8787"), envText);
      assert.ok(envText.includes("RELAY_REGISTRATION_KEY=test-secret"), envText);
      const calls = fs.readFileSync(logFile, "utf8");
      if (mode === "systemd-ok") {
        assert.ok(calls.includes("systemctl daemon-reload"), calls);
        assert.ok(calls.includes("systemctl enable --now alma-relay"), calls);
        assert.ok(calls.includes("systemctl restart alma-relay"), calls);
      } else {
        assert.ok(calls.includes("rc-update add alma-relay default"), calls);
        assert.ok(calls.includes("service alma-relay restart"), calls);
      }
    } else if (mode === "systemd-start-fail") {
      assert.notEqual(res.status, 0, "systemd start failure must fail");
      assert.ok(res.stderr.includes("Alma Relay service failed to start"), res.stderr);
    } else if (mode === "missing-bundle") {
      assert.notEqual(res.status, 0, "missing bundle must fail");
      assert.ok(res.stderr.includes("Alma Relay bundle was not found"), res.stderr);
    }
    console.log(`alma-relay setup ${mode}: passed`);
  }
} finally {
  fs.rmSync(tmp, { recursive: true, force: true });
}
