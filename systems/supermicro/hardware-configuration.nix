# Do not modify this file!  It was generated by ‘nixos-generate-config’
# and may be overwritten by future invocations.  Please make changes
# to /etc/nixos/configuration.nix instead.
{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot.initrd.availableKernelModules =
    [ "xhci_pci" "ahci" "usbhid" "usb_storage" "sd_mod" ];
  boot.initrd.kernelModules = [ "dm-snapshot" ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/cf99254f-ae54-43ce-a5c7-111d0689bbec";
    fsType = "ext4";
  };

  fileSystems."/media/temp" = {
    device = "/dev/disk/by-uuid/6e4ebf4b-9fa8-438f-bd10-747bbd8c3128";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/C700-7B4B";
    fsType = "vfat";
    options = [ "fmask=0077" "dmask=0077" ];
  };

  # fileSystems."/media/storage" = {
  #   device = "//192.168.0.29/storage";
  #   fsType = "cifs";
  #   options = [
  #     "username=admin"
  #     (builtins.readFile /etc/nixsecrets/storage-mount.txt)
  #     "rw"
  #     "nounix"
  #     "iocharset=utf8"
  #     "file_mode=0777"
  #     "dir_mode=0777 0 0"
  #   ];
  # };

  fileSystems."/media/storage" = {

    # Your existing mount options here, plus:
    device = "storagepool/storage";
    fsType = "zfs";
  };

  swapDevices =
    [{ device = "/dev/disk/by-uuid/1cfc05f1-af75-403a-b92c-cd3e2fca4efe"; }];

  # Enables DHCP on each ethernet and wireless interface. In case of scripted networking
  # (the default) this is the recommended approach. When using systemd-networkd it's
  # still possible to use this option, but it's recommended to use it in conjunction
  # with explicit per-interface declarations with `networking.interfaces.<interface>.useDHCP`.
  networking.useDHCP = lib.mkDefault true;
  # networking.interfaces.eno1.useDHCP = lib.mkDefault true;
  # networking.interfaces.eno2.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode =
    lib.mkDefault config.hardware.enableRedistributableFirmware;
}
