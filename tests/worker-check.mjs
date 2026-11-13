import fs from "node:fs";
import assert from "node:assert/strict";
import { createHash } from "node:crypto";

const workerSource = fs.readFileSync("worker/rels-worker.js", "utf8");
const sources = new Map([
  ["install.sh", "scripts/installer/install.sh"],
  ["setup-relay.sh", "scripts/installer/setup-relay.sh"],
  ["reload-relay-certificate.sh", "scripts/certificate/reload-relay-certificate.sh"],
  ["rels", "packaging/ova/files/rels"],
]);
const releaseSums = [...sources.keys()].map(name => `old  ${name}\n`).join("") + "binary-hash  netbird-relay-linux-amd64.tar.gz\n";
let broken = "";
let missingEntries = false;
globalThis.fetch = async (requestUrl) => {
  const url = String(requestUrl);
  if (broken && url.endsWith(`/${broken}`)) return new Response("unavailable", { status: 503 });
  if (url.endsWith("/SHA256SUMS")) return new Response(missingEntries ? "" : releaseSums);
  for (const [, file] of sources) {
    if (url.endsWith(`/main/${file}`)) return new Response(fs.readFileSync(file));
  }
  if (url.endsWith("/main.sh")) return new Response("bootstrap");
  if (url.endsWith("/netbird-relay-linux-amd64.tar.gz")) return new Response("binary");
  throw new Error(`unexpected fetch: ${url}`);
};
eval(workerSource.replace("export default", "globalThis.worker ="));
const request = path => globalThis.worker.fetch(new Request(`https://rels.jinfei.org${path}`));
for (const empty of [false, true]) {
  missingEntries = empty;
  const response = await request("/download/SHA256SUMS");
  assert.equal(response.status, 200);
  const sums = await response.text();
  for (const [name, file] of sources) {
    const script = await request(`/download/${name}`);
    assert.equal(script.status, 200);
    assert.equal(await script.text(), fs.readFileSync(file, "utf8"));
    const hash = createHash("sha256").update(fs.readFileSync(file)).digest("hex");
    assert.equal(sums.split("\n").filter(line => line === `${hash}  ${name}`).length, 1);
  }
  if (!empty) assert.ok(sums.includes("binary-hash  netbird-relay-linux-amd64.tar.gz"));
}
for (const name of [...sources.keys(), "SHA256SUMS"]) {
  broken = name;
  assert.equal((await request("/download/SHA256SUMS")).status, 502);
  assert.equal((await request(`/download/${name}`)).status, 502);
}
broken = "";
assert.equal(await (await request("/install.sh")).text(), fs.readFileSync(sources.get("install.sh"), "utf8"));
assert.equal(await (await request("/")).text(), "bootstrap");
assert.equal(await (await request("/download/netbird-relay-linux-amd64.tar.gz")).text(), "binary");
assert.equal((await request("/download/unknown.sh")).status, 404);
console.log("worker-check passed: four scripts match SHA256; missing entries, failures and routes verified");
