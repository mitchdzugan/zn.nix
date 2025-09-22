{ pkgs, lib, home-manager, ssbm, zkg, zkm, ztr, zn, ... }:

{
  system.stateVersion = "25.05";
  wsl.enable = true;
  wsl.defaultUser = "dz";

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  imports = [
    home-manager.nixosModules.default
  ];

  home-manager.users.dz = hm@{ pkgs, ... }: {
    home.stateVersion = "25.05";
    programs.fish = {
      enable = true;
      functions = {
        get_fish_pid = "echo $fish_pid";
        get_fish_pid_interactive = "echo $fish_pid_interactive";
        cdproj = "cd $(codeProject.py)";
        _zdev_is_active = ''
          if [ "$ZDEV_ACTIVE" != "1" ]
            return 1
          end
          set -l pidvar "ZDEV_PID_$ZDEV_ID"
          if [ "$$pidvar" != "$fish_pid_interactive" ]
            return 1
          end
        '';
        _tide_item_znix = ''
          if set -q IN_NIX_SHELL
            set -l depth "?"
            set -l label $IN_NIX_SHELL
            if _zdev_is_active
              set depth $ZDEV_DEPTH
              set label $ZDEV_LABEL
            end
            set label (set_color $tide_znix_color_bright && echo $label)
            set -l full $label
            if [ "$depth" != "1" ]
              set -l sep (set_color $tide_znix_color && echo ":")
              set depth (set_color $tide_znix_color_bright && echo $depth)
              set full $label$sep$depth
            end
            _tide_print_item znix "$tide_znix_icon $full"
          end
        '';
        _tide_item_rich_status = ''
          if string match -qv 0 $_tide_pipestatus # If there is a failure anywhere in the pipestatus
            fish_status_to_signal $_tide_pipestatus | string replace SIG "" | string join '|' | read -l out
            test $_tide_status = 0 && _tide_print_item rich_status $tide_rich_status_icon' ' $out ||
              tide_rich_status_bg_color=$tide_rich_status_bg_color_failure tide_rich_status_color=$tide_rich_status_color_failure \
                _tide_print_item rich_status $tide_rich_status_icon_failure' ' $out
          else if not contains zpb $_tide_left_items
            _tide_print_item rich_status $tide_rich_status_icon
          end
        '';
        _tide_item_rich_character = ''
          test $_tide_status = 0 \
            && set -fx tide_rich_character_bg_color $tide_rich_character_bg0 \
            || set -fx tide_rich_character_bg_color $tide_rich_character_bgX
          test $_tide_status = 0 \
            && set -fx tide_rich_character_color $tide_rich_character_color0 \
            || set -fx tide_rich_character_color $tide_rich_character_colorX

          _tide_print_item rich_character $tide_rich_character_char
        '';
        _tide_item_zvi_mode = ''
          _tide_item_vi_mode
        '';
        _tide_item_zpb = ''
          set -gx tide_left_prompt_separator_diff_color "🭎"
          _tide_item_rich_character
        '';
        _tide_item_zpp = ''
          set -gx tide_left_prompt_separator_diff_color "🭪"
          _tide_item_rich_character
        '';
        _tide_item_zpe = ''
          set -l prev_sep $tide_right_prompt_separator_diff_color
          set -gx tide_right_prompt_separator_diff_color "🮍"
          _tide_item_rich_character
          set -gx tide_right_prompt_separator_diff_color $prev_sep
        '';
        _tide_item_zpwd = ''
          set -gx tide_left_prompt_separator_diff_color "🬾"
          _tide_item_pwd
        '';
        _tide_item_rich_context = ''
          set -l ctxt_icon ""
          if set -q SSH_TTY
            set -fx tide_rich_context_color $tide_rich_context_color_ssh
            set ctxt_icon "󰌘"
          else if test "$EUID" = 0
            set -fx tide_rich_context_color $tide_rich_context_color_root
            set ctxt_icon "󰞀"
          else if test "$tide_rich_context_always_display" = true
            set -fx tide_rich_context_color $tide_rich_context_color_default
            set ctxt_icon "󰍹"
          else
            return
          end

          string match -qr "^(?<h>(\.?[^\.]*){0,$tide_context_hostname_parts})" $hostname
          set -l fullstr "$ctxt_icon $(\
            set_color $tide_rich_context_color_user && echo $USER)$(\
            set_color $tide_rich_context_color && echo @)$(\
            set_color $tide_rich_context_color_host && echo $h)"
          _tide_print_item rich_context $fullstr
        '';
      };
      interactiveShellInit = builtins.readFile (
        ./domain/fish/interactiveShellInit.fish
      );
      plugins = with pkgs.fishPlugins; [
        { name = "z"; src = z.src; }
        { name = "grc"; src = grc.src; }
        { name = "fzf"; src = fzf.src; }
        { name = "tide"; src = tide.src; }
        { name = "done"; src = done.src; }
        { name = "bass"; src = bass.src; }
        { name = "gruvbox"; src = gruvbox.src; }
        { name = "autopair"; src = autopair.src; }
      ];
    };
    programs.neovim = import ./domain/nvim/config.nix { lib = lib; pkgs = pkgs; };
    programs.kitty = {
      enable = true;
      shellIntegration = {
        enableFishIntegration = true;
      };
      settings = {
        shell = "fish";
        confirm_os_window_close = -1;
        cursor_trail = 1;
        cursor_blink_interval = "1.0 ease-in";
        dynamic_background_opacity = "yes";
        background_opacity = 0.9;
        transparent_background_colors = lib.concatStrings [
          "#604b49@0.9 "
          "#605955@0.9 "
          "#385167@0.9 "
          "#4b4e6c@0.9 "
          "#11111b@0.8 "
          "#6c7086@0.8 "
          # "#181825@0.8 "
          "#1e1e2e@0.9"
        ];
      };
      themeFile = "purpurite";
    };
  };

  environment.systemPackages = [
    pkgs.bat
    pkgs.emacs
    pkgs.fastfetch
    pkgs.firefox
    pkgs.git
    pkgs.gh
    pkgs.wget
    ssbm.packages.${pkgs.hostPlatform.system}.slippi-launcher
    ssbm.packages.${pkgs.hostPlatform.system}.slippi-netplay
    ssbm.packages.${pkgs.hostPlatform.system}.slippi-playback
    zn.nixRebuild
    zn.rep
    zn.reply
    zn.uu
    # zn.wait-for
    zn.zflake
    zkg.packages.${pkgs.hostPlatform.system}.zkg
    # zkm.packages.${pkgs.hostPlatform.system}.zkm
    ztr.packages.${pkgs.hostPlatform.system}.ztr
  ];

  fonts.packages = with pkgs; [
    dina-font
    fira-code
    fira-code-symbols
    font-awesome
    liberation_ttf
    monaspace
    mplus-outline-fonts.githubRelease
    nerd-fonts.comic-shanns-mono
    nerd-fonts.daddy-time-mono
    nerd-fonts.go-mono
    nerd-fonts.heavy-data
    nerd-fonts.monaspace
    nerd-fonts.open-dyslexic
    nerd-fonts.proggy-clean-tt
    nerd-fonts.recursive-mono
    nerd-fonts.sauce-code-pro
    nerd-fonts.space-mono
    nerd-fonts.symbols-only
    nerd-fonts.terminess-ttf
    nerd-fonts.ubuntu-sans
    noto-fonts-cjk-sans
    noto-fonts-emoji
    powerline-fonts
    powerline-symbols
    proggyfonts
    ubuntu_font_family
  ];
  fonts.enableDefaultPackages = true;
  fonts.fontconfig = {
    defaultFonts = {
      serif = [  "Liberation Serif" ];
      sansSerif = [ "Ubuntu" ];
      monospace = [ "MonaspiceKr Nerd Font Mono" ];
    };
  };
}
