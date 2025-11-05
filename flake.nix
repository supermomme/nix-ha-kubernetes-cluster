# flake.nix
{
  inputs = {
    nixpkgs.url = "flake:nixpkgs/nixos-25.05";

    flake-utils.url = "github:numtide/flake-utils";

    nixos-generators.url = "github:nix-community/nixos-generators";
    nixos-generators.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs@{ self, nixpkgs, flake-utils, ... }: 
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      devShells.default = pkgs.mkShell {
        buildInputs = with pkgs; [
          (pkgs.callPackage ./scripts/etcd.nix { })
          (pkgs.callPackage ./scripts/kubernetes.nix { })
        ];
      };
    }) // {
    nixosConfigurations = {
      controlplane0 = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = {
          inherit inputs;
        };
        modules = [
          "${inputs.nixpkgs}/nixos/modules/installer/cd-dvd/iso-image.nix"
          ./modules/base-config.nix
          ./hosts/controlplane0.nix
          {
            nixpkgs.hostPlatform = "x86_64-linux";
            system.stateVersion = "25.05";
          }
        ];
      };
    };
    ## nix build .#controlplane0
    ## nixcfg --build-iso && nixcfg --burn-iso 00000111112222333
    # packages.x86_64-linux.controlplane0 = inputs.nixos-generators.nixosGenerate {
    #   system = "x86_64-linux";
    #   format = "iso";
    #   specialArgs = {
    #     inherit inputs;
    #   };
    #   modules = [
    #     "${inputs.nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
    #     ./images/iso.nix
    #     ./hosts/controlplane0.nix
    #     {
    #       system.stateVersion = "25.11";
    #     }
    #   ];
    # };
  };
}