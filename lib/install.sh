# shellcheck shell=bash
# `omacase install` — the idempotent setup engine. Safe to re-run; it is the
# same engine `omacase update` calls. Omacase owns its dotfiles via symlinks
# (no chezmoi), and snapshots anything it would overwrite first.

omacase_install() {
  ensure_brew_env
  dryrun_banner
  source "$OMACASE_ROOT/lib/backup.sh"

  step "1/6  Packages & apps (brew bundle)"
  run brew bundle --file="$OMACASE_ROOT/Brewfile" || warn "Some brew items failed; re-run later."

  step "2/6  Safety backup (so this is reversible)"
  _auto_backup

  step "3/6  Dotfiles (symlinks)"
  _link_dotfiles

  step "4/6  macOS defaults"
  bash "$OMACASE_ROOT/macos/defaults.sh"   # honors OMACASE_DRYRUN itself

  step "5/6  Theme"
  source "$OMACASE_ROOT/lib/theme.sh"
  omacase_theme "$(cat "$OMACASE_STATE/theme" 2>/dev/null || echo catppuccin-mocha)"

  step "6/6  Window manager + services"
  source "$OMACASE_ROOT/lib/wm.sh"
  omacase_wm "$(cat "$OMACASE_STATE/wm" 2>/dev/null || echo aerospace)"

  step "Done"
  success "omacase installed."
  warn "Next: run \`omacase doctor\` and grant Accessibility to AeroSpace, SketchyBar, Karabiner & Raycast."
  warn "macOS requires those grants by hand — no installer can click them for you."
  warn "Don't like the result? \`omacase restore\` rolls back to the pre-install snapshot."
}

# Symlink every file under home/ into $HOME, translating chezmoi-style dot_
# prefixes (dot_zshrc → ~/.zshrc, dot_config/x → ~/.config/x). Pre-existing
# real config at a managed target is removed only AFTER _auto_backup saved it.
# Leaf-file granularity lets theme symlinks (e.g. nvim/lua/theme.lua) live
# alongside without polluting the repo.
_link_dotfiles() {
  source "$OMACASE_ROOT/lib/backup.sh"
  # Clear pre-existing real config at managed targets (already backed up).
  local t
  while IFS= read -r t; do
    [ -n "$t" ] || continue
    if ! _is_omacase_link "$t" && { [ -e "$t" ] || [ -L "$t" ]; }; then
      run rm -rf "$t"
    fi
  done < <(_managed_targets)

  # Symlink each source file to its translated target.
  local src="$OMACASE_ROOT/home" f rel target
  while IFS= read -r f; do
    rel="${f#"$src"/}"
    target="$HOME/$(printf '%s' "$rel" | sed -e 's#^dot_#.#' -e 's#/dot_#/.#g')"
    run mkdir -p "$(dirname "$target")"
    run ln -sfn "$f" "$target"
  done < <(find "$src" -type f ! -name '.DS_Store')
}

omacase_uninstall() {
  source "$OMACASE_ROOT/lib/backup.sh"
  warn "This removes Omacase-managed symlinks & stops its services."
  warn "It does NOT uninstall your Homebrew apps."
  is_dryrun || confirm "Proceed?" || { info "Cancelled."; return; }
  source "$OMACASE_ROOT/lib/wm.sh"; _wm_stop_all || true

  # Remove only the symlinks Omacase created.
  local src="$OMACASE_ROOT/home" f rel target
  while IFS= read -r f; do
    rel="${f#"$src"/}"
    target="$HOME/$(printf '%s' "$rel" | sed -e 's#^dot_#.#' -e 's#/dot_#/.#g')"
    _is_omacase_link "$target" && run rm -f "$target"
  done < <(find "$src" -type f ! -name '.DS_Store')

  success "Omacase symlinks removed."
  log "To bring back your original config: omacase restore   (see: omacase restore --list)"
}
