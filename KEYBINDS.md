# Omacase Keybinds

Two separate layers:

- **Super** = **right ⌘** → `⌃⌥⌘` (via Karabiner) = window management (AeroSpace tiling)
- **Launcher** = **Spotlight** (`⌘Space`) — built in; nothing to configure

> Super is `⌃⌥⌘` (Hyper minus Shift) so **Super+Shift** stays available as the
> "move" layer — exactly like Omarchy's `SUPER` / `SUPER+SHIFT`.

Reload the WM config after edits: **`Super + Shift + c`**.

---

## Launcher — Spotlight (built in)
On Tahoe, Spotlight is launcher + Actions + clipboard history + Quick Keys.

| Keys | Action |
|---|---|
| `⌘ Space` | Spotlight — launcher / search / Actions / clipboard history |
| `⌃⌘ Space` | Emoji & Symbols (Character Viewer) |
| `⌘ Tab` / AltTab | Switch windows |

> No setup — `⌘Space` is Spotlight by default. If it's been reassigned, re-enable it
> in System Settings → Keyboard → Keyboard Shortcuts → Spotlight.

---

## Spotlight launchers — the Omarchy command layer

**The easy way — `omacase launchers`.** macOS *Shortcuts* can't be authored from a
script, but `osacompile`'d `.app` launchers can. Run once:

```sh
omacase launchers          # build ~/Applications/*.app for every web app + Toggle Appearance
omacase launchers remove   # delete them again (only the ones omacase made)
```

Then open any from Spotlight (`⌘Space`, type the name): ChatGPT, Grok, HEY Email,
HEY Calendar, YouTube, WhatsApp, Google Messages, Google Photos, X, X Post, Toggle
Appearance. First launch of *Toggle Appearance* prompts once for Automation. (The
Super key drives AeroSpace now, so these are invoked by typing in Spotlight, not a
Super chord.)

**Or by hand as a Shortcut** (gets auto-learned Quick Keys, unlike a `.app`):
Shortcuts app → New Shortcut → "Run Shell Script", paste a command, name it:

> Shortcuts run with a minimal `PATH`, so use the **full path** to omacase and add
> Homebrew to `PATH`. Each script body is:
> ```sh
> export PATH="/opt/homebrew/bin:$PATH"
> "$HOME/.local/share/omacase/bin/omacase" <args>
> ```

### omacase actions (mirror Omarchy's Super-key menu)
| Shortcut name | Command (`omacase …`) | Omarchy analog |
|---|---|---|
| Theme <name> | `theme gruvbox` | `Super Shift Ctrl Space` theme menu |
| Toggle Appearance | `appearance toggle` | `Super Ctrl N` nightlight |
| Update System | `update` | menu → Update |
| Omacase Menu | `menu` *(terminal only — gum TUI; launch via Ghostty, not headless)* | `Super Alt Space` omarchy-menu |

### Web apps — `omacase webapp <name>` (Omarchy's set, `Super Shift` + letter)
Make one Shortcut per app (`webapp email`, `webapp chatgpt`, …); name it for the
site so Spotlight finds it. Opens a chromeless app window if you have a Chromium
browser, else the default browser.

| Shortcut | Command | Omarchy |
|---|---|---|
| ChatGPT | `webapp chatgpt` | `Super Shift A` |
| Grok | `webapp grok` | `Super Shift Alt A` |
| Email | `webapp email` | `Super Shift E` |
| Calendar | `webapp calendar` | `Super Shift C` |
| YouTube | `webapp youtube` | `Super Shift Y` |
| WhatsApp | `webapp whatsapp` | `Super Shift Alt G` |
| Messages | `webapp messages` | `Super Shift Ctrl G` |
| Photos | `webapp photos` | `Super Shift P` |
| X | `webapp x` | `Super Shift X` |
| X Post | `webapp x-post` | `Super Shift Alt X` |

> Native already — no Shortcut needed: **app launch** (type the app in Spotlight),
> **emoji** (`⌃⌘Space`), **screenshots** (`⌘⇧3/4/5`), **calculator** (Spotlight math),
> **clipboard history** (Spotlight, Tahoe), **lock/sleep** (Shortcuts has built-in
> actions). Window tiling lives on the **Super** layer below (AeroSpace), not Spotlight.

---

## Super — AeroSpace window management
**Super** = **right ⌘** (Karabiner maps it to `⌃⌥⌘`). Mirrors Omarchy's `SUPER`.

### Focus / move (WASD — W up, A left, S down, D right)
| Keys | Action |
|---|---|
| `Super + w / a / s / d` | Focus up / left / down / right |
| `Super + Shift + w / a / s / d` | Move window up / left / down / right |

### Size & layout
| Keys | Action |
|---|---|
| `Super + f` | **Fullscreen toggle** (fills the screen; yields when another window takes the space) |
| `Super + =` | Grow focused window |
| `Super + -` | Shrink focused window |
| `Super + e` | Tiles layout — flip split orientation (side-by-side ↔ stacked) |
| `Super + q` | Accordion layout — windows stack, focused one expands |
| `Super + Shift + Space` | Float / unfloat the window (escape tiling) |

### Workspaces (the way to give each app a full screen)
| Keys | Action |
|---|---|
| `Super + 1 … 9` | Switch to workspace N |
| `Super + Shift + 1 … 9` | Send focused window to workspace N |
| `Super + Tab` | Toggle to previous workspace |
| `Super + Shift + Tab` | Move workspace to the next monitor |

### Service mode — `Super + Shift + ;`, then:
| Key | Action |
|---|---|
| `esc` | Reload config and exit service mode |
| `r` | Flatten / reset the workspace tree (fixes weird splits) |
| `f` | Toggle floating/tiling for the window |
| `backspace` | Close all windows but the focused one |

---

## Why windows "keep shrinking"
AeroSpace tiles **every** window in a workspace, so each new window you open in
that space shrinks the others to make room. `Super + f` fullscreen is a per-window
*toggle* — it does **not** stop new/!other windows from re-tiling the space, so it
looks like things "un-fullscreen."

The fix is to give busy apps their own space instead of cramming one workspace:

- Put one app per workspace: focus it, `Super + Shift + 2` to send it to space 2,
  then `Super + 1` / `Super + 2` to flip. A workspace with a single window is
  effectively full-screen and stays that way.
- Or use `Super + q` (accordion) so the focused window stays large and the rest
  tuck to the side.
- Use `Super + f` for a quick temporary zoom, not as a permanent state.
