{
  description = "Nixos config flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, ... }@inputs:
    inputs.flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
        {
          devShells.default = pkgs.mkShell {
            buildInputs = [
              pkgs.hello
            ];
          };
          nixosModules = rec {
            default = { pkgs, config, lib, ... }:
              import ./modules/kube-cluster.nix { inherit pkgs config lib; };
          };
          packages = rec {
            default = import ./scripts/certs/default.nix;
          };
        }
      );
}
