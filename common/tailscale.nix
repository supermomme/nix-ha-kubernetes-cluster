{ lib, config, pkgs, ... }: {
  environment.systemPackages = [ pkgs.tailscale ];
  services.tailscale.enable = true;

  sops.secrets."tailscale_authkey" = { };
  systemd.services.tailscale-autoconnect = {
    description = "Automatic connection to Tailscale";
    after = [ "network-pre.target" "tailscale.service" ];
    wants = [ "network-pre.target" "tailscale.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig.Type = "oneshot";
    script = with pkgs; ''
      sleep 2
      status="$(${tailscale}/bin/tailscale status -json | ${jq}/bin/jq -r .BackendState)"
      if [ $status = "Running" ]; then # if so, then do nothing
        exit 0
      fi
      ${tailscale}/bin/tailscale up -authkey $(cat ${config.sops.secrets."tailscale_authkey".path})
    '';
  };

  networking.firewall.trustedInterfaces = [ "tailscale0" ];
  networking.firewall.allowedUDPPorts = [ config.services.tailscale.port ];
}
