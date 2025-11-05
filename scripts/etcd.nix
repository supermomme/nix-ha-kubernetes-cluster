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

  caCsr = mkCsr "etcd-ca" { cn = "etcd-ca"; };
  serverCsr = mkCsr "etcd-server" {
    cn = "etcd";
    altNames = ["127.0.0.1" "controlplane0" "10.0.0.70"];
  };
  peerCsr = mkCsr "etcd-peer" {
    cn = "etcd-peer";
    altNames = ["127.0.0.1" "controlplane0" "10.0.0.70"];
  };
  clientCsr = mkCsr "etcd-client" {
    cn = "etcd-client";
    altNames = ["127.0.0.1" "controlplane0" "10.0.0.70"];
  };
  flannelClientCsr = mkCsr "flannel" {
    cn = "flannel";
    altNames = ["127.0.0.1" "controlplane0" "10.0.0.70"];
  };
in

pkgs.writeShellScriptBin "generate-certs-etcd" ''
  ${pkgs.callPackage ./script-utils.nix { pkgs = pkgs; }}
  echo "Generating etcd certificates"

  out=./certs/etcd
  mkdir -p $out
  pushd $out > /dev/null

  genCa ${caCsr}
  genCert server server ${serverCsr}
  genCert peer peer ${peerCsr}
  genCert client client ${clientCsr}
  genCert client flannel-client ${flannelClientCsr}

  popd > /dev/null

  file="./hosts/controlplane0-secrets.nix"

  echo "Replacing etcd certs in $file"
  replacement="
    environment.etc.\"etcd/ca.pem\".text = \'\'$(cat $out/ca.pem)\'\';
    environment.etc.\"etcd/server.pem\".text = \'\'$(cat $out/server.pem)\'\';
    environment.etc.\"etcd/server-key.pem\".text = \'\'$(cat $out/server-key.pem)\'\';
    environment.etc.\"etcd/peer.pem\".text = \'\'$(cat $out/peer.pem)\'\';
    environment.etc.\"etcd/peer-key.pem\".text = \'\'$(cat $out/peer-key.pem)\'\';
    environment.etc.\"etcd/client.pem\".text = \'\'$(cat $out/client.pem)\'\';
    environment.etc.\"etcd/client-key.pem\".text = \'\'$(cat $out/client-key.pem)\'\';
    environment.etc.\"flannel/etcd-client.pem\".text = \'\'$(cat $out/flannel-client.pem)\'\';
    environment.etc.\"flannel/etcd-client-key.pem\".text = \'\'$(cat $out/flannel-client-key.pem)\'\';
  "

  ${pkgs.busybox}/bin/awk -v repl="$replacement" '
    BEGIN { in_block=0 }
    /^  ### ETCD CERTS ###$/ {
      print
      print repl
      in_block=1
      next
    }
    /^  ### ETCD CERTS END ###$/ {
      in_block=0
    }
    !in_block
  ' "$file" > "$file.tmp" && mv "$file.tmp" "$file"

''
  # out=./certs/generated
  # ${pkgs.callPackage ./etcd.nix { }}
  # ${pkgs.callPackage ./kubernetes.nix { }}
  # ${pkgs.callPackage ./coredns.nix { }}
  # ${pkgs.callPackage ./flannel.nix { }}