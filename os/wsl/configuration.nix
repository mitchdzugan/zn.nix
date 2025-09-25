{ pkgs, lib, nixgl, home-manager, ssbm, zkg, zkm, ztr, zn, ... }:

let
  mk_xmolib = haskellPackages: haskellPackages.mkDerivation {
    pname = "xmolib";
    version = "0.0.1";
    src = ./domain/xmolib;
    libraryHaskellDepends = with haskellPackages; [
      base prettyprinter prettyprinter-ansi-terminal process text
      transformers transformers-compat
      aeson xmonad xmonad-contrib xmonad-dbus xmonad-extras
    ];
    license = lib.licenses.bsd3;
  };
in {
  system.stateVersion = "25.05";
  wsl.enable = true;
  wsl.defaultUser = "dz";

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  imports = [
    home-manager.nixosModules.default
  ];

  hardware.graphics = {
    enable = true;
    extraPackages = [pkgs.mesa];
    enable32Bit = true;
  };

  services.xrdp.enable = true;
  services.xrdp.defaultWindowManager = "bspwm";
  services.xrdp.openFirewall = true;

  home-manager.users.dz = hm@{ pkgs, config, ... }: {
    home.stateVersion = "25.05";
    home.sessionPath = [
      "/home/dz/Projects/dz-bin"
      "/home/dz/Projects/dz-bspwm/bin"
    ];

    nixGL.packages = nixgl.packages;

    xdg.configFile = {
      "blesh" = {
        source = hm.config.lib.file.mkOutOfStoreSymlink ./domain/bash/blesh;
        recursive = true;
      };
      "fastfetch" = {
        source = hm.config.lib.file.mkOutOfStoreSymlink ./domain/fastfetch;
        recursive = true;
      };
      "nvim/lua" = {
        source = hm.config.lib.file.mkOutOfStoreSymlink ./domain/nvim/lua;
        recursive = true;
      };
      "nvim/filetype.vim" = {
        source = hm.config.lib.file.mkOutOfStoreSymlink ./domain/nvim/filetype.vim;
        recursive = true;
      };
      "xmonad/xmonad.hs" = {
        source = pkgs.writeText "xmonad.hs" ''
          import qualified Xmolib.Entry.Xmonad as Xmolib
          main :: IO ()
          main = Xmolib.runXmonad
        '';
        recursive = false;
      };
      "xonsh/rc.d" = {
        source = hm.config.lib.file.mkOutOfStoreSymlink ./domain/xonsh/rc.d;
        recursive = true;
      };
    };

    programs.bash.enable = true;
    programs.bash.enableVteIntegration = true;
    programs.bash.profileExtra = ''
      eval $(ssh-agent) &> /dev/null
      ssh-add ~/.ssh/bitbucket_work &> /dev/null
    '';

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
    programs.firefox = {
      enable = true;
      package = config.lib.nixGL.wrap pkgs.firefox;
      policies = {
        Preferences = {
          "toolkit.legacyUserProfileCustomizations.stylesheets" = { Value = true; Status = "locked"; };
          "layout.css.devPixelsPerPx" = { Value = "1.0"; Status = "locked"; };
        };
      };
      profiles = {
        default = {
          id = 0;
          name = "default";
          isDefault = true;
          settings = {
            "browser.tabs.inTitlebar" = 0;
            "full-screen-api.ignore-widgets" = true;
            "full-screen-api.exit-on.windowRaise" = false;
            /*
            "extensions.activeThemeId" = with config.nur.repos.rycee;
              firefox-addons.dracula-dark-colorscheme.addonId;
            */
          };
          userChrome = builtins.readFile ./domain/firefox/userChrome.css;
          /*
          extensions = with nixospkgs.nur.repos.rycee.firefox-addons; [
            dracula-dark-colorscheme
            ublock-origin
            video-downloadhelper
          ];
          */
        };
        streaming = {
          id = 1;
          name = "streaming";
          isDefault = false;
          settings = {
            "browser.tabs.inTitlebar" = 0;
            "full-screen-api.ignore-widgets" = true;
            "full-screen-api.exit-on.windowRaise" = false;
            /*
            "extensions.activeThemeId" = with config.nur.repos.rycee;
              firefox-addons.dracula-dark-colorscheme.addonId;
            */
          };
          userChrome = builtins.readFile ./domain/firefox/userChrome.css;
          /*
          extensions = with nixospkgs.nur.repos.rycee.firefox-addons; [
            dracula-dark-colorscheme
            i-auto-fullscreen
            ublock-origin
            video-downloadhelper
          ];
          */
        };
      };
    };
    programs.kitty = {
      enable = true;
      package = config.lib.nixGL.wrap pkgs.kitty;
      shellIntegration = {
        enableFishIntegration = true;
      };
      settings = {
        shell = "bash --login -c 'fish'";
        confirm_os_window_close = -1;
        cursor_trail = 1;
        cursor_blink_interval = "1.0 ease-in";
        dynamic_background_opacity = "yes";
        background_opacity = 0.9;
        linux_display_server = "x11";
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
    programs.tmux = {
      enable = true;
      clock24 = true;
      mouse = true;
      escapeTime = 0;
      keyMode = "vi";
      plugins = with pkgs.tmuxPlugins; [
        {
          plugin = rose-pine;
          extraConfig = ''
            set -g @rose_pine_variant 'main'
          '';
        }
      ];

      extraConfig = ''
        set -g allow-passthrough on
        set -g default-shell ${pkgs.fish}/bin/fish
      '';
    };

    # autorandr -c
    # blueman-applet &
    # nm-applet &
    # xset s off -dpms
    # systemctl --user start redshift
    xsession.windowManager.bspwm = {
      enable = true;
      extraConfigEarly = ''
        sxhkd &
        xsetroot -cursor_name left_ptr
        systemctl --user start picom
        systemctl --user start polybar
        systemctl --user start bspwm-polybar
        nitrogen --restore
      '';
      extraConfig = ''
        bspwm-reset-monitors.js
      '';
      rules = {
        float_kitty = {
          rectangle="960x540+480+254";
          state = "floating";
        };
        ztr = {
          border = false;
          focus = false;
          state = "floating";
          center = true;
        };
        Ztr = {
          border = false;
          focus = false;
          state = "floating";
          center = true;
        };
      };
      settings = {
        focus_follows_pointer = true;
        pointer_follows_focus = true;
        pointer_follows_monitor = true;
        border_width = 2;
        normal_border_color  = "#646464";
        active_border_color  = "#645276";
        focused_border_color = "#a487c7";
      };
    };

    services = {
      autorandr.enable = true;
      dunst = {
        enable = true;
        iconTheme.package = pkgs.dracula-icon-theme;
        iconTheme.name = "Dracula";
        settings = {
          global = {
            transparency = 10;
            corner_radius = 13;
            background = "#1E1F29";
          };
        };
      };
      cliphist = { enable = true; };
      sxhkd = {
        enable = true;
        keybindings = {
          "alt + shift + q" = "bspc quit";
          "alt + q" = "bspc node --close";
          "alt + space" = "home.zkm";
          "alt + slash" = "openApp";
          "alt + Return" = "kitty";
          "alt + w" = "firefox";
          "alt + e" = "thunar";
          "alt + grave" = "bspwm-cycle-monitor-focus.js";
          "alt + {t,shift + t,f,m}" = "bspc node -t {tiled,pseudo_tiled,floating,fullscreen}";
          "alt + {1-9,0,equal}" = "bspwm-focus-desktop.js {1-9,10,f}";
          "alt + shift + {1-9,0,plus}" = "bspwm-move-to-desktop.js -d {1-9,10,f}";
          "alt + {Left,Right,Up,Down}" = "bspc node -f {west,east,north,south}";
          "alt + ctrl + Left" = "bspc node -z left -10 0 || bspc node -z right -10 0";
          "alt + ctrl + Right" = "bspc node -z left 10 0 || bspc node -z right 10 0";
          "alt + ctrl + Up" = "bspc node -z top 0 -10 || bspc node -z bottom 0 -10";
          "alt + ctrl + Down" = "bspc node -z top 0 10 || bspc node -z bottom 0 10";
          "XF86MonBrightnessUp" = "brightnessUp";
          "XF86MonBrightnessDown" = "brightnessDown";
          "XF86AudioRaiseVolume" = "volumeUp";
          "XF86AudioLowerVolume" = "volumeDown";
          "XF86AudioMute" = "volumeToggleMute";
          "shift + XF86AudioRaiseVolume" = "next.py";
          "shift + XF86AudioLowerVolume" = "prev.py";
          "shift + XF86AudioMute" = "pause.py";
          "XF86AudioPlay" = "pause.py";
          "XF86AudioNext" = "next.py";
          "XF86AudioPrev" = "prev.py";
          "Print" = "ss_dir_scrot";
          "ctrl + Print" = "ss_dir_scrot --select";
          "shift + Print" = "ss_dir_scrot -u";
        };
      };
      polybar =
        let
          polybar_cava = pkgs.writeShellApplication {
            name = "polybar_cava";
            runtimeInputs = [ pkgs.coreutils pkgs.cava pkgs.gnused ];
            text = builtins.readFile ./domain/polybar/cava.sh;
          };
          extraBinPath = lib.makeBinPath [
            pkgs.coreutils
            pkgs.systemd
            pkgs.which
            pkgs.bspwm
            pkgs.nodejs
            /* pkgs.pamixer */
            pkgs.pulseaudio
            polybar_cava
          ];
        in {
          enable = true;
          package = (pkgs.polybar.override {
            alsaSupport = true;
            iwSupport = true;
            githubSupport = true;
            pulseSupport = true;
            mpdSupport = true;
          });
          config = ./domain/polybar/config.ini;
          script = ''
            export PATH=$PATH:/home/dz/Projects/dz-bspwm/bin:${extraBinPath}

            for m in $(polybar --list-monitors | cut -d":" -f1); do
              MONITOR=$m polybar --reload example &
            done
          '';
        };

      redshift = {
        # enable = true;
        tray = true;
        latitude = 41.86;
        longitude = -88.12;
      };

      picom = {
        enable = true;
        package = pkgs.picom;
        backend = "glx";
        vSync = true;
        # extraArgs = ["--config" "/home/dz/.config/picom/final.conf"];
        settings = {
          shadow = true;
          shadow-radius = 50;
          shadow-opacity = 0.35;
          shadow-offset-x = -49;
          shadow-offset-y = -47;
          shadow-color = "#00020b";
          frame-opacity = 0.95;
          frame-opacity-for-same-colors = true;
          inner-border-width = 1;
          corner-radius = 13;
          blur-method = "dual_kawase";
          blur-strength = 10;
          blur-background = true;
          blur-background-frame = true;
          dithered-present = false;
          detect-client-opacity = true;
          detect-transient = true;
          detect-client-leader = true;
          glx-no-stencil = true;
          glx-no-rebind-pixmap = true;
          use-damage = true;
          xrender-sync-fence = true;
        };
      };
    };
  };

  programs.nix-ld.enable = true;
  environment.systemPackages = [
    pkgs.bat
    pkgs.fzf
    pkgs.fastfetch
    pkgs.git
    pkgs.grc
    pkgs.wget
    pkgs.emacs
    pkgs.gh
    pkgs.nitrogen
    pkgs.xorg.xorgserver
    pkgs.xorg.xset
    pkgs.xorg.xsetroot
    pkgs.dotnet-sdk_9
    pkgs.nodePackages.nodejs
    (pkgs.python3.withPackages (python-pkgs: [
      python-pkgs.beautifulsoup4
      # python-pkgs.coconut
      python-pkgs.dmenu-python
      python-pkgs.mpd2
      python-pkgs.requests
      python-pkgs.xlib
      python-pkgs.pip
    ]))
    pkgs.typescript
    pkgs.typescript-language-server
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
    zkm.packages.${pkgs.hostPlatform.system}.zkm
    ztr.packages.${pkgs.hostPlatform.system}.ztr
    ### xmonad stuff
    (pkgs.stdenv.mkDerivation {
      pname = "xmoctrl";
      version = "0.0.1";

      src = lib.cleanSourceWith {
        filter = name: type: false;
        src = lib.cleanSource ./.;
      };

      buildInputs = [
        pkgs.xmonadctl
        (pkgs.haskellPackages.ghcWithPackages (
          haskellPackages: [(mk_xmolib haskellPackages)]
        ))
      ];
      propagatedBuildInputs = [ pkgs.xmonadctl ];

      dontConfigure = true;
      buildPhase = ''
        echo -e \
          "\nimport qualified Xmolib.Entry.Xmoctrl as Xmolib"\
          "\nmain :: IO ()"\
          "\nmain = Xmolib.runXmoctrl" > xmoctrl.hs
        ghc xmoctrl.hs
      '';
      installPhase = ''
        mkdir -p $out/bin
        cp xmoctrl $out/bin/xmoctrl
      '';

      meta = {
        description = "command runner built on top of xmonadctl";
        homepage = "https://github.com/mitchdzugan/dz-nixos";
        license = lib.licenses.mit;
        maintainers = with lib.maintainers; [ mitchdzugan ];
        platforms = lib.platforms.linux;
      };
    })
    pkgs.xmonadctl
  ];

  services.xserver.enable = true;
  services.xserver.displayManager.sddm.enable = true;
  services.xserver.windowManager.bspwm.enable = true;
  services.xserver.windowManager.xmonad = {
    enable = true;
    enableContribAndExtras = true;
    extraPackages = haskellPackages: [
      haskellPackages.dbus
      haskellPackages.List
      haskellPackages.monad-logger
      (mk_xmolib haskellPackages)
    ];
  };

  systemd.user.services.picom.wantedBy = [];
  systemd.user.services.polybar.wantedBy = [];
  systemd.user.services.redshift.wantedBy = [];
  systemd.user.services.bspwm-polybar = {
    enable = true;
    description = "control dzbspwm polybar module";
    serviceConfig = {
      Type = "exec";
      ExecStart = "/home/dz/Projects/dz-bin/bspwm-polybar-watch";
      Restart = "on-failure";
      Environment="PATH=$PATH:${lib.makeBinPath [ pkgs.coreutils pkgs.bash pkgs.which pkgs.ps pkgs.nodejs pkgs.bspwm pkgs.polybar ]}:/home/dz/Projects/dz-bin:/home/dz/Projects/dz-bspwm/bin";
    };
    wantedBy = [];
  };
  programs.dconf.enable = true;

  environment.sessionVariables= {
    QT_QPA_PLATFORM = "xcb";
    MOZ_ENABLE_WAYLAND = "0";
    DISABLE_WAYLAND = "1";
  };

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
