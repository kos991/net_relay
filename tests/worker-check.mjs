import fs from "node:fs";

const workerSource = fs.readFileSync("worker/rels-worker.js", "utf8");
const installText = fs.readFileSync("scripts/installer/install.sh", "utf8");
const setupText = fs.readFileSync("scripts/installer/setup-relay.sh", "utf8");
const releaseSums = "old-install  install.sh\nold-setup  setup-relay.sh\n";

globalThis.fetch = async (requestUrl) => {
  const url = String(requestUrl);
  if (url.endsWith("/SHA256SUMS")) return new Response(releaseSums);
  if (url.includes("/scripts/installer/install.sh")) return new Response(installText);
  if (url.includes("/scripts/installer/setup-relay.sh")) return new Response(setupText);
  throw new Error(`unexpected fetch: ${url}`);
};

eval(workerSource.replace("export default", "globalThis.worker ="));

const setupResponse = await globalThis.worker.fetch(
  new Request("https://rels.jinfei.org/download/setup-relay.sh"),
);
if (!(await setupResponse.text()).includes('RELS_LANG="${RELS_LANG:-en}"')) {
  throw new Error("setup script was not proxied from main");
}

const checksumResponse = await globalThis.worker.fetch(
  new Request("https://rels.jinfei.org/download/SHA256SUMS"),
);
const checksumText = await checksumResponse.text();
if (!/^[0-9a-f]{64}  install\.sh$/m.test(checksumText)) {
  throw new Error("install checksum was not rewritten");
}
if (!/^[0-9a-f]{64}  setup-relay\.sh$/m.test(checksumText)) {
  throw new Error("setup checksum was not rewritten");
}

console.log("worker online-script proxy test passed");
