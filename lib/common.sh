# shellcheck shell=bash
# Shared helpers: logging, idempotency guards, brew/PATH bootstrap, state dir.
# Sourced by bin/omacase and every lib/*.sh.

OMACASE_STATE="${OMACASE_STATE:-$HOME/.local/state/omacase}"
mkdir -p "$OMACASE_STATE"
# Data/cache dir for downloaded artifacts (e.g. per-theme wallpapers).
OMACASE_DATA="${OMACASE_DATA:-$HOME/.local/share/omacase}"

# --- logging -----------------------------------------------------------------
_c()      { printf '\033[%sm' "$1"; }
log()     { printf '%s\n' "$*"; }
info()    { printf '\033[34m➜\033[0m %s\n' "$*"; }
success() { printf '\033[32m✓\033[0m %s\n' "$*"; }
warn()    { printf '\033[33m! \033[0m%s\n' "$*" >&2; }
error()   { printf '\033[31m✗\033[0m %s\n' "$*" >&2; }
step()    { printf '\n\033[1;35m▒▒ %s\033[0m\n' "$*"; }

abort()   { error "$*"; exit 1; }

confirm() { # confirm "Question?" -> 0 if yes
  local reply
  read -r -p "$(printf '\033[36m? %s [y/N] \033[0m' "$1")" reply
  [[ "$reply" =~ ^[Yy]$ ]]
}

# --- environment -------------------------------------------------------------
ensure_brew_env() {
  if [ -x /opt/homebrew/bin/brew ]; then eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [ -x /usr/local/bin/brew ]; then eval "$(/usr/local/bin/brew shellenv)"
  elif is_dryrun; then warn "Homebrew not found (dry run — continuing)."
  else abort "Homebrew not found — run boot.sh first."; fi
}

have() { command -v "$1" >/dev/null 2>&1; }

# The directory the `omacase` command is symlinked into so it lands on PATH:
# Homebrew's bin (already on PATH wherever brew is). Falls back to the standard
# Apple-Silicon / Intel prefixes if `brew --prefix` isn't resolvable.
_omacase_bindir() {
  local prefix; prefix="$(brew --prefix 2>/dev/null)"
  [ -n "$prefix" ] && [ -d "$prefix/bin" ] || prefix="$( [ -d /opt/homebrew/bin ] && echo /opt/homebrew || echo /usr/local )"
  [ -d "$prefix/bin" ] && printf '%s\n' "$prefix/bin"
}

# --- dry run -----------------------------------------------------------------
# Set OMACASE_DRYRUN=1 to print mutating commands instead of running them.
# Wrap every side-effecting command (brew, chezmoi, ln, defaults, services…)
# in `run`. Read-only inspection commands don't need it.
is_dryrun() { [ -n "${OMACASE_DRYRUN:-}" ]; }

run() {
  if is_dryrun; then
    printf '\033[2m[dry-run]\033[0m %s\n' "$*"
  else
    "$@"
  fi
}

dryrun_banner() {
  # NOTE: must return 0 — called as a bare statement under `set -e`.
  if is_dryrun; then printf '\033[1;33m▒▒ DRY RUN — no changes will be made ▒▒\033[0m\n'; fi
}

# --- idempotency -------------------------------------------------------------
# once <key> <command...> : run command only the first time, record a marker.
# Use for genuinely one-shot actions (e.g. changing login shell). Most steps
# should instead be naturally idempotent (brew bundle, symlinking, defaults).
once() {
  local key="$1"; shift
  local marker="$OMACASE_STATE/once.$key"
  if [ -f "$marker" ]; then return 0; fi
  "$@" && touch "$marker"
}

# --- macOS appearance automation ---------------------------------------------
# Switching themes flips macOS Light/Dark via AppleScript to System Events,
# which requires Automation consent for the controlling terminal. This probe is
# read-only (it *gets* dark mode), but it exercises the exact same TCC grant, so
# it both tests and — on first run — triggers the consent prompt. Returns 0 when
# appearance control is allowed, 1 when blocked or unavailable.
can_set_appearance() {
  case "$(osascript -e 'tell application "System Events" to tell appearance preferences to get dark mode' 2>&1)" in
    true|false) return 0 ;;
    *)          return 1 ;;
  esac
}

# --- conflicting window managers ---------------------------------------------
# Loop (com.MrKai77.Loop) is a third-party window manager. Its global drag-to-
# snap and keyboard shortcuts fight AeroSpace/yabai for control of the same
# windows, producing flicker and lost focus. Detect it and offer to quit it +
# stop it relaunching at login. Used by both `install` and `doctor`.
# Returns 0 when there's no live conflict, 1 when Loop is still running after.
_loop_installed() { [ -d "/Applications/Loop.app" ] || [ -d "$HOME/Applications/Loop.app" ]; }
_loop_running()   { pgrep -x Loop >/dev/null 2>&1; }

check_loop_conflict() {
  _loop_installed || return 0
  if ! _loop_running; then
    info "Loop is installed but not running — keep it closed to avoid window-manager conflicts."
    return 0
  fi

  warn "Loop is running — it conflicts with the Omacase window manager (AeroSpace/yabai)."
  if confirm "Quit Loop now and stop it launching at login?"; then
    run osascript -e 'tell application "Loop" to quit' >/dev/null 2>&1 || run killall Loop >/dev/null 2>&1 || true
    # Best-effort: only removes a classic System Events login item. Apps using
    # SMAppService won't appear here, so we also tell the user to toggle it off.
    run osascript -e 'tell application "System Events" to delete login item "Loop"' >/dev/null 2>&1 || true
    if _loop_running; then
      warn "Loop did not quit — close it manually (menu bar → Quit)."
      return 1
    fi
    success "Loop quit. Also disable 'Launch at login' in Loop → Settings to be sure."
    return 0
  fi
  warn "Leaving Loop running — expect window-management conflicts with Omacase."
  return 1
}

# --- gum (optional TUI sugar) ------------------------------------------------
gum_choose() { # gum_choose "header" opt1 opt2 ...  -> prints choice
  local header="$1"; shift
  if have gum; then gum choose --header "$header" "$@"
  else
    printf '%s\n' "$header" >&2
    select c in "$@"; do [ -n "$c" ] && { printf '%s\n' "$c"; return; }; done
  fi
}
