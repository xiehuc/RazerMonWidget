#!/bin/bash
# Compatibility entry point for checkout users.
set -euo pipefail
exec /bin/bash "$(cd "$(dirname "$0")/.." && pwd)/install.sh" "$@"
