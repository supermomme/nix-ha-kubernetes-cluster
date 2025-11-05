{ config, lib, pkgs, ... }: let 
  
in {
  imports = [
    ./controlplane0-secrets.nix
  ];

  # Add iptables for kube-proxy to work properly
  environment.systemPackages = with pkgs; [
    iptables
  ];

  networking.hostName = "controlplane0";
  networking.firewall.enable = false;
  
  # Enable netfilter for iptables rules (needed for kube-proxy)
  networking.firewall.checkReversePath = false;

  # networking
  networking.interfaces.eth0.ipv4.addresses = [
    {
      address = "10.0.0.70";
      prefixLength = 16;
    }
  ];
  networking.defaultGateway = "10.0.0.1";
  networking.nameservers = [ "8.8.8.8" ];

  # Add route for service CIDR to enable service discovery
  systemd.services.add-service-route = {
    description = "Add route for Kubernetes service CIDR";
    after = [ "network.target" "flannel.service" ];
    wants = [ "flannel.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.bash}/bin/bash -c 'sleep 5 && ${pkgs.iproute2}/bin/ip route add 10.32.0.0/24 dev cni0 || true'";
      ExecStop = "${pkgs.iproute2}/bin/ip route del 10.32.0.0/24 dev cni0 || true";
    };
  };

  # permanent storage
  fileSystems."/storage" = {
    device = "/dev/disk/by-uuid/8c54196e-b84b-4747-a563-42fb2be84699";
    fsType = "ext4";
    options = [ "nofail" ]; # Don't fail boot if the device is not available
  };

  # etcd
  environment.etc."etcd/ca.pem".user = "etcd";
  environment.etc."etcd/ca.pem".group = "etcd";
  environment.etc."etcd/ca.pem".mode = "0777";
  environment.etc."etcd/server.pem".user = "etcd";
  environment.etc."etcd/server.pem".group = "etcd";
  environment.etc."etcd/server.pem".mode = "0600";
  environment.etc."etcd/server-key.pem".user = "etcd";
  environment.etc."etcd/server-key.pem".group = "etcd";
  environment.etc."etcd/server-key.pem".mode = "0600";
  environment.etc."etcd/peer.pem".user = "etcd";
  environment.etc."etcd/peer.pem".group = "etcd";
  environment.etc."etcd/peer.pem".mode = "0600";
  environment.etc."etcd/peer-key.pem".user = "etcd";
  environment.etc."etcd/peer-key.pem".group = "etcd";
  environment.etc."etcd/peer-key.pem".mode = "0600";
  environment.etc."etcd/client.pem".user = "etcd";
  environment.etc."etcd/client.pem".group = "etcd";
  environment.etc."etcd/client.pem".mode = "0777";
  environment.etc."etcd/client-key.pem".user = "etcd";
  environment.etc."etcd/client-key.pem".group = "etcd";
  environment.etc."etcd/client-key.pem".mode = "0777";

  environment.variables."ETCDCTL_API" = "3";
  environment.variables."ETCDCTL_CACERT" = "/etc/etcd/ca.pem";
  environment.variables."ETCDCTL_CERT" = "/etc/etcd/client.pem";
  environment.variables."ETCDCTL_KEY" = "/etc/etcd/client-key.pem";

  services.etcd = {
    enable = true;
    name = config.networking.hostName;

    advertiseClientUrls = [ "https://10.0.0.70:2379" ];
    initialAdvertisePeerUrls = [ "https://10.0.0.70:2380" ];
    initialCluster = ["${config.services.etcd.name}=https://10.0.0.70:2380"];
    initialClusterState = "new";
    listenClientUrls = [ "https://10.0.0.70:2379" "https://127.0.0.1:2379" ];
    listenPeerUrls = [ "https://10.0.0.70:2380" "https://127.0.0.1:2380" ];

    dataDir = "/storage/etcd";

    clientCertAuth = true;
    peerClientCertAuth = true;

    certFile = "/etc/etcd/server.pem";
    keyFile = "/etc/etcd/server-key.pem";

    peerCertFile = "/etc/etcd/peer.pem";
    peerKeyFile = "/etc/etcd/peer-key.pem";

    peerTrustedCaFile = "/etc/etcd/ca.pem";
    trustedCaFile = "/etc/etcd/ca.pem";
  };

  systemd.services.etcd = {
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
  };


  #### api server
  # networking.firewall.allowedTCPPorts = [ 6443 ];

  environment.etc."kubernetes/ca.pem".user = "kubernetes";
  environment.etc."kubernetes/ca.pem".group = "kubernetes";
  environment.etc."kubernetes/ca.pem".mode = "0777";

  environment.etc."kubernetes/apiserver-kubelet-client.pem".user = "kubernetes";
  environment.etc."kubernetes/apiserver-kubelet-client.pem".group = "kubernetes";
  environment.etc."kubernetes/apiserver-kubelet-client.pem".mode = "0600";

  environment.etc."kubernetes/apiserver-kubelet-client-key.pem".user = "kubernetes";
  environment.etc."kubernetes/apiserver-kubelet-client-key.pem".group = "kubernetes";
  environment.etc."kubernetes/apiserver-kubelet-client-key.pem".mode = "0600";

  environment.etc."kubernetes/apiserver.pem".user = "kubernetes";
  environment.etc."kubernetes/apiserver.pem".group = "kubernetes";
  environment.etc."kubernetes/apiserver.pem".mode = "0600";

  environment.etc."kubernetes/apiserver-key.pem".user = "kubernetes";
  environment.etc."kubernetes/apiserver-key.pem".group = "kubernetes";
  environment.etc."kubernetes/apiserver-key.pem".mode = "0600";


  services.kubernetes.clusterCidr = "10.200.0.0/16";
  services.kubernetes.apiserver = let
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
  in {
    enable = true;
    advertiseAddress = "10.0.0.70";
    serviceClusterIpRange = "10.32.0.0/24";

    # Using ABAC for CoreDNS running outside of k8s
    # is more simple in this case than using kube-addon-manager
    authorizationMode = [ "RBAC" "Node" "ABAC" ];
    authorizationPolicy = corednsPolicies;

    etcd = {
      servers = ["https://10.0.0.70:2379"]; ## etcd cluster nodes
      caFile = "/etc/etcd/ca.pem";
      certFile = "/etc/etcd/client.pem";
      keyFile = "/etc/etcd/client-key.pem";
    };

    clientCaFile = "/etc/kubernetes/ca.pem";

    kubeletClientCaFile = "/etc/kubernetes/ca.pem";
    kubeletClientCertFile = "/etc/kubernetes/apiserver-kubelet-client.pem";
    kubeletClientKeyFile = "/etc/kubernetes/apiserver-kubelet-client-key.pem";

    # TODO: separate from server keys
    serviceAccountKeyFile = "/etc/kubernetes/apiserver.pem"; # (public key/certificate for verifying tokens)
    serviceAccountSigningKeyFile = "/etc/kubernetes/apiserver-key.pem"; # private key for signing tokens

    tlsCertFile = "/etc/kubernetes/apiserver.pem";
    tlsKeyFile = "/etc/kubernetes/apiserver-key.pem";
  };

  ### controller manager
  environment.etc."kubernetes/controller-manager.pem".user = "kubernetes";
  environment.etc."kubernetes/controller-manager.pem".group = "kubernetes";
  environment.etc."kubernetes/controller-manager.pem".mode = "0600";
  environment.etc."kubernetes/controller-manager-key.pem".user = "kubernetes";
  environment.etc."kubernetes/controller-manager-key.pem".group = "kubernetes";
  environment.etc."kubernetes/controller-manager-key.pem".mode = "0600";

  services.kubernetes.controllerManager = {
    enable = true;
    rootCaFile = "/etc/kubernetes/ca.pem"; # CA certificate to populate in the kube-root-ca.crt ConfigMap
    serviceAccountKeyFile = "/etc/kubernetes/apiserver-key.pem"; # private key for signing service account tokens
    kubeconfig = {
      caFile = "/etc/kubernetes/ca.pem";
      certFile = "/etc/kubernetes/controller-manager.pem";
      keyFile = "/etc/kubernetes/controller-manager-key.pem";
      server = "https://10.0.0.70:6443";
    };
  };

  ### scheduler
  environment.etc."kubernetes/scheduler.pem".user = "kubernetes";
  environment.etc."kubernetes/scheduler.pem".group = "kubernetes";
  environment.etc."kubernetes/scheduler.pem".mode = "0600";
  environment.etc."kubernetes/scheduler-key.pem".user = "kubernetes";
  environment.etc."kubernetes/scheduler-key.pem".group = "kubernetes";
  environment.etc."kubernetes/scheduler-key.pem".mode = "0600";

  services.kubernetes.scheduler = {
    enable = true;
    kubeconfig = {
      caFile = "/etc/kubernetes/ca.pem";
      certFile = "/etc/kubernetes/scheduler.pem";
      keyFile = "/etc/kubernetes/scheduler-key.pem";
      server = "https://10.0.0.70:6443";
    };
  };


  ######## worker node components ########
  virtualisation.containerd.settings = {
    root = "/storage/containerd";
  };
  # services.kubernetes.clusterCidr = "10.200.0.0/16";
  ### kubelet
  environment.etc."kubernetes/kubelet-client.pem".user = "kubernetes";
  environment.etc."kubernetes/kubelet-client.pem".group = "kubernetes";
  environment.etc."kubernetes/kubelet-client.pem".mode = "0600";
  environment.etc."kubernetes/kubelet-client-key.pem".user = "kubernetes";
  environment.etc."kubernetes/kubelet-client-key.pem".group = "kubernetes";
  environment.etc."kubernetes/kubelet-client-key.pem".mode = "0600";

  services.kubernetes.kubelet = {
    enable = true;
    unschedulable = false;
    kubeconfig = {
      caFile = "/etc/kubernetes/ca.pem";
      certFile = "/etc/kubernetes/kubelet-client.pem";
      keyFile = "/etc/kubernetes/kubelet-client-key.pem";
      server = "https://10.0.0.70:6443";
    };
    clientCaFile = "/etc/kubernetes/ca.pem";
    tlsCertFile = "/etc/kubernetes/kubelet-client.pem";
    tlsKeyFile = "/etc/kubernetes/kubelet-client-key.pem";
    # extraOpts = "--fail-swap-on=false"; 
  };

  ### kube-proxy
  environment.etc."kubernetes/proxy.pem".user = "kubernetes";
  environment.etc."kubernetes/proxy.pem".group = "kubernetes";
  environment.etc."kubernetes/proxy.pem".mode = "0600";
  environment.etc."kubernetes/proxy-key.pem".user = "kubernetes";
  environment.etc."kubernetes/proxy-key.pem".group = "kubernetes";
  environment.etc."kubernetes/proxy-key.pem".mode = "0600";

  services.kubernetes.proxy = {
    enable = true;
    kubeconfig = {
      caFile = "/etc/kubernetes/ca.pem";
      certFile = "/etc/kubernetes/proxy.pem";
      keyFile = "/etc/kubernetes/proxy-key.pem";
      server = "https://10.0.0.70:6443";
    };
  };

  ### flannel
  environment.etc."flannel/etcd-client.pem".user = "kubernetes";
  environment.etc."flannel/etcd-client.pem".group = "kubernetes";
  environment.etc."flannel/etcd-client.pem".mode = "0777";
  environment.etc."flannel/etcd-client-key.pem".user = "kubernetes";
  environment.etc."flannel/etcd-client-key.pem".group = "kubernetes";
  environment.etc."flannel/etcd-client-key.pem".mode = "0777";

  networking = {
    dhcpcd.denyInterfaces = [ "mynet*" "flannel*" ];
    firewall.allowedUDPPorts = [
      8285 # flannel udp
      8472 # flannel vxlan
    ];
  };

  services.flannel = {
    enable = true;
    network = "10.200.0.0/16"; # pod cidr only

    storageBackend = "etcd"; # TODO: reconsider
    etcd = {
      endpoints = ["https://10.0.0.70:2379"]; # etcd cluster nodes

      caFile = "/etc/etcd/ca.pem";
      certFile = "/etc/flannel/etcd-client.pem";
      keyFile = "/etc/flannel/etcd-client-key.pem";
    };
  };
  services.resolved.enable = false;
  services.kubernetes.kubelet = {
    cni.config = [{
      name = "mynet";
      type = "flannel";
      cniVersion = "0.3.1";
      delegate = {
        isDefaultGateway = true;
        bridge = "cni0";
      };
    }
    {
      cniVersion = "0.3.1";
      name = "lo";
      type = "loopback";
    }
    ];
  };

  # coredns
  # environment.etc."kubernetes/ca.pem".user = "coredns";
  environment.etc."kubernetes/coredns.pem".user = "coredns";
  environment.etc."kubernetes/coredns.pem".group = "coredns";
  environment.etc."kubernetes/coredns.pem".mode = "0600";
  environment.etc."kubernetes/coredns-key.pem".user = "coredns";
  environment.etc."kubernetes/coredns-key.pem".group = "coredns";
  environment.etc."kubernetes/coredns-key.pem".mode = "0600";

  services.coredns = {
    enable = true;
    config = ''
      .:53 {
        kubernetes cluster.local {
          endpoint https://10.0.0.70:6443
          tls /etc/kubernetes/coredns.pem /etc/kubernetes/coredns-key.pem "/etc/kubernetes/ca.pem"
          pods verified
        }
        forward . 1.1.1.1:53 1.0.0.1:53
      }
    '';
  };

  services.kubernetes.kubelet.clusterDns = ["10.0.0.70"]; # self ip

  networking.firewall.interfaces.mynet.allowedTCPPorts = [ 53 ];
  networking.firewall.interfaces.mynet.allowedUDPPorts = [ 53 ];

  users.groups.coredns = { };
  users.users.coredns = {
    group = "coredns";
    isSystemUser = true;
  };

}