{ pkgs }:
let
  csrDefaults = {
    key = {
      algo = "rsa";
      size = 2048;
    };
  };
  writeJSONText = name: obj: pkgs.writeText "${name}.json" (builtins.toJSON obj);
  mkCsr = name: { cn, altNames ? [ ], organization ? null }:
    writeJSONText name (pkgs.lib.attrsets.recursiveUpdate csrDefaults {
      CN = cn;
      hosts = [ cn ] ++ altNames;
      names = if organization == null then null else [
        { "O" = organization; }
      ];
    });

  caCsr = mkCsr "kubernetes-ca" { cn = "kubernetes-ca"; };
  apiServerCsr = mkCsr "kube-api-server" {
    cn = "kubernetes";
    altNames =
      ["127.0.0.1" "controlplane0" "10.0.0.70"] ++ ## controlplanes, loadbalancers, virtualIPs
      pkgs.lib.singleton "10.32.0.1" ++ ## kubernetes service cluster IP
      [ "kubernetes" "kubernetes.default" "kubernetes.default.svc" "kubernetes.default.svc.cluster" "kubernetes.svc.cluster.local" ];
  };

  apiServerKubeletClientCsr = mkCsr "kube-api-server-kubelet-client" {
    cn = "kube-api-server";
    altNames = ["127.0.0.1" "controlplane0" "10.0.0.70"]; ## controlplanes
    organization = "system:masters";
  };

  controllerManagerCsr = mkCsr "kube-controller-manager" {
    cn = "system:kube-controller-manager";
    organization = "system:kube-controller-manager";
  };

  adminCsr = mkCsr "admin" {
    cn = "admin";
    organization = "system:masters";
  };

  proxyCsr = mkCsr "kube-proxy" {
    cn = "system:kube-proxy";
    organization = "system:node-proxier";
  };

  schedulerCsr = mkCsr "kube-scheduler" {
    cn = "system:kube-scheduler";
    organization = "system:kube-scheduler";
  };

  coreDnsCsr = mkCsr "coredns" {
    cn = "system:coredns";
    # organization = "system:kube-scheduler";
  };

  kubeletClientCsr = mkCsr "kubelet-client" {
    cn = "system:node:controlplane0";
    organization = "system:nodes";
    altNames = [ "controlplane0" "10.0.0.70" ];
  };

in

pkgs.writeShellScriptBin "generate-certs-kubernetes" ''
  ${pkgs.callPackage ./script-utils.nix { pkgs = pkgs; }}
  echo "Generating kubernetes certificates"

  out=./certs/kubernetes
  mkdir -p $out
  pushd $out > /dev/null

  genCa ${caCsr}
  genCert server apiserver ${apiServerCsr}
  genCert server apiserver-kubelet-client ${apiServerKubeletClientCsr}
  genCert client admin ${adminCsr}
  genCert client controller-manager ${controllerManagerCsr}
  genCert client proxy ${proxyCsr}
  genCert client scheduler ${schedulerCsr}
  genCert client coredns ${schedulerCsr}
  genCert peer kubelet-client ${kubeletClientCsr}

  popd > /dev/null
  file="./hosts/controlplane0-secrets.nix"

  echo "Replacing kubernetes certs in $file"
  replacement="
    environment.etc.\"kubernetes/ca.pem\".text = \'\'$(cat $out/ca.pem)\'\';
    environment.etc.\"kubernetes/apiserver.pem\".text = \'\'$(cat $out/apiserver.pem)\'\';
    environment.etc.\"kubernetes/apiserver-key.pem\".text = \'\'$(cat $out/apiserver-key.pem)\'\';
    environment.etc.\"kubernetes/apiserver-kubelet-client.pem\".text = \'\'$(cat $out/apiserver-kubelet-client.pem)\'\';
    environment.etc.\"kubernetes/apiserver-kubelet-client-key.pem\".text = \'\'$(cat $out/apiserver-kubelet-client-key.pem)\'\';
    environment.etc.\"kubernetes/admin.pem\".text = \'\'$(cat $out/admin.pem)\'\';
    environment.etc.\"kubernetes/admin-key.pem\".text = \'\'$(cat $out/admin-key.pem)\'\';
    environment.etc.\"kubernetes/controller-manager.pem\".text = \'\'$(cat $out/controller-manager.pem)\'\';
    environment.etc.\"kubernetes/controller-manager-key.pem\".text = \'\'$(cat $out/controller-manager-key.pem)\'\';
    environment.etc.\"kubernetes/proxy.pem\".text = \'\'$(cat $out/proxy.pem)\'\';
    environment.etc.\"kubernetes/proxy-key.pem\".text = \'\'$(cat $out/proxy-key.pem)\'\';
    environment.etc.\"kubernetes/scheduler.pem\".text = \'\'$(cat $out/scheduler.pem)\'\';
    environment.etc.\"kubernetes/scheduler-key.pem\".text = \'\'$(cat $out/scheduler-key.pem)\'\';
    environment.etc.\"kubernetes/coredns.pem\".text = \'\'$(cat $out/coredns.pem)\'\';
    environment.etc.\"kubernetes/coredns-key.pem\".text = \'\'$(cat $out/coredns-key.pem)\'\';
    environment.etc.\"kubernetes/kubelet-client.pem\".text = \'\'$(cat $out/kubelet-client.pem)\'\';
    environment.etc.\"kubernetes/kubelet-client-key.pem\".text = \'\'$(cat $out/kubelet-client-key.pem)\'\';
  "

  ${pkgs.busybox}/bin/awk -v repl="$replacement" '
    BEGIN { in_block=0 }
    /^  ### K8S CERTS ###$/ {
      print
      print repl
      in_block=1
      next
    }
    /^  ### K8S CERTS END ###$/ {
      in_block=0
    }
    !in_block
  ' "$file" > "$file.tmp" && mv "$file.tmp" "$file"

  echo "Generating local kubeconfig"
    ${pkgs.kubectl}/bin/kubectl --kubeconfig admin.kubeconfig config set-credentials admin \
      --client-certificate=$out/admin.pem \
      --client-key=$out/admin-key.pem \
      --embed-certs=true > /dev/null
  ${pkgs.kubectl}/bin/kubectl --kubeconfig admin.kubeconfig config set-cluster k8s-on-nix \
      --certificate-authority=$out/ca.pem \
      --server=https://10.0.0.70:6443 \
      --embed-certs=true > /dev/null
  ${pkgs.kubectl}/bin/kubectl --kubeconfig admin.kubeconfig config set-context k8s-on-nix \
      --user admin \
      --cluster k8s-on-nix > /dev/null
  ${pkgs.kubectl}/bin/kubectl --kubeconfig admin.kubeconfig config use-context k8s-on-nix > /dev/null

''
  # genCert client proxy ${proxyCsr}
  # genCert client scheduler ${schedulerCsr}
