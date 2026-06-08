# shellcheck shell=bash
# `omacase menu` — the gum TUI, the omarchy-menu analog. Bind to a Raycast
# hotkey (Raycast → Script Commands → run `omacase menu`).

omacase_menu() {
  local choice
  choice="$(gum_choose "Omacase" \
    "Update everything" \
    "Switch theme" \
    "Switch window manager" \
    "Run doctor" \
    "Restore a backup" \
    "Edit config" \
    "Quit")" || return

  case "$choice" in
    "Update everything")     source "$OMACASE_ROOT/lib/update.sh"; omacase_update ;;
    "Switch theme")          source "$OMACASE_ROOT/lib/theme.sh";  omacase_theme ;;
    "Switch window manager") source "$OMACASE_ROOT/lib/wm.sh";     omacase_wm ;;
    "Run doctor")            source "$OMACASE_ROOT/lib/doctor.sh"; omacase_doctor ;;
    "Restore a backup")      source "$OMACASE_ROOT/lib/backup.sh"; omacase_restore ;;
    "Edit config")           exec "${EDITOR:-open}" "$OMACASE_ROOT/home" ;;
    "Quit"|"")               return ;;
  esac
}
