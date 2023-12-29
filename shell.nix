{ pkgs ? import <nixpkgs> {} }:
let
  build = flake: ssh: pkgs.writeShellScriptBin "build-${flake}" ''
    ${pkgs.nixos-rebuild}/bin/nixos-rebuild switch --fast --use-remote-sudo --flake .#${flake} --target-host ${ssh} --build-host ${ssh}
  '';
in pkgs.mkShell {
  buildInputs = with pkgs.buildPackages; [
    (pkgs.writeShellScriptBin "make-certs" ''
      $(nix-build --no-out-link scripts/certs)/bin/generate-certs
    '')
  ];
}
