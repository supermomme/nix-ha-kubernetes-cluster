{ lib, pkgs, ... }:
let
  writeJSONText = name: obj: pkgs.writeText "${name}.json" (builtins.toJSON obj);

  csrDefaults = {
    key = {
      algo = "rsa";
      size = 2048;
    };
  };
in
{
  # Form a CSR request, as expected by cfssl
  mkCsr = name: { cn, altNames ? [ ], organization ? null }:
    writeJSONText name (lib.attrsets.recursiveUpdate csrDefaults {
      CN = cn;
      hosts = [ cn ] ++ altNames;
      names = if organization == null then null else [
        { "O" = organization; }
      ];
    });
}
