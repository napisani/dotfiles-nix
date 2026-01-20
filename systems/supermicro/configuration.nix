# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ../../mods/system-packages.nix
    # ../mods/shell.nix
    # ../mods/git.nix
    # ../mods/gh.nix
    # ../mods/rust.nix
    # ../mods/javascript.nix
    # ../mods/golang.nix
    # ../mods/neovim.nix
  ];
  networking.nameservers = [
    "8.8.8.8"
    "9.9.9.9"
  ];
  # Use the GRUB 2 boot loader.
  # boot.loader.grub.enable = true;

  boot.loader.systemd-boot.enable = true;

  # disable sleep
  systemd.targets.sleep.enable = false;
  systemd.targets.suspend.enable = false;
  systemd.targets.hibernate.enable = false;
  systemd.targets.hybrid-sleep.enable = false;

  # enable zfs
  boot.supportedFilesystems = [ "zfs" ];
  boot.zfs.forceImportRoot = false;
  networking.hostId = "14ad4931";

  # Add the sysctl parameter for inotify max_user_instances
  boot.kernel.sysctl = {
    "fs.inotify.max_user_instances" = 512;
  };
  # boot.loader.grub.efiSupport = true;
  # boot.loader.grub.efiInstallAsRemovable = true;
  # boot.loader.efi.efiSysMountPoint = "/boot/efi";
  # Define on which hard drive you want to install Grub.
  # boot.loader.grub.device = "/dev/sda"; # or "nodev" for efi only

  # Select internationalisation properties.
  # i18n.defaultLocale = "en_US.UTF-8";
  # console = {
  #   font = "Lat2-Terminus16";
  #   keyMap = "us";
  #   useXkbConfig = true; # use xkb.options in tty.
  # };

  # Enable the X11 windowing system.
  # services.xserver.enable = true;

  # Configure keymap in X11
  # services.xserver.xkb.layout = "us";
  # services.xserver.xkb.options = "eurosign:e,caps:escape";

  # Enable CUPS to print documents.
  # services.printing.enable = true;

  # Enable sound.
  # hardware.pulseaudio.enable = true;
  # OR
  # services.pipewire = {
  #   enable = true;
  #   pulse.enable = true;
  # };

  # Enable touchpad support (enabled default in most desktopManager).
  # services.libinput.enable = true;
  virtualisation.docker.enable = true;

  users.groups = {
    kube-pods = {
      name = "kube-pods";
      gid = 1000;
    };
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.nick = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "docker"
      "kube-pods"
    ]; # Enable ‘sudo’ for the user.
    openssh.authorizedKeys.keys = [
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCtAGvt/B1nDT4FjDde2a5P91roW0QLqJU3aNrEdQ1zCcqPy+Hj39OXu1zc1i0TGOrZpBHReFqZn2Je8UAIzYpSqBSuxIiCFJvzsfkjeKF2HmWCECqBpNDxblp87DdoQv6sKqB9zroJ9CAnJS/+alLyNX2/JSNMvHt6dOQE5DF6QV3TlReEzFZx+E7nzOGDW7Ph6VhOzkqHNL6D68niOM0Slvj4wFTD+prZJe4Y5lFY6YI0y/UGvMqcnxicJhpiA5KqQgRrLqirtDI9MHk7sTxwVnGkOuBpn6sEZz+AncVhM37jhGvINN1FKiVAUP4iZ5cxAjHLhCI8yfCEy84ytSUEXWxwWO8uP7jHy0qCRO7cWhA7xSfHT7cGuGofY/MNgF85t2Bgj0NG36rtpd7XWj5QIn2S89c9MbIu+Zw9MYluHhyOsbi35KoC/e4HnJWtX2pe5TNwfi41wBWLkH1vET8cd9zLj7VT5SGiL0UhWA9As67G0jZ/1juGzJ/lj+DQBkU= olivetin@olivetin-f5bd7df78-5ncnp"
    ];
  };

  programs.nix-ld.enable = true;

  # programs.nix-ld.libraries = with pkgs;
  #   [

  #     # Add any missing dynamic libraries for unpackaged programs
  #     # here, NOT in environment.systemPackages
  #   ];
  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

  services.samba = {
    enable = true;
    nmbd.enable = true;
    openFirewall = true;
    securityType = "user";
    settings = {
      global = {
        "workgroup" = "WORKGROUP";
        "map to guest" = "Bad User";
        "server min protocol" = "SMB2";
        "unix password sync" = "yes";
        "pam password change" = "yes";
        "obey pam restrictions" = "yes";
        "passdb backend" = "tdbsam";
      };
      storage = {
        path = "/media/storage";
        comment = "Supermicro storage";
        browseable = "yes";
        "read only" = "no";
        "guest ok" = "no";
        "valid users" = "nick";
        "force user" = "nick";
        "create mask" = "0664";
        "directory mask" = "0775";
      };
    };
  };

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # Copy the NixOS configuration file and link it from the resulting system
  # (/run/current-system/configuration.nix). This is useful in case you
  # accidentally delete configuration.nix.
  # system.copySystemConfiguration = true;

  # This option defines the first version of NixOS you have installed on this particular machine,
  # and is used to maintain compatibility with application data (e.g. databases) created on older NixOS versions.
  #
  # Most users should NEVER change this value after the initial install, for any reason,
  # even if you've upgraded your system to a new NixOS release.
  #
  # This value does NOT affect the Nixpkgs version your packages and OS are pulled from,
  # so changing it will NOT upgrade your system - see https://nixos.org/manual/nixos/stable/#sec-upgrading for how
  # to actually do that.
  #
  # This value being lower than the current NixOS release does NOT mean your system is
  # out of date, out of support, or vulnerable.
  #
  # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
  # and migrated your data accordingly.
  #
  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "24.05"; # Did you read the comment?
  nix = {
    package = pkgs.nixVersions.latest;
    extraOptions = ''
      experimental-features = nix-command flakes
    '';
  };

  networking.hostName = "supermicro"; # Define your hostname.
  # Pick only one of the below networking options.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
  # networking.networkmanager.enable = true;  # Easiest to use and most distros use this by default.

  # Set your time zone.
  # time.timeZone = "Europe/Amsterdam";

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  networking.firewall.allowedTCPPorts = [
    80 # HTTP
    443 # HTTPS
    6443 # k3s: required so that pods can reach the API server (running on port 6443 by default)
    # 2379 # k3s, etcd clients: required if using a "High Availability Embedded etcd" configuration
    # 2380 # k3s, etcd peers: required if using a "High Availability Embedded etcd" configuration
    32400 # plex
  ];
  networking.firewall.allowedUDPPorts = [
    # 8472 # k3s, flannel: required if using multi-node for inter-node networking
    32400 # plex
    7359 # jellyfin local discovery
  ];
  services.k3s.enable = true;
  services.k3s.role = "server";
  services.k3s.extraFlags = toString [
    # "--kubelet-arg=v=4" # Optionally add additional args to k3s
    # "--no-deploy traefik"
    "--disable traefik"
  ];

  # Enable cron service
  services.cron = {
    enable = true;
    systemCronJobs = [
      "0 1 * * *      root    bash ~/.config/home-manager/mods/dotfiles/supermicro_scripts/backup_pgvector.sh"
      "1 1 * * *      root    bash ~/.config/home-manager/mods/dotfiles/supermicro_scripts/backup_postgres.sh"
      "2 1 * * *      root    bash ~/.config/home-manager/mods/dotfiles/supermicro_scripts/backup_mongo.sh"
      "10 1 * * *      root    rsync -rlv --delete /home/nick/ /media/storage/computer_backups/supermicro/home"

    ];

  };

}
