# shellcheck shell=bash
# `omacase doctor` — diagnose the things an installer can't fix automatically:
# TCC permission grants and SIP state. Deep-links to the right Settings pane.

omacase_doctor() {
  ensure_brew_env
  local issues=0

  step "Tooling"
  for c in brew gum sketchybar borders; do
    if have "$c"; then success "$c installed"; else error "$c missing — run \`omacase install\`"; issues=$((issues + 1)); fi
  done

  step "Command on PATH (\`omacase\`)"
  local bindir link want; bindir="$(_omacase_bindir)"; want="$OMACASE_ROOT/bin/omacase"
  if [ -z "$bindir" ]; then
    warn "No Homebrew bin dir found — can't link \`omacase\` onto PATH."; issues=$((issues + 1))
  else
    link="$bindir/omacase"
    if [ "$(readlink "$link" 2>/dev/null)" = "$want" ]; then
      success "\`omacase\` → $link"
    elif [ -e "$link" ] && [ ! -L "$link" ]; then
      warn "$link exists and isn't a symlink — leaving it alone."; issues=$((issues + 1))
    else
      warn "\`omacase\` not linked onto PATH — repairing → $link"
      run ln -sfn "$want" "$link"
      is_dryrun || success "linked \`omacase\` → $link"
    fi
  fi

  step "Shell completion (zsh)"
  local zfunc comp; zfunc="$(_omacase_zfuncdir)"; comp="$OMACASE_ROOT/completions/_omacase"
  if [ -z "$zfunc" ]; then
    warn "No Homebrew prefix found — can't link zsh completion."; issues=$((issues + 1))
  elif [ "$(readlink "$zfunc/_omacase" 2>/dev/null)" = "$comp" ]; then
    success "_omacase → $zfunc/_omacase  (omacase <Tab> completes; compinit runs via ~/.zshrc)"
  else
    warn "zsh completion not linked — repairing → $zfunc/_omacase"
    run mkdir -p "$zfunc"
    run ln -sfn "$comp" "$zfunc/_omacase"
    is_dryrun || success "linked _omacase → $zfunc/_omacase  (open a new shell to pick it up)"
  fi
  # Group-writable dirs above an fpath entry make compinit prompt "insecure
  # directories?" on every new shell (brew installs can re-add go-w to share/).
  if [ -n "$zfunc" ]; then
    local share="${zfunc%/zsh/site-functions}" insecure
    insecure="$(find "$share" "$share/zsh" "$zfunc" "$share/zsh-completions" -maxdepth 0 -perm +022 2>/dev/null)"
    if [ -n "$insecure" ]; then
      warn "group/world-writable completion dirs (compinit will nag) — fixing: $insecure"
      run chmod go-w $insecure 2>/dev/null || true
    else
      success "completion dirs pass compaudit (no group-writable parents)"
    fi
  fi

  step "Backups"
  source "$OMACASE_ROOT/lib/backup.sh"
  local last; last="$(cat "$OMACASE_STATE/last-backup" 2>/dev/null)"
  if [ -n "$last" ]; then success "latest snapshot: $last  (omacase restore to roll back)"
  else info "no backups yet (created automatically on first install)"; fi

  step "Window manager"
  local wm; wm="$(cat "$OMACASE_STATE/wm" 2>/dev/null || echo aerospace)"
  info "Active profile: $wm"
  if [ "$wm" = aerospace ]; then
    pgrep -x AeroSpace >/dev/null && success "AeroSpace running" || { warn "AeroSpace not running — \`omacase wm aerospace\`"; issues=$((issues + 1)); }
  else
    pgrep -x yabai >/dev/null && success "yabai running" || { warn "yabai not running"; issues=$((issues + 1)); }
    if csrutil status 2>/dev/null | grep -qi enabled; then
      error "SIP fully enabled — yabai scripting addition won't load. See \`omacase wm yabai\`."; issues=$((issues + 1))
    fi
  fi
  check_loop_conflict || issues=$((issues + 1))

  step "Desktop apps"
  # Karabiner 15+ uses DriverKit; the real "Super key live" signal is the system
  # extension being 'activated enabled' (not 'waiting for user').
  if pgrep -x Karabiner-Elements >/dev/null || pgrep -f Karabiner-Core-Service >/dev/null; then
    local se; se="$(systemextensionsctl list 2>/dev/null | grep -i karabiner)"
    if printf '%s' "$se" | grep -q 'activated enabled'; then
      success "Karabiner driver active (Super key live)"
    elif printf '%s' "$se" | grep -q 'waiting for user'; then
      warn "Karabiner driver is 'waiting for user' — APPROVE it: System Settings → General →"
      warn "  Login Items & Extensions → Driver Extensions (toggle Karabiner on)."
      issues=$((issues + 1))
    else
      warn "Karabiner driver extension not enabled — enable it + Input Monitoring."
      issues=$((issues + 1))
    fi
  else
    warn "Karabiner-Elements not running — \`open -a Karabiner-Elements\`"; issues=$((issues + 1))
  fi

  step "Appearance sync (theme ⇄ macOS Light/Dark)"
  if can_set_appearance; then
    success "Terminal can drive macOS appearance — theme switches will flip Light/Dark."
  else
    warn "Terminal can't control System Events, so theme switches can't flip macOS Light/Dark."
    warn "  Grant it: System Settings → Privacy & Security → Automation → (your terminal) → System Events."
    issues=$((issues + 1))
  fi

  step "Permissions (macOS requires these by hand)"
  cat <<'EOF'
  These need a manual toggle in System Settings → Privacy & Security.
  No script can grant them — that's the OS security model, by design.

    Accessibility      : AeroSpace / yabai, SketchyBar
    Input Monitoring   : Karabiner-Elements, skhd (yabai profile)
    Automation         : terminal → System Events (theme Light/Dark sync)
    Full Disk Access   : (optional) terminal, for some defaults writes
EOF

  step "Launcher (Spotlight — built in, no third-party app)"
  cat <<'EOF'
  macOS Spotlight is the launcher / command palette. On Tahoe it also has a
  clipboard manager, Actions (App Intents), and auto-learned Quick Keys.
    ⌘ Space        →  Spotlight (launcher / search / actions / clipboard)
    ⌃⌘ Space       →  Emoji & Symbols (Character Viewer)
    ⌘ Tab          →  Switch apps (macOS app switcher)
  If ⌘Space doesn't open Spotlight (e.g. a launcher had taken it), re-enable it:
  System Settings → Keyboard → Keyboard Shortcuts → Spotlight → "Show Spotlight search".
  Tip: bind your own automations as Shortcuts to run them from Spotlight (and via
  the Karabiner Super key if you like).
EOF
  if confirm "Open the Accessibility settings pane now?"; then
    open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility" || true
  fi

  step "Summary"
  if [ "$issues" -eq 0 ]; then success "No automated issues found. Verify the manual grants above."
  else warn "$issues issue(s) detected above."; fi
}
