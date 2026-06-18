{ pkgs, theme, ... }:
{
  # catppuccin is loaded by the catppuccin hm module; don't call setup()/colorscheme here (double-load races the compile cache)
  catppuccin.nvim.settings = {
    transparent_background = false;
    integrations = {
      blink_cmp = true;
      gitsigns = true;
      neotree = true;
      telescope = true;
      which_key = true;
      treesitter = true;
      notify = true;
      mini = {
        enabled = true;
      };
      native_lsp = {
        enabled = true;
      };
    };
  };

  # syntax for azzie's .plan finger file (filetype mapped in extraLuaConfig).
  # Sourced by the syntax loader after its `syntax clear`, so the matches stick.
  # Colors mirror the `plan show` command, from the theme palette SSOT.
  home.file.".config/nvim/syntax/plan.vim".text = ''
    if exists("b:current_syntax")
      finish
    endif

    " scaffolding recedes; task text (default fg) is what stands out.
    syntax match planRule     /^─.*$/

    " section headers (glyph + label)
    syntax match planDoing    /^▶.*$/
    syntax match planNext     /^▷.*$/
    syntax match planSomeday  /^\~.*$/
    syntax match planDoneHdr  /^✓.*$/

    " items: dim the bullet, leave the text plain; indented lines are notes.
    syntax match planBullet   /^\s*·/
    syntax match planDetail   /^    .*$/
    syntax match planDoneItem /^\s*×.*$/

    " %hidden: tint the line softly, conceal the literal tag (shows in insert).
    syntax match planHidden    /^.*%hidden.*$/ contains=planHiddenTag
    syntax match planHiddenTag /\s*%hidden/ contained conceal

    highlight default planRule      guifg=${theme.palette.overlay0}
    highlight default planDoing     guifg=${theme.palette.mauve} gui=bold
    highlight default planNext      guifg=${theme.palette.sapphire} gui=bold
    highlight default planSomeday   guifg=${theme.palette.overlay2} gui=bold
    highlight default planDoneHdr   guifg=${theme.palette.overlay1} gui=bold
    highlight default planBullet    guifg=${theme.palette.overlay1}
    highlight default planDetail    guifg=${theme.palette.overlay1} gui=italic
    highlight default planDoneItem  guifg=${theme.palette.overlay0}
    highlight default planHidden    guifg=${theme.palette.flamingo}

    let b:current_syntax = "plan"
  '';

  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    withPython3 = false;
    withRuby = false;
    withNodeJs = false;

    # lsp servers, formatters, search tools (from nixpkgs, not mason)
    extraPackages = with pkgs; [
      nixd
      lua-language-server
      basedpyright
      ruff
      gopls
      rust-analyzer
      clang-tools
      bash-language-server
      typescript-language-server
      vscode-langservers-extracted
      taplo
      asm-lsp

      nixfmt-rfc-style
      stylua
      gofumpt
      rustfmt
      prettierd
      shfmt

      ripgrep
      fd
    ];

    plugins = with pkgs.vimPlugins; [
      catppuccin-nvim
      mini-icons
      lualine-nvim
      bufferline-nvim
      dressing-nvim
      fidget-nvim
      nvim-notify

      blink-cmp
      luasnip
      friendly-snippets

      neo-tree-nvim
      nui-nvim
      nvim-window-picker

      telescope-nvim
      telescope-fzf-native-nvim
      plenary-nvim

      nvim-lspconfig
      conform-nvim
      trouble-nvim
      todo-comments-nvim

      (nvim-treesitter.withPlugins (p: [
        p.nix
        p.lua
        p.bash
        p.go
        p.python
        p.rust
        p.c
        p.cpp
        p.markdown
        p.markdown_inline
        p.json
        p.yaml
        p.toml
        p.vimdoc
        p.diff
        p.gitcommit
      ]))
      nvim-treesitter-textobjects
      gitsigns-nvim
      which-key-nvim
      nvim-autopairs
      comment-nvim
      indent-blankline-nvim
      flash-nvim
    ];

    initLua = ''
      --  1. LEADER + CORE OPTIONS
      -- Leader is <Space>. It's the prefix for the discoverable menu layer:
      -- tap <Space> and wait, and which-key pops up showing every command.
      vim.g.mapleader = " "
      vim.g.maplocalleader = " "

      local o = vim.opt
      o.number = true            -- absolute line number on the cursor line
      o.relativenumber = true    -- relative numbers elsewhere (jump with 5j etc.)
      o.cursorline = true        -- highlight the current line (like VSCode)
      o.expandtab = true         -- spaces, not tabs
      o.shiftwidth = 2           -- 2-space indents by default...
      o.tabstop = 2              -- ...and a tab renders as 2 columns
      o.smartindent = true       -- auto-indent new lines sensibly
      o.ignorecase = true        -- search is case-insensitive...
      o.smartcase = true         -- ...unless you type a capital letter
      o.termguicolors = true     -- 24-bit color (required for Catppuccin)
      o.signcolumn = "yes"       -- always show the gutter (no width jitter)
      o.scrolloff = 8            -- keep 8 lines visible above/below cursor
      o.updatetime = 250         -- faster diagnostics/CursorHold
      o.splitright = true        -- vertical splits open to the right
      o.splitbelow = true        -- horizontal splits open below
      o.undofile = true          -- persistent undo across sessions
      o.clipboard = "unnamedplus"-- yank/paste uses the system clipboard
      o.wrap = false             -- don't soft-wrap long lines
      o.mouse = "a"              -- mouse works (click, select, scroll) like VSCode
      o.confirm = true           -- prompt to save instead of erroring on :q

      -- A tiny helper so every mapping reads cleanly below.
      local map = vim.keymap.set

      --  2. THEME ACCENT — mauve cursor-line number (from the palette SSOT)
      -- The catppuccin colorscheme itself is loaded by the catppuccin
      -- home-manager module (see the `catppuccin.nvim.settings` block in the
      -- enclosing .nix file) — NOT here. We only layer one extra accent on top:
      -- the current line's number in the rice's signature mauve. We do it from
      -- a ColorScheme autocmd so it re-applies if the colorscheme ever reloads
      -- (and so it lands *after* catppuccin has painted its own highlights).
      local mauve = "${theme.palette.mauve}"
      vim.api.nvim_create_autocmd("ColorScheme", {
        callback = function()
          vim.api.nvim_set_hl(0, "CursorLineNr", { fg = mauve, bold = true })
        end,
      })
      -- Apply once now too, in case the colorscheme already loaded before us.
      vim.api.nvim_set_hl(0, "CursorLineNr", { fg = mauve, bold = true })

      --  3. ICONS — one provider for everything
      require("mini.icons").setup()
      -- Shim so any plugin still asking for nvim-web-devicons gets mini.icons.
      MiniIcons.mock_nvim_web_devicons()

      --  4. NOTIFICATIONS — route vim.notify through nvim-notify (toasts)
      local notify = require("notify")
      notify.setup({ stages = "fade", timeout = 2500, render = "compact" })
      vim.notify = notify

      -- Prettier UI for selects/inputs (LSP rename prompt, code-action menu).
      require("dressing").setup({})

      --  5. TREESITTER — syntax highlighting + indentation + text objects
      -- NOTE: nixpkgs ships the *main* branch of nvim-treesitter, which dropped
      -- the old `require("nvim-treesitter.configs").setup{ highlight = ... }`
      -- module. On this version, highlighting is a core Neovim feature you turn
      -- on per-buffer with vim.treesitter.start(); the plugin just supplies the
      -- (Nix-installed) parsers. So we enable highlighting via a FileType
      -- autocmd over exactly the languages whose grammars we built in.
      require("nvim-treesitter").setup()

      local ts_filetypes = {
        "nix", "lua", "bash", "sh", "go", "python", "rust",
        "c", "cpp", "markdown", "json", "yaml", "toml",
        "vimdoc", "diff", "gitcommit",
      }
      vim.api.nvim_create_autocmd("FileType", {
        pattern = ts_filetypes,
        callback = function()
          -- Highlighting (provided by Neovim core, fed by the TS parser).
          pcall(vim.treesitter.start)
          -- Experimental treesitter indentation from the plugin.
          vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
        end,
      })

      -- .plan files (azzie's finger plan) carry no extension, so nvim assigns
      -- them no filetype and no color. Map them to the `plan` filetype; the
      -- colors live in syntax/plan.vim (a FileType autocmd here would have its
      -- matches wiped by syntax-on's later `syntax clear`, so a real syntax
      -- file on the runtime path is the only reliable home for them).
      vim.filetype.add({
        filename = {
          [".plan"] = "plan",
          ["plan.txt"] = "plan",
        },
        pattern = {
          [".*/%.plan"] = "plan",
        },
      })
      -- A .plan should read like a clean document, not source code. Strip the
      -- editor chrome (numbers/signcolumn/cursorline), soft-wrap the long detail
      -- lines, and enable conceal so syntax/plan.vim can hide the %hidden tag
      -- (it re-reveals in insert/visual via concealcursor, so nothing is lost).
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "plan",
        callback = function()
          vim.bo.commentstring = "# %s"
          local w = vim.wo
          w.number = false
          w.relativenumber = false
          w.signcolumn = "no"
          w.cursorline = false
          w.wrap = true
          w.linebreak = true
          w.breakindent = true
          w.conceallevel = 2
          w.concealcursor = "nc"
        end,
      })

      -- Text objects (also on the main branch now — different API). This gives
      -- you `af`/`if` = a/inner function, `ac`/`ic` = a/inner class, usable as
      -- motions: `daf` deletes a function, `vif` selects inside one, etc.
      require("nvim-treesitter-textobjects").setup({
        select = { lookahead = true },
      })
      local ts_sel = require("nvim-treesitter-textobjects.select").select_textobject
      local function sel(obj)
        return function() ts_sel(obj, "textobjects") end
      end
      map({ "x", "o" }, "af", sel("@function.outer"), { desc = "a function" })
      map({ "x", "o" }, "if", sel("@function.inner"), { desc = "inner function" })
      map({ "x", "o" }, "ac", sel("@class.outer"),    { desc = "a class" })
      map({ "x", "o" }, "ic", sel("@class.inner"),    { desc = "inner class" })

      --  6. STATUSLINE + TABS
      require("lualine").setup({
        options = {
          theme = "catppuccin",
          globalstatus = true,             -- one statusline for the whole window
          section_separators = "", component_separators = "",
        },
        sections = {
          -- Show diagnostics counts right in the statusline, VSCode-style.
          lualine_c = { "filename", "diagnostics" },
        },
      })

      require("bufferline").setup({
        options = {
          diagnostics = "nvim_lsp",        -- error/warn badges on each tab
          show_buffer_close_icons = true,
          offsets = {                       -- don't let tabs overlap the tree
            { filetype = "neo-tree", text = "Explorer", separator = true },
          },
        },
      })

      --  7. GIT GUTTER (gitsigns) + indent guides + autopairs + comments
      require("gitsigns").setup({
        on_attach = function(bufnr)
          local gs = require("gitsigns")
          local function m(mode, l, r, desc)
            map(mode, l, r, { buffer = bufnr, desc = desc })
          end
          -- Hunk navigation, like VSCode's gutter arrows.
          m("n", "]h", gs.next_hunk, "Next git hunk")
          m("n", "[h", gs.prev_hunk, "Prev git hunk")
        end,
      })

      require("ibl").setup()                -- indent-blankline guides
      require("nvim-autopairs").setup()     -- auto-close brackets/quotes
      require("Comment").setup()            -- gcc / gc{motion} commenting

      -- TODO/FIXME/HACK/NOTE highlighting + a telescope picker (<leader>xt).
      require("todo-comments").setup()

      -- Flash: press `s` then a 2-char label to jump anywhere on screen.
      require("flash").setup()
      map({ "n", "x", "o" }, "s", function() require("flash").jump() end,
        { desc = "Flash jump" })

      --  8. COMPLETION — blink.cmp (the VSCode IntelliSense feel)
      -- friendly-snippets ships VSCode-format snippet JSON; luasnip loads it,
      -- and blink pulls completions + snippets together into one menu.
      require("luasnip.loaders.from_vscode").lazy_load()

      require("blink.cmp").setup({
        snippets = { preset = "luasnip" },  -- use luasnip + friendly-snippets
        sources = {
          -- Order = priority. LSP first, then snippets, buffer words, paths.
          -- (blink's built-in provider id is "snippets", plural.)
          default = { "lsp", "snippets", "buffer", "path" },
        },
        appearance = { nerd_font_variant = "normal" },
        completion = {
          -- Documentation popup beside the menu, like VSCode.
          documentation = { auto_show = true, auto_show_delay_ms = 200 },
          ghost_text = { enabled = true },  -- inline preview of the selection
          menu = { auto_show = true },
        },
        signature = { enabled = true },     -- show signature help while typing
        keymap = {
          -- VSCode-ish: <C-space> summons, Tab/S-Tab cycle, <CR> accepts,
          -- <C-e> dismisses. Arrow-keys also navigate the menu.
          preset = "default",
          ["<C-space>"] = { "show", "show_documentation", "hide_documentation" },
          ["<CR>"] = { "accept", "fallback" },
          ["<Tab>"] = { "select_next", "snippet_forward", "fallback" },
          ["<S-Tab>"] = { "select_prev", "snippet_backward", "fallback" },
        },
      })

      --  9. FILE TREE — neo-tree (Ctrl+B)
      require("window-picker").setup()      -- used by neo-tree's "open in split"
      require("neo-tree").setup({
        close_if_last_window = true,        -- don't leave a lone tree open
        filesystem = {
          follow_current_file = { enabled = true },  -- reveal the active file
          use_libuv_file_watcher = true,    -- live-refresh on disk changes
          filtered_items = { hide_dotfiles = false, hide_gitignored = false },
        },
        window = { width = 32 },
      })

      --  10. FUZZY FINDER — telescope (+ native fzf sorter)
      local telescope = require("telescope")
      telescope.setup({
        defaults = {
          -- <C-/> in a picker shows that picker's own keymap cheatsheet.
          mappings = { i = { ["<C-h>"] = "which_key" } },
        },
      })
      telescope.load_extension("fzf")       -- enable the fast native sorter
      local tb = require("telescope.builtin")

      --  11. DIAGNOSTICS UI — signs, floats, and the Trouble panel
      vim.diagnostic.config({
        virtual_text = true,                -- inline messages at end of line
        severity_sort = true,
        float = { border = "rounded", source = true },
        signs = {
          text = {
            [vim.diagnostic.severity.ERROR] = "",
            [vim.diagnostic.severity.WARN]  = "",
            [vim.diagnostic.severity.INFO]  = "",
            [vim.diagnostic.severity.HINT]  = "",
          },
        },
      })
      require("trouble").setup()            -- the "Problems" panel
      require("fidget").setup()             -- LSP progress spinner (bottom-right)

      --  12. FORMAT-ON-SAVE — conform.nvim
      -- Each filetype maps to its formatter. The binaries come from
      -- extraPackages above, so this is fully reproducible.
      require("conform").setup({
        formatters_by_ft = {
          nix = { "nixfmt" },
          lua = { "stylua" },
          -- ruff does both: format the code, then sort imports.
          python = { "ruff_format", "ruff_organize_imports" },
          go = { "gofumpt" },
          rust = { "rustfmt" },
          c = { "clang_format" },
          cpp = { "clang_format" },
          sh = { "shfmt" },
          bash = { "shfmt" },
          toml = { "taplo" },
          json = { "prettierd" },
          yaml = { "prettierd" },
          markdown = { "prettierd" },
          javascript = { "prettierd" },
          typescript = { "prettierd" },
          javascriptreact = { "prettierd" },
          typescriptreact = { "prettierd" },
        },
        -- On save: try the dedicated formatter; if none applies, fall back to
        -- the LSP's own formatter. 500ms is plenty and won't hang a save.
        format_on_save = { timeout_ms = 500, lsp_format = "fallback" },
      })

      --  13. LSP — language servers + per-buffer keymaps
      -- blink.cmp advertises richer completion capabilities to each server.
      local caps = require("blink.cmp").get_lsp_capabilities()

      -- on_attach runs once per buffer when a server connects. This is where
      -- the "go to definition / hover / rename" keys get wired — buffer-local
      -- so they only exist where an LSP is actually attached.
      local function on_attach(_, bufnr)
        local function m(keys, fn, desc)
          map("n", keys, fn, { buffer = bufnr, desc = desc })
        end
        -- Navigation — telescope versions give you a fuzzy picker of results.
        m("gd", tb.lsp_definitions, "Goto definition")
        m("gD", vim.lsp.buf.declaration, "Goto declaration")
        m("gr", tb.lsp_references, "Goto references")
        m("gi", tb.lsp_implementations, "Goto implementation")
        m("gy", tb.lsp_type_definitions, "Goto type definition")
        -- Docs + signature.
        m("K", vim.lsp.buf.hover, "Hover docs")
        m("<C-k>", vim.lsp.buf.signature_help, "Signature help")
        -- Refactor.
        m("<F2>", vim.lsp.buf.rename, "Rename symbol")
        m("<leader>cr", vim.lsp.buf.rename, "Rename symbol")
        m("<leader>ca", vim.lsp.buf.code_action, "Code action")
        -- VSCode's Ctrl+. is code action; mapped below at the global level too.
        m("<C-.>", vim.lsp.buf.code_action, "Code action")
      end

      local lsp = require("lspconfig")

      -- Most servers are happy with just capabilities + on_attach.
      local servers = {
        "nixd", "lua_ls", "gopls", "rust_analyzer",
        "clangd", "bashls", "ts_ls", "jsonls", "taplo", "asm_lsp",
      }
      for _, s in ipairs(servers) do
        lsp[s].setup({ capabilities = caps, on_attach = on_attach })
      end

      -- Python is split across two servers on purpose:
      --   basedpyright → types, hover, goto (strict pyright superset)
      --   ruff         → fast lint + organize-imports
      -- We tell basedpyright to NOT sort imports so ruff owns that (no fight).
      lsp.basedpyright.setup({
        capabilities = caps,
        on_attach = on_attach,
        settings = {
          basedpyright = {
            disableOrganizeImports = true,
          },
        },
      })
      lsp.ruff.setup({ capabilities = caps, on_attach = on_attach })

      --  14. KEYMAPS — VSCode-familiar layer
      -- The philosophy: the chords you already have in muscle memory from
      -- VSCode are wired here, AND every one of them has a <leader> mirror so
      -- which-key can teach you the vim way over time. Nothing is unreachable.
      -- ⚠ Terminal caveat: a TTY can't always tell Ctrl+Shift+P from Ctrl+P,
      --   or deliver Ctrl+. / Ctrl+/ at all, unless the terminal sends CSI-u
      --   key encoding. WezTerm supports this — see docs/neovim-cheatsheet.md.
      --   That's why the <leader> fallbacks below exist: even with a "dumb"
      --   terminal, <leader>cp (palette), <leader>ca (action), <leader>/
      --   (comment) always work.

      -- ── Save (Ctrl+S) — works in normal, insert, and visual like VSCode
      map("n", "<C-s>", "<cmd>w<cr>", { desc = "Save" })
      map("i", "<C-s>", "<C-o><cmd>w<cr>", { desc = "Save (stay in insert)" })
      map("v", "<C-s>", "<cmd>w<cr>", { desc = "Save" })
      map("n", "<leader>w", "<cmd>w<cr>", { desc = "Save" })

      -- ── Find files (Ctrl+P)
      map({ "n", "i" }, "<C-p>", function() tb.find_files() end,
        { desc = "Find files" })

      -- ── Command palette (Ctrl+Shift+P) — needs CSI-u; leader fallback below
      map({ "n", "i" }, "<C-S-p>", function() tb.commands() end,
        { desc = "Command palette" })

      -- ── Search in files / live grep (Ctrl+Shift+F)
      map({ "n", "i" }, "<C-S-f>", function() tb.live_grep() end,
        { desc = "Search in files (grep)" })

      -- ── Toggle file tree (Ctrl+B)
      map({ "n", "i" }, "<C-b>", "<cmd>Neotree toggle<cr>",
        { desc = "Toggle file tree" })

      -- ── Toggle comment (Ctrl+/). Terminals often send Ctrl+_ (0x1F) for
      --    this chord, so map BOTH to be safe. Visual mode comments the block.
      map("n", "<C-_>", function()
        require("Comment.api").toggle.linewise.current()
      end, { desc = "Toggle comment" })
      map("n", "<C-/>", function()
        require("Comment.api").toggle.linewise.current()
      end, { desc = "Toggle comment" })
      map("x", "<C-_>", "<Plug>(comment_toggle_linewise_visual)",
        { desc = "Toggle comment" })
      map("x", "<C-/>", "<Plug>(comment_toggle_linewise_visual)",
        { desc = "Toggle comment" })

      -- ── Integrated terminal toggle (Ctrl+`)
      -- Opens a terminal in a bottom split; press again from terminal mode to
      -- get back to normal mode. <Esc> in the terminal also drops you out.
      map("n", "<C-`>", "<cmd>botright split | resize 14 | terminal<cr>",
        { desc = "Open terminal" })
      map("t", "<Esc>", [[<C-\><C-n>]], { desc = "Terminal → normal mode" })

      -- ── Diagnostics navigation
      -- nvim 0.12 deprecated goto_prev/goto_next in favour of jump({count=...}).
      -- count = 1 → next, count = -1 → previous. Using jump keeps the
      -- notification area clean (no deprecation toasts via nvim-notify).
      map("n", "[d", function() vim.diagnostic.jump({ count = -1 }) end,
        { desc = "Prev diagnostic" })
      map("n", "]d", function() vim.diagnostic.jump({ count = 1 }) end,
        { desc = "Next diagnostic" })
      map("n", "[e", function()
        vim.diagnostic.jump({ count = -1, severity = vim.diagnostic.severity.ERROR })
      end, { desc = "Prev ERROR" })
      map("n", "]e", function()
        vim.diagnostic.jump({ count = 1, severity = vim.diagnostic.severity.ERROR })
      end, { desc = "Next ERROR" })

      -- ── Buffer/tab navigation (Shift+H / Shift+L) + close (Ctrl+W)
      map("n", "<S-h>", "<cmd>BufferLineCyclePrev<cr>", { desc = "Prev buffer" })
      map("n", "<S-l>", "<cmd>BufferLineCycleNext<cr>", { desc = "Next buffer" })
      map("n", "<C-w>", "<cmd>bdelete<cr>", { desc = "Close buffer" })

      -- ── Clear search highlight with Esc
      map("n", "<Esc>", "<cmd>nohlsearch<cr>", { desc = "Clear highlight" })

      -- ── Manual format (in case you turned off format-on-save for a file)
      map({ "n", "v" }, "<leader>cf", function()
        require("conform").format({ async = true, lsp_format = "fallback" })
      end, { desc = "Format buffer" })

      --  15. WHICH-KEY — the discoverable <leader> menu (your safety net)
      -- Tap <Space>, wait half a second, and this popup lists everything.
      -- These leader mappings mirror the VSCode chords above so you can learn
      -- gradually — and they ALWAYS work, even on a terminal without CSI-u.
      local wk = require("which-key")
      wk.setup()
      wk.add({
        -- Group labels (the "+find", "+code"… headers in the popup).
        { "<leader>f", group = "find" },
        { "<leader>c", group = "code" },
        { "<leader>g", group = "git" },
        { "<leader>x", group = "trouble/diagnostics" },
        { "<leader>b", group = "buffer" },

        -- find
        { "<leader>ff", tb.find_files,  desc = "Files" },
        { "<leader>fg", tb.live_grep,   desc = "Grep (search in files)" },
        { "<leader>fb", tb.buffers,     desc = "Open buffers" },
        { "<leader>fr", tb.oldfiles,    desc = "Recent files" },
        { "<leader>fh", tb.help_tags,   desc = "Help tags" },
        { "<leader>fs", tb.lsp_document_symbols, desc = "Document symbols" },
        { "<leader>fd", tb.diagnostics, desc = "Diagnostics list" },
        { "<leader>fp", tb.commands,    desc = "Command palette" },

        -- code
        { "<leader>ca", vim.lsp.buf.code_action, desc = "Code action" },
        { "<leader>cd", vim.diagnostic.open_float, desc = "Line diagnostic" },
        -- (cr rename + cf format are wired per-buffer / globally above.)

        -- git (gitsigns)
        { "<leader>gb", function() require("gitsigns").blame_line() end, desc = "Blame line" },
        { "<leader>gp", function() require("gitsigns").preview_hunk() end, desc = "Preview hunk" },
        { "<leader>gs", function() require("gitsigns").stage_hunk() end, desc = "Stage hunk" },
        { "<leader>gr", function() require("gitsigns").reset_hunk() end, desc = "Reset hunk" },
        { "<leader>gd", function() require("gitsigns").diffthis() end, desc = "Diff this" },

        -- trouble / diagnostics
        { "<leader>xx", "<cmd>Trouble diagnostics toggle<cr>", desc = "Problems panel" },
        { "<leader>xd", "<cmd>Trouble diagnostics toggle filter.buf=0<cr>", desc = "Buffer diagnostics" },
        { "<leader>xX", "<cmd>Trouble diagnostics toggle<cr>", desc = "Workspace diagnostics" },
        { "<leader>xt", "<cmd>TodoTelescope<cr>", desc = "TODO list" },

        -- buffer
        { "<leader>bd", "<cmd>bdelete<cr>", desc = "Delete buffer" },
        { "<leader>bn", "<cmd>BufferLineCycleNext<cr>", desc = "Next buffer" },
        { "<leader>bp", "<cmd>BufferLineCyclePrev<cr>", desc = "Prev buffer" },
        { "<leader>bo", "<cmd>BufferLineCloseOthers<cr>", desc = "Close others" },

        -- top-level singles
        { "<leader>e", "<cmd>Neotree focus<cr>", desc = "Focus file tree" },
        { "<leader>q", "<cmd>confirm q<cr>", desc = "Quit" },
        { "<leader>/", function()
            require("Comment.api").toggle.linewise.current()
          end, desc = "Toggle comment" },
      })
    '';
  };
}
