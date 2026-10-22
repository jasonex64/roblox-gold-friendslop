#!/usr/bin/env bash
# CI only (Linux x86_64). Installs the exact versions pinned in rokit.toml.
# Locally, use `rokit install` instead.
set -euo pipefail
ver() { grep -E "^$1 *=" rokit.toml | sed -E 's/.*@([0-9.]+)".*/\1/'; }
BIN="$HOME/.local/bin"; mkdir -p "$BIN"
get() { # name url
	local tmp; tmp="$(mktemp -d)"
	curl -fsSL "$2" -o "$tmp/t.zip"
	unzip -oq "$tmp/t.zip" -d "$tmp/x"
	install -m 755 "$(find "$tmp/x" -type f -name "$1" | head -n1)" "$BIN/$1"
	rm -rf "$tmp"
}
get rojo   "https://github.com/rojo-rbx/rojo/releases/download/v$(ver rojo)/rojo-$(ver rojo)-linux-x86_64.zip"
get lune   "https://github.com/lune-org/lune/releases/download/v$(ver lune)/lune-$(ver lune)-linux-x86_64.zip"
get stylua "https://github.com/JohnnyMorganz/StyLua/releases/download/v$(ver stylua)/stylua-linux-x86_64.zip"
get selene "https://github.com/Kampfkarren/selene/releases/download/$(ver selene)/selene-$(ver selene)-linux.zip"
echo "$BIN" >> "${GITHUB_PATH:-/dev/null}"
"$BIN/rojo" --version; "$BIN/lune" --version; "$BIN/stylua" --version; "$BIN/selene" --version
