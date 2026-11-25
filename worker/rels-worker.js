const RELEASE_BASE = "https://github.com/kos991/net_relay/releases/latest/download";
const SOURCE_INSTALL_URL = "https://raw.githubusercontent.com/kos991/net_relay/main/scripts/installer/install.sh";
const SOURCE_SETUP_URL = "https://raw.githubusercontent.com/kos991/net_relay/main/scripts/installer/setup-relay.sh";
const SOURCE_RELS_URL = "https://raw.githubusercontent.com/kos991/net_relay/main/packaging/ova/files/rels";
const SOURCE_RELOAD_URL = "https://raw.githubusercontent.com/kos991/net_relay/main/scripts/certificate/reload-relay-certificate.sh";
const SOURCE_ALMA_BUNDLE_URL = "https://raw.githubusercontent.com/kos991/net_relay/main/packaging/alma-relay/alma-relay.cjs";
const SOURCE_ALMA_SERVICE_URL = "https://raw.githubusercontent.com/kos991/net_relay/main/packaging/alma-relay/alma-relay.service";
const SOURCE_ALMA_OPENRC_URL = "https://raw.githubusercontent.com/kos991/net_relay/main/packaging/alma-relay/alma-relay.openrc";
const RELEASE_ASSETS = new Set([
  "rels",
  "install.sh",
  "SHA256SUMS",
  "netbird-relay-linux-amd64.tar.gz",
  "netbird-relay-linux-arm64.tar.gz",
  "setup-relay.sh",
  "reload-relay-certificate.sh",
  "alma-relay.cjs",
  "alma-relay.service",
  "alma-relay.openrc",
]);

async function proxyAsset(name, contentDisposition = true) {
  const upstream = await fetch(`${RELEASE_BASE}/${name}`, {
    headers: { "user-agent": "net-relay-worker" },
  });

  if (!upstream.ok) {
    return new Response(`Failed to fetch ${name}\n`, {
      status: 502,
      headers: { "content-type": "text/plain; charset=utf-8" },
    });
  }

  const headers = new Headers(upstream.headers);
  headers.set("cache-control", "public, max-age=300");
  if (name.endsWith(".sh")) {
    headers.set("content-type", "text/x-shellscript; charset=utf-8");
  }
  if (contentDisposition) {
    headers.set("content-disposition", `attachment; filename="${name}"`);
  } else {
    headers.delete("content-disposition");
  }

  return new Response(upstream.body, {
    status: upstream.status,
    headers,
  });
}

async function proxySourceScript(sourceUrl, name, contentType = "text/x-shellscript; charset=utf-8") {
  const upstream = await fetch(sourceUrl, {
    headers: { "user-agent": "net-relay-worker" },
  });

  if (!upstream.ok) {
    return new Response(`Failed to fetch ${name}\n`, {
      status: 502,
      headers: { "content-type": "text/plain; charset=utf-8" },
    });
  }

  return new Response(await upstream.text(), {
    status: upstream.status,
    headers: {
      "cache-control": "public, max-age=60",
      "content-type": contentType,
    },
  });
}

async function proxyInstallScript() {
  return proxySourceScript(SOURCE_INSTALL_URL, "install.sh");
}

async function proxySetupScript() {
  return proxySourceScript(SOURCE_SETUP_URL, "setup-relay.sh");
}

async function sha256Hex(text) {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(text),
  );
  return Array.from(new Uint8Array(digest), (byte) =>
    byte.toString(16).padStart(2, "0"),
  ).join("");
}

