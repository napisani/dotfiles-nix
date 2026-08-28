# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  # Declarative on/off for the reconcile timer. Set to false to build the unit
  # but NOT schedule it (e.g. during migration, to run it once by hand first),
  # then flip to true and rebuild to activate — no `systemctl` needed.
  gitopsSyncTimerEnabled = true;

  # Nix-managed entrypoint so a script always exists to run even before the
  # monorepo is cloned. It clones on first run, then hands off to the
  # versioned reconcile script that lives inside the repo's
  # priv/kube-home-lab/ subdirectory (deploy/host-sync.sh). This is a
  # dedicated automated checkout — separate from any interactive ~/code/monorepo
  # checkout on this host — since it gets an unattended `git reset --hard`
  # every tick and must never contain hand edits.
  gitopsSyncBootstrap = pkgs.writeShellScript "gitops-sync-bootstrap" ''
    set -euo pipefail
    REPO_DIR="''${REPO_DIR:-$WORKSPACE/repo}"
    REPO_SUBDIR="''${REPO_SUBDIR:-priv/kube-home-lab}"
    branch="''${REPO_BRANCH:-main}"
    sentinel="$WORKSPACE/last-processed-commit"
    # Dedicated gitops topic, matching host-sync.ts's getNotifyTopic("gitops-sync")
    # default — this is a GitOps reconcile, not a backup job, so it must not land
    # on the shared /backups channel.
    NTFY_TOPIC="''${NTFY_TOPIC:-https://ntfy.napisani.xyz/gitops-sync}"
    TAG="[gitops-sync]"

    notify() {
      curl -fsS -d "message=$(date -Is) $TAG $*" "$NTFY_TOPIC" >/dev/null 2>&1 || true
    }

    if [ ! -d "$REPO_DIR/.git" ]; then
      mkdir -p "$(dirname "$REPO_DIR")"
      ${pkgs.git}/bin/git clone "$REPO_URL" "$REPO_DIR"
    fi

    # Cheap pre-gate: only pay for `nix develop` + a reconcile when the tracked
    # branch points at a commit we have not already processed successfully.
    # host-sync.ts writes "$sentinel" on success, so unchanged ticks stop here.
    # Note this compares the whole-monorepo branch tip, not just
    # priv/kube-home-lab/ — host-sync.ts does the path-scoped check that
    # actually decides whether to run the reconcile stages.
    ${pkgs.git}/bin/git -C "$REPO_DIR" fetch --quiet origin "$branch"
    target=$(${pkgs.git}/bin/git -C "$REPO_DIR" rev-parse "origin/$branch")
    if [ "$target" = "$(cat "$sentinel" 2>/dev/null || true)" ]; then
      exit 0
    fi

    # Reset before entering the dev shell so `nix develop` evaluates the latest
    # flake. The kube-home-lab flake devShell owns the reconcile toolchain
    # (deno, kubectl, helm, git, docker, curl); run the script inside it so
    # those deps are defined once in the project, not duplicated on this host.
    ${pkgs.git}/bin/git -C "$REPO_DIR" reset --hard --quiet "$target"

    # Don't notify on START/SUCCESS here: the whole-monorepo pre-gate above
    # passes for any monorepo commit (docs, dotfiles-nix, …), but host-sync.ts
    # then does the path-scoped check and no-ops when priv/kube-home-lab is
    # unchanged — so a bootstrap-level SUCCESS would fire on every unrelated
    # commit. host-sync.ts already emits an ntfy "Applied commit …" only when
    # it actually reconciles, plus per-stage "FAILED …" notifications. Keep
    # just the ERROR backstop here for the case where `nix develop` fails to
    # even enter the shell (host-sync.ts never runs, so it can't self-report).
    if ! ${config.nix.package}/bin/nix develop "$REPO_DIR/$REPO_SUBDIR" \
      --command ${pkgs.bash}/bin/bash "$REPO_DIR/$REPO_SUBDIR/deploy/host-sync.sh"; then
      status=$?
      notify "ERROR GitOps sync failed (exit ''${status}) (''${branch} ''${target:0:8})"
      exit "''${status}"
    fi
  '';

  secretInject = inputs.secret_inject.packages.${pkgs.stdenv.hostPlatform.system}.default;

  # Services own their runtime environment. Do not couple unattended GitOps to
  # interactive shell startup: fetch and evaluate secret_inject's shell-safe
  # exports immediately before executing the Nix-managed bootstrap.
  gitopsSyncEntrypoint = pkgs.writeShellScript "gitops-sync-with-secrets" ''
    set -euo pipefail
    _secret_exports="$(${secretInject}/bin/secret_inject)"
    eval "$_secret_exports"
    unset _secret_exports
    exec ${gitopsSyncBootstrap}
  '';
