{ pkgs ? import <nixpkgs> {} }:
let
  build = flake: ssh: pkgs.writeShellScriptBin "build-${flake}" ''
    ${pkgs.nixos-rebuild}/bin/nixos-rebuild switch --fast --use-remote-sudo --flake .#${flake} --target-host ${ssh} --build-host ${ssh}
  '';
in pkgs.mkShell {
  nativeBuildInputs = with pkgs.buildPackages; [
    (build "utm-nixos1" "momme@10.211.55.9")
    (build "utm-nixos2" "momme@10.211.55.10")
    (build "utm-nixos3" "momme@10.211.55.11")
    (pkgs.writeShellScriptBin "make-certs" ''
      $(nix-build --no-out-link scripts/certs)/bin/generate-certs
    '')
  ];
  packages = [
    pkgs.cfssl
    pkgs.nixos-rebuild
  ];
}