{ lib, config, pkgs, ... }:
let
  cfg = config.controllerManager;
in
{
  options.controllerManager = with lib; {
    enable = mkEnableOption "enable controllerManager module";
    kubeApiHostname = mkOption {
      type = types.str;
      description = "Hostname/IP of apiserver or loadbalancer";
    };

    kubernetesCa = mkOption {
      type = types.str;
      default = "kubernetes/ca";
    };
    controllerManagerCert = mkOption {
      type = types.str;
      default = "utm-nixos1/kubernetes/controllerManagerCert";
    };
  };
  config = lib.mkIf cfg.enable {

    sops.secrets."${cfg.kubernetesCa}/cert" = { mode = "0777"; };
  
    ### controller-manager
    sops.secrets."${cfg.controllerManagerCert}/cert" = { owner = "kubernetes"; };
    sops.secrets."${cfg.controllerManagerCert}/key" = { owner = "kubernetes"; };
    services.kubernetes.controllerManager = {
      enable = true;
      kubeconfig = {
        caFile = config.sops.secrets."${cfg.kubernetesCa}/cert".path;
        certFile = config.sops.secrets."${cfg.controllerManagerCert}/cert".path;
        keyFile = config.sops.secrets."${cfg.controllerManagerCert}/key".path;
        server = "https://${cfg.kubeApiHostname}:6443";
      };
    };
  };
}
