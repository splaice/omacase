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
  - Click **toggles** a **controlled btop window** via the `omacase btop` subcommand (`lib/wm.sh`): a new window in the *existing* (undecorated) Ghostty instance — not a 2nd instance (avoids the session-restore prompt) — running `exec btop` (so quitting btop closes the window), floated via `aerospace layout floating`, centered at ~65% of the main display via System Events. Clicking again sends `q` and the window closes.
  - Files: `lib/wm.sh` (`omacase_btop`), `bin/omacase` + `completions/_omacase` (dispatch/usage), `home/dot_config/sketchybar/sketchybarrc` (`sysstats.sh` + click → `omacase btop`).

- [x] **App-launch keybind layer** — bare-Super launch/overlay binds. ✅
  - `Super+B` → default browser (`omacase browser`, reads the LaunchServices https handler).
  - `Super+Shift+F` → ranger file popup (`omacase files`; `Super+F` is fullscreen). Chromeless centered Ghostty, toggle. Added `ranger` to the Brewfile.
  - `Super+M` → music overlay (`omacase music`; default Spotify, `omacase music apple` switches to Apple Music, falls back to whichever is installed).
  - `Super+O` → Obsidian overlay (`omacase obsidian`).
  - `Super+P` → 1Password overlay (`omacase 1password`).
  - Overlay pattern: GUI apps (music/obsidian) toggle reveal/hide as centered floats *above* everything (`_app_toggle` + `on-window-detected` float rules); terminal popups (btop/files) share `_ghostty_popup_toggle`.
  - Files: `lib/wm.sh`, `bin/omacase`, `completions/_omacase`, `home/dot_config/aerospace/aerospace.toml`, `Brewfile`, `KEYBINDS.md`.

- [x] **Default messaging app** — `Super+G` → iMessage. ✅
  - `omacase message` (alias `messages`) toggles a centered Messages overlay sized to 80% of the screen (chat wants more room than the other overlays — `_app_toggle` gained an optional size-percent arg). Single default for now; multiple-app support (Signal/etc., like `omacase music`) can come later.

- [x] **Per-app window rules** — curated float list for system utilities. ✅
  - A grouped, commented "Window rules" section in `aerospace.toml` floats ~30 system-utility / dialog-style apps (Calculator, Activity Monitor, System Settings, Disk Utility, Font Book, Screenshot, Console, …), the input/WM helper settings (Karabiner, BetterMouse, Loop), and small converters — so they escape tiling. Everything else tiles (the correct default); extend by copy-pasting a block (the header documents how + the float/tile-only caveat).
  - Kept native/inline (chosen over a generated registry): AeroSpace is single-file with no includes, the exception set is small, and a plain block is the copy-pasteable path for others.
  - Note: `on-window-detected` can't size/position — only float/tile/assign-workspace. Centered/sized overlays stay the job of the `omacase` commands.
  - Deferred: workspace pinning (`move-node-to-workspace`) — opinionated, interacts with dynamic workspaces.
  - Files: `home/dot_config/aerospace/aerospace.toml`.

- [x] **Bar: update-available indicator** — Homebrew outdated count on the left. ✅
  - Logic lives in `omacase outdated` (lib/update.sh): counts `brew outdated` and paints the SketchyBar `update` item; shown only when >0, hidden otherwise. Polled every 30 min + on wake. Click → `omacase update` in a terminal.
  - Gotcha handled: brew crashes when the SketchyBar daemon spawns it directly (`Hardware::CPU.cores` → nil), so `omacase outdated` runs brew inside a fresh login shell; `HOMEBREW_NO_AUTO_UPDATE=1` keeps it read-only/fast.
  - Future: fold in omacase self-updates once omacase ships versioned releases (no distribution yet).
  - Files: `lib/update.sh`, `bin/omacase`, `completions/_omacase`, `home/dot_config/sketchybar/sketchybarrc`.

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
