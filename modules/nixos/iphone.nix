# iphone <-> linux bridge (rice.iphone.*), default OFF, switched on per host.
# three legs, which is everything apple permits from linux:
#   usb: usbmuxd + libimobiledevice + ifuse (pair, mount media for yazi, tether)
#   wifi: kdeconnect (file/photo transfer, manual clipboard pushes; the ios app
#         cannot mirror notifications, apple sandboxes the notification stream)
#   ble: ancs4linux (real notification mirroring via ANCS, the apple-watch path)
# deps: pkgs.ancs4linux (pkgs/ancs4linux, additions overlay), bluetooth enabled
# in the host layer (tuna: strix-halo.nix, the mt7925 combo die).
{
  config,
  lib,
  pkgs,
  username,
  ...
}:
let
  cfg = config.rice.iphone;
in
{
  options.rice.iphone.enable = lib.mkEnableOption "iphone integration (usb, kdeconnect, ANCS notifications)";

  config = lib.mkIf cfg.enable {
    # usb leg. usbmuxd owns the device socket; tethering rides NM once trusted.
    services.usbmuxd.enable = true;
    environment.systemPackages = with pkgs; [
      libimobiledevice
      ifuse
      ancs4linux
    ];

    # wifi leg. opens 1714-1764 tcp+udp so the ios app can discover the box.
    programs.kdeconnect.enable = true;

    # ble leg, system half: observer tracks connected ANCS devices, advertising
    # exposes the box as a BLE peripheral the phone can connect to. both run as
    # root and claim system dbus names (policies ship in the package).
    services.dbus.packages = [ pkgs.ancs4linux ];
    systemd.services.ancs4linux-observer = {
      description = "ancs4linux observer daemon";
      requires = [ "bluetooth.service" ];
      after = [ "bluetooth.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "dbus";
        BusName = "ancs4linux.Observer";
        ExecStart = "${pkgs.ancs4linux}/bin/ancs4linux-observer";
      };
    };
    systemd.services.ancs4linux-advertising = {
      description = "ancs4linux advertising daemon";
      requires = [ "bluetooth.service" ];
      after = [ "bluetooth.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "dbus";
        BusName = "ancs4linux.Advertising";
        ExecStart = "${pkgs.ancs4linux}/bin/ancs4linux-advertising";
      };
    };

    # upstream's dbus policy gates client access behind this group; the user
    # needs it for ancs4linux-ctl and the session daemon below.
    users.groups.ancs4linux = { };
    users.users.${username}.extraGroups = [ "ancs4linux" ];

    # ble leg, session half: turns ANCS events into freedesktop notifications
    # (lands in wired-notify on the niri rice).
    systemd.user.services.ancs4linux-desktop-integration = {
      description = "ancs4linux desktop integration daemon";
      after = [ "graphical-session.target" ];
      partOf = [ "graphical-session.target" ];
      wantedBy = [ "graphical-session.target" ];
      serviceConfig.ExecStart = "${pkgs.ancs4linux}/bin/ancs4linux-desktop-integration";
    };
  };
}
