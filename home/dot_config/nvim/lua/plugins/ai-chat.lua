-- AI chat / inline assistant via codecompanion.nvim, wired to LM Studio (OpenAI-compatible).
--   <leader>aa actions, <leader>ac toggle chat, <leader>ai inline.
-- Set `model.default` below to the id from `curl http://localhost:1234/v1/models`.
return {
  "olimorris/codecompanion.nvim",
  dependencies = { "nvim-lua/plenary.nvim", "nvim-treesitter/nvim-treesitter" },
  cmd = { "CodeCompanion", "CodeCompanionChat", "CodeCompanionActions" },
  opts = {
    adapters = {
      http = {
        lmstudio = function()
          return require("codecompanion.adapters").extend("openai_compatible", {
            name = "lmstudio",
            env = {
              url = "http://localhost:1234",
              api_key = "TERM", -- dummy; LM Studio needs no key
              chat_url = "/v1/chat/completions",
            },
            schema = {
              model = { default = "qwen2.5-coder-7b-instruct" }, -- EDIT to match LM Studio
            },
          })
        end,
      },
    },
    strategies = {
      chat = { adapter = "lmstudio" },
      inline = { adapter = "lmstudio" },
    },
  },
  keys = {
    { "<leader>aa", "<cmd>CodeCompanionActions<cr>", mode = { "n", "v" }, desc = "CodeCompanion actions" },
    { "<leader>ac", "<cmd>CodeCompanionChat Toggle<cr>", mode = { "n", "v" }, desc = "CodeCompanion chat" },
    { "<leader>ai", "<cmd>CodeCompanion<cr>", mode = { "n", "v" }, desc = "CodeCompanion inline" },
  },
}
