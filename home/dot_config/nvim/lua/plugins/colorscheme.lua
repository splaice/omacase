-- omacase theme integration. `omacase theme <name>` symlinks
-- themes/<name>/nvim.lua → ~/.config/nvim/lua/theme.lua, which returns the
-- active colorscheme name. We read it and hand it to LazyVim so the editor
-- matches the rest of the system. Every theme's colorscheme plugin is declared
-- below (one per Omarchy theme) so whichever one theme.lua names is installed
-- and lazy-loaded on demand.
local ok, colorscheme = pcall(require, "theme")
if not ok or type(colorscheme) ~= "string" then
  colorscheme = "catppuccin-mocha"
end

return {
  -- Colorscheme plugins (mirrors Omarchy's per-theme neovim.lua specs).
  { "catppuccin/nvim", name = "catppuccin", priority = 1000 },     -- catppuccin-mocha / -latte
  { "folke/tokyonight.nvim", priority = 1000 },                    -- tokyonight-night
  { "neanias/everforest-nvim", main = "everforest", opts = { background = "soft" } },
  { "ellisonleao/gruvbox.nvim" },
  { "rebelot/kanagawa.nvim" },
  { "EdenEast/nightfox.nvim" },                                    -- nordfox (nord)
  { "ribru17/bamboo.nvim", priority = 1000 },                      -- bamboo (osaka-jade)
  { "rose-pine/neovim", name = "rose-pine" },                      -- rose-pine-dawn
  { "OldJobobo/miasma.nvim", priority = 1000 },
  { "OldJobobo/retro-82.nvim", priority = 1000 },
  { "bjarneo/ethereal.nvim", priority = 1000 },
  { "bjarneo/hackerman.nvim", dependencies = { "bjarneo/aether.nvim" }, priority = 1000 },
  { "omacom-io/lumon.nvim", priority = 1000 },
  { "tahayvr/matteblack.nvim" },                                   -- matteblack (matte-black)
  { "bjarneo/vantablack.nvim", priority = 1000 },
  { "bjarneo/white.nvim", priority = 1000 },
  { "kepano/flexoki-neovim", priority = 1000 },                    -- flexoki-light

  -- ristretto = the monokai-pro "ristretto" filter; needs setup() before apply.
  {
    "gthelding/monokai-pro.nvim",
    config = function()
      require("monokai-pro").setup({
        filter = "ristretto",
        override = function()
          return {
            NonText = { fg = "#948a8b" },
            MiniIconsGrey = { fg = "#948a8b" },
            MiniIconsRed = { fg = "#fd6883" },
            MiniIconsBlue = { fg = "#85dacc" },
            MiniIconsGreen = { fg = "#adda78" },
            MiniIconsYellow = { fg = "#f9cc6c" },
            MiniIconsOrange = { fg = "#f38d70" },
            MiniIconsPurple = { fg = "#a8a9eb" },
            MiniIconsAzure = { fg = "#a8a9eb" },
            MiniIconsCyan = { fg = "#85dacc" },
          }
        end,
      })
    end,
  },

  -- Activate whichever colorscheme matches the system theme.
  { "LazyVim/LazyVim", opts = { colorscheme = colorscheme } },
}
