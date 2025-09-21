# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

# NixOS-WSL specific options are documented on the NixOS-WSL repository:
# https://github.com/nix-community/NixOS-WSL

{ config, lib, pkgs, ... }:

{
  system.stateVersion = "25.05"; # Did you read the comment?
  wsl.enable = true;
  wsl.defaultUser = "dz";

  environment.systemPackages = [
    pkgs.emacs
    pkgs.firefox
    pkgs.git
    pkgs.gh
    pkgs.neovim
    pkgs.wget
  ];
}
