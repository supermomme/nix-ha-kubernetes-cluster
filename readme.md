
nix develop --command bash -c "generate-certs-etcd"
nix develop --command bash -c "generate-certs-kubernetes"

nix build .#nixosConfigurations.controlplane0.config.system.build.isoImage
nix run nixpkgs#nixos-generators -- --format iso --flake .#controlplane0 -o result

scp result/iso/*.iso root@10.0.0.60:/var/lib/vz/template/iso/nixos.iso
