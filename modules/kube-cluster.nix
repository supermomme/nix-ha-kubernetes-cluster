{ lib, config, pkgs, ... }:
let
  cfg = config.kubeCluster;
  inherit (pkgs.callPackage ../kube-resources.nix { }) clusterNodes;
in
{
  options.kubeCluster = with lib; {
    enable = mkEnableOption "enable kubeCluster module";
    hostname = mkOption {
      type = types.str;
      default = config.networking.hostName;
    };
    selfIP = mkOption {
      type = types.str;
      default = (lib.findFirst (c: c.hostname == cfg.hostname) {ip = "127.0.0.1";} cfg.cluster).ip;
    };
    cluster = mkOption {
      type = types.listOf types.attrs;
      default = clusterNodes;
      description = "all cluster resources from kube-resources.nix";
    };
  };
  imports = [
    ./etcd.nix
    ./apiserver.nix
    ./controllerManager.nix
    ./scheduler.nix
    ./worker-node.nix
  ];
  config = lib.mkIf cfg.enable {
    etcd = {
      enable = (lib.findFirst (c: c.hostname == cfg.hostname) {etcd = false;} cfg.cluster).etcd or false;
      selfIP = cfg.selfIP;
      cluster = (builtins.filter (c: c.etcd or false) cfg.cluster);
      serverCert = "${cfg.hostname}/etcd/serverCert";
      peerCert = "${cfg.hostname}/etcd/peerCert";
    };
    
    apiserver = {
      enable =
        (lib.findFirst (c: c.hostname == cfg.hostname) { controlPlane = false; } cfg.cluster).controlPlane or false ||
        (lib.findFirst (c: c.hostname == cfg.hostname) { apiserver = false; } cfg.cluster).apiserver or false;
      selfIP = cfg.selfIP;
      etcdClientCert = "${cfg.hostname}/etcd/apiserverCert";
      apiserverKubeletClientCert = "${cfg.hostname}/kubernetes/apiserver/kubeletClientCert";
      apiserverServerCert = "${cfg.hostname}/kubernetes/apiserver/serverCert";
    };

    controllerManager = {
      enable =
        (lib.findFirst (c: c.hostname == cfg.hostname) { controlPlane = false; } cfg.cluster).controlPlane or false ||
        (lib.findFirst (c: c.hostname == cfg.hostname) { controllerManager = false; } cfg.cluster).controllerManager or false;
      kubeApiHostname = (lib.findFirst (c: (c.controlPlane or false) || (c.apiserver or false)) { ip = "127.0.0.1"; } cfg.cluster).ip; # TODO: loadbalancer
      controllerManagerCert = "${cfg.hostname}/kubernetes/controllerManagerCert";
    };

    scheduler = {
      enable =
        (lib.findFirst (c: c.hostname == cfg.hostname) { controlPlane = false; } cfg.cluster).controlPlane or false ||
        (lib.findFirst (c: c.hostname == cfg.hostname) { scheduler = false; } cfg.cluster).scheduler or false;
      kubeApiHostname = (lib.findFirst (c: (c.controlPlane or false) || (c.apiserver or false)) { ip = "127.0.0.1"; } cfg.cluster).ip; # TODO: loadbalancer
      schedulerCert = "${cfg.hostname}/kubernetes/schedulerCert";
    };

    workerNode = {
      enable = (lib.findFirst (c: c.hostname == cfg.hostname) {workerNode = false;} cfg.cluster).workerNode or false;
      selfIP = cfg.selfIP;
      kubeApiHostname = (lib.findFirst (c: (c.controlPlane or false) || (c.apiserver or false)) { ip = "127.0.0.1"; } cfg.cluster).ip; # TODO: loadbalancer
      kubeletCert = "${cfg.hostname}/kubernetes/kubeletCert";
      proxyCert = "${cfg.hostname}/kubernetes/proxyCert";
      flannelEtcdCert = "${cfg.hostname}/etcd/flannelCert";
      corednsCert = "${cfg.hostname}/kubernetes/corednsCert";
    };
  };
}
