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
  run brew services start splaice/formulae/borders 2>/dev/null || warn "borders not installed?"
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

# `omacase grid [workspace]` — toggle a workspace (default: the focused one)
# into/out of a 2x2 grid. AeroSpace has no native grid layout (it's i3-style
# tree tiling), so we build one: force the root to plain horizontal tiles (a
# grid of accordions renders as an accordion, not a grid), flatten to a single
# row, then join windows by id into two perpendicular pairs — [1/2][3/4].
# Opposite-orientation normalization makes each nested pair run across the
# other axis, yielding quadrants. Bound to Super+q.
#
# Floating windows are ignored throughout: they don't tile, so they must not
# count toward the 4 needed windows, be join targets, or trip the toggle
# detection (their parent layout is "floating", never the root layout).
#
# Toggle: if any tiled window sits in a container whose layout differs from the
# root — which, given opposite-orientation normalization, only happens when
# nested — pressing again flattens back.
omacase_grid() {
  ensure_brew_env   # invoked from AeroSpace bindings, whose PATH lacks Homebrew (and thus `aerospace`)
  have aerospace || abort "grid needs AeroSpace (active profile: $(cat "$OMACASE_STATE/wm" 2>/dev/null || echo unknown))."
  local ws="${1:-focused}"

  # join-with is direction-based, and directions only exist on the visible
  # workspace (AeroSpace parks hidden workspaces' windows in a corner, so
  # nothing is "left" of anything there). Bring an explicitly named workspace
  # forward before rearranging it; Super+q always targets the visible one.
  [ "$ws" = focused ] || aerospace workspace "$ws" 2>/dev/null || abort "no such workspace '$ws'"

  # Tiled windows only: "<id> <parent-layout> <root-layout>" per line.
  local tiled root
  tiled="$(aerospace list-windows --workspace "$ws" \
             --format '%{window-id} %{window-parent-container-layout} %{workspace-root-container-layout}' \
             2>/dev/null | awk '$2 != "floating"')"
  root="$(printf '%s\n' "$tiled" | awk 'NR==1 {print $3}')"

  # Toggle off: any tiled window nested deeper than the root → flatten back.
  if printf '%s\n' "$tiled" | awk -v r="$root" '$2 != r {found=1} END {exit !found}'; then
    aerospace flatten-workspace-tree --workspace "$ws" 2>/dev/null || true
    return 0
  fi

  # Toggle on: flatten to one row, then pair the first four tiled windows.
  aerospace flatten-workspace-tree --workspace "$ws" 2>/dev/null || true
  local ids count
  ids="$(aerospace list-windows --workspace "$ws" \
           --format '%{window-id} %{window-parent-container-layout}' \
           2>/dev/null | awk '$2 != "floating" {print $1}')"
  count="$(printf '%s\n' "$ids" | grep -c .)"
  if [ "$count" -lt 4 ]; then
    _grid_notify "Need 4 tiled windows for a 2x2 grid (this workspace has $count)."
    return 0
  fi

  # Force plain horizontal tiles at the root (any window's parent IS the root
  # after flattening), so joins form visible quadrants even if the workspace
  # was in accordion.
  aerospace layout h_tiles --window-id "$(printf '%s\n' "$ids" | sed -n 1p)" 2>/dev/null || true

  # join-with needs the row's on-screen order, which list-windows does NOT
  # give (it sorts by app name, not tree position). Depth-first order is the
  # on-screen order: walk dfs indices and read back each focused window,
  # skipping floating ones.
  local ordered="" prev_focus line id parent i=0
  prev_focus="$(aerospace list-windows --focused --format '%{window-id}' 2>/dev/null)"
  while [ "$i" -lt 32 ]; do
    aerospace focus --dfs-index "$i" 2>/dev/null || break
    line="$(aerospace list-windows --focused --format '%{window-id} %{window-parent-container-layout}' 2>/dev/null)"
    id="${line%% *}"; parent="${line#* }"
    [ "$parent" = floating ] || ordered="$ordered$id"$'\n'
    i=$((i + 1))
  done

  # Join 2→1 and 4→3; under a horizontal root each joined pair becomes a
  # vertical container, i.e. [1/2][3/4]. Join acts on the focused window —
  # focusing by id sidesteps any ambiguity about which window "left" is
  # relative to.
  local b d
  b="$(printf '%s' "$ordered" | sed -n 2p)"
  d="$(printf '%s' "$ordered" | sed -n 4p)"
  aerospace focus --window-id "$b" && aerospace join-with left
  aerospace focus --window-id "$d" && aerospace join-with left
  [ -n "$prev_focus" ] && aerospace focus --window-id "$prev_focus" 2>/dev/null
  [ "$count" -gt 4 ] && _grid_notify "Gridded the first 4 of $count tiled windows; the rest stay alongside."
  return 0
}

# Best-effort desktop notification (grid runs from a keybinding, so there's no
# terminal to print to). Silent if Automation/notification consent is missing.
_grid_notify() {
  osascript -e "display notification \"$1\" with title \"omacase grid\"" >/dev/null 2>&1 || true
}

