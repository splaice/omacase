# Outstanding Features

A working checklist of functionality gaps between **Omacase** and **Omarchy**,
limited to things that are practical to implement on macOS. Derived from a
gap analysis (Omacase repo vs. the Omarchy manual / `basecamp/omarchy`,
stable v3.8.2 ≈ dev 4.0.0-alpha).

Tiers are by value-for-effort. Check items off as we land them. Each item notes
**what** it is, the **Omarchy** reference, the **macOS path**, and likely
**files** to touch.

---

## Tier 1 — High value, low effort

- [x] **Bar: system-status modules** — CPU + memory on SketchyBar, click → btop. ✅
  - Scope decision: macOS's own menu bar owns battery/network/bluetooth/audio, so the bottom bar only adds what it lacks: **live CPU + memory** (`sysstats.sh`, left, next to caffeine, updates every 5s).
  - Click opens a **controlled btop window** (`btop_popup.sh`): a new window in the *existing* (undecorated) Ghostty instance — not a 2nd instance (avoids the session-restore prompt) — running btop, floated via `aerospace layout floating`, centered at ~65% of the main display via System Events.
  - Files: `home/dot_config/sketchybar/sketchybarrc` (generated `sysstats.sh` + `btop_popup.sh`).

- [ ] **App-launch keybind layer** — `Super+Shift+<letter>` to launch/focus native apps.
  - Omarchy: `SUPER+SHIFT+B` browser, `F` files, `M` Spotify, `G` Signal, `O` Obsidian, `/` 1Password, etc.
  - macOS: AeroSpace `exec-and-forget open -a "<App>"` (focuses if running). Mirrors existing `Super+Return`.
  - Files: `home/dot_config/aerospace/aerospace.toml`; document in `KEYBINDS.md`, `README.md`.
  - Notes: pick the app set (browser, Finder, editor, 1Password, chat, music). Mind Super = `⌃⌥⌘`, Shift layer free.

- [ ] **Per-app window rules** — expand `[[on-window-detected]]` (today: only float System Settings).
  - Omarchy: auto-float/center dialogs & TUIs; assign apps to workspaces.
  - macOS: more `layout floating` rules (Calculator, System Information, small utilities) + `move-node-to-workspace` assignments (e.g. chat→a workspace).
  - Files: `home/dot_config/aerospace/aerospace.toml` (line ~120 onward).

- [ ] **Bar: update-available indicator** — show when `brew outdated` has updates.
  - Omarchy: Waybar update indicator.
  - macOS: SketchyBar item on an interval running `brew outdated`; click → `omacase update`.
  - Files: `home/dot_config/sketchybar/sketchybarrc`.

---

## Tier 2 — Medium value

- [ ] **Global system menu** — bind a key to an interactive Omacase menu.
  - Omarchy: `SUPER+ALT+SPACE` menu (Capture / Toggle / Style / Setup / Install / power).
  - macOS: bind to launch `omacase menu` in a Ghostty popup (or a Shortcut); extend the gum menu with Capture, Toggle, power entries.
  - Files: `lib/menu.sh`, `home/dot_config/aerospace/aerospace.toml`.

- [ ] **Zed theme sync** — fold Zed into `omacase theme` (installed but unthemed today).
  - Omarchy: themes restyle VSCode + editors.
  - macOS: add `themes/<name>/zed` + a symlink/settings step in `lib/theme.sh`.
  - Files: `lib/theme.sh`, `themes/*/`.

- [ ] **DND / Focus toggle + notify helper.**
  - Omarchy: mako DND toggle + `omarchy-notification-send`.
  - macOS: toggle a Focus via `shortcuts run`/osascript; add a `terminal-notifier`/`osascript` notify helper for scripts.
  - Files: new `lib/` helper or `omacase` subcommand; optional SketchyBar indicator.

- [ ] **Config migrations** — versioned, idempotent migrations on `omacase update`.
  - Omarchy: 300+ timestamped migration scripts.
  - macOS: a `migrations/` dir + a runner in `lib/update.sh` that tracks the last-applied id in `$OMACASE_STATE`.
  - Files: `lib/update.sh`, new `migrations/`.

- [ ] **Wallpaper cycling** — multiple backgrounds per theme + a cycle hotkey.
  - Omarchy: per-theme `backgrounds/` dir, `omarchy-theme-bg-next`.
  - macOS: extend `omacase theme` wallpaper step; add `omacase wallpaper next` + a keybind.
  - Files: `lib/theme.sh` (or new), `themes/*/`.

---

## Tier 3 — Nice-to-have

- [ ] **Color-picker hotkey** — Digital Color Meter or a CLI picker on a key.
- [ ] **Screen OCR hotkey** — macOS Live Text / `shortcuts` to grab text from a region.
- [ ] **Theme install from URL** — `omacase theme install <git-url>`.
- [ ] **Font switcher** — `omacase font <name>` to retarget Ghostty/SketchyBar.
- [ ] **Quick reminders hotkey** — set/show via Reminders/osascript (`omarchy-reminder` analog).
- [ ] **Night Shift toggle hotkey** — toggle macOS Night Shift on a key.

---

## Out of scope (recorded so we don't relitigate)

**Native on macOS — no gap:** screenshots/recording (`⌘⇧3/4/5`), lock screen
(`⌃⌘Q`), idle/screensaver, volume/brightness/media-key OSD, wifi/bluetooth menus,
clipboard history (Tahoe Spotlight). Clock was removed on purpose.

**Linux-only / impractical:** ISO installer, Limine/Plymouth/SDDM, btrfs+Snapper
boot rollback, hardware tuning, gaming stack, Windows VM, UFW/FIDO2, keyboard RGB,
Hyprland blur/shadows, window **grouping/tabbed** & **scratchpad** (AeroSpace
limitation), Caps→Compose key.

**Already in Omacase:** caffeinate toggle, gaps, accordion, 2×2 grid (`Super+q`),
web apps + Spotlight launchers, dictation (Wispr Flow), modern CLI stack
(eza/bat/fd/rg/fzf/zoxide/atuin/mise/direnv).
