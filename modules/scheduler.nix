{ config, pkgs, lib, ... }:
let
  cfg = config.scheduler;
in
{
  options.scheduler = with lib; {
    enable = mkEnableOption "enable scheduler module";
    kubeApiHostname = mkOption {
      type = types.str;
      description = "Hostname/IP of apiserver or loadbalancer";
    };

    kubernetesCa = mkOption {
      type = types.str;
      default = "kubernetes/ca";
    };
    schedulerCert = mkOption {
      type = types.str;
      default = "utm-nixos1/kubernetes/schedulerCert";
    };
  };
  config = lib.mkIf cfg.enable {

    sops.secrets."${cfg.kubernetesCa}/cert" = { mode = "0777"; };
  
    ### scheduler
    sops.secrets."${cfg.schedulerCert}/cert" = { owner = "kubernetes"; };
    sops.secrets."${cfg.schedulerCert}/key" = { owner = "kubernetes"; };
    services.kubernetes.scheduler = {
      enable = true;
      kubeconfig = {
        caFile = config.sops.secrets."${cfg.kubernetesCa}/cert".path;
        certFile = config.sops.secrets."${cfg.schedulerCert}/cert".path;
        keyFile = config.sops.secrets."${cfg.schedulerCert}/key".path;
        server = "https://${cfg.kubeApiHostname}:6443";
      };
    };
  };
}
