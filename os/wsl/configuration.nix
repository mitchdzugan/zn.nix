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
    pkgs.fish
    pkgs.git
    pkgs.gh
    pkgs.neovim
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
}
