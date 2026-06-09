const RELEASE_BASE = "https://github.com/kos991/net_relay/releases/latest/download";

function getReleaseBase(env) {
  return (env && env.R2_RELEASE_BASE ? env.R2_RELEASE_BASE : RELEASE_BASE).replace(/\/+$/, "");
}

function objectKeyForPath(pathname) {
  if (pathname === "/" || pathname === "/main.sh") {
    return { key: "latest/main.sh", name: "main.sh", inline: true };
  }

  const latestMatch = pathname.match(/^\/latest\/([^/]+)$/);
  if (latestMatch) {
    return { key: `latest/${latestMatch[1]}`, name: latestMatch[1], inline: latestMatch[1] === "main.sh" };
  }

  const releaseMatch = pathname.match(/^\/releases\/([^/]+)\/([^/]+)$/);
  if (releaseMatch) {
    return {
      key: `releases/${releaseMatch[1]}/${releaseMatch[2]}`,
      name: releaseMatch[2],
      inline: releaseMatch[2] === "main.sh",
    };
  }

  const rootAssets = new Set(["install.sh", "net_relay-main.tar.gz", "SHA256SUMS"]);
  const rootName = pathname.replace(/^\/+/, "");
  if (rootAssets.has(rootName)) {
    return { key: `latest/${rootName}`, name: rootName, inline: false };
  }

  return null;
}

function responseHeaders(name, contentDisposition = true, sourceHeaders = new Headers()) {
  const headers = new Headers(sourceHeaders);
  headers.set("cache-control", "public, max-age=300");
  if (name.endsWith(".sh")) {
    headers.set("content-type", "text/x-shellscript; charset=utf-8");
  }
  if (contentDisposition) {
    headers.set("content-disposition", `attachment; filename="${name}"`);
  } else {
    headers.delete("content-disposition");
  }
  return headers;
}

async function getR2Asset(asset, env) {
  if (!env || !env.RELEASE_BUCKET) {
    return null;
  }

  const object = await env.RELEASE_BUCKET.get(asset.key);
  if (!object) {
    return null;
  }

  const headers = responseHeaders(asset.name, !asset.inline);
  object.writeHttpMetadata(headers);
  headers.set("etag", object.httpEtag);
  return new Response(object.body, { headers });
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

  const headers = responseHeaders(name, contentDisposition, upstream.headers);

  return new Response(upstream.body, {
    status: upstream.status,
    headers,
  });
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const asset = objectKeyForPath(url.pathname);

    if (asset) {
      const r2Response = await getR2Asset(asset, env);
      if (r2Response) {
        return r2Response;
      }
    }

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
