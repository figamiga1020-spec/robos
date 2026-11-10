#!/usr/bin/env bash
# Installs the pinned toolchain into ~/.local/bin (Linux x86_64) and fetches Roblox type definitions.
set -euo pipefail
BIN="${HOME}/.local/bin"
mkdir -p "$BIN"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$ROOT/.tools"
get() {
	local tmp
	tmp="$(mktemp -d)"
	curl -sSL -o "$tmp/t.zip" "$1"
	unzip -o -q "$tmp/t.zip" -d "$BIN"
	rm -rf "$tmp"
}
command -v rojo >/dev/null || get https://github.com/rojo-rbx/rojo/releases/download/v7.7.1/rojo-7.7.1-linux-x86_64.zip
command -v selene >/dev/null || get https://github.com/Kampfkarren/selene/releases/download/0.32.0/selene-0.32.0-linux.zip
command -v stylua >/dev/null || get https://github.com/JohnnyMorganz/StyLua/releases/download/v2.6.0/stylua-linux-x86_64.zip
command -v lune >/dev/null || get https://github.com/lune-org/lune/releases/download/v0.11.1/lune-0.11.1-linux-x86_64.zip
command -v luau-lsp >/dev/null || get https://github.com/JohnnyMorganz/luau-lsp/releases/download/1.70.1/luau-lsp-linux-x86_64.zip
chmod +x "$BIN"/* || true
[ -f "$ROOT/.tools/globalTypes.d.luau" ] || curl -sSL -o "$ROOT/.tools/globalTypes.d.luau" \
	https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/main/scripts/globalTypes.d.luau
echo "tools ready in $BIN"
