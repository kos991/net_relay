const RELEASE_TAG = "v1.0.3";
const RELEASE_BASE = `https://github.com/kos991/net_relay/releases/download/${RELEASE_TAG}`;

const MAIN_SH_B64 = "IyEvdXNyL2Jpbi9lbnYgYmFzaApzZXQgLWV1byBwaXBlZmFpbAoKSU5TVEFMTF9VUkw9IiR7SU5TVEFMTF9VUkw6LWh0dHBzOi8vcmVscy5qaW5mZWkub3JnL2luc3RhbGwuc2h9IgoKdG1wX2ZpbGU9IiQobWt0ZW1wKSIKY2xlYW51cCgpIHsKICBybSAtZiAiJHRtcF9maWxlIgp9CnRyYXAgY2xlYW51cCBFWElUCgpkb3dubG9hZF9maWxlKCkgewogIGxvY2FsIHVybD0iJDEiCiAgbG9jYWwgb3V0cHV0PSIkMiIKCiAgZWNobyAi5q2j5Zyo5LiL6L295a6J6KOF5YWl5Y+j77yaJHt1cmx9IiA+JjIKICBpZiBjb21tYW5kIC12IGN1cmwgPi9kZXYvbnVsbCAyPiYxOyB0aGVuCiAgICBjdXJsIC1mTCAtLWNvbm5lY3QtdGltZW91dCAxMCAtLW1heC10aW1lIDEyMCAtLXJldHJ5IDIgLS1yZXRyeS1kZWxheSAyICIkdXJsIiAtbyAiJG91dHB1dCIKICBlbGlmIGNvbW1hbmQgLXYgd2dldCA+L2Rldi9udWxsIDI+JjE7IHRoZW4KICAgIHdnZXQgLS10aW1lb3V0PTEwIC0tdHJpZXM9MyAtTyAiJG91dHB1dCIgIiR1cmwiCiAgZWxzZQogICAgZWNobyAi6ZyA6KaB5a6J6KOFIGN1cmwg5oiWIHdnZXQg5ZCO5YaN5omn6KGM44CCIiA+JjIKICAgIGV4aXQgMQogIGZpCn0KCmRvd25sb2FkX2ZpbGUgIiRJTlNUQUxMX1VSTCIgIiR0bXBfZmlsZSIgfHwgewogIGVjaG8gIuS4i+i9veWksei0pe+8miR7SU5TVEFMTF9VUkx9IiA+JjIKICBlY2hvICLor7fmo4Dmn6Xlronoo4XlhaXlj6PmmK/lkKblj6/orr/pl67vvIzmiJbkuLTml7borr7nva4gSU5TVEFMTF9VUkwg5Li65Y+v6K6/6Zeu55qEIGluc3RhbGwuc2gg5Zyw5Z2A44CCIiA+JjIKICBleGl0IDEKfQoKYmFzaCAiJHRtcF9maWxlIgo=";
const INSTALL_SH_B64 = "IyEvdXNyL2Jpbi9lbnYgYmFzaApzZXQgLWV1byBwaXBlZmFpbAoKUkVQT19VUkw9IiR7UkVQT19VUkw6LWh0dHBzOi8vZ2l0aHViLmNvbS9rb3M5OTEvbmV0X3JlbGF5LmdpdH0iCkFSQ0hJVkVfVVJMPSIke0FSQ0hJVkVfVVJMOi1odHRwczovL3JlbHMuamluZmVpLm9yZy9uZXRfcmVsYXktbWFpbi50YXIuZ3p9IgpBUkNISVZFX0ZBTExCQUNLX1VSTD0iJHtBUkNISVZFX0ZBTExCQUNLX1VSTDotaHR0cHM6Ly9naXRodWIuY29tL2tvczk5MS9uZXRfcmVsYXkvYXJjaGl2ZS9yZWZzL2hlYWRzL21haW4udGFyLmd6fSIKSU5TVEFMTF9ESVI9IiR7SU5TVEFMTF9ESVI6LS9vcHQvbmV0YmlyZC1yZWxheS1pbnN0YWxsZXJ9IgpCUkFOQ0g9IiR7QlJBTkNIOi1tYWlufSIKCkdSRUVOPSdcMDMzWzA7MzJtJwpSRUQ9J1wwMzNbMDszMW0nCllFTExPVz0nXDAzM1sxOzMzbScKTkM9J1wwMzNbMG0nCgpsb2coKSB7CiAgZWNobyAtZSAiJHtHUkVFTn0kKiR7TkN9Igp9Cgp3YXJuKCkgewogIGVjaG8gLWUgIiR7WUVMTE9XfSQqJHtOQ30iCn0KCmZhaWwoKSB7CiAgZWNobyAtZSAiJHtSRUR9JCoke05DfSIgPiYyCiAgZXhpdCAxCn0KCmRvd25sb2FkX2ZpbGUoKSB7CiAgbG9jYWwgdXJsPSIkMSIKICBsb2NhbCBvdXRwdXQ9IiQyIgogIGxvY2FsIGZhbGxiYWNrX3VybD0iJHszOi19IgoKICBsb2cgIuato+WcqOS4i+i9veWuieijheWZqO+8miR7dXJsfSIKICBpZiBjb21tYW5kIC12IGN1cmwgPi9kZXYvbnVsbCAyPiYxOyB0aGVuCiAgICBpZiBjdXJsIC1mTCAtLWNvbm5lY3QtdGltZW91dCAxMCAtLW1heC10aW1lIDE4MCAtLXJldHJ5IDIgLS1yZXRyeS1kZWxheSAyICIkdXJsIiAtbyAiJG91dHB1dCI7IHRoZW4KICAgICAgcmV0dXJuIDAKICAgIGZpCiAgZWxpZiBjb21tYW5kIC12IHdnZXQgPi9kZXYvbnVsbCAyPiYxOyB0aGVuCiAgICBpZiB3Z2V0IC0tdGltZW91dD0xMCAtLXRyaWVzPTMgLU8gIiRvdXRwdXQiICIkdXJsIjsgdGhlbgogICAgICByZXR1cm4gMAogICAgZmkKICBlbHNlCiAgICBmYWlsICLpnIDopoHlronoo4UgZ2l044CBY3VybCDmiJYgd2dldCDkuYvkuIDvvIznlKjkuo7kuIvovb3lronoo4XlmajjgIIiCiAgZmkKCiAgaWYgW1sgLW4gIiRmYWxsYmFja191cmwiIF1dOyB0aGVuCiAgICB3YXJuICLkuLvkuIvovb3lnLDlnYDlpLHotKXvvIzlsJ3or5UgR2l0SHViIOWkh+eUqO+8miR7ZmFsbGJhY2tfdXJsfSIKICAgIGlmIGNvbW1hbmQgLXYgY3VybCA+L2Rldi9udWxsIDI+JjE7IHRoZW4KICAgICAgY3VybCAtZkwgLS1jb25uZWN0LXRpbWVvdXQgMTAgLS1tYXgtdGltZSAxODAgLS1yZXRyeSAxIC0tcmV0cnktZGVsYXkgMiAiJGZhbGxiYWNrX3VybCIgLW8gIiRvdXRwdXQiCiAgICBlbHNlCiAgICAgIHdnZXQgLS10aW1lb3V0PTEwIC0tdHJpZXM9MiAtTyAiJG91dHB1dCIgIiRmYWxsYmFja191cmwiCiAgICBmaQogIGVsc2UKICAgIHJldHVybiAxCiAgZmkKfQoKbmVlZF9yb290X2Zvcl9pbnN0YWxsX2RpcigpIHsKICBpZiBbWyAiJHtFVUlEfSIgLW5lIDAgJiYgIiRJTlNUQUxMX0RJUiIgPT0gL29wdC8qIF1dOyB0aGVuCiAgICBmYWlsICLor7fkvb/nlKggcm9vdCDmiafooYzvvIzmiJbpgJrov4cgSU5TVEFMTF9ESVIg5oyH5a6a5b2T5YmN55So5oi35Y+v5YaZ55uu5b2V44CCIgogIGZpCn0KCmRvd25sb2FkX3dpdGhfdGFyYmFsbCgpIHsKICBsb2NhbCB0bXBfZGlyCiAgdG1wX2Rpcj0iJChta3RlbXAgLWQpIgoKICBpZiBjb21tYW5kIC12IGN1cmwgPi9kZXYvbnVsbCAyPiYxOyB0aGVuCiAgICBkb3dubG9hZF9maWxlICIkQVJDSElWRV9VUkwiICIkdG1wX2Rpci9yZXBvLnRhci5neiIgIiRBUkNISVZFX0ZBTExCQUNLX1VSTCIKICBlbGlmIGNvbW1hbmQgLXYgd2dldCA+L2Rldi9udWxsIDI+JjE7IHRoZW4KICAgIGRvd25sb2FkX2ZpbGUgIiRBUkNISVZFX1VSTCIgIiR0bXBfZGlyL3JlcG8udGFyLmd6IiAiJEFSQ0hJVkVfRkFMTEJBQ0tfVVJMIgogIGVsc2UKICAgIGZhaWwgIumcgOimgeWuieijhSBnaXTjgIFjdXJsIOaIliB3Z2V0IOS5i+S4gO+8jOeUqOS6juS4i+i9veWuieijheWZqOOAgiIKICBmaQoKICBybSAtcmYgIiRJTlNUQUxMX0RJUiIKICBta2RpciAtcCAiJElOU1RBTExfRElSIgogIHRhciAteHpmICIkdG1wX2Rpci9yZXBvLnRhci5neiIgLUMgIiR0bXBfZGlyIgogIHNob3B0IC1zIGRvdGdsb2IgbnVsbGdsb2IKICBtdiAiJHRtcF9kaXIiL25ldF9yZWxheS0qLyogIiRJTlNUQUxMX0RJUiIvCiAgcm0gLXJmICIkdG1wX2RpciIKfQoKc3luY19yZXBvKCkgewogIG1rZGlyIC1wICIkKGRpcm5hbWUgIiRJTlNUQUxMX0RJUiIpIgoKICBpZiBjb21tYW5kIC12IGdpdCA+L2Rldi9udWxsIDI+JjE7IHRoZW4KICAgIHdhcm4gIuajgOa1i+WIsCBnaXTvvIzkvYbpu5jorqTkvb/nlKggcmVscy5qaW5mZWkub3JnIOWuieijheWMheS7pemBv+WFjSBHaXRIdWIg572R57uc5LiN56iz5a6a44CCIgogIGVsc2UKICAgIHdhcm4gIuacquajgOa1i+WIsCBnaXTvvIzkvb/nlKjljovnvKnljIXkuIvovb3lronoo4XlmajjgIIiCiAgZmkKICBkb3dubG9hZF93aXRoX3RhcmJhbGwKfQoKbmVlZF9yb290X2Zvcl9pbnN0YWxsX2RpcgpzeW5jX3JlcG8KY2htb2QgK3ggIiRJTlNUQUxMX0RJUi9zZXR1cC1yZWxheS5zaCIKCmxvZyAi5q2j5Zyo5ZCv5Yqo5a6J6KOF5Zmo77yaJHtJTlNUQUxMX0RJUn0iCmNkICIkSU5TVEFMTF9ESVIiCmV4ZWMgLi9zZXR1cC1yZWxheS5zaAo=";

function decodeBase64(value) {
  const binary = atob(value);
  const bytes = Uint8Array.from(binary, (char) => char.charCodeAt(0));
  return new TextDecoder().decode(bytes);
}

const MAIN_SH = decodeBase64(MAIN_SH_B64);
const INSTALL_SH = decodeBase64(INSTALL_SH_B64);

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
      return textResponse(INSTALL_SH);
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


