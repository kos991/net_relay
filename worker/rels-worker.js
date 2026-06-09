const RELEASE_BASE = "https://github.com/kos991/net_relay/releases/latest/download";

function getReleaseBase(env) {
  return (env && env.R2_RELEASE_BASE ? env.R2_RELEASE_BASE : RELEASE_BASE).replace(/\/+$/, "");
}

async function proxyAsset(name, env, contentDisposition = true) {
  const upstream = await fetch(`${getReleaseBase(env)}/${name}`, {
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
  async fetch(request, env) {
    const url = new URL(request.url);

    if (url.pathname === "/" || url.pathname === "/main.sh") {
      return proxyAsset("main.sh", env, false);
    }
    if (url.pathname === "/install.sh") {
      return proxyAsset("install.sh", env);
    }
    if (url.pathname === "/net_relay-main.tar.gz") {
      return proxyAsset("net_relay-main.tar.gz", env);
    }
    if (url.pathname === "/SHA256SUMS") {
      return proxyAsset("SHA256SUMS", env);
    }

    return new Response("Not found\n", {
      status: 404,
      headers: { "content-type": "text/plain; charset=utf-8" },
    });
  },
};
