# shellcheck shell=bash
# `omacase theme [name]` — apply one theme to every app at once. A theme is a
# directory under themes/<name>/ containing per-app fragments that get symlinked
# or rendered into the live config locations.

omacase_theme() {
  local name="${1:-}"
  local themes_dir="$OMACASE_ROOT/themes"

  if [ -z "$name" ]; then
    name="$(gum_choose "Pick a theme" $(_theme_list))" || return
  fi
  local src="$themes_dir/$name"
  [ -d "$src" ] || abort "Unknown theme '$name'. Available: $(_theme_list | tr '\n' ' ')"

  info "Applying theme: $name"
  # Each app reads a single 'current' file that we point at the chosen theme.
  # Apps include this file from their main config (see home/dot_config/*).
  local cfg="$HOME/.config"
  _link "$src/ghostty"    "$cfg/ghostty/theme"
  _link "$src/sketchybar" "$cfg/sketchybar/theme.sh"
  _link "$src/borders"    "$cfg/borders/theme.conf"
  _link "$src/btop"       "$cfg/btop/themes/current.theme"
  _link "$src/nvim.lua"   "$cfg/nvim/lua/theme.lua"
  _link "$src/starship"   "$cfg/starship/theme.toml"

  is_dryrun || echo "$name" > "$OMACASE_STATE/theme"
  _theme_appearance "$name"
  _theme_reload
  success "Theme '$name' applied."
}

_theme_list() { ls -1 "$OMACASE_ROOT/themes" 2>/dev/null; }

# Light vs dark is derived from the theme's SketchyBar BAR_COLOR (0xffRRGGBB)
# using perceived luminance, so it stays correct for every theme with no
# per-theme flag to maintain. Returns 0 (true) when the background is light.
_theme_is_light() {
  local f="$OMACASE_ROOT/themes/$1/sketchybar" hex
  hex="$(sed -n 's/.*BAR_COLOR=0[xX][fF][fF]\([0-9a-fA-F]\{6\}\).*/\1/p' "$f" 2>/dev/null | head -1)"
  [ -n "$hex" ] || return 1   # unknown/empty background → treat as dark
  local r=$((16#${hex:0:2})) g=$((16#${hex:2:2})) b=$((16#${hex:4:2}))
  # Rec. 601 luma scaled by 1000 to stay in integer math; >128 ≈ light.
  [ $(( (299*r + 587*g + 114*b) / 1000 )) -gt 128 ]
}

# Match macOS system appearance to the theme's brightness at switch time.
_theme_appearance() {
  local dark=true
  _theme_is_light "$1" && dark=false
  info "macOS appearance → $([ "$dark" = true ] && echo Dark || echo Light)"
  # System Events drives the global Light/Dark toggle; needs Automation consent
  # for the controlling terminal (granted once, on first prompt).
  run osascript -e "tell application \"System Events\" to tell appearance preferences to set dark mode to $dark" >/dev/null 2>&1 \
    || warn "Couldn't set macOS appearance (grant Automation to your terminal: System Settings → Privacy & Security → Automation)."
}

_link() { # _link <src> <dest>  (only if src exists)
  [ -e "$1" ] || return 0
  run mkdir -p "$(dirname "$2")"
  run ln -sfn "$1" "$2"
}

_theme_reload() {
  # Live-reload anything already running; ignore if not.
  pgrep -x sketchybar >/dev/null && run sketchybar --reload || true
  pgrep -x borders   >/dev/null && run brew services restart borders 2>/dev/null || true
  # Ghostty reloads its config (and the theme include) on SIGUSR2 since 1.2,
  # which also refreshes ANSI-palette CLIs like eza/ls. CAUTION: any OTHER
  # signal makes Ghostty quit. macOS truncates `comm` and hides GUI argv from
  # pgrep, so find the GUI process precisely via ps: args is exactly the binary
  # path with no extra args (NF==2), which excludes `ghostty +cmd` CLI runs.
  local gpid
  gpid="$(ps -Axo pid=,args= | awk '$2=="/Applications/Ghostty.app/Contents/MacOS/ghostty" && NF==2 {print $1}')"
  [ -n "$gpid" ] && run kill -USR2 $gpid || true
  # nvim picks up the theme on next launch or via its own reload bind.
}
