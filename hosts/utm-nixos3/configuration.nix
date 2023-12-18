{ config, lib, pkgs, modulesPath, inputs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/kube-cluster.nix
  ];

  networking.hostName = "utm-nixos3"; # Define your hostname.

  kubeCluster = {
    enable = true;
  };

  environment.systemPackages = with pkgs; [
    wget
    nano
  ];

  system.stateVersion = "23.11"; # Did you read the comment?
}

