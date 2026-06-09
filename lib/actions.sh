# shellcheck shell=bash
# Small, scriptable actions meant to be wrapped in a macOS Shortcut and triggered
# from Spotlight — the macOS analog of Omarchy's Super-key launcher/menu helpers
# (omarchy-launch-webapp, the toggle scripts). Each is a clean one-liner a
# Shortcut's "Run Shell Script" step can call.

# Omarchy's default web-app set (name -> URL). Kept in sync with Omarchy's
# config/hypr/bindings.conf Super+Shift web apps.
_webapp_url() {
  case "$1" in
    chatgpt)  echo "https://chatgpt.com" ;;
    grok)     echo "https://grok.com" ;;
    calendar) echo "https://app.hey.com/calendar/weeks/" ;;
    email)    echo "https://app.hey.com" ;;
    youtube)  echo "https://youtube.com/" ;;
    whatsapp) echo "https://web.whatsapp.com/" ;;
    messages) echo "https://messages.google.com/web/conversations" ;;
    photos)   echo "https://photos.google.com/" ;;
    x)        echo "https://x.com/" ;;
    x-post)   echo "https://x.com/compose/post" ;;
    *)        return 1 ;;
  esac
}
_webapp_names="chatgpt grok calendar email youtube whatsapp messages photos x x-post"

# omacase webapp [name] — open a named web app. With no name (or `list`), print
# the set. Opens as a chromeless "app" window when a Chromium browser is present
# (Omarchy's PWA feel), otherwise in the default browser.
omacase_webapp() {
  local name="${1:-}"
  if [ -z "$name" ] || [ "$name" = list ]; then
    info "Web apps — \`omacase webapp <name>\`:"
    local n; for n in $_webapp_names; do printf '  %-9s %s\n' "$n" "$(_webapp_url "$n")"; done
    return 0
  fi
  local url; url="$(_webapp_url "$name")" || abort "Unknown web app '$name'. Try: $_webapp_names"
  # Open in a dedicated browser (Brave, from the Brewfile) so the chromeless app
  # window is its own process — ⌘Q on a web app won't quit your daily browser.
  # Google Chrome is last: it's most often the default, so use it only as a last
  # resort before plain `open`.
  local b
  for b in "Brave Browser" "Chromium" "Microsoft Edge" "Vivaldi" "Google Chrome"; do
    if [ -d "/Applications/$b.app" ]; then
      run open -na "$b" --args "--app=$url"; return 0
    fi
  done
  run open "$url"   # default browser fallback
}

# omacase appearance [toggle|dark|light] — flip or set macOS system Light/Dark.
# The analog of Omarchy's nightlight toggle. This changes only the system
# appearance; use `omacase theme` to switch the whole palette (which also flips
# appearance to match).
omacase_appearance() {
  local want="${1:-toggle}" cur dark
  cur="$(osascript -e 'tell application "System Events" to tell appearance preferences to get dark mode' 2>/dev/null || true)"
  case "$want" in
    toggle) [ "$cur" = true ] && dark=false || dark=true ;;
    dark)   dark=true ;;
    light)  dark=false ;;
    *) abort "usage: omacase appearance [toggle|dark|light]" ;;
  esac
  if run osascript -e "tell application \"System Events\" to tell appearance preferences to set dark mode to $dark"; then
    info "macOS appearance → $([ "$dark" = true ] && echo Dark || echo Light)"
  else
    warn "Couldn't set appearance — grant Automation → System Events to the caller (\`omacase doctor\`)."
  fi
}

# Spotlight launchers. macOS Shortcuts can't be authored from a script, but a
# tiny osacompile'd .app can: it's indexed by Spotlight and runs a shell command
# when launched. We generate one per web app (plus an appearance toggle) into
# ~/Applications, so each is launchable by name from Spotlight (⌘Space).
# Display name | omacase subcommand+args. Names are picked to be distinct in
# Spotlight (e.g. "Google Photos", not "Photos", which collides with Photos.app).
_LAUNCHERS=(
  "ChatGPT|webapp chatgpt"
  "Grok|webapp grok"
  "HEY Email|webapp email"
  "HEY Calendar|webapp calendar"
  "YouTube|webapp youtube"
  "WhatsApp|webapp whatsapp"
  "Google Messages|webapp messages"
  "Google Photos|webapp photos"
  "X|webapp x"
  "X Post|webapp x-post"
  "Toggle Appearance|appearance toggle"
)

omacase_launchers() {
  local action="${1:-build}" dir="$HOME/Applications" bin="$OMACASE_ROOT/bin/omacase"
  case "$action" in
    build|"") ;;
    remove)   _launchers_remove "$dir"; return ;;
    *) abort "usage: omacase launchers [build|remove]" ;;
  esac
  have osacompile || abort "osacompile not found (ships with macOS)."

  mkdir -p "$dir"
  local entry name args app tmp
  for entry in "${_LAUNCHERS[@]}"; do
    name="${entry%%|*}"; args="${entry#*|}"
    app="$dir/$name.app"
    if is_dryrun; then printf '\033[2m[dry-run]\033[0m create %s → omacase %s\n' "$app" "$args"; continue; fi
    rm -rf "$app"
    # Launchers run with a minimal PATH, so set Homebrew + call omacase by path.
    tmp="$(mktemp).applescript"
    printf 'do shell script "export PATH=/opt/homebrew/bin:$PATH; %s %s"\n' "$bin" "$args" > "$tmp"
    if osacompile -o "$app" "$tmp" >/dev/null 2>&1; then
      : > "$app/Contents/Resources/.omacase-launcher"   # marker for clean removal
      success "$name"
    else
      warn "failed to build $name"
    fi
    rm -f "$tmp"
  done
  info "Created in $dir — open from Spotlight (⌘Space, type the name)."
  info "First launch of an action may prompt for permission; \`omacase launchers remove\` deletes them."
}

# Remove only the .app bundles we created (identified by the marker file).
_launchers_remove() {
  local dir="$1" app n=0
  for app in "$dir"/*.app; do
    [ -e "$app/Contents/Resources/.omacase-launcher" ] || continue
    run rm -rf "$app"; n=$((n + 1))
  done
  success "Removed $n omacase launcher(s) from $dir."
}
