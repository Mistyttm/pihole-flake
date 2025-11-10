{ config, lib, ... }:
{
  options.services.pihole.container = {
    user = lib.mkOption {
      type = lib.types.str;
      description = "Username that runs the Pi-hole container. Must have `subUidRanges` and `subGidRanges` configured for rootless podman.";
      example = "pihole";
    };

    enableLingering = lib.mkOption {
      type = lib.types.oneOf [
        lib.types.bool
        (lib.types.enum [ "suppressWarning" ])
      ];
      description = "Enable systemd lingering to ensure the container starts at boot even when the user is not logged in. Set to `\"suppressWarning\"` if lingering is managed externally.";
      default = false;
      example = true;
    };

    name = lib.mkOption {
      type = lib.types.str;
      description = "Name of the Podman container running Pi-hole. Must be unique if running multiple instances.";
      default = "pihole_${config.services.pihole.container.user}";
      defaultText = lib.literalExpression ''"pihole_''${config.services.pihole.container.user}"'';
      example = "pihole-dns";
    };

    persistVolumes = lib.mkOption {
      type = lib.types.bool;
      description = "Enable persistent storage for Pi-hole configuration and data. When disabled, all configuration is lost on container restart (useful for testing).";
      default = false;
      example = true;
    };

    volumesPath = lib.mkOption {
      type = lib.types.str;
      description = "Directory where Pi-hole's persistent data is stored (`/etc/pihole` and `/etc/dnsmasq.d`). Must be writable by the container user. Created automatically if it doesn't exist.";
      default = "${config.users.users.${config.services.pihole.container.user}.home}/pihole-volumes";
      defaultText = lib.literalExpression ''"''${config.users.users.''${config.services.pihole.container.user}.home}/pihole-volumes"'';
      example = "/var/lib/pihole-volumes";
    };

    dnsPort = lib.mkOption {
      type = lib.types.nullOr (lib.types.either lib.types.port lib.types.str);
      description = "Port for DNS service (TCP and UDP). Standard is 53, but rootless containers need privileged port setup for ports <1024. Format: port number (e.g., `53`) or `\"ip:port\"` (e.g., `\"192.168.1.2:53\"`). Set to `null` to not expose DNS.";
      default = null;
      example = lib.literalExpression ''"192.168.1.2:53"'';
    };

    dhcpPort = lib.mkOption {
      type = lib.types.nullOr (lib.types.either lib.types.port lib.types.str);
      description = "Port for DHCP service (UDP). Must be 67 for DHCP to work, requires privileged port setup. Format: port number (e.g., `67`) or `\"ip:port\"` (e.g., `\"192.168.1.1:67\"`). Only needed if DHCP is enabled.";
      default = null;
      example = 67;
    };

    webPort = lib.mkOption {
      type = lib.types.nullOr (lib.types.either lib.types.port lib.types.str);
      description = "Port for web administration interface (HTTP). Standard is 80, or use 8080+ for rootless without special setup. Format: port number (e.g., `8080`) or `\"ip:port\"` (e.g., `\"127.0.0.1:8080\"`).";
      default = null;
      example = 8080;
    };

    suppressTmpDirWarning = lib.mkOption {
      type = lib.types.bool;
      description = "Suppress warning about rootless Podman leaving files in `/tmp` that can prevent container startup after reboot. Only set to `true` if you've configured `/tmp` cleanup (e.g., `boot.tmp.cleanOnBoot = true`).";
      default = false;
      example = true;
    };
  };
}
