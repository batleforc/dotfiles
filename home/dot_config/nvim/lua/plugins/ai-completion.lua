-- AI autocomplete via minuet-ai.nvim, backed by a local model served by LM Studio.
-- Mode: virtual text (ghost text), MANUAL trigger only.
--   <A-y> request a completion, then:
--   <A-a> accept one line, <A-A> accept all, <A-]>/<A-[> cycle, <A-e> dismiss.
-- LM Studio: start the local server (default http://localhost:1234), load a coder model,
-- and set `model` below to the id from `curl http://localhost:1234/v1/models`.
return {
  {
    "milanglacier/minuet-ai.nvim",
    event = "InsertEnter",
    dependencies = { "nvim-lua/plenary.nvim" },
    opts = {
      provider = "openai_fim_compatible",
      n_completions = 1, -- keep low for local hardware
      context_window = 512,
      request_timeout = 2.5,
      throttle = 1500,
      debounce = 600,
      provider_options = {
        openai_fim_compatible = {
          api_key = "TERM", -- dummy; LM Studio needs no key, but an env var name is required
          name = "LMStudio",
          end_point = "http://localhost:1234/v1/completions",
          model = "qwen2.5-coder-7b-instruct", -- EDIT to match `curl http://localhost:1234/v1/models`
          stream = true,
          optional = {
            max_tokens = 128,
            top_p = 0.9,
          },
        },
      },
      virtualtext = {
        auto_trigger_ft = {}, -- empty = manual only
        keymap = {
          accept = "<A-A>", -- accept full suggestion
          accept_line = "<A-a>", -- accept one line
          accept_n_lines = "<A-z>",
          prev = "<A-[>", -- invokes completion if none shown, else cycles
          next = "<A-]>",
          dismiss = "<A-e>",
        },
      },
    },
    keys = {
      {
        "<A-y>",
        function()
          require("minuet.virtualtext").action.invoke()
        end,
        mode = "i",
        desc = "Minuet: request AI completion",
      },
    },
  },
  -- Also expose minuet inside the blink.cmp menu (manual). blink.cmp ships with LazyVim,
  -- so we only override its opts.
  {
    "saghen/blink.cmp",
    optional = true,
    opts = {
      sources = {
        default = { "lsp", "path", "snippets", "buffer" },
        providers = {
          minuet = {
            name = "minuet",
            module = "minuet.blink",
            async = true,
            timeout_ms = 3000,
            score_offset = 50,
          },
        },
      },
      completion = { trigger = { prefetch_on_insert = false } },
    },
  },
}
