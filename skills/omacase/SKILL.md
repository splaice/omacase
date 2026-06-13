---
name: omacase
description: Install, configure, theme, and manage an opinionated tiling macOS (AeroSpace + SketchyBar + Ghostty + Spotlight) via the `omacase` CLI. Use when the user wants to set up their Mac, switch themes/window managers, diagnose tiling/permission issues, or change system defaults.
---

# Omacase — opinionated tiling macOS

Omacase is a single CLI (`~/.local/share/omacase/bin/omacase`) over an idempotent
bash engine. Prefer driving it through these subcommands instead of editing live
config by hand — the CLI keeps state and re-applies themes/WM consistently.

## Command surface
- `omacase install` — full idempotent setup (re-runnable; same engine as update)
- `omacase update` — git pull + `brew bundle` + re-apply dotfiles, defaults, theme, WM
- `omacase theme [name]` — apply a theme everywhere at once; 19 Omarchy themes ship in `themes/` (run `omacase theme` to pick from the list). Light/dark is derived from the theme background and also flips macOS appearance and the Claude Code CLI theme. The desktop wallpaper is set to the theme's Omarchy background (fetched on first use into `~/.local/share/omacase/backgrounds/`, then cached).
- `omacase webapp [name]` — open an Omarchy web app (no name = list); meant to be wrapped in a Spotlight Shortcut
- `omacase appearance [toggle|dark|light]` — flip/set macOS system Light/Dark
- `omacase launchers [build|remove]` — generate/remove Spotlight `.app` launchers (in `~/Applications`) for each web app + appearance toggle, via `osacompile`
- `omacase wm <aerospace|yabai>` — switch window-manager profile
- `omacase doctor` — check tooling, WM, SIP state, and missing permission grants
- `omacase backup [label]` / `omacase restore [id]` — snapshot & roll back dotfiles + defaults
- `omacase menu` — gum TUI (wrap in a Shortcut to launch from Spotlight)

## Reversibility (important)
- Omacase owns its dotfiles via **symlinks** from `home/` into `$HOME` — it does NOT
  use chezmoi, so it never collides with a user's existing chezmoi/stow setup.
- `install` calls `_auto_backup` first: it snapshots any pre-existing dotfile targets
  and the touched macOS `defaults` domains into `$OMACASE_STATE/backups/<id>/`.
- If a user dislikes the result, `omacase restore` rolls back (latest by default;
  `omacase restore --list` to choose). Don't hand-undo changes — use restore.

## Architecture (where to change things)
- `Brewfile` — the package/app set; edit then `omacase update`.
- `macos/defaults.sh` — `defaults write` layer (key repeat, Finder, Dock, screenshots…).
  Keep `OMACASE_DEFAULTS_DOMAINS` in `lib/backup.sh` in sync with the domains it writes.
- `home/` — dotfile source (symlinked into `$HOME`; `dot_` prefix → `.`).
  `home/dot_config/aerospace/aerospace.toml` holds the Hyprland-style keybinds on
  the Super key (right ⌘ → ⌃⌥⌘ via Karabiner): Super+WASD focus, Super+Shift+WASD
  move, Super+[1-9] workspaces.
- `themes/<name>/` — per-app color fragments; `omacase theme` symlinks them into `~/.config`.
- `lib/*.sh` — one file per subcommand.

## Hard limits — set expectations honestly
- **Permission grants can't be automated.** AeroSpace/yabai, SketchyBar, and
  Karabiner need Accessibility/Input-Monitoring approval that macOS (TCC) requires
  a human to click. `omacase doctor` deep-links the right Settings pane; the user
  must toggle it. The launcher is Spotlight (built in — no app or hotkey to set up).
- **yabai needs SIP partially disabled** — a manual Recovery-mode step that cannot be
  scripted from the running OS. Default to the **AeroSpace** profile, which needs none
  of this. Only walk the user through yabai if they explicitly want BSP dynamic tiling.
- **No blur / window animations / rounded corners on arbitrary windows** — macOS's
  window server doesn't expose them. JankyBorders (active-window borders) is the only
  Hyprland-style effect available. Don't promise the rest.

## Common requests → action
- "Set up my Mac" → `omacase install`, then tell them to run `omacase doctor` and grant permissions.
- "Change the theme" → `omacase theme tokyo-night` (or list with `omacase theme`).
- "Tiling stopped working" → `omacase doctor`; check AeroSpace is running and granted Accessibility.
- "Add an app" → add a line to `Brewfile`, then `omacase update`.
- "Tweak a keybind" → edit `home/dot_config/aerospace/aerospace.toml` (it's symlinked, so changes are live; reload AeroSpace with Super+Shift+c).
- "Undo / I don't like this" → `omacase restore` (or `omacase restore --list` then `omacase restore <id>`).
