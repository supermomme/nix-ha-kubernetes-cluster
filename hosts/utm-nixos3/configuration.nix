{ config, lib, pkgs, modulesPath, inputs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/etcd.nix
    ../../modules/worker-node.nix
  ];

  networking.hostName = "utm-nixos3"; # Define your hostname.

  etcd = {
    enable = true;
    selfIP = "10.211.55.11";
    privateSecretPath = "utm-nixos3/etcd";
    cluster = [
      { ip = "10.211.55.9"; hostname = "utm-nixos1"; }
      { ip = "10.211.55.10"; hostname = "utm-nixos2"; }
      { ip = "10.211.55.11"; hostname = "utm-nixos3"; }
    ];
  };

  workerNode = {
    enable = true;
    selfIP = "10.211.55.11";
    kubeApiHostname = "10.211.55.9";
  };

  environment.systemPackages = with pkgs; [
    wget
    nano
  ];

  system.stateVersion = "23.11"; # Did you read the comment?
}

