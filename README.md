# nix-ha-kubernetes-cluster

HA Kubernete Cluster for learning purpose (homelab)

## The Idea
This repository generates NixOS configurations and creates bootable ISO files for a Kubernetes cluster.

**Key Features:**
- Boot ISOs to automatically create a cluster
- Minimal persistent storage (only for essential data like etcd)
- Everything else runs in tmpfs for performance
- Worker nodes don't need disks - just RAM - completely ephemeral
- Future goal: Auto-scaling with PXE boot (nodes boot when needed, drain and shutdown when idle)

## Current configuration
I use Proxmox-VMs with nixos (x86_64)
- controlplane0
  - etcd
  - control-plane (apiserver, controller-manager, scheduler)
  - worker (kubelet, kube-proxy, flannel, coredns)

## TODOs
- [x] bootable iso
- [x] basic etcd
- [x] basic apisever
- [x] basic controllerManager
- [x] basic scheduler
- [x] basic kublet
- [x] basic flannel
- [x] basic coredns
- [x] basic cert creation script
- [ ] split controlplane and worker into modules
- [ ] streamline kube-resources into config. create certs and isos based on that config
- [ ] improve cert management
- [ ] reconsider cert expiry
- [ ] loadbalancer for apiserver
- [ ] consider idea: loadbalancer for reverse proxy?
- [ ] make proper readme :)
- [ ] documentation: proper quickstart
- [ ] documentation: add controlplane member
- [ ] research: add kubernetes resources into cluster (deployments, services, ...)

## (Quick)-start (WIP)
TBD

###### some commands i need to save somewhere xD
```zsh
nix develop --command bash -c "generate-certs-etcd"
nix develop --command bash -c "generate-certs-kubernetes"

nix build .#nixosConfigurations.controlplane0.config.system.build.isoImage
# nix run nixpkgs#nixos-generators -- --format iso --flake .#controlplane0 -o result

scp result/iso/*.iso root@10.0.0.60:/var/lib/vz/template/iso/nixos.iso
```

## Further Resources

This project is heavily inspired by [justinas/nixos-ha-kubernetes](https://github.com/justinas/nixos-ha-kubernetes/tree/73809dda76f5d9d27b0ebb6f7f7ce19d5b380038)

- [justinas/nixos-ha-kubernetes](https://github.com/justinas/nixos-ha-kubernetes/tree/73809dda76f5d9d27b0ebb6f7f7ce19d5b380038)
- https://kubernetes.io/docs/concepts/architecture/
- https://etcd.io/docs/v3.5/op-guide/clustering/
- https://etcd.io/docs/v3.5/op-guide/clustering/#static
- https://etcd.io/docs/v3.5/op-guide/runtime-configuration/