# shellcheck shell=bash
# `omacase wm` — (re)start the AeroSpace window manager + its shared services
# (SketchyBar, JankyBorders). AeroSpace is i3-style tiling and needs no SIP
# changes.

omacase_wm() {
  _wm_use_aerospace
  is_dryrun || echo "aerospace" > "$OMACASE_STATE/wm"
}

_wm_start_shared() {
  run brew services start splaice/formulae/borders 2>/dev/null || warn "borders not installed?"
  run brew services start sketchybar 2>/dev/null || warn "sketchybar not installed?"
}

_wm_use_aerospace() {
  ensure_brew_env   # may be invoked from the menu/popup, whose PATH lacks Homebrew
  info "Profile: AeroSpace (no SIP disable required)"
  # NEVER quit-then-relaunch: `open -a` can fire while the quit is still in
  # flight, the relaunch gets dropped, and AeroSpace is left DOWN (which breaks
  # the SketchyBar workspace list). Instead: if it's up, reload its config; if
  # it's down, launch it. It also starts at login via its own config.
  if pgrep -x AeroSpace >/dev/null; then
    run aerospace reload-config 2>/dev/null || true
  else
    run open -a AeroSpace 2>/dev/null || warn "AeroSpace not installed — check Brewfile/brew bundle."
  fi
  _wm_start_shared
  run sketchybar --reload 2>/dev/null || true   # repopulate the workspace list against current WM state
  success "AeroSpace active. Super+WASD focus, Super+Shift+WASD move, Super+[1-9] workspaces."
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

# --- App-launch / overlay popups --------------------------------------------
# Shared pattern: reveal a thing centered and floating "above everything", or
# hide it when it's already up — so a keybind reveals/hides a single overlay.
# Terminal popups (btop, files) run a TUI in a chromeless Ghostty window;
# GUI popups (music, obsidian) toggle an app's visibility. All need
# Accessibility (granted by `omacase doctor`).

# Center a floating Ghostty popup (matched by title substring) at ~65% of the
# main display once it appears.
_popup_center() {
  local match="$1" bounds sw sh w h px py
  bounds="$(osascript -e 'tell application "Finder" to get bounds of window of desktop' 2>/dev/null | tr ',' ' ')"
  set -- $bounds; sw="${3:-1440}"; sh="${4:-900}"
  w=$(( sw * 65 / 100 )); h=$(( sh * 65 / 100 )); px=$(( (sw - w) / 2 )); py=$(( (sh - h) / 2 ))
  osascript - "$match" "$px" "$py" "$w" "$h" >/dev/null 2>&1 <<'OSA' || true
on run argv
  set m to item 1 of argv
  set px to (item 2 of argv) as integer
  set py to (item 3 of argv) as integer
  set ww to (item 4 of argv) as integer
  set hh to (item 5 of argv) as integer
  tell application "System Events" to tell process "Ghostty"
    set n to 0
    repeat until (exists (first window whose name contains m)) or n > 50
      delay 0.1
      set n to n + 1
    end repeat
    if exists (first window whose name contains m) then
      set win to (first window whose name contains m)
      set position of win to {px, py}
      set size of win to {ww, hh}
    end if
  end tell
end run
OSA
}

# Toggle a chromeless, centered Ghostty TUI popup.
#   $1 = window-title match (for centering)
#   $2 = shell command to run (should `exec` the TUI so closing it ends cleanly)
#   $3 = pgrep/pkill pattern uniquely identifying the TUI process
# Hide: kill the marked process — its exec'd Ghostty window then closes on its
# own. We close by PROCESS, not a synthetic "q" keystroke, because this runs
# from a keybind where the still-held Super/Shift modifiers would corrupt the
# keystroke (Super = ⌃⌥⌘, so a sent "q" lands as ⌘Q etc.).
# Reveal: NEW WINDOW in the existing (undecorated) instance — not a 2nd instance,
# which trips Ghostty's session-restore prompt — type the command (the 0.4s
# delay lets the trigger keys release so the type-ahead lands), float, center.
_ghostty_popup_toggle() {
  ensure_brew_env
  local match="$1" cmd="$2" proc="$3"
  if pgrep -f "$proc" >/dev/null 2>&1; then
    pkill -f "$proc"
    return 0
  fi
  osascript -e 'tell application "Ghostty" to activate' \
            -e 'tell application "System Events" to tell process "Ghostty" to click menu item "New Window" of menu "File" of menu bar 1' 2>/dev/null
  sleep 0.4
  osascript - "$cmd" >/dev/null 2>&1 <<'OSA' || true
on run argv
  tell application "System Events"
    keystroke (item 1 of argv)
    key code 36
  end tell
end run
OSA
  aerospace layout floating 2>/dev/null || true
  _popup_center "$match"
}

# Toggle a GUI app as a centered floating overlay. If it's frontmost, hide it;
# otherwise launch/activate it, float it (so it overlays the tiles), center it
# and raise it above everything. $1 = app name; optional $2 = size as a percent
# of the screen (e.g. 80) — omitted keeps the window's current size.
_app_toggle() {
  ensure_brew_env
  local app="$1" pct="${2:-0}" front
  front="$(osascript -e 'tell application "System Events" to get name of first process whose frontmost is true' 2>/dev/null)"
  if [ "$front" = "$app" ]; then
    osascript -e "tell application \"System Events\" to set visible of process \"$app\" to false" 2>/dev/null
    return 0
  fi
  open -a "$app" 2>/dev/null || { warn "Couldn't launch '$app' — is it installed?"; return 1; }
  sleep 0.3
  aerospace layout floating 2>/dev/null || true
  osascript - "$app" "$pct" >/dev/null 2>&1 <<'OSA' || true
on run argv
  set a to item 1 of argv
  set pct to (item 2 of argv) as integer
  tell application "Finder" to set b to bounds of window of desktop
  set sw to (item 3 of b)
  set sh to (item 4 of b)
  tell application "System Events" to tell process a
    set n to 0
    repeat until (exists window 1) or n > 50
      delay 0.1
      set n to n + 1
    end repeat
    if exists window 1 then
      set win to window 1
      if pct > 0 then
        set {ww, hh} to {(sw * pct) div 100, (sh * pct) div 100}
        set size of win to {ww, hh}
      else
        set {ww, hh} to size of win
      end if
      set position of win to {(sw - ww) div 2, (sh - hh) div 2}
      perform action "AXRaise" of win
    end if
  end tell
end run
OSA
}

# `omacase btop` — toggle a resources-only btop popup (Super CPU/mem click).
# Its own config drops the proc box and keeps btop's on-exit save away from the
# shared btop.conf (which a terminal `btop` should keep, proc list and all).
omacase_btop() {
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
  _ghostty_popup_toggle "btop" "exec btop -c '$popup_conf'" "omacase-popup"
}

# `omacase files` — toggle a ranger file-manager popup (Super+Shift+F). ranger
# leaves the title alone (update_title defaults false), so we set it via OSC and
# match "omacase-files" for centering. Passing the (default) --confdir gives the
# process a unique argv marker to pgrep/pkill on, without changing ranger's
# behavior or losing the user's ranger config.
omacase_files() {
  _ghostty_popup_toggle "omacase-files" \
    "printf '\033]0;omacase-files\007'; exec ranger --confdir='$HOME/.config/ranger'" \
    "ranger --confdir"
}

# `omacase sysmenu` — toggle the global system menu (Super+Space): a centered,
# floating Ghostty popup running the `omacase menu` gum TUI. The `--popup`
# sentinel both marks the process so the toggle pgrep/pkills exactly this window
# (never a plain terminal `omacase menu`) and stays distinct from the wrapper's
# own `omacase sysmenu` command line. This is Omarchy's Super+Alt+Space menu — on
# macOS the Alt already lives inside Super (⌃⌥⌘), so it sits on Super+Space.
omacase_sysmenu() {
  _ghostty_popup_toggle "omacase-menu" \
    "printf '\033]0;omacase-menu\007'; exec omacase menu --popup" \
    "omacase menu --popup"
}

# `omacase browser` — open/focus the system default browser (Super+B). Reads the
# default https handler from LaunchServices; falls back to Safari.
omacase_browser() {
  local id
  id="$(python3 - <<'PY' 2>/dev/null
import plistlib, os
p = os.path.expanduser("~/Library/Preferences/com.apple.LaunchServices/com.apple.launchservices.secure.plist")
try:
    d = plistlib.load(open(p, "rb"))
    for h in d.get("LSHandlers", []):
        if h.get("LSHandlerURLScheme") == "https":
            print(h.get("LSHandlerRoleAll", "")); break
except Exception:
    pass
PY
)"
  if [ -n "$id" ]; then open -b "$id" 2>/dev/null || open -a Safari; else open -a Safari; fi
}

