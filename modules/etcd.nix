{ lib, config, pkgs, ... }:
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
    globalSecretFile = mkOption {
      type = types.path;
      description = "Secret File with CA";
      default = ../secrets/secrets.yaml;
    };
    globalSecretPath = mkOption {
      type = types.str;
      description = "Global Secret Path-Prefix";
      default = "etcd";
    };
    privateSecretFile = mkOption {
      type = types.path;
      description = "Secret File with server cert and peer cert";
      default = ../secrets/secrets.yaml;
    };
    privateSecretPath = mkOption {
      type = types.str;
      description = "Private Secret Path-Prefix";
      default = "etcd";
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

    sops.secrets."${cfg.globalSecretPath}/ca/cert" = {
      owner = "etcd";
      sopsFile = cfg.globalSecretFile;
    };
    sops.secrets."${cfg.privateSecretPath}/serverCert/cert" = {
      owner = "etcd";
      sopsFile = cfg.privateSecretFile;
    };
    sops.secrets."${cfg.privateSecretPath}/serverCert/key" = {
      owner = "etcd";
      sopsFile = cfg.privateSecretFile;
    };
    sops.secrets."${cfg.privateSecretPath}/peerCert/cert" = {
      owner = "etcd";
      sopsFile = cfg.privateSecretFile;
    };
    sops.secrets."${cfg.privateSecretPath}/peerCert/key" = {
      owner = "etcd";
      sopsFile = cfg.privateSecretFile;
    };

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

      certFile = config.sops.secrets."${cfg.privateSecretPath}/serverCert/cert".path;
      keyFile = config.sops.secrets."${cfg.privateSecretPath}/serverCert/key".path;

      peerCertFile = config.sops.secrets."${cfg.privateSecretPath}/peerCert/cert".path;
      peerKeyFile = config.sops.secrets."${cfg.privateSecretPath}/peerCert/key".path;

      peerTrustedCaFile = config.sops.secrets."${cfg.globalSecretPath}/ca/cert".path;
      trustedCaFile = config.sops.secrets."${cfg.globalSecretPath}/ca/cert".path;
    };
    networking.firewall.allowedTCPPorts = [ 2379 2380 ];

  };
}
