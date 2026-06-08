# shellcheck shell=bash
# `omacase doctor` — diagnose the things an installer can't fix automatically:
# TCC permission grants and SIP state. Deep-links to the right Settings pane.

omacase_doctor() {
  ensure_brew_env
  local issues=0

  step "Tooling"
  for c in brew gum sketchybar borders; do
    if have "$c"; then success "$c installed"; else error "$c missing — run \`omacase install\`"; ((issues++)); fi
  done

  step "Backups"
  source "$OMACASE_ROOT/lib/backup.sh"
  local last; last="$(cat "$OMACASE_STATE/last-backup" 2>/dev/null)"
  if [ -n "$last" ]; then success "latest snapshot: $last  (omacase restore to roll back)"
  else info "no backups yet (created automatically on first install)"; fi

  step "Window manager"
  local wm; wm="$(cat "$OMACASE_STATE/wm" 2>/dev/null || echo aerospace)"
  info "Active profile: $wm"
  if [ "$wm" = aerospace ]; then
    pgrep -x AeroSpace >/dev/null && success "AeroSpace running" || { warn "AeroSpace not running — \`omacase wm aerospace\`"; ((issues++)); }
  else
    pgrep -x yabai >/dev/null && success "yabai running" || { warn "yabai not running"; ((issues++)); }
    if csrutil status 2>/dev/null | grep -qi enabled; then
      error "SIP fully enabled — yabai scripting addition won't load. See \`omacase wm yabai\`."; ((issues++))
    fi
  fi

  step "Permissions (macOS requires these by hand)"
  cat <<'EOF'
  These need a manual toggle in System Settings → Privacy & Security.
  No script can grant them — that's the OS security model, by design.

    Accessibility      : AeroSpace / yabai, SketchyBar, Raycast
    Input Monitoring   : Karabiner-Elements, skhd (yabai profile)
    Full Disk Access   : (optional) terminal, for some defaults writes
EOF

  step "Raycast hotkeys (set once in Raycast prefs — not a dotfile)"
  cat <<'EOF'
  Super = right ⌘ (Hyper, via Karabiner). In Raycast → Settings → Hotkey:
    Super + Space  →  Raycast root search (launcher)
    Super + F      →  Clipboard History
    Super + D      →  Switch Windows
    Super + E      →  Search Emoji & Symbols  (and/or Snippets)
  Karabiner emits Super as ⌘⌃⌥⇧, so record those chords in Raycast.
EOF
  if confirm "Open the Accessibility settings pane now?"; then
    open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility" || true
  fi

  step "Summary"
  if [ "$issues" -eq 0 ]; then success "No automated issues found. Verify the manual grants above."
  else warn "$issues issue(s) detected above."; fi
}
