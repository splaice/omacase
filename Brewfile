# omacase Brewfile — the opinionated package set. `brew bundle` is idempotent.
# Edit, then `omacase update` (or `brew bundle`) to converge.

# --- Window management & desktop -------------------------------------------
tap "nikitabobko/tap"
tap "FelixKratz/formulae"
cask "nikitabobko/tap/aerospace"     # tiling WM (default profile, no SIP disable)
brew "FelixKratz/formulae/sketchybar" # status bar (Waybar analog)
brew "FelixKratz/formulae/borders"    # JankyBorders — active-window borders
# yabai profile (advanced; needs SIP partially disabled — see `omacase wm yabai`)
brew "koekeishiya/formulae/yabai"
brew "koekeishiya/formulae/skhd"
tap  "koekeishiya/formulae"

# --- The "make Mac behave" set ---------------------------------------------
# Launcher is macOS Spotlight (⌘Space) — Tahoe's Spotlight has actions,
# clipboard history, and Quick Keys built in, so no third-party launcher.
cask "karabiner-elements" # mints the Super key (right ⌘ → ⌃⌥⌘) for AeroSpace
cask "alt-tab"            # real alt-tab across all windows
cask "jordanbaird-ice"    # Ice — open-source menu-bar manager (Bartender alt)

# --- Terminal & shell -------------------------------------------------------
cask "ghostty"           # native GPU terminal
brew "starship"          # prompt
brew "eza"               # ls
brew "bat"               # cat
brew "fd"                # find
brew "ripgrep"           # grep
brew "zoxide"            # cd
brew "fzf"               # fuzzy finder
brew "btop"              # system monitor
brew "atuin"             # shell history
brew "git-delta"         # git diffs
brew "tmux"              # multiplexer
brew "zsh-completions"   # extra completion defs beyond zsh's bundled set (wired in dot_zshrc)
brew "glow"              # markdown rendered in the terminal (read READMEs where you are)
brew "dust"              # du
brew "jq"                # JSON wrangling
brew "tldr"              # example-first man pages
brew "fastfetch"         # branded system summary (`omacase menu` → About); config in home/

# --- Editor & dev -----------------------------------------------------------
brew "neovim"            # + LazyVim (seeded via dotfiles)
cask "zed"               # GUI editor
brew "mise"              # runtime version manager (node/python/ruby)
brew "direnv"
brew "lazygit"
brew "gh"

# --- Tooling ----------------------------------------------------------------
brew "gum"               # TUI for `omacase menu`
# (Omacase manages its own dotfiles via symlinks — no chezmoi dependency.)

# --- Fonts ------------------------------------------------------------------
cask "font-jetbrains-mono-nerd-font"

# --- Browser ----------------------------------------------------------------
# Brave is the dedicated `omacase webapp` browser (signed; opens chromeless
# app windows) so ⌘Q on a web app never quits your daily/default browser.
cask "brave-browser"     # Chromium + PWAs; pairs with Safari "Add to Dock"
