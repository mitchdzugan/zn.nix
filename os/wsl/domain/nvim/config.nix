{ lib, pkgs, ... }:

{
  enable = true;
  defaultEditor = true;
  viAlias = true;
  vimAlias = true;
  vimdiffAlias = true;
  withNodeJs = true;
  withPython3 = true;
  withRuby = true;
  extraConfig = builtins.readFile ./init.vim;
  extraLuaConfig = ''require("dz.init")'';
  plugins = let
    markdownWithQueries = pkgs.vimPlugins.nvim-treesitter-parsers.markdown.overrideAttrs { installQueries = true; };
    /* orgWithQueries = pkgs.vimPlugins.nvim-treesitter-parsers.org.overrideAttrs { installQueries = true; }; */
    nvim-treesitter-with-plugins = pkgs.vimPlugins.nvim-treesitter.withPlugins (treesitter-plugins:
      with treesitter-plugins; [
        bash
        c
        clojure
        cmake
        cpp
        css
        csv
        dhall
        dockerfile
        elixir
        erlang
        fennel
        gitignore
        graphql
        haskell
        html
        ini
        javascript
        json
        latex
        lua
        luadoc
        make
        markdownWithQueries
        markdown_inline
        menhir
        nix
        ocaml
        ocaml_interface
        ocamllex
        /* orgWithQueries */
        purescript
        python
        rasi
        regex
        ruby
        rust
        scala
        scss
        sql
        toml
        typescript
        vim
        xml
        yaml
      ]);
    fromGitHub = repo: ref: rev: pkgs.vimUtils.buildVimPlugin {
      pname = "${lib.strings.sanitizeDerivationName repo}";
      version = ref;
      src = builtins.fetchGit {
        url = "https://github.com/${repo}.git";
        ref = ref;
        rev = rev;
      };
    };
  in
    with pkgs.vimPlugins; [
      aurora
      aylin-vim
      catppuccin-nvim
      cmp-nvim-lsp
      cmp-buffer
      cmp-conjure
      cmp-path
      cmp-cmdline
      cmp-vsnip
      conjure
      dracula-nvim
      gitsigns-nvim
      guess-indent-nvim
      image-nvim
      indent-blankline-nvim
      kanagawa-nvim
      lualine-lsp-progress
      lualine-nvim
      lspkind-nvim
      lsp_lines-nvim
      mini-icons
      neoscroll-nvim
      netrw-nvim
      nui-nvim
      nvim-autopairs
      nvim-cmp
      nvim-cursorline
      nvim-lspconfig
      nvim-navic
      nvim-paredit
      nvim-tree-lua
      nvim-treesitter-with-plugins
      nvim-web-devicons
      oxocarbon-nvim
      plenary-nvim
      render-markdown-nvim
      rose-pine
      rainbow-delimiters-nvim
      tabby-nvim
      telescope-nvim
      venn-nvim
      vim-dispatch
      vim-jack-in
      vim-vsnip
      which-key-nvim
      (fromGitHub
        "mcauley-penney/tidy.nvim"
        "HEAD"
        "f6c9cfc9ac5a92bb5ba3c354bc2c09a7ffa966f2"
        )
      (fromGitHub
        "Jxstxs/conceal.nvim"
        "HEAD"
        "1aff9fc5d1157aef1c7c88b6df6d6db21268d00a"
        )
      (fromGitHub
        "tiagovla/tokyodark.nvim"
        "HEAD"
        "14bc1b3e596878a10647af7c82de7736300f3322"
        )
      (fromGitHub
        "bluz71/vim-moonfly-colors"
        "HEAD"
        "63f20d657c9fd46ecdd75bd45c321f74ef9b11fe"
        )
      (fromGitHub
        "dgox16/oldworld.nvim"
        "HEAD"
        "1b8e1b2052b5591386187206a9afbe9e7fdbb35f"
        )
      (fromGitHub
        "fynnfluegge/monet.nvim"
        "HEAD"
        "af6c8fb9faaae2fa7aa16dd83b1b425c2b372891"
        )
      (fromGitHub
        "maxmx03/fluoromachine.nvim"
        "HEAD"
        "d638ea221b4c6636978f49c1987d10ff2733c23d"
        )
      (fromGitHub
       "Dan7h3x/signup.nvim"
        "HEAD"
        "2b21a2aa51efbdeb9454a3f5d62659368d87d420"
        )
      /*
      (fromGitHub
        "drybalka/tree-climber.nvim"
        "HEAD"
        "9b0c8c8358f575f924008945c74fd4f40d814cd7"
        )
      */
      (fromGitHub
        "shellRaining/hlchunk.nvim"
        "HEAD"
        "5465dd33ade8676d63f6e8493252283060cd72ca"
        )
    ];
}
