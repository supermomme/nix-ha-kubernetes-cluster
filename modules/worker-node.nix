{ lib, config, pkgs, ... }:
let
  cfg = config.workerNode;
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
  options.workerNode = with lib; {
    enable = mkEnableOption "enable etcd module";
    selfIP = mkOption {
      type = types.str;
      description = "IP of node";
    };
    kubeApiHostname = mkOption {
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
    kubeletCert = mkOption {
      type = types.str;
      default = "utm-nixos3/kubernetes/kubeletCert";
    };
    proxyCert = mkOption {
      type = types.str;
      default = "utm-nixos3/kubernetes/proxyCert";
    };
    flannelEtcdCert = mkOption {
      type = types.str;
      default = "utm-nixos3/etcd/flannelCert";
    };
    corednsCert = mkOption {
      type = types.str;
      default = "utm-nixos3/kubernetes/corednsCert";
    };
  };
  config = lib.mkIf cfg.enable {

    networking.dhcpcd.denyInterfaces = [ "mynet*" "flannel*" ];
    networking.firewall.allowedTCPPorts = [
      config.services.kubernetes.kubelet.port
      8285 # flannel udp
      8472 # flannel vxlan
    ];
    services.kubernetes.clusterCidr = "10.200.0.0/16";

    sops.secrets."${cfg.etcdCa}/cert" = { mode = "0777"; };
    sops.secrets."${cfg.kubernetesCa}/cert" = { owner = "kubernetes"; mode = "0777"; };

    sops.secrets."${cfg.kubeletCert}/cert" = { owner = "kubernetes"; };
    sops.secrets."${cfg.kubeletCert}/key" = { owner = "kubernetes"; };
    services.kubernetes.kubelet = rec {
      enable = true;
      unschedulable = false;
      kubeconfig = rec {
        caFile = config.sops.secrets."${cfg.kubernetesCa}/cert".path;
        certFile = tlsCertFile;
        keyFile = tlsKeyFile;
        server = "https://${cfg.kubeApiHostname}:6443";
      };
      clientCaFile = config.sops.secrets."${cfg.kubernetesCa}/cert".path;
      tlsCertFile = config.sops.secrets."${cfg.kubeletCert}/cert".path;
      tlsKeyFile = config.sops.secrets."${cfg.kubeletCert}/key".path;
      extraOpts = "--fail-swap-on=false"; 
    };

    sops.secrets."${cfg.proxyCert}/cert" = { owner = "kubernetes"; };
    sops.secrets."${cfg.proxyCert}/key" = { owner = "kubernetes"; };
    services.kubernetes.proxy = {
      enable = true;
      kubeconfig = {
        caFile = config.sops.secrets."${cfg.kubernetesCa}/cert".path;
        certFile = config.sops.secrets."${cfg.proxyCert}/cert".path;
        keyFile = config.sops.secrets."${cfg.proxyCert}/key".path;
        server = "https://${cfg.kubeApiHostname}:6443";
      };
    };

    # flannel

    sops.secrets."${cfg.flannelEtcdCert}/cert" = { owner = "kubernetes"; };
    sops.secrets."${cfg.flannelEtcdCert}/key" = { owner = "kubernetes"; };
    services.flannel = {
      enable = true;
      network = config.services.kubernetes.clusterCidr;

      storageBackend = "etcd"; # TODO: reconsider
      etcd = {
        endpoints = map (r: "https://${r.ip}:2379") config.etcd.cluster;

        caFile = config.sops.secrets."${cfg.etcdCa}/cert".path;
        certFile = config.sops.secrets."${cfg.flannelEtcdCert}/cert".path;
        keyFile = config.sops.secrets."${cfg.flannelEtcdCert}/key".path;
      };
    };
    services.kubernetes.kubelet = {
      cni.config = [{
        name = "mynet";
        type = "flannel";
        cniVersion = "0.3.1";
        delegate = {
          isDefaultGateway = true;
          bridge = "mynet";
        };
      }];
    };

    # coredns
    sops.secrets."${cfg.corednsCert}/cert" = { owner = "coredns"; };
    sops.secrets."${cfg.corednsCert}/key" = { owner = "coredns"; };
    services.coredns = {
      enable = true;
      config = ''
        .:53 {
          kubernetes cluster.local {
            endpoint https://${cfg.kubeApiHostname}:6443
            tls ${config.sops.secrets."${cfg.corednsCert}/cert".path} ${config.sops.secrets."${cfg.corednsCert}/key".path} ${config.sops.secrets."${cfg.kubernetesCa}/cert".path}
            pods verified
          }
          forward . 1.1.1.1:53 1.0.0.1:53
        }
      '';
    };

    services.kubernetes.kubelet.clusterDns = "${cfg.selfIP}"; # self ip

    networking.firewall.interfaces.mynet.allowedTCPPorts = [ 53 ];
    networking.firewall.interfaces.mynet.allowedUDPPorts = [ 53 ];

    users.groups.coredns = { };
    users.users.coredns = {
      group = "coredns";
      isSystemUser = true;
    };
  };
}
