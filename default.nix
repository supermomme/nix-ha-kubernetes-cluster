{ }:
{
  generateCerts = import ./scripts/certs;
  # modules = {
  #   kubeCluster = lib.module rec {
  #     inherit (lib) // import ./modules/kube-cluster.nix;
  #   };
  # };
  modules = {
    kubeCluster = import ./modules/kube-cluster.nix;
    
  };
}