#!/bin/bash
# Supports: curl -fsSL https://raw.githubusercontent.com/xiehuc/RazerMonWidget/main/install.sh | bash
set -euo pipefail

repo="${RAZERMONWIDGET_REPO:-xiehuc/RazerMonWidget}"
version=latest
local_mode=false
usage() {
    cat <<'HELP'
Install RazerMonWidget as a per-user launchctl service (without sudo).

Usage: bash install.sh [--version TAG] [--repo OWNER/REPO]
       bash install.sh --local

Default: download a precompiled universal macOS binary from GitHub Releases.
  --local        Install the project’s existing build; no download or compilation.
  --version TAG  Use a specific release instead of the latest release.
  --repo REPO    GitHub repository (default: xiehuc/RazerMonWidget).
  -h, --help     Show this help.
HELP
}
fail() { printf 'Error: %s\n' "$*" >&2; exit 1; }
while [ "$#" -gt 0 ]; do
    case "$1" in
        --local) local_mode=true; shift ;;
        --version|--repo)
            [ "$#" -ge 2 ] && [ -n "$2" ] || fail "$1 requires a value"
            case "$1" in
                --version) version="$2" ;;
                --repo) repo="$2" ;;
            esac
            shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) fail "Unknown argument: $1 (use --help)" ;;
    esac
done
[ "$(uname -s)" = Darwin ] || fail 'macOS is required'
[ "$(id -u)" -ne 0 ] || fail 'Run as your logged-in user, without sudo'
case "$(uname -m)" in arm64|x86_64) ;; *) fail 'Unsupported CPU architecture' ;; esac
/bin/launchctl print "gui/$(id -u)" >/dev/null 2>&1 || fail 'A logged-in macOS GUI session is required'

if [ "$local_mode" = true ]; then
    [ "$version" = latest ] || fail '--local cannot be combined with --version'
    [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ] || fail '--local must be run from a saved install.sh'
    project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    binary=""
    for candidate in \
        "$project_dir/.build/release/RazerMonWidget" \
        "$project_dir/.build/apple/Products/Release/RazerMonWidget" \
        "$project_dir/dist/RazerMonWidget-macos-universal"; do
        if [ -f "$candidate" ] && [ -x "$candidate" ]; then
            binary="$candidate"
            break
        fi
    done
    [ -n "$binary" ] || fail 'No local release binary found. Run swift build -c release or bash scripts/build-release.sh first.'
    printf 'Installing local binary: %s\n' "$binary"

else
    [[ "$repo" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] || fail 'Invalid OWNER/REPO'
    [[ "$version" =~ ^[A-Za-z0-9_.-]+$ ]] || fail 'Invalid release tag'
    temporary="$(mktemp -d "${TMPDIR:-/tmp}/razermonwidget.XXXXXXXX")"
    trap 'rm -rf "$temporary"' EXIT
    asset=RazerMonWidget-macos-universal
    if [ "$version" = latest ]; then
        base="https://github.com/$repo/releases/latest/download"
    else
        base="https://github.com/$repo/releases/download/$version"
    fi
    printf 'Downloading %s (%s)...\n' "$repo" "$version"
    curl --fail --silent --show-error --location --proto '=https' --tlsv1.2 "$base/$asset" -o "$temporary/$asset"
    curl --fail --silent --show-error --location --proto '=https' --tlsv1.2 "$base/$asset.sha256" -o "$temporary/$asset.sha256"
    expected="$(awk 'NR == 1 { print $1 }' "$temporary/$asset.sha256")"
    [[ "$expected" =~ ^[a-fA-F0-9]{64}$ ]] || fail 'Invalid SHA-256 checksum file'
    actual="$(shasum -a 256 "$temporary/$asset" | awk '{ print $1 }')"
    [ "$actual" = "$expected" ] || fail 'Release checksum mismatch'
    binary="$temporary/$asset"
    chmod 755 "$binary"
fi
# Verification precedes any changes to the installed service. Keep the release signature.
/usr/bin/codesign --verify --strict "$binary" || fail 'Invalid executable signature'
"$binary" --install-service
