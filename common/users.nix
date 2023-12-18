{ pkgs, ... }: {
  security.sudo.wheelNeedsPassword = false;
  users.users.momme = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    packages = with pkgs; [
  #     firefox
  #     tree

    ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPGZ1R2leDvakw36bFBa9U7IQruW6DjbHahHfZqTerD6"
    ];
  };
}