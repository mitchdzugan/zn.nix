{ pkgs, ssbm, zkg, zkm, ztr, zn, ... }:

{
  system.stateVersion = "25.05";
  wsl.enable = true;
  wsl.defaultUser = "dz";

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

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
    zkm.packages.${pkgs.hostPlatform.system}.zkm
    ztr.packages.${pkgs.hostPlatform.system}.ztr
  ];
}
