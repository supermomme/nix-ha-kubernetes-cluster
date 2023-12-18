# nix-ha-kubernetes-cluster

HA Kubernete Cluster for learning purpose

## Current configuration
I use UTM-VMs with nixos (aarch64-linux)
- utm-nixos1
  - etcd
  - control-plane (apiserver, controller-manager, scheduler)
- utm-nixos2
  - etcd
  - control-plane (apiserver, controller-manager, scheduler)
  - worker-node (kubelet, flannel, coredns)
- utm-nixos3
  - etcd
  - worker-node (kubelet, flannel, coredns)

## TODO
- create apiserver loadbalancer
- maybe port 443 loadbalancer
- put resources into single location (currently in shell and every configuration.nix)
- bundle everything in single module, that other repos can use this
- investigate apiserver-error `Failed to remove file watch, it may have been deleted` during cert-rotation

## Further Resources

This project is heavily inspired by [justinas/nixos-ha-kubernetes](https://github.com/justinas/nixos-ha-kubernetes/tree/73809dda76f5d9d27b0ebb6f7f7ce19d5b380038)

- [justinas/nixos-ha-kubernetes](https://github.com/justinas/nixos-ha-kubernetes/tree/73809dda76f5d9d27b0ebb6f7f7ce19d5b380038)
- https://kubernetes.io/docs/concepts/architecture/
- https://etcd.io/docs/v3.4/op-guide/clustering/
