{ pkgs ? import <nixpkgs> {}
, cfssl ? pkgs.cfssl
, lib ? pkgs.lib
}:
let
  inherit (pkgs.callPackage ./utils.nix { }) mkCsr;

  caConfig = pkgs.writeText "ca-config.json" ''
    {
      "signing": {
        "profiles": {
          "client": {
            "expiry": "87600h",
            "usages": ["signing", "key encipherment", "client auth"]
          },
          "peer": {
            "expiry": "87600h",
            "usages": ["signing", "key encipherment", "client auth", "server auth"]
          },
          "server": {
            "expiry": "8760h",
            "usages": ["signing", "key encipherment", "client auth", "server auth"]
          }
        }
      }
    }
  '';

  etcds = [
    { hostname = "utm-nixos1"; ip = "10.211.55.9"; }
    { hostname = "utm-nixos2"; ip = "10.211.55.10"; }
    { hostname = "utm-nixos3"; ip = "10.211.55.11"; }
  ];

  controlPlanes = [
    { hostname = "utm-nixos1"; ip = "10.211.55.9"; }
    { hostname = "utm-nixos2"; ip = "10.211.55.10"; }
  ];

  workerNodes = [
    { hostname = "utm-nixos2"; ip = "10.211.55.10"; }
    { hostname = "utm-nixos3"; ip = "10.211.55.11"; }
  ];


in
# Only use Nix to generate the certificate generation ( :) ) script.
  # That way, we avoid certificates ending up in the world-readable Nix store
