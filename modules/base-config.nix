# images/base-config.nix
{ lib
  , pkgs
  , config
  , ...
}:
{
  imports = [
    # ../modules/base-system.nix
    # ../modules/services/numlock-on-tty
  ];

  networking.hostName = lib.mkDefault "nixos-live";

  # boot.supportedFilesystems = [ "zfs" "f2fs" ];

  users.mutableUsers = false;
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIH0gvAJBj4c6c8RRQ+mX3i1Ims03XPztG/+Ju63PSRm4 ssh@momme.world"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFe4TuSO+XGsRnRJ1HQum9UmKnkeVgbm9454XsWcjJ2Z pve@momme.world"
  ];

  environment.etc."ssh/ssh_host_rsa_key".mode = lib.mkIf (config.environment.etc."ssh/ssh_host_rsa_key" ? text) "0600";
  environment.etc."ssh/ssh_host_ed25519_key".mode = lib.mkIf (config.environment.etc."ssh/ssh_host_ed25519_key" ? text) "0600";

  # sshd
  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
    settings.PermitRootLogin = "prohibit-password";
    hostKeys = [
      { type = "rsa"; bits = 4096; path = "/etc/ssh/ssh_host_rsa_key"; }
      { type = "ed25519"; path = "/etc/ssh/ssh_host_ed25519_key"; }
    ];
  };

  # Turn on flakes.
  nix.package = pkgs.nixVersions.stable;
  nix.extraOptions = ''
    experimental-features = nix-command flakes
  '';

  # includes this flake in the live iso : "/etc/nixcfg"
  environment.etc.nixcfg.source =
    builtins.filterSource
      (path: type:
        baseNameOf path
        != ".git"
        && type != "symlink"
        && !(pkgs.lib.hasSuffix ".qcow2" path)
        && baseNameOf path != "secrets")
      ../.;

  environment.systemPackages = with pkgs; [
    git
    htop
    tmux
    tree
    nano
    rsync
    ripgrep
    cryptsetup
    nixpkgs-fmt
  ];

  ## FIX for running out of space / tmp, which is used for building
  fileSystems."/nix/.rw-store" = {
    fsType = "tmpfs";
    options = [ "mode=0755" "nosuid" "nodev" "relatime" "size=14G" ];
    neededForBoot = true;
  };

  # Part of base-system.nix:
  # environment.variables = {
  #   TERM = "xterm-256color";
  # };

  # # Use a high-res font.
  # boot.loader.systemd-boot.consoleMode = "0";
  time.timeZone = "Europe/Berlin";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "de_DE.UTF-8";
    LC_IDENTIFICATION = "de_DE.UTF-8";
    LC_MEASUREMENT = "de_DE.UTF-8";
    LC_MONETARY = "de_DE.UTF-8";
    LC_NAME = "de_DE.UTF-8";
    LC_NUMERIC = "de_DE.UTF-8";
    LC_PAPER = "de_DE.UTF-8";
    LC_TELEPHONE = "de_DE.UTF-8";
    LC_TIME = "de_DE.UTF-8";
  };

  services.xserver.xkb = {
    layout = "de";
    variant = "";
  };
  console.keyMap = "de";
  # console = {
  #   # https://github.com/NixOS/nixpkgs/issues/114698
  #   # earlySetup = true; # Sets the font size much earlier in the boot process
  #   # colors = [
  #   #   # # frappe colors
  #   #   "51576d"
  #   #   "e78284"
  #   #   "a6d189"
  #   #   "e5c890"
  #   #   "8caaee"
  #   #   "f4b8e4"
  #   #   "81c8be"
  #   #   "b5bfe2"
  #   #   "626880"
  #   #   "e78284"
  #   #   "a6d189"
  #   #   "e5c890"
  #   #   "8caaee"
  #   #   "f4b8e4"
  #   #   "81c8be"
  #   #   "a5adce"
  #   # ];
  #   keyMap = "de";
  #   font = "Lat2-Terminus16";
  #   useXkbConfig = true; # Use same config for linux console
  # };

  # services.xserver = {
  #   enable = lib.mkDefault false; # but still here so we can copy the XKB config to TTYs
  #   autoRepeatDelay = 300;
  #   autoRepeatInterval = 35;
  # } // lib.optionalAttrs false {
  #   xkbVariant = "colemak";
  #   xkbOptions = "caps:super,compose:ralt,shift:both_capslock";
  # };
}