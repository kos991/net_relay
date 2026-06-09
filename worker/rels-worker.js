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
  if (!env || !env.R2_ACCOUNT_ID || !env.R2_BUCKET || !env.R2_ACCESS_KEY_ID || !env.R2_SECRET_ACCESS_KEY) {
    return null;
  }

  const encodedKey = asset.key.split("/").map(encodeURIComponent).join("/");
  const url = `https://${env.R2_ACCOUNT_ID}.r2.cloudflarestorage.com/${env.R2_BUCKET}/${encodedKey}`;
  const request = new Request(url, { headers: { host: `${env.R2_ACCOUNT_ID}.r2.cloudflarestorage.com` } });
  const signedRequest = await signR2Request(request, env);
  const upstream = await fetch(signedRequest);

  if (upstream.status === 404) {
    return null;
  }

  if (!upstream.ok) {
    return new Response(`Failed to fetch ${asset.name}\n`, {
      status: 502,
      headers: { "content-type": "text/plain; charset=utf-8" },
    });
  }

  const headers = responseHeaders(asset.name, !asset.inline, upstream.headers);
  return new Response(upstream.body, { status: upstream.status, headers });
}

async function signR2Request(request, env) {
  const method = request.method;
  const url = new URL(request.url);
  const service = "s3";
  const region = "auto";
  const algorithm = "AWS4-HMAC-SHA256";
  const now = new Date();
  const amzDate = now.toISOString().replace(/[:-]|\.\d{3}/g, "");
  const dateStamp = amzDate.slice(0, 8);
  const credentialScope = `${dateStamp}/${region}/${service}/aws4_request`;
  const credential = `${env.R2_ACCESS_KEY_ID}/${credentialScope}`;
  const canonicalUri = url.pathname;
  const canonicalQueryString = "";
  const signedHeaders = "host;x-amz-content-sha256;x-amz-date";
  const payloadHash = await sha256Hex("");
  const canonicalHeaders = `host:${url.host}\nx-amz-content-sha256:${payloadHash}\nx-amz-date:${amzDate}\n`;
  const canonicalRequest = [method, canonicalUri, canonicalQueryString, canonicalHeaders, signedHeaders, payloadHash].join("\n");
  const stringToSign = [algorithm, amzDate, credentialScope, await sha256Hex(canonicalRequest)].join("\n");
  const signingKey = await getSignatureKey(env.R2_SECRET_ACCESS_KEY, dateStamp, region, service);
  const signature = await hmacHex(signingKey, stringToSign);
  const headers = new Headers(request.headers);

  headers.set("x-amz-content-sha256", payloadHash);
  headers.set("x-amz-date", amzDate);
  headers.set("authorization", `${algorithm} Credential=${credential}, SignedHeaders=${signedHeaders}, Signature=${signature}`);
  return new Request(request, { headers });
}

async function getSignatureKey(secretKey, dateStamp, regionName, serviceName) {
  const kDate = await hmacRaw(new TextEncoder().encode(`AWS4${secretKey}`), dateStamp);
  const kRegion = await hmacRaw(kDate, regionName);
  const kService = await hmacRaw(kRegion, serviceName);
  return hmacRaw(kService, "aws4_request");
}

async function hmacRaw(key, message) {
  const cryptoKey = await crypto.subtle.importKey("raw", key, { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  return new Uint8Array(await crypto.subtle.sign("HMAC", cryptoKey, new TextEncoder().encode(message)));
}

async function hmacHex(key, message) {
  return hex(await hmacRaw(key, message));
}

async function sha256Hex(message) {
  return hex(new Uint8Array(await crypto.subtle.digest("SHA-256", new TextEncoder().encode(message))));
}

function hex(bytes) {
  return [...bytes].map((byte) => byte.toString(16).padStart(2, "0")).join("");
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