# `omacase terminal [command...]` — open a new Ghostty window in the *running*
# instance, optionally running a command in it.
#
# Ghostty's `+new-window` action is GTK/Linux-only (it prints "not supported on
# this platform" on macOS), and `open -na Ghostty` spawns a whole new process
# every time. So we drive Ghostty's own File → New Window menu via System
# Events: deterministic no matter which window is frontmost, and it reuses the
# existing process. If Ghostty isn't running yet, just launch it — that already
# yields a window.
#
# A command can't ride the menu (New Window takes no argument, and macOS has no
# per-window IPC into Ghostty), so we type it into the new window's shell. zsh's
# line editor buffers the type-ahead at the tty, so it runs once the prompt is
# ready even if we type slightly early. Used by Super+Return (no command) and
# Super+Shift+Return (`tmux new-session -A -s main`). The menu click and the
# keystroke both need Accessibility (granted by `omacase doctor`).
omacase_terminal() {
  # Pass the command as an argv item so its spaces/flags need no shell-escaping
  # inside the AppleScript; empty string means "plain window, type nothing".
  osascript - "$*" >/dev/null 2>&1 <<'APPLESCRIPT' || true
on run argv
  set theCmd to item 1 of argv
  if application "Ghostty" is running then
    tell application "Ghostty" to activate
    tell application "System Events" to tell process "Ghostty" to click menu item "New Window" of menu "File" of menu bar 1
  else
    tell application "Ghostty" to activate
  end if
  if theCmd is not "" then
    delay 0.5
    tell application "System Events"
      keystroke theCmd
      key code 36
    end tell
  end if
end run
APPLESCRIPT
}

# `omacase workspace <name>` — switch the active AeroSpace workspace. Lets the
# generated Spotlight launchers (Omacase 1…9) drive AeroSpace, not just keys.
omacase_workspace() {
  ensure_brew_env   # invoked from Spotlight launchers, whose PATH lacks Homebrew (and thus `aerospace`)
  local n="${1:-}"
  [ -n "$n" ] || abort "usage: omacase workspace <1-9>"
  have aerospace || abort "workspace switching needs AeroSpace (active profile: $(cat "$OMACASE_STATE/wm" 2>/dev/null || echo unknown))."
  run aerospace workspace "$n"
}

# `omacase btop` — toggle a centered, chromeless btop popup. Bound to the
# SketchyBar CPU/mem click.
#
# Open: a NEW WINDOW in the existing (undecorated) Ghostty instance — not a 2nd
# instance, which trips Ghostty's session-restore prompt and makes window
# targeting ambiguous — running `exec btop` (replaces the shell, so quitting
# btop closes the window with no leftover prompt and no close-confirm). It's
# floated off the tiling and centered at ~65% of the main display.
# Close: if a btop window is already up, focus it and send `q`; because we
# exec'd btop, that quits it and the window closes. So clicking toggles.
# Needs Accessibility (granted by `omacase doctor`).
omacase_btop() {
  ensure_brew_env   # invoked from SketchyBar's click env, whose PATH lacks Homebrew (and thus `aerospace`)

  local exists='tell application "System Events" to tell process "Ghostty" to (exists (first window whose name contains "btop"))'
  if osascript -e "$exists" 2>/dev/null | grep -q true; then
    # Toggle off: raise the btop window and quit btop (exec'd → window closes).
    osascript -e 'tell application "Ghostty" to activate' \
              -e 'tell application "System Events" to tell process "Ghostty" to perform action "AXRaise" of (first window whose name contains "btop")' \
              -e 'tell application "System Events" to keystroke "q"' 2>/dev/null
    return 0
  fi

  # The popup is about resources, not processes, so it runs btop with its own
  # config (no "proc" box) — kept beside the main btop.conf so it shares the
  # themes dir, but separate so btop's on-exit save never rewrites the proc-box
  # layout that a plain `btop` in a terminal should keep.
  local popup_conf="$HOME/.config/btop/omacase-popup.conf"
  if [ ! -f "$popup_conf" ]; then
    cat > "$popup_conf" <<'BTOPCONF'
#? omacase btop popup — resources only (no proc box). Its own config so btop's
#? on-exit save can't touch the shared btop.conf (which keeps the proc list).
color_theme = "current"
theme_background = false
vim_keys = true
rounded_corners = true
update_ms = 1000
shown_boxes = "cpu mem net"
BTOPCONF
  fi

  # Toggle on: new window in the existing instance, then `exec btop` in it
  # (exec → quitting btop closes the window). Quote the path for safety.
  osascript -e 'tell application "Ghostty" to activate' \
            -e 'tell application "System Events" to tell process "Ghostty" to click menu item "New Window" of menu "File" of menu bar 1' 2>/dev/null
  sleep 0.4
  osascript -e "tell application \"System Events\" to keystroke \"exec btop -c '$popup_conf'\"" \
            -e 'tell application "System Events" to key code 36' 2>/dev/null

  aerospace layout floating 2>/dev/null || true   # float so AeroSpace won't tile it

  # Center at ~65% of the main display once the window appears.
  local bounds sw sh w h px py
  bounds="$(osascript -e 'tell application "Finder" to get bounds of window of desktop' 2>/dev/null | tr ',' ' ')"
  set -- $bounds; sw="${3:-1440}"; sh="${4:-900}"
  w=$(( sw * 65 / 100 )); h=$(( sh * 65 / 100 )); px=$(( (sw - w) / 2 )); py=$(( (sh - h) / 2 ))
  osascript - "$px" "$py" "$w" "$h" >/dev/null 2>&1 <<'OSA' || true
on run argv
  set px to (item 1 of argv) as integer
  set py to (item 2 of argv) as integer
  set ww to (item 3 of argv) as integer
  set hh to (item 4 of argv) as integer
  tell application "System Events" to tell process "Ghostty"
    set n to 0
    repeat until (exists (first window whose name contains "btop")) or n > 50
      delay 0.1
      set n to n + 1
    end repeat
    if exists (first window whose name contains "btop") then
      set win to (first window whose name contains "btop")
      set position of win to {px, py}
      set size of win to {ww, hh}
    end if
  end tell
end run
OSA
}
