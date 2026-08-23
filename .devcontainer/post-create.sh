#!/usr/bin/env bash
set -euo pipefail

# --- System packages the app needs to even boot, plus a browser for system tests ---
# libvips: image_processing/ruby-vips (Gemfile) loads it via FFI at runtime, not at
#   `bundle install` time, so its absence doesn't show up until the app actually boots.
# chromium/chromium-driver: `bin/rails test:system` (test/application_system_test_case.rb)
#   drives headless Chrome. CI gets a browser for free from the GitHub-hosted runner
#   image; this container doesn't, so install one explicitly.
# node-gyp: mirrors what .github/workflows/ci.yml installs, so this container matches CI.
# fonts-noto-cjk: the base image ships no CJK glyphs at all. Without this, headless
#   Chromium (system tests, and anyone taking a screenshot) renders every Japanese
#   character as a tofu box — silent, and easy to mistake for a real rendering bug.
sudo apt-get update
sudo apt-get install -y --no-install-recommends libvips42t64 chromium chromium-driver node-gyp fonts-noto-cjk

# --- yuru7 fonts: install locally, not bundled into the app ---
# The app's CJK monospace stack (app/assets/stylesheets/_typography.scss) names
# three of these first — Bizin Gothic, UDEV Gothic, HackGen — because their
# 1:2 half/full-width ratio makes mixed Japanese/code text far easier to read
# than the fallbacks. The app deliberately does NOT ship any of the font
# files itself: bundling multi-MB fonts to be downloaded on every fresh visit
# isn't worth it just to upgrade a font that already degrades gracefully to
# the next name in the stack. Installing them here is purely so this
# container's own headless Chrome (system tests, screenshots) renders the
# fonts the project actually recommends, matching what a contributor who
# followed docs/engineering/dev-environment.md would see locally. End users
# who want the same upgrade install them the same way, on their own machine.
#
# Only the plain Regular/Bold weights are installed — not the Console/35/NF/
# JPDOC/etc. variants each project also ships — matching the family names
# the CSS stack actually asks for.
install_yuru7_font() {
  local dest_name="$1"
  local zip_url="$2"
  local tmp="/tmp/${dest_name}-install"
  local dest="$HOME/.local/share/fonts/$dest_name"
  shift 2
  if [ -d "$dest" ] && [ -n "$(ls -A "$dest" 2>/dev/null)" ]; then
    return
  fi
  mkdir -p "$dest" "$tmp"
  curl -sL -o "$tmp/font.zip" "$zip_url"
  unzip -o -q "$tmp/font.zip" -d "$tmp/extracted"
  for pattern in "$@"; do
    find "$tmp/extracted" -name "$pattern" -exec cp {} "$dest/" \;
  done
  rm -rf "$tmp"
  fc-cache -f "$dest" >/dev/null
}

install_yuru7_font "bizin-gothic" \
  "https://github.com/yuru7/bizin-gothic/releases/download/v0.0.4/BizinGothic_v0.0.4.zip" \
  "BizinGothic-Regular.ttf" "BizinGothic-Bold.ttf"

install_yuru7_font "udev-gothic" \
  "https://github.com/yuru7/udev-gothic/releases/download/v2.2.0/UDEVGothic_v2.2.0.zip" \
  "UDEVGothic-Regular.ttf" "UDEVGothic-Bold.ttf"

install_yuru7_font "hackgen" \
  "https://github.com/yuru7/HackGen/releases/download/v2.10.0/HackGen_v2.10.0.zip" \
  "HackGen-Regular.ttf" "HackGen-Bold.ttf"

# --- Ruby LSP: register the container's Ruby with rbenv ---
mkdir -p "$(rbenv root)/versions"
ln -sfn "$(dirname "$(dirname "$(which ruby)")")" "$(rbenv root)/versions/$(cat .ruby-version)"
rbenv rehash
gem install rails

# --- Claude Code: fix ownership of the persisted ~/.claude volume ---
# Docker mounts a brand-new named volume as root-owned. Without this, the
# vscode user can't write auth/session data into it and every rebuild
# forces a re-login.
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
if [ -d "$CLAUDE_DIR" ] && [ "$(stat -c '%U' "$CLAUDE_DIR")" != "$(id -un)" ]; then
  sudo chown -R "$(id -un):$(id -gn)" "$CLAUDE_DIR"
fi

# Seed a minimal config so the extension doesn't error before first login.
if [ ! -s "$CLAUDE_DIR/.claude.json" ]; then
  mkdir -p "$CLAUDE_DIR"
  echo '{}' > "$CLAUDE_DIR/.claude.json"
fi
