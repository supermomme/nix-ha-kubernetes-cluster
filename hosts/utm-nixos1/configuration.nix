{ config, lib, pkgs, modulesPath, inputs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/etcd.nix
    ../../modules/control-plane.nix
  ];

  networking.hostName = "utm-nixos1"; # Define your hostname.

  etcd = {
    enable = true;
    selfIP = "10.211.55.9";
    privateSecretPath = "utm-nixos1/etcd";
    cluster = [
      { ip = "10.211.55.9"; hostname = "utm-nixos1"; }
      { ip = "10.211.55.10"; hostname = "utm-nixos2"; }
      { ip = "10.211.55.11"; hostname = "utm-nixos3"; }
    ];
  };

  controlPlane = {
    enable = true;
    selfIP = "10.211.55.9";
    etcdClientCert = "utm-nixos1/etcd/apiserverCert";
    apiserverKubeletClientCert = "utm-nixos1/kubernetes/apiserver/kubeletClientCert";
    apiserverServerCert = "utm-nixos1/kubernetes/apiserver/serverCert";
    controllerManagerCert = "utm-nixos1/kubernetes/controllerManagerCert";
    schedulerCert = "utm-nixos1/kubernetes/schedulerCert";
  };

  environment.systemPackages = with pkgs; [
    wget
    nano
  ];

  system.stateVersion = "23.11"; # Never ever change this!
}

