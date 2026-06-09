# shellcheck shell=bash
# `omacase wm <aerospace|yabai>` — choose the window-manager profile.
#
#   aerospace (default): no SIP disable, stable, i3-style tiling.
#   yabai (advanced):    real BSP dynamic tiling, but requires SIP partially
#                        disabled (manual Recovery step — see _yabai_notes).
# Both share SketchyBar + JankyBorders.

omacase_wm() {
  local profile="${1:-}"
  [ -n "$profile" ] || profile="$(gum_choose "Window manager profile" aerospace yabai)" || return

  case "$profile" in
    aerospace) _wm_use_aerospace ;;
    yabai)     _wm_use_yabai ;;
    *) abort "Unknown wm profile '$profile' (aerospace|yabai)" ;;
  esac
  is_dryrun || echo "$profile" > "$OMACASE_STATE/wm"
}

_wm_stop_all() {
  for svc in yabai skhd aerospace; do
    run brew services stop "$svc" 2>/dev/null || true
  done
  pgrep -x AeroSpace >/dev/null && run osascript -e 'quit app "AeroSpace"' 2>/dev/null || true
}

_wm_start_shared() {
  run brew services start borders 2>/dev/null || warn "borders not installed?"
  run brew services start sketchybar 2>/dev/null || warn "sketchybar not installed?"
}

_wm_use_aerospace() {
  info "Profile: AeroSpace (no SIP disable required)"
  _wm_stop_all
  # AeroSpace runs as a regular app from /Applications, started at login via
  # its own config (start-at-login = true). Just launch it now.
  run open -a AeroSpace 2>/dev/null || warn "AeroSpace not installed — check Brewfile/brew bundle."
  _wm_start_shared
  success "AeroSpace active. Alt+hjkl focus, Alt+Shift+hjkl move, Alt+[1-9] workspaces."
}

_wm_use_yabai() {
  info "Profile: yabai (advanced — needs SIP partially disabled)"
  if ! _sip_ok_for_yabai; then _yabai_notes; fi
  _wm_stop_all
  run brew services start yabai 2>/dev/null || warn "yabai not installed — add to Brewfile."
  run brew services start skhd  2>/dev/null || warn "skhd not installed — add to Brewfile."
  _wm_start_shared
  success "yabai active (if SIP/scripting-addition are configured)."
}

_sip_ok_for_yabai() {
  # Scripting addition needs SIP partially disabled; csrutil reports status.
  csrutil status 2>/dev/null | grep -qiE 'disabled|partial'
}

_yabai_notes() {
  warn "yabai's scripting addition needs SIP partially disabled."
  cat <<'EOF'
  This CANNOT be scripted from the running OS. Do it once:
    1. Apple menu → Restart, hold the power button to reach Recovery (Apple Silicon).
    2. Utilities → Terminal:  csrutil disable --with kext --with dtrace --with nvram
    3. Reboot, then:          sudo yabai --load-sa
    4. Re-run:                omacase wm yabai
  Prefer not to? Stay on AeroSpace — it needs none of this.
EOF
}

# `omacase grid` — toggle the focused workspace into/out of a 2x2 grid. AeroSpace
# has no native grid layout (it's i3-style tree tiling), so we build one: flatten
# the workspace to a single row/column, then join windows by id into two
# perpendicular pairs — [1/2][3/4]. Opposite-orientation normalization makes each
# nested pair run across the other axis, yielding quadrants. Bound to Super+q.
#
# Toggle: if the workspace is already nested (any window sits in a container
# whose layout differs from the root — which, given opposite-orientation
# normalization, only happens when nested), pressing again flattens it back.
omacase_grid() {
  have aerospace || abort "grid needs AeroSpace (active profile: $(cat "$OMACASE_STATE/wm" 2>/dev/null || echo unknown))."

  local root parents
  root="$(aerospace list-windows --workspace focused --format '%{workspace-root-container-layout}' 2>/dev/null | sed -n 1p)"
  parents="$(aerospace list-windows --workspace focused --format '%{window-parent-container-layout}' 2>/dev/null)"

  # Toggle off: nested → flatten back to a plain tiled layout.
  if [ -n "$parents" ] && printf '%s\n' "$parents" | grep -qv "^${root}\$"; then
    aerospace flatten-workspace-tree 2>/dev/null || true
    return 0
  fi

  # Toggle on: flatten to one row/column, then pair the first four windows.
  aerospace flatten-workspace-tree 2>/dev/null || true
  local ids count
  ids="$(aerospace list-windows --workspace focused --format '%{window-id}' 2>/dev/null)"
  count="$(printf '%s\n' "$ids" | grep -c .)"
  if [ "$count" -lt 4 ]; then
    _grid_notify "Need 4 windows for a 2x2 grid (this workspace has $count)."
    return 0
  fi

  # Pair into the axis perpendicular to the row/column so each pair forms a
  # quadrant: join "left" under a horizontal root, "up" under a vertical one.
  local dir=left
  root="$(aerospace list-windows --workspace focused --format '%{workspace-root-container-layout}' 2>/dev/null | sed -n 1p)"
  [ "$root" = v_tiles ] && dir=up

  # Window ids stay valid across the first join.
  local b d
  b="$(printf '%s\n' "$ids" | sed -n 2p)"
  d="$(printf '%s\n' "$ids" | sed -n 4p)"
  aerospace join-with --window-id "$b" "$dir"
  aerospace join-with --window-id "$d" "$dir"
  [ "$count" -gt 4 ] && _grid_notify "Gridded the first 4 of $count windows; the rest stay tiled alongside."
  return 0
}

# Best-effort desktop notification (grid runs from a keybinding, so there's no
# terminal to print to). Silent if Automation/notification consent is missing.
_grid_notify() {
  osascript -e "display notification \"$1\" with title \"omacase grid\"" >/dev/null 2>&1 || true
}

# `omacase workspace <name>` — switch the active AeroSpace workspace. Lets the
# generated Spotlight launchers (Omacase 1…9) drive AeroSpace, not just keys.
omacase_workspace() {
  local n="${1:-}"
  [ -n "$n" ] || abort "usage: omacase workspace <1-9>"
  have aerospace || abort "workspace switching needs AeroSpace (active profile: $(cat "$OMACASE_STATE/wm" 2>/dev/null || echo unknown))."
  run aerospace workspace "$n"
}
