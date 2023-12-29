{ config, pkgs, lib, ... }:
# { config, pkgs ? import <nixpkgs> {}, lib ? pkgs.lib }:
let
  cfg = config.etcd;
in
{
  options.etcd = with lib; {
    enable = mkEnableOption "enable etcd module";
    selfIP = mkOption {
      type = types.str;
      description = "IP of node";
    };
    etcdCa = mkOption {
      type = types.str;
      default = "etcd/ca";
    };
    serverCert = mkOption {
      type = types.str;
      default = "etcd/serverCert";
    };
    peerCert = mkOption {
      type = types.str;
      default = "etcd/peerCert";
    };
    cluster = mkOption {
      type = types.listOf types.attrs;
      description = "list like [{ hostname: \"foo\"; ip: \"123.123.123.123\"}]";
    };

  };
  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      etcd
    ];

    sops.secrets."${cfg.etcdCa}/cert" = { owner = "etcd"; };
    sops.secrets."${cfg.serverCert}/cert" = { owner = "etcd"; };
    sops.secrets."${cfg.serverCert}/key" = { owner = "etcd"; };
    sops.secrets."${cfg.peerCert}/cert" = { owner = "etcd"; };
    sops.secrets."${cfg.peerCert}/key" = { owner = "etcd"; };

    services.etcd = {
      enable = true;
      name = config.networking.hostName;

      advertiseClientUrls = [ "https://${cfg.selfIP}:2379" ];
      initialAdvertisePeerUrls = [ "https://${cfg.selfIP}:2380" ];
      initialCluster = lib.concatMap (node: ["${node.hostname}=https://${node.ip}:2380"]) cfg.cluster;
      initialClusterState = "new";
      listenClientUrls = [ "https://${cfg.selfIP}:2379" "https://127.0.0.1:2379" ];
      listenPeerUrls = [ "https://${cfg.selfIP}:2380" ];

      clientCertAuth = true;
      peerClientCertAuth = true;

      certFile = config.sops.secrets."${cfg.serverCert}/cert".path;
      keyFile = config.sops.secrets."${cfg.serverCert}/key".path;

      peerCertFile = config.sops.secrets."${cfg.peerCert}/cert".path;
      peerKeyFile = config.sops.secrets."${cfg.peerCert}/key".path;

      peerTrustedCaFile = config.sops.secrets."${cfg.etcdCa}/cert".path;
      trustedCaFile = config.sops.secrets."${cfg.etcdCa}/cert".path;
    };
    networking.firewall.allowedTCPPorts = [ 2379 2380 ];

  };
}
