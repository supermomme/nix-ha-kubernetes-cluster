{ ... }: {
  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
    settings.KbdInteractiveAuthentication = false;
    settings.PermitRootLogin = "no";

  };
  networking.firewall.allowedTCPPorts = [ 22 ];
}