#!/usr/bin/env bash
# MITVARIS website — bootstrap.
#
#   curl -fsSL https://raw.githubusercontent.com/mitvaris/website-installer/main/get.sh | sudo bash
#
# Downloads the website's production package from the image registry, checks
# it, unpacks it into /opt/mitvaris-website, and runs its installer. The same
# line upgrades an existing install.
#
# It needs only curl and a READ-ONLY registry token (on GitHub: a classic token
# with read:packages). That token can download images and nothing else — it
# cannot read any source code. This script holds no secrets: it is safe to
# publish.
#
# Options (environment):
#   MITVARIS_VERSION   a release to install, e.g. 2026.09.25-382eba8 (default: latest)
#   MITVARIS_DIR       install folder (default: /opt/mitvaris-website)
#   REGISTRY_USERNAME, REGISTRY_TOKEN   skip the sign-in questions
set -euo pipefail

REGISTRY="ghcr.io"
PACKAGE_REPO="mitvaris/mitvaris-website-package"
DIR="${MITVARIS_DIR:-/opt/mitvaris-website}"
VERSION="${MITVARIS_VERSION:-latest}"

if [ -t 1 ]; then B=$'\e[1m'; G=$'\e[32m'; Y=$'\e[33m'; R=$'\e[31m'; N=$'\e[0m'; else B=''; G=''; Y=''; R=''; N=''; fi
ok()   { printf '%s  ✓ %s%s\n' "$G" "$*" "$N"; }
warn() { printf '%s  ! %s%s\n' "$Y" "$*" "$N"; }
die()  { printf '%s  ✗ %s%s\n' "$R" "$*" "$N" >&2; exit 1; }

# Piped into bash, stdin is this script: questions are asked on the terminal.
[ -r /dev/tty ] || die "run this from an interactive terminal"
[ "$(id -u)" -eq 0 ] || die "run it with sudo:  curl -fsSL <url> | sudo bash"
for tool in curl tar sha256sum; do command -v "$tool" >/dev/null || die "$tool is required"; done

printf '\n%sMITVARIS website installer%s\n\n' "$B" "$N"

# --- Sign-in: from the environment, an existing install, or the operator ----
setting() { grep -E "^$1=" "$2" 2>/dev/null | tail -1 | cut -d= -f2- | sed "s/^'//; s/'\$//" ; }
user="${REGISTRY_USERNAME:-$(setting REGISTRY_USERNAME "$DIR/.env")}"
token="${REGISTRY_TOKEN:-$(setting REGISTRY_TOKEN "$DIR/.env")}"
if [ -z "$token" ]; then
  echo "  The website is downloaded from $REGISTRY. Sign in with a READ-ONLY token"
  echo "  (GitHub: Settings → Developer settings → Tokens (classic) → read:packages only)."
  read -r -p "  Registry username: " user < /dev/tty
  read -r -s -p "  Registry token: " token < /dev/tty; echo
fi
[ -n "$user" ] && [ -n "$token" ] || die "a registry username and token are needed"

# --- Registry API: a pull token for the package repository ------------------
bearer="$(curl -fsS -u "$user:$token" \
  "https://$REGISTRY/token?scope=repository:$PACKAGE_REPO:pull&service=$REGISTRY" \
  | sed -n 's/.*"token"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')" \
  || die "the registry refused the sign-in — check the username and token"
[ -n "$bearer" ] || die "the registry refused the sign-in — check the username and token"
api() { curl -fsS -H "Authorization: Bearer $bearer" "$@"; }
digests() { grep -o '"digest"[[:space:]]*:[[:space:]]*"sha256:[0-9a-f]\{64\}"' | grep -o 'sha256:[0-9a-f]\{64\}'; }

if [ "$VERSION" = latest ]; then
  latest="$(api "https://$REGISTRY/v2/$PACKAGE_REPO/tags/list" \
    | grep -o '"[0-9]\{4\}\.[0-9]\{2\}\.[0-9]\{2\}-[0-9a-f]\{7,\}"' | tr -d '"' | sort -V | tail -1 || true)"
  [ -n "$latest" ] && echo "  Latest release: $latest"
fi

accept='application/vnd.oci.image.manifest.v1+json,application/vnd.docker.distribution.manifest.v2+json'
accept="$accept,application/vnd.oci.image.index.v1+json,application/vnd.docker.distribution.manifest.list.v2+json"
manifest="$(api -H "Accept: $accept" "https://$REGISTRY/v2/$PACKAGE_REPO/manifests/$VERSION")" \
  || die "release '$VERSION' was not found in $REGISTRY/$PACKAGE_REPO"
if printf '%s' "$manifest" | grep -q '"manifests"'; then
  # An index: take its one image manifest.
  inner="$(printf '%s' "$manifest" | digests | head -1)"
  manifest="$(api -H "Accept: $accept" "https://$REGISTRY/v2/$PACKAGE_REPO/manifests/$inner")"
fi
# The package image is one layer, listed after its config: the last digest.
layer="$(printf '%s' "$manifest" | digests | tail -1)"
[ -n "$layer" ] || die "could not read the release manifest"

# --- Download, and check it twice -------------------------------------------
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
api -L -o "$work/layer.tar.gz" "https://$REGISTRY/v2/$PACKAGE_REPO/blobs/$layer" \
  || die "the download failed"
# 1. The registry is content-addressed: the bytes must hash to their digest.
[ "sha256:$(sha256sum "$work/layer.tar.gz" | cut -d' ' -f1)" = "$layer" ] \
  || die "the download does not match its digest — not installing it"
tar -xzf "$work/layer.tar.gz" -C "$work"
pkg="$(find "$work" -maxdepth 1 -name 'mitvaris-website-*.tar.gz' | head -1)"
[ -n "$pkg" ] || die "the release contains no package"
# 2. The package's own checksum, written when it was built.
( cd "$work" && sha256sum -c --quiet "$(basename "$pkg").sha256" ) \
  || die "the package checksum does not match — not installing it"
version="$(basename "$pkg" .tar.gz)"; version="${version#mitvaris-website-}"
ok "downloaded and verified release $version"

# --- Unpack and hand over ----------------------------------------------------
# A package never contains .env, backups/ or releases.log, so unpacking over an
# existing install keeps the settings, the backups and the release history.
mkdir -p "$DIR"
tar -xzf "$pkg" --strip-components=1 -C "$DIR"
ok "unpacked into $DIR"

cd "$DIR"
export REGISTRY_USERNAME="$user" REGISTRY_TOKEN="$token"
exec ./install.sh < /dev/tty
