{ config, lib, pkgs, modulesPath, inputs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/etcd.nix
    ../../modules/control-plane.nix
    ../../modules/worker-node.nix
  ];

  networking.hostName = "utm-nixos2"; # Define your hostname.

  etcd = {
    enable = true;
    selfIP = "10.211.55.10";
    privateSecretPath = "utm-nixos2/etcd";
    cluster = [
      { ip = "10.211.55.9"; hostname = "utm-nixos1"; }
      { ip = "10.211.55.10"; hostname = "utm-nixos2"; }
      { ip = "10.211.55.11"; hostname = "utm-nixos3"; }
    ];
  };

  controlPlane = {
    enable = true;
    selfIP = "10.211.55.10";
    etcdClientCert = "utm-nixos2/etcd/apiserverCert";
    apiserverKubeletClientCert = "utm-nixos2/kubernetes/apiserver/kubeletClientCert";
    apiserverServerCert = "utm-nixos2/kubernetes/apiserver/serverCert";
    controllerManagerCert = "utm-nixos2/kubernetes/controllerManagerCert";
    schedulerCert = "utm-nixos2/kubernetes/schedulerCert";
  };

  workerNode = {
    enable = true;
    selfIP = "10.211.55.11";
    kubeApiHostname = "10.211.55.10";
    kubeletCert = "utm-nixos2/kubernetes/kubeletCert";
    proxyCert = "utm-nixos2/kubernetes/proxyCert";
    flannelEtcdCert = "utm-nixos2/etcd/flannelCert";
    corednsCert = "utm-nixos2/kubernetes/corednsCert";
  };


  environment.systemPackages = with pkgs; [
    wget
    nano
    kubectl
  ];

  system.stateVersion = "23.11"; # Did you read the comment?
}

