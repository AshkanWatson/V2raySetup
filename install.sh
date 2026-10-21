#!/usr/bin/env bash
# V2raySetup bootstrap — downloads the app to /opt/v2raysetup and starts it.
#
#   bash <(curl -fsSL https://raw.githubusercontent.com/AshkanWatson/V2raySetup/main/install.sh)
#
# Env: V2S_BRANCH (default main), V2S_PREFIX (default /opt/v2raysetup)
set -euo pipefail

REPO=AshkanWatson/V2raySetup
BRANCH=${V2S_BRANCH:-main}
PREFIX=${V2S_PREFIX:-/opt/v2raysetup}

say() { printf '\033[38;5;173m●\033[0m %s\n' "$*"; }
die() { printf '\033[31m✖\033[0m %s\n' "$*" >&2; exit 1; }

[[ $EUID -eq 0 ]] || die "Please run as root (sudo -i)."
command -v curl >/dev/null || {
  say "Installing curl"
  if command -v apt-get >/dev/null; then apt-get update -y >/dev/null && apt-get install -y curl >/dev/null
  elif command -v dnf >/dev/null; then dnf install -y curl >/dev/null
  elif command -v yum >/dev/null; then yum install -y curl >/dev/null
  elif command -v apk >/dev/null; then apk add --no-cache curl bash >/dev/null
  else die "curl is required"; fi
}
command -v tar >/dev/null || die "tar is required"

tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
say "Downloading V2raySetup ($BRANCH)"
curl -fsSL "https://codeload.github.com/$REPO/tar.gz/refs/heads/$BRANCH" -o "$tmp/src.tgz" ||
  curl -fsSL "https://github.com/$REPO/archive/refs/heads/$BRANCH.tar.gz" -o "$tmp/src.tgz" ||
  die "Download failed. Is GitHub reachable from this server?"
tar -xzf "$tmp/src.tgz" -C "$tmp"
src=$(find "$tmp" -mindepth 1 -maxdepth 1 -type d | head -n1)
[[ -f $src/v2raysetup.sh ]] || die "Downloaded archive looks wrong"

rm -rf "$PREFIX.new"; mkdir -p "$PREFIX.new"
cp -a "$src/." "$PREFIX.new/"
rm -rf "$PREFIX"; mv "$PREFIX.new" "$PREFIX"
chmod +x "$PREFIX/v2raysetup.sh" "$PREFIX/lib/iran-guard.sh"
ln -sf "$PREFIX/v2raysetup.sh" /usr/local/bin/v2raysetup
say "Installed to $PREFIX — run it any time with: v2raysetup"

exec bash "$PREFIX/v2raysetup.sh" "$@"