async function proxyChecksums() {
  const [
    sumsResponse,
    installResponse,
    setupResponse,
    relsResponse,
    reloadResponse,
    almaBundleResponse,
    almaServiceResponse,
    almaOpenrcResponse,
  ] = await Promise.all([
    fetch(`${RELEASE_BASE}/SHA256SUMS`, {
      headers: { "user-agent": "net-relay-worker" },
    }),
    fetch(SOURCE_INSTALL_URL, {
      headers: { "user-agent": "net-relay-worker" },
    }),
    fetch(SOURCE_SETUP_URL, {
      headers: { "user-agent": "net-relay-worker" },
    }),
    fetch(SOURCE_RELS_URL, {
      headers: { "user-agent": "net-relay-worker" },
    }),
    fetch(SOURCE_RELOAD_URL, {
      headers: { "user-agent": "net-relay-worker" },
    }),
    fetch(SOURCE_ALMA_BUNDLE_URL, {
      headers: { "user-agent": "net-relay-worker" },
    }),
    fetch(SOURCE_ALMA_SERVICE_URL, {
      headers: { "user-agent": "net-relay-worker" },
    }),
    fetch(SOURCE_ALMA_OPENRC_URL, {
      headers: { "user-agent": "net-relay-worker" },
    }),
  ]);

  if (
    !sumsResponse.ok ||
    !installResponse.ok ||
    !setupResponse.ok ||
    !relsResponse.ok ||
    !reloadResponse.ok ||
    !almaBundleResponse.ok ||
    !almaServiceResponse.ok ||
    !almaOpenrcResponse.ok
  ) {
    return new Response("Failed to fetch checksums\n", {
      status: 502,
      headers: { "content-type": "text/plain; charset=utf-8" },
    });
  }

  const [
    sumsText,
    installText,
    setupText,
    relsText,
    reloadText,
    almaBundleText,
    almaServiceText,
    almaOpenrcText,
  ] = await Promise.all([
    sumsResponse.text(),
    installResponse.text(),
    setupResponse.text(),
    relsResponse.text(),
    reloadResponse.text(),
    almaBundleResponse.text(),
    almaServiceResponse.text(),
    almaOpenrcResponse.text(),
  ]);
  const hashes = new Map([
    ["install.sh", await sha256Hex(installText)],
    ["setup-relay.sh", await sha256Hex(setupText)],
    ["rels", await sha256Hex(relsText)],
    ["reload-relay-certificate.sh", await sha256Hex(reloadText)],
    ["alma-relay.cjs", await sha256Hex(almaBundleText)],
    ["alma-relay.service", await sha256Hex(almaServiceText)],
    ["alma-relay.openrc", await sha256Hex(almaOpenrcText)],
  ]);
  const found = new Set();
  let output = sumsText
    .split(/\r?\n/)
    .map((line) => {
      for (const [name, hash] of hashes) {
        if (new RegExp(`\\s${name.replace('.', '\\.')}$`).test(line)) {
          found.add(name);
          return `${hash}  ${name}`;
        }
      }
      return line;
    })
    .join("\n");
  for (const [name, hash] of hashes) {
    if (!found.has(name)) {
      output += `${output.endsWith("\n") ? "" : "\n"}${hash}  ${name}\n`;
    }
  }

  return new Response(output, {
    status: 200,
    headers: {
      "cache-control": "public, max-age=60",
      "content-type": "text/plain; charset=utf-8",
    },
  });
}

export default {
  async fetch(request) {
    const url = new URL(request.url);

    if (url.pathname === "/" || url.pathname === "/main.sh") {
      return proxyAsset("main.sh", false);
    }
    if (url.pathname === "/install.sh") {
      return proxyInstallScript();
    }
    if (url.pathname === "/SHA256SUMS") {
      return proxyChecksums();
    }
    if (url.pathname.startsWith("/download/")) {
      const assetName = url.pathname.slice("/download/".length);
      if (!RELEASE_ASSETS.has(assetName)) {
        return new Response("Not found\n", {
          status: 404,
          headers: { "content-type": "text/plain; charset=utf-8" },
        });
      }
      if (assetName === "install.sh") {
        return proxyInstallScript();
      }
      if (assetName === "setup-relay.sh") {
        return proxySetupScript();
      }
      if (assetName === "rels") {
        return proxySourceScript(SOURCE_RELS_URL, "rels");
      }
      if (assetName === "reload-relay-certificate.sh") {
        return proxySourceScript(SOURCE_RELOAD_URL, assetName);
      }
      if (assetName === "alma-relay.cjs") {
        return proxySourceScript(SOURCE_ALMA_BUNDLE_URL, assetName, "application/javascript; charset=utf-8");
      }
      if (assetName === "alma-relay.service") {
        return proxySourceScript(SOURCE_ALMA_SERVICE_URL, assetName, "text/plain; charset=utf-8");
      }
      if (assetName === "alma-relay.openrc") {
        return proxySourceScript(SOURCE_ALMA_OPENRC_URL, assetName);
      }
      if (assetName === "SHA256SUMS") {
        return proxyChecksums();
      }
      return proxyAsset(assetName, assetName.endsWith(".sh") ? false : true);
    }
    if (url.pathname === "/net_relay-main.tar.gz") {
      return proxyAsset("net_relay-main.tar.gz");
    }
    return new Response("Not found\n", {
      status: 404,
      headers: { "content-type": "text/plain; charset=utf-8" },
    });
  },
};
