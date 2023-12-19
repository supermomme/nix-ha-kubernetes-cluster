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

## TODOs
- [x] etcd
- [x] apisever
- [x] controllerManager
- [x] scheduler
- [x] workerNode with kublet, flannel and coredns
- [x] cert creation script into sops
- [ ] loadbalancer for apiserver 
- [ ] consider idea: loadbalancer for traefik?
- [x] put resources into single location (e.g. kube-resources.nix)
- [x] bundle everything in single module
- [ ] expose module, that other repos can use it
- [x] expose script, that other repos can use it
- [ ] investigate apiserver-error `Failed to remove file watch, it may have been deleted` during cert-rotation
- [ ] make proper readme :)
- [ ] variable secretFile
- [ ] reconsider temporary ca and cert files
- [ ] reconsider cert expiry
- [ ] fix etcd wait issue during initial startup
- [ ] seperate example into repo [supermomme/nix-ha-kubernetes-cluster-example](https://github.com/supermomme/nix-ha-kubernetes-cluster-example)
- [ ] research: add kubernetes resources into cluster (deployments, services, ...)
- [ ] check pin nixpkgs in all modules

## (Quick)-start (WIP)

### assumption:
- your sops-secret file is located in secrets/secrets.yaml
- all nodes have this secret as the default provider
- .gitignore contains `admin.kubeconfig` `ca.pem` `ca-key.pem` `admin.pem` and `admin-key.pem`
- IPs of nodes do not change (static-ish)

### kube-resources.nix
create a `kube-resources.nix`. adjust to your nodes and requirements
```nix
{
  clusterNodes = [
    {
      hostname = "host1";
      ip = "<ip of host1>";
      etcd = true;
    }
    {
      hostname = "host2";
      ip = "<ip of host2>";
      etcd = true;
      controlPlane = true;
      workerNode = true;
    }
    {
      hostname = "host3";
      ip = "<ip of host3>";
      etcd = true;
      workerNode = true;
    }
  ];
}
```

### generate-certs script
put the cert-generation script into your `shell.nix` like this:
```nix
{ pkgs ? import <nixpkgs> {} }: pkgs.mkShell {
  buildInputs = with pkgs.buildPackages; [
    (pkgs.writeShellScriptBin "generate-certs" ''
      $(nix-build --no-out-link --arg clusterNodes "(import ./kube-resources.nix).clusterNodes" https://github.com/supermomme/nix-ha-kubernetes-cluster/archive/main.tar.gz -A generateCerts)/bin/generate-certs
    '')
  ];
}
```

call the `generate-certs`-script via nix-shell: `nix-shell --command make-certs`

### kubeCluster module
```nix
# configuration.nix
{ config, lib, pkgs, modulesPath, inputs, ... }: {
  imports = [
    # ...
    ../../modules/kube-cluster.nix # TBD
  ];
  networking.hostName = "host1"; # Define your hostname.
  kubeCluster = {
    enable = true;
  };
  # ...
}
```

### kubeCluster module via flakes
```nix
# flake.nix
{
  # TBD
}
```

```nix
# configuration.nix
{ config, lib, pkgs, modulesPath, inputs, ... }: {
  imports = [
    # ...
    # TBD
  ];
  networking.hostName = "host1"; # Define your hostname.
  kubeCluster = {
    enable = true;
  };
  # ...
}
```

### rebuild

the etcd nodes should be build at the same time, because they wait for each other


## Further Resources

This project is heavily inspired by [justinas/nixos-ha-kubernetes](https://github.com/justinas/nixos-ha-kubernetes/tree/73809dda76f5d9d27b0ebb6f7f7ce19d5b380038)

- [justinas/nixos-ha-kubernetes](https://github.com/justinas/nixos-ha-kubernetes/tree/73809dda76f5d9d27b0ebb6f7f7ce19d5b380038)
- https://kubernetes.io/docs/concepts/architecture/
- https://etcd.io/docs/v3.4/op-guide/clustering/
