-- Kanagawa theme (https://github.com/rebelot/kanagawa.nvim)
return {
  { "rebelot/kanagawa.nvim", lazy = false, priority = 1000, theme = "dragon" },

  -- Tell LazyVim to use it
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "kanagawa",
    },
  },
}
