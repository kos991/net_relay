const RELEASE_BASE = "https://github.com/kos991/net_relay/releases/latest/download";

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

export default {
  async fetch(request) {
    const url = new URL(request.url);

    if (url.pathname === "/" || url.pathname === "/main.sh") {
      return proxyAsset("main.sh", false);
    }
    if (url.pathname === "/install.sh") {
      return proxyAsset("install.sh");
    }
    if (url.pathname === "/net_relay-main.tar.gz") {
      return proxyAsset("net_relay-main.tar.gz");
    }
    if (url.pathname === "/SHA256SUMS") {
      return proxyAsset("SHA256SUMS");
    }

    return new Response("Not found\n", {
      status: 404,
      headers: { "content-type": "text/plain; charset=utf-8" },
    });
  },
};
