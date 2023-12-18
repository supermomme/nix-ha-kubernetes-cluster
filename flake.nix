{
  description = "Nixos config flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, ... }@inputs:
    {
    
      nixosConfigurations = {
        # nix shell nixpkgs#nixos-rebuild --command nixos-rebuild switch --fast --use-remote-sudo --flake .#utm-nixos1 --target-host momme@10.211.55.9 --build-host momme@10.211.55.9
        # nixos-rebuild switch --flake .#utm-nixos1
        utm-nixos1 = nixpkgs.lib.nixosSystem {
          specialArgs = {inherit inputs;};
          modules = [ 
            ./hosts/utm-nixos1/configuration.nix
            ./common/common.nix
            ./common/sops.nix
            ./common/users.nix
            ./common/openssh.nix
            ./common/tailscale.nix
            ./common/firewall.nix
            # inputs.home-manager.nixosModules.default
          ];
        };

        # nix shell nixpkgs#nixos-rebuild --command nixos-rebuild switch --fast --use-remote-sudo --flake .#utm-nixos2 --target-host momme@10.211.55.10 --build-host momme@10.211.55.10
        # nixos-rebuild switch --flake .#utm-nixos2
        utm-nixos2 = nixpkgs.lib.nixosSystem {
          specialArgs = {inherit inputs;};
          modules = [ 
            ./hosts/utm-nixos2/configuration.nix
            ./common/common.nix
            ./common/sops.nix
            ./common/users.nix
            ./common/openssh.nix
            ./common/tailscale.nix
            ./common/firewall.nix
            # inputs.home-manager.nixosModules.default
          ];
        };

        # nix shell nixpkgs#nixos-rebuild --command nixos-rebuild switch --fast --use-remote-sudo --flake .#utm-nixos3 --target-host root@10.211.55.11 --build-host root@10.211.55.11
        # nixos-rebuild switch --flake .#utm-nixos3
        utm-nixos3 = nixpkgs.lib.nixosSystem {
          specialArgs = {inherit inputs;};
          modules = [ 
            ./hosts/utm-nixos3/configuration.nix
            ./common/common.nix
            ./common/sops.nix
            ./common/users.nix
            ./common/openssh.nix
            ./common/tailscale.nix
            ./common/firewall.nix
            # inputs.home-manager.nixosModules.default
          ];
        };
      };
    };
}