in
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
  # /boot is a small 487M partition; unbounded generations filled it to 100%
  # and blocked the bootloader install step entirely. Cap how many are kept.
  boot.loader.systemd-boot.configurationLimit = 5;

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
    settings = {
      global = {
        "security" = "user";
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

  # ─── Tailscale Subnet Router ──────────────────────────────────────────
  # Replaces the k8s StatefulSet approach. Tailscale runs directly on the
  # host, advertising the LAN subnet so remote peers can reach
  # *.napisani.xyz → 192.168.1.51 without DNS hacks.
  services.tailscale = {
    enable = true;
    openFirewall = true;

    # Handles net.ipv4.ip_forward and net.ipv6.conf.all.forwarding automatically.
    useRoutingFeatures = "server";

    # For fully automated provisioning, uncomment when you have your key:
    # authKeyFile = "/etc/nixsecrets/tailscale-authkey";
    # extraUpFlags = [
    #   "--advertise-routes=192.168.1.0/24"
    #   "--accept-routes"
    # ];
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
  networking.firewall.trustedInterfaces = [ "tailscale0" ];
  services.k3s.enable = true;
  services.k3s.role = "server";
  services.k3s.extraFlags = toString [
    # "--kubelet-arg=v=4" # Optionally add additional args to k3s
    # "--no-deploy traefik"
    "--disable traefik"
  ];

  # ─── GitOps sync (host-side reconcile) ────────────────────────────────────
  # Replaces the in-cluster gitops-sync CronJob. Runs deploy/host-sync.sh from
  # the monorepo's priv/kube-home-lab/ subdirectory on a timer: pull -> build
  # custom images (host Docker) -> cdk8s synth -> helm infra -> kubectl apply
  # -> prune (home only). The standalone napisani/kube-home-lab repo is retired;
  # this clones napisani/monorepo directly (see docs/contracts/gitops-sync.md).
  #
  # Runs as `nick`, with credentials injected by the service-owned entrypoint
  # immediately before the reconcile bootstrap. Shell startup remains strictly
  # user-facing and is not an implicit dependency of this unattended unit.
  # As nick it uses ~/.kube/config (the k3s admin config) and the docker group,
  # so no root/kubeconfig-file wiring is needed. The reconcile toolchain is owned
  # by the kube-home-lab flake devShell (entered via `nix develop` on the
  # checkout's priv/kube-home-lab subdirectory), so this host only needs git +
  # nix to bootstrap.
  systemd.services.gitops-sync = {
    description = "kube-home-lab GitOps reconcile (git -> build -> apply)";
    after = [
      "k3s.service"
      "docker.service"
      "network-online.target"
    ];
    wants = [ "network-online.target" ];

    # Only the bootstrap essentials live here; the reconcile toolchain (deno,
    # kubectl, helm, docker, curl, …) is owned by the kube-home-lab flake's
    # devShell, which the bootstrap enters via `nix develop`.
    path = [
      pkgs.git # clone/fetch the repo before entering the dev shell
      pkgs.curl # ntfy notifications
      config.nix.package # `nix develop` to run inside the project's devShell
    ];

    serviceConfig = {
      Type = "oneshot";
      User = "nick"; # ~/.kube/config, keyring, and docker group access
      # Persistent workspace: repo checkout, deno cache, helm cache.
      StateDirectory = "gitops-sync";
      Environment = [
        "WORKSPACE=/var/lib/gitops-sync" # deno cache, image-tags.env (persistent state)
        "REPO_DIR=/home/nick/code/monorepo-gitops-sync" # dedicated automated monorepo checkout (not ~/code/monorepo)
        "REPO_SUBDIR=priv/kube-home-lab" # project root within the checkout
        "HOME=/home/nick" # secret_inject config/cache and user-scoped tool state
        "DENO_DIR=/var/lib/gitops-sync/deno"
        "REPO_URL=https://github.com/napisani/monorepo"
        "REPO_BRANCH=main"
        "GITOPS_SYNC_PRUNE_MODE=delete"
        "IMAGE_DELIVERY=push" # push to registry (import mode would require running as root)
      ];
      ExecStart = gitopsSyncEntrypoint;
    };
  };

  # A oneshot won't start a second activation while one is still running, so
  # this is the systemd equivalent of the CronJob's concurrencyPolicy: Forbid.
  systemd.timers.gitops-sync = {
    # wantedBy drives scheduling declaratively: [] = built but dormant,
    # [ "timers.target" ] = active. Flip gitopsSyncTimerEnabled + rebuild.
    wantedBy = lib.optionals gitopsSyncTimerEnabled [ "timers.target" ];
    timerConfig = {
      OnBootSec = "3min";
      OnUnitActiveSec = "5min"; # cadence (cron-equivalent: OnCalendar = "*:0/5")
      RandomizedDelaySec = "30s";
      Persistent = true; # run once on next boot if a tick was missed while off
    };
  };

  # Enable cron service
  services.cron = {
    enable = true;
    systemCronJobs = [
      # Note: database backups (postgres, mongodb) are now defined as
      # Kubernetes CronJobs in the kube-home-lab repo (see
      # src/namespaces/home/apps/{postgres,mongodb}.ts)
      "10 1 * * *      root    rsync -rlv --delete /home/nick/ /media/storage/computer_backups/supermicro/home"

    ];

  };

}
