{ lib, config, pkgs, ... }:
let
  cfg = config.apiserver;
  corednsPolicies = map
    (r: {
      apiVersion = "abac.authorization.kubernetes.io/v1beta1";
      kind = "Policy";
      spec = {
        user = "system:coredns";
        namespace = "*";
        resource = r;
        readonly = true;
      };
    }) [ "endpoints" "services" "pods" "namespaces" ]
  ++ lib.singleton
    {
      apiVersion = "abac.authorization.kubernetes.io/v1beta1";
      kind = "Policy";
      spec = {
        user = "system:coredns";
        namespace = "*";
        resource = "endpointslices";
        apiGroup = "discovery.k8s.io";
        readonly = true;
      };
    };
in
{
  options.apiserver = with lib; {
    enable = mkEnableOption "enable apiserver module";
    selfIP = mkOption {
      type = types.str;
      description = "IP of node";
    };

    etcdCa = mkOption {
      type = types.str;
      default = "etcd/ca";
    };
    kubernetesCa = mkOption {
      type = types.str;
      default = "kubernetes/ca";
    };
    etcdClientCert = mkOption {
      type = types.str;
      default = "utm-nixos1/etcd/apiserverCert";
    };
    apiserverKubeletClientCert = mkOption {
      type = types.str;
      default = "utm-nixos1/kubernetes/apiserver/kubeletClientCert";
    };
    apiserverServerCert = mkOption {
      type = types.str;
      default = "utm-nixos1/kubernetes/apiserver/serverCert";
    };
  };
  config = lib.mkIf cfg.enable {

    networking.firewall.allowedTCPPorts = [ 6443 ];
    services.kubernetes.clusterCidr = "10.200.0.0/16";

    sops.secrets."${cfg.etcdCa}/cert" = { mode = "0777"; };
    sops.secrets."${cfg.kubernetesCa}/cert" = { mode = "0777"; };

    ### apiserver
    sops.secrets."${cfg.etcdClientCert}/cert" = { owner = "kubernetes"; };
    sops.secrets."${cfg.etcdClientCert}/key" = { owner = "kubernetes"; };
    sops.secrets."${cfg.apiserverKubeletClientCert}/cert" = { owner = "kubernetes"; };
    sops.secrets."${cfg.apiserverKubeletClientCert}/key" = { owner = "kubernetes"; };
    sops.secrets."${cfg.apiserverServerCert}/cert" = { owner = "kubernetes"; };
    sops.secrets."${cfg.apiserverServerCert}/key" = { owner = "kubernetes"; };

    services.kubernetes.apiserver = {
      enable = true;
      advertiseAddress = "${cfg.selfIP}";
      serviceClusterIpRange = "10.32.0.0/24";

      # Using ABAC for CoreDNS running outside of k8s
      # is more simple in this case than using kube-addon-manager
      authorizationMode = [ "RBAC" "Node" "ABAC" ];
      authorizationPolicy = corednsPolicies;

      etcd = {
        servers = map (r: "https://${r.ip}:2379") config.etcd.cluster;
        caFile = config.sops.secrets."${cfg.etcdCa}/cert".path;
        certFile = config.sops.secrets."${cfg.etcdClientCert}/cert".path;
        keyFile = config.sops.secrets."${cfg.etcdClientCert}/key".path;
      };

      clientCaFile = config.sops.secrets."${cfg.kubernetesCa}/cert".path;

      kubeletClientCaFile = config.sops.secrets."${cfg.kubernetesCa}/cert".path;
      kubeletClientCertFile = config.sops.secrets."${cfg.apiserverKubeletClientCert}/cert".path;
      kubeletClientKeyFile = config.sops.secrets."${cfg.apiserverKubeletClientCert}/key".path;

      # TODO: separate from server keys
      serviceAccountKeyFile = config.sops.secrets."${cfg.apiserverServerCert}/cert".path;
      serviceAccountSigningKeyFile = config.sops.secrets."${cfg.apiserverServerCert}/key".path;

      tlsCertFile = config.sops.secrets."${cfg.apiserverServerCert}/cert".path;
      tlsKeyFile = config.sops.secrets."${cfg.apiserverServerCert}/key".path;
    };
  };
}
