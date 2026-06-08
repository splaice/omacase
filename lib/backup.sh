# shellcheck shell=bash
# Backup & restore — Omacase snapshots any pre-existing state it is about to
# overwrite (dotfiles + macOS defaults) so a run is always reversible.
#
#   omacase backup [label]     create a snapshot now
#   omacase restore [id]       restore a snapshot (default: most recent)
#   omacase restore --list     list snapshots
#
# Snapshots live in $OMACASE_STATE/backups/<id>/ :
#   meta            label, version, host, date
#   manifest        one line per managed dotfile target: "PRESENT|ABSENT <rel>"
#   files/<rel>     copies of pre-existing dotfile targets (relative to $HOME)
#   defaults/*.plist  exported macOS defaults domains

OMACASE_BACKUPS="$OMACASE_STATE/backups"

# macOS defaults domains touched by macos/defaults.sh — kept in sync with it.
OMACASE_DEFAULTS_DOMAINS=(
  NSGlobalDomain
  com.apple.finder
  com.apple.desktopservices
  com.apple.dock
  com.apple.screencapture
  com.apple.AppleMultitouchTrackpad
)

# Top-level paths Omacase manages, derived from the home/ source tree.
# dot_zshrc → ~/.zshrc ; dot_config/<app> → ~/.config/<app>
_managed_targets() {
  ( cd "$OMACASE_ROOT/home" 2>/dev/null || return
    for e in dot_*; do
      [ -e "$e" ] || continue
      if [ "$e" = "dot_config" ]; then
        for a in dot_config/*; do echo "$HOME/.config/$(basename "$a")"; done
      else
        echo "$HOME/.${e#dot_}"
      fi
    done )
}

# True if PATH is a symlink that already points inside this repo.
_is_omacase_link() {
  local t="$1" dest
  [ -L "$t" ] || return 1
  dest="$(readlink "$t")"
  case "$dest" in "$OMACASE_ROOT"/*) return 0 ;; *) return 1 ;; esac
}

# --- backup ------------------------------------------------------------------
omacase_backup() {
  local label="${1:-manual}"
  local id; id="$(date +%Y%m%d-%H%M%S)"
  local dest="$OMACASE_BACKUPS/$id"

  info "Creating backup $id ($label)"
  if is_dryrun; then
    log "[dry-run] would snapshot dotfiles + defaults into $dest"
    return 0
  fi
  mkdir -p "$dest/files" "$dest/defaults"
  {
    echo "label=$label"
    echo "version=$(cat "$OMACASE_ROOT/VERSION" 2>/dev/null)"
    echo "host=$(hostname)"
    echo "date=$(date)"
  } > "$dest/meta"

  local n=0
  while IFS= read -r target; do
    [ -n "$target" ] || continue
    local rel="${target#"$HOME"/}"
    if _is_omacase_link "$target"; then
      continue                                  # our own symlink — nothing of theirs to save
    elif [ -e "$target" ] || [ -L "$target" ]; then
      mkdir -p "$dest/files/$(dirname "$rel")"
      cp -RP "$target" "$dest/files/$rel"
      echo "PRESENT $rel" >> "$dest/manifest"
      n=$((n+1))
    else
      echo "ABSENT $rel" >> "$dest/manifest"    # record so restore can remove what we create
    fi
  done < <(_managed_targets)

  local d
  for d in "${OMACASE_DEFAULTS_DOMAINS[@]}"; do
    defaults export "$d" "$dest/defaults/$d.plist" 2>/dev/null || true
  done

  echo "$id" > "$OMACASE_STATE/last-backup"
  success "Backup $id saved ($n existing dotfile target(s) + ${#OMACASE_DEFAULTS_DOMAINS[@]} defaults domains)."
  log    "Restore anytime with:  omacase restore $id"
}

# Auto-backup before a destructive step, but only if there is real (non-Omacase)
# state to lose — so repeated installs don't pile up empty snapshots.
_auto_backup() {
  local t
  while IFS= read -r t; do
    [ -n "$t" ] || continue
    if ! _is_omacase_link "$t" && { [ -e "$t" ] || [ -L "$t" ]; }; then
      omacase_backup pre-install
      return
    fi
  done < <(_managed_targets)
  info "No pre-existing conflicting dotfiles — skipping backup."
}

# --- restore -----------------------------------------------------------------
omacase_restore() {
  if [ "${1:-}" = "--list" ] || [ "${1:-}" = "-l" ]; then _restore_list; return; fi
  local id="${1:-$(cat "$OMACASE_STATE/last-backup" 2>/dev/null)}"
  [ -n "$id" ] || abort "No backups found. (omacase restore --list)"
  local dir="$OMACASE_BACKUPS/$id"
  [ -d "$dir" ] || abort "No such backup '$id'. (omacase restore --list)"

  warn "Restoring backup $id ($(grep '^label=' "$dir/meta" 2>/dev/null | cut -d= -f2))."
  warn "This overwrites the current Omacase-managed dotfiles & defaults with the snapshot."
  is_dryrun || confirm "Proceed?" || { info "Cancelled."; return; }

  if [ -f "$dir/manifest" ]; then
    local status rel target
    while read -r status rel; do
      [ -n "$rel" ] || continue
      target="$HOME/$rel"
      case "$status" in
        PRESENT)
          run rm -rf "$target"
          run mkdir -p "$(dirname "$target")"
          run cp -RP "$dir/files/$rel" "$target" ;;
        ABSENT)
          run rm -rf "$target" ;;             # remove what Omacase created
      esac
    done < "$dir/manifest"
  fi

  local plist domain
  for plist in "$dir"/defaults/*.plist; do
    [ -e "$plist" ] || continue
    domain="$(basename "$plist" .plist)"
    run defaults import "$domain" "$plist"
  done
  for app in Dock Finder SystemUIServer; do run killall "$app" 2>/dev/null || true; done

  success "Restored backup $id. (Restart any open apps to pick up reverted config.)"
}

_restore_list() {
  if [ ! -d "$OMACASE_BACKUPS" ] || [ -z "$(ls -A "$OMACASE_BACKUPS" 2>/dev/null)" ]; then
    info "No backups yet."; return
  fi
  local last; last="$(cat "$OMACASE_STATE/last-backup" 2>/dev/null)"
  printf '%-18s %-12s %s\n' "ID" "LABEL" "DATE"
  local d id
  for d in "$OMACASE_BACKUPS"/*/; do
    id="$(basename "$d")"
    printf '%-18s %-12s %s%s\n' "$id" \
      "$(grep '^label=' "$d/meta" 2>/dev/null | cut -d= -f2)" \
      "$(grep '^date='  "$d/meta" 2>/dev/null | cut -d= -f2-)" \
      "$([ "$id" = "$last" ] && echo '  (latest)')"
  done
}