# `omacase music [spotify|apple]` — toggle the music overlay (Super+M). Defaults
# to Spotify; `apple` switches to Apple Music, and the choice persists. If the
# chosen app isn't installed, falls back to whichever music app is.
omacase_music() {
  local statef="$OMACASE_STATE/music-app" app
  case "${1:-}" in
    spotify)     echo "Spotify" > "$statef" ;;
    apple|music) echo "Music"   > "$statef" ;;
    "")          : ;;
    *)           abort "usage: omacase music [spotify|apple]" ;;
  esac
  app="$(cat "$statef" 2>/dev/null || echo Spotify)"
  if ! osascript -e "id of app \"$app\"" >/dev/null 2>&1; then
    if osascript -e 'id of app "Spotify"' >/dev/null 2>&1; then app="Spotify"
    elif osascript -e 'id of app "Music"' >/dev/null 2>&1; then app="Music"; fi
  fi
  _app_toggle "$app"
}

# `omacase obsidian` — toggle the Obsidian overlay (Super+O).
omacase_obsidian() { _app_toggle "Obsidian"; }

# `omacase 1password` — toggle the 1Password overlay (Super+P).
omacase_1password() { _app_toggle "1Password"; }

# `omacase message` — toggle the messaging overlay (Super+G). iMessage for now,
# sized to 80% of the screen (chat needs more room than the other overlays);
# multiple-app support can come later (cf. `omacase music`).
omacase_message() { _app_toggle "Messages" 80; }
