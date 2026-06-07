const RELEASE_BASE = "https://github.com/kos991/net_relay/releases/latest/download";

const MAIN_SH = `#!/bin/sh
set -eu

INSTALL_URL="\${INSTALL_URL:-https://rels.jinfei.org/install.sh}"

log() {
  printf '%s\\n' "$*" >&2
}

fail() {
  log "$*"
  exit 1
}

run_as_root() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  elif command -v sudo >/dev/null 2>&1; then
    sudo "$@"
  else
    fail "需要 root 权限安装 bash/curl。请使用 root 运行，或先安装 sudo 并授权当前用户。"
  fi
}

ensure_bootstrap_tools() {
  if command -v bash >/dev/null 2>&1 && { command -v curl >/dev/null 2>&1 || command -v wget >/dev/null 2>&1; }; then
    return 0
  fi

  if [ -r /etc/os-release ]; then
    . /etc/os-release
  fi

  case " \${ID:-} \${ID_LIKE:-} " in
    *" alpine "*)
      run_as_root apk add --no-cache bash curl ca-certificates
      ;;
    *" debian "*|*" ubuntu "*)
      run_as_root apt-get update
      run_as_root env DEBIAN_FRONTEND=noninteractive apt-get install -y bash curl ca-certificates
      ;;
    *" rhel "*|*" fedora "*|*" rocky "*|*" almalinux "*|*" centos "*)
      if command -v dnf >/dev/null 2>&1; then
        run_as_root dnf install -y bash curl ca-certificates
      else
        run_as_root yum install -y bash curl ca-certificates
      fi
      ;;
    *)
      fail "无法自动安装 bash/curl。支持 Debian/Ubuntu/Rocky/Alma/Alpine。"
      ;;
  esac
}

download_file() {
  url="$1"
  output="$2"

  log "正在下载安装入口：\${url}"
  if command -v curl >/dev/null 2>&1; then
    curl -fL --connect-timeout 10 --max-time 120 --retry 2 --retry-delay 2 "$url" -o "$output"
  elif command -v wget >/dev/null 2>&1; then
    wget --timeout=10 --tries=3 -O "$output" "$url"
  else
    fail "需要安装 curl 或 wget 后再执行。"
  fi
}

ensure_bootstrap_tools

tmp_file="$(mktemp)"
trap 'rm -f "$tmp_file"' 0 HUP INT TERM

download_file "$INSTALL_URL" "$tmp_file" || {
  log "下载失败：\${INSTALL_URL}"
  log "请检查安装入口是否可访问，或临时设置 INSTALL_URL 为可访问的 install.sh 地址。"
  exit 1
}

bash "$tmp_file"
`;

function textResponse(body) {
  return new Response(body, {
    headers: {
      "content-type": "text/x-shellscript; charset=utf-8",
      "cache-control": "public, max-age=60",
    },
  });
}

async function proxyAsset(name) {
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
  headers.set("content-disposition", `attachment; filename="${name}"`);
  return new Response(upstream.body, {
    status: upstream.status,
    headers,
  });
}

export default {
  async fetch(request) {
    const url = new URL(request.url);

    if (url.pathname === "/" || url.pathname === "/main.sh") {
      return textResponse(MAIN_SH);
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
