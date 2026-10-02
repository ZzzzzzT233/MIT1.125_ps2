#!/usr/bin/env bash
# Application entry point: check dependencies, then start the main menu.
#   ./app.sh

ROOT="$(cd "$(dirname "$0")" && pwd)"

if ! command -v gum >/dev/null 2>&1; then
  echo "This app needs Gum: https://github.com/charmbracelet/gum  (macOS: brew install gum)" >&2
  exit 1
fi

chmod +x "$ROOT"/*.sh "$ROOT"/*/*.sh 2>/dev/null   # make every component runnable
exec "$ROOT/ui/main_menu.sh"
