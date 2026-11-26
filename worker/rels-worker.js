const RELEASE_BASE = "https://github.com/kos991/net_relay/releases/latest/download";
const RELEASE_ASSETS = new Set([
  "main.sh",
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
const INLINE_ASSETS = new Set([
  "main.sh",
  "rels",
  "install.sh",
  "setup-relay.sh",
  "reload-relay-certificate.sh",
  "SHA256SUMS",
  "alma-relay.service",
  "alma-relay.openrc",
]);

function contentTypeFor(name) {
  if (name.endsWith(".sh") || name === "rels" || name.endsWith(".openrc")) {
    return "text/x-shellscript; charset=utf-8";
  }
  if (name === "SHA256SUMS" || name.endsWith(".service")) {
    return "text/plain; charset=utf-8";
  }
  if (name.endsWith(".cjs")) {
    return "application/javascript; charset=utf-8";
  }
  return null;
}

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
  headers.set("cache-control", INLINE_ASSETS.has(name) ? "public, max-age=60" : "public, max-age=300");
  const contentType = contentTypeFor(name);
  if (contentType) {
    headers.set("content-type", contentType);
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

export default {
  async fetch(request) {
    const url = new URL(request.url);

    if (url.pathname === "/" || url.pathname === "/main.sh") {
      return proxyAsset("main.sh", false);
    }
    if (url.pathname === "/install.sh") {
      return proxyAsset("install.sh", false);
    }
    if (url.pathname === "/SHA256SUMS") {
      return proxyAsset("SHA256SUMS", false);
    }
    if (url.pathname.startsWith("/download/")) {
      const assetName = url.pathname.slice("/download/".length);
      if (!RELEASE_ASSETS.has(assetName)) {
        return new Response("Not found\n", {
          status: 404,
          headers: { "content-type": "text/plain; charset=utf-8" },
        });
      }
      return proxyAsset(assetName, !INLINE_ASSETS.has(assetName));
    }
    if (url.pathname === "/net_relay-main.tar.gz") {
      return proxyAsset("net_relay-main.tar.gz", true);
    }
    return new Response("Not found\n", {
      status: 404,
      headers: { "content-type": "text/plain; charset=utf-8" },
    });
  },
};