pkgs.writeShellScriptBin "generate-certs" ''
  set -e

  # Generates a CA, if one does not exist, in the current directory.
  function genCa() {
    caYamlPath=$1
    csrjson=$2
    [ -n "$caYamlPath" ] || { echo "Usage: genCa caYamlPath csrjson" && return 1; }
    [ -n "$csrjson" ] || { echo "Usage: genCa caYamlPath csrjson" && return 1; }

    # check if exists
    caFieldValue=$(yq eval "$caYamlPath" "secrets/secrets.yaml")
    if [ -n "$caFieldValue" ] && [ "$caFieldValue" != "null" ]; then
      echo "$caYamlPath exists, not replacing the CA"
      return 0
    fi

    ${pkgs.yq-go}/bin/yq "$caYamlPath = $(${cfssl}/bin/cfssl gencert -loglevel 3 -initca "$csrjson")" -i "secrets/secrets.yaml"
  }

  # Generates a certificate signed by CA
  # (convention over configuration).
  function genCert() {
    caYamlPath=$1
    certYamlPath=$2
    profile=$3
    csrjson=$4
    [ -n "$caYamlPath" ] || { echo "Usage: genCa caYamlPath certYamlPath profile csrjson" && return 1; }
    [ -n "$certYamlPath" ] || { echo "Usage: genCa caYamlPath certYamlPath profile csrjson" && return 1; }
    [ -n "$profile" ] || { echo "Usage: genCa caYamlPath certYamlPath profile csrjson" && return 1; }
    [ -n "$csrjson" ] || { echo "Usage: genCa caYamlPath certYamlPath profile csrjson" && return 1; }

    ${pkgs.yq-go}/bin/yq "$caYamlPath.cert" "secrets/secrets.yaml" > ca.pem
    ${pkgs.yq-go}/bin/yq "$caYamlPath.key" "secrets/secrets.yaml" > ca-key.pem

    result=$(${cfssl}/bin/cfssl gencert \
        -loglevel 3 \
        -ca ca.pem \
        -ca-key ca-key.pem \
        -config ${caConfig} \
        -profile "$profile" \
        "$csrjson")
    ${pkgs.yq-go}/bin/yq "$certYamlPath = $result" -i "secrets/secrets.yaml"
    rm ca.pem ca-key.pem
  }

  ${pkgs.sops}/bin/sops -d -i secrets/secrets.yaml

  ### CAs
  genCa ".etcd.ca" ${mkCsr "etcd-ca" { cn = "etcd-ca"; }}
  genCa ".kubernetes.ca" ${mkCsr "kubernetes-ca" { cn = "kubernetes-ca"; }}

  ### etcds
  ${lib.concatLines (map (etcd: ''
    genCert ".etcd.ca" ".${etcd.hostname}.etcd.serverCert" "server" ${ mkCsr "etcd-server" {
      cn = "etcd";
      altNames = [ "127.0.0.1" "${etcd.hostname}" "${etcd.ip}" ];
    }}
    genCert ".etcd.ca" ".${etcd.hostname}.etcd.peerCert" "peer" ${mkCsr "etcd-peer" {
      cn = "etcd-peer";
      altNames = [ "127.0.0.1" "${etcd.hostname}" "${etcd.ip}" ];
    }}
    echo "etcd ${etcd.hostname} ${etcd.ip}"
  '') etcds)}


  ### controlPlanes
  ${lib.concatLines (map (controlPlane: ''
    genCert ".etcd.ca" ".${controlPlane.hostname}.etcd.apiserverCert" "client" ${mkCsr "etcd-client" {
      cn = "etcd-client";
      altNames = [ "${controlPlane.hostname}" "${controlPlane.ip}" ];
    }}
    genCert ".kubernetes.ca" ".${controlPlane.hostname}.kubernetes.apiserver.serverCert" "server" ${mkCsr "kube-api-server" {
      cn = "kubernetes";
      altNames =
        [ "${controlPlane.hostname}" "${controlPlane.ip}" ] ++
        # getAltNames "loadbalancer" ++ # TODO: loadbalancers
        [ "kubernetes" "kubernetes.default" "kubernetes.default.svc" "kubernetes.default.svc.cluster" "kubernetes.svc.cluster.local" ];
    }}
    genCert ".kubernetes.ca" ".${controlPlane.hostname}.kubernetes.apiserver.kubeletClientCert" "server" ${mkCsr "kube-api-server-kubelet-client" {
      cn = "kube-api-server";
      altNames = [ "${controlPlane.hostname}" "${controlPlane.ip}" ];
      organization = "system:masters";
    }}
    genCert ".kubernetes.ca" ".${controlPlane.hostname}.kubernetes.controllerManagerCert" "client" ${mkCsr "kube-controller-manager" {
      cn = "system:kube-controller-manager";
      organization = "system:kube-controller-manager";
    }}
    genCert ".kubernetes.ca" ".${controlPlane.hostname}.kubernetes.schedulerCert" "client" ${mkCsr "kube-scheduler" rec {
      cn = "system:kube-scheduler";
      organization = cn;
    }}

    echo "controlPlane ${controlPlane.hostname} ${controlPlane.ip}"
  '') controlPlanes)}


  ### workerNodes
  ${lib.concatLines (map (workerNode: ''
    genCert ".etcd.ca" ".${workerNode.hostname}.etcd.flannelCert" "client" ${mkCsr "etcd-client" {
      cn = "flannel";
      altNames = [ "${workerNode.hostname}" "${workerNode.ip}" ];
    }}
    genCert ".kubernetes.ca" ".${workerNode.hostname}.kubernetes.corednsCert" "client" ${mkCsr "coredns" { cn = "system:coredns"; }}
    genCert ".kubernetes.ca" ".${workerNode.hostname}.kubernetes.proxyCert" "client" ${mkCsr "kube-proxy" {
      cn = "system:kube-proxy";
      organization = "system:node-proxier";
    }}
    genCert ".kubernetes.ca" ".${workerNode.hostname}.kubernetes.kubeletCert" "peer" ${mkCsr "kubelet-${workerNode.hostname}" { # single worker TODO: map
      cn = "system:node:${workerNode.hostname}";
      organization = "system:nodes";
      altNames = [ "${workerNode.hostname}" "${workerNode.ip}" ];
    }}
    echo "worker node ${workerNode.hostname} ${workerNode.ip}"
  '') workerNodes)}
  

  ### kubeconfig
  ${pkgs.yq-go}/bin/yq ".kubernetes.ca.cert" "secrets/secrets.yaml" > ca.pem
  ${pkgs.yq-go}/bin/yq ".kubernetes.ca.key" "secrets/secrets.yaml" > ca-key.pem
  result=$(${cfssl}/bin/cfssl gencert \
    -loglevel 3 \
    -ca ca.pem \
    -ca-key ca-key.pem \
    -config ${caConfig} \
    -profile "client" \
    "${mkCsr "admin" { cn = "admin"; organization = "system:masters"; }}")

  echo $result | ${pkgs.yq-go}/bin/yq -p=json '.cert' -- > admin.pem
  echo $result | ${pkgs.yq-go}/bin/yq -p=json '.key' -- > admin-key.pem

  ${pkgs.kubectl}/bin/kubectl --kubeconfig admin.kubeconfig config set-credentials admin \
      --client-certificate=admin.pem \
      --client-key=admin-key.pem \
      --embed-certs=true
  ${pkgs.kubectl}/bin/kubectl --kubeconfig admin.kubeconfig config set-cluster virt \
      --certificate-authority=ca.pem \
      --server=https://10.211.55.9:6443 \
      --embed-certs=true
  ${pkgs.kubectl}/bin/kubectl --kubeconfig admin.kubeconfig config set-cluster virt2 \
      --certificate-authority=ca.pem \
      --server=https://10.211.55.10:6443 \
      --embed-certs=true
  ${pkgs.kubectl}/bin/kubectl --kubeconfig admin.kubeconfig config set-context virt \
      --user admin \
      --cluster virt
  ${pkgs.kubectl}/bin/kubectl --kubeconfig admin.kubeconfig config set-context virt2 \
      --user admin \
      --cluster virt2
  ${pkgs.kubectl}/bin/kubectl --kubeconfig admin.kubeconfig config use-context virt > /dev/null
  rm ca.pem ca-key.pem admin.pem admin-key.pem

  ${pkgs.sops}/bin/sops -e -i secrets/secrets.yaml

''
