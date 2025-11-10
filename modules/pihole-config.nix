{ config, lib, ... }:
let
  systemTimeZone = config.time.timeZone;
  mkContainerEnvOption =
    { envVar, ... }@optionAttrs:
    (lib.mkOption (removeAttrs optionAttrs [ "envVar" ])) // { inherit envVar; };
in
{
  options.services.pihole = {
    timezone = mkContainerEnvOption {
      type = lib.types.str;
      description = "Timezone for Pi-hole's internal clock and log rotation. Ensures logs rotate at local midnight.";
      default = systemTimeZone;
      defaultText = lib.literalExpression "config.time.timeZone";
      example = "Europe/Amsterdam";
      envVar = "TZ";
    };

    interface = mkContainerEnvOption {
      type = lib.types.str;
      description = "Network interface inside the container for DNS queries. Default works with standard Podman networking.";
      default = "tap0";
      example = "eth0";
      envVar = "INTERFACE";
    };

    web = {
      password = mkContainerEnvOption {
        type = lib.types.nullOr lib.types.str;
        description = "Plain-text password for web interface. WARNING: Stored in Nix store (world-readable). Use `passwordFile` instead for secure storage. If `null`, a random password is generated (check logs).";
        default = null;
        example = "changeme123";
        envVar = "WEBPASSWORD";
      };

      passwordFile = lib.mkOption {
        type = lib.types.str;
        description = "Path to file containing the admin password. Recommended over `password` option for security. File must be readable by the container user.";
        default = "";
        example = "/run/secrets/pihole-admin-password";
      };

      virtualHost = mkContainerEnvOption {
        type = lib.types.str;
        description = "Virtual hostname for accessing the web interface. Allows admin access via custom hostname in addition to `http://pi.hole/admin/`.";
        example = "pihole.example.com";
        envVar = "VIRTUAL_HOST";
      };

      layout = mkContainerEnvOption {
        type = lib.types.enum [
          "boxed"
          "traditional"
        ];
        description = "Web interface layout style. `boxed` is modern (better for large screens), `traditional` is full-width.";
        default = "boxed";
        example = "traditional";
        envVar = "WEBUIBOXEDLAYOUT";
      };

      theme = mkContainerEnvOption {
        type = lib.types.enum [
          "default-dark"
          "default-darker"
          "default-light"
          "default-auto"
          "lcars"
        ];
        description = "Web interface color theme. Options: light, dark, darker, auto (matches system), or lcars (Star Trek inspired).";
        default = "default-light";
        example = "default-dark";
        envVar = "WEBTHEME";
      };
    };

    dns = {
      upstreamServers = mkContainerEnvOption {
        type = lib.types.nullOr (lib.types.listOf lib.types.str);
        description = "Upstream DNS servers for forwarding non-blocked queries. Supports custom ports (`\"127.0.0.1#5353\"`), IPv6, and Docker service names. If set, this becomes the sole management method (web interface changes are overwritten on restart).";
        default = null;
        example = lib.literalExpression ''[ "1.1.1.1" "1.0.0.1" ]'';
        envVar = "PIHOLE_DNS_";
      };

      dnssec = mkContainerEnvOption {
        type = lib.types.bool;
        description = "Enable DNSSEC validation to protect against DNS spoofing. Requires DNSSEC-supporting upstream servers.";
        default = false;
        example = true;
        envVar = "DNSSEC";
      };

      bogusPriv = mkContainerEnvOption {
        type = lib.types.bool;
        description = "Never forward reverse DNS lookups for private IP ranges to upstream servers (improves privacy).";
        default = true;
        example = false;
        envVar = "DNS_BOGUS_PRIV";
      };

      fqdnRequired = mkContainerEnvOption {
        type = lib.types.bool;
        description = "Never forward non-fully-qualified domain names (e.g., `server` vs `server.example.com`) to upstream DNS.";
        default = true;
        example = false;
        envVar = "DNS_FQDN_REQUIRED";
      };
    };

    revServer = {
      enable = mkContainerEnvOption {
        type = lib.types.bool;
        description = "Enable conditional forwarding to show device hostnames instead of IPs in Pi-hole's query logs. Requires `domain`, `target`, and `cidr` to be set.";
        default = false;
        example = true;
        envVar = "REV_SERVER";
      };

      domain = mkContainerEnvOption {
        type = lib.types.nullOr lib.types.str;
        description = "Local network domain name for conditional forwarding (e.g., `\"lan\"`, `\"home.arpa\"`).";
        default = null;
        example = "lan";
        envVar = "REV_SERVER_DOMAIN";
      };

      target = mkContainerEnvOption {
        type = lib.types.nullOr lib.types.str;
        description = "Router IP address for conditional forwarding (your network's default gateway).";
        default = null;
        example = "192.168.1.1";
        envVar = "REV_SERVER_TARGET";
      };

      cidr = mkContainerEnvOption {
        type = lib.types.nullOr lib.types.str;
        description = "Network range in CIDR notation for conditional forwarding (e.g., `\"192.168.1.0/24\"`).";
        default = null;
        example = "192.168.1.0/24";
        envVar = "REV_SERVER_CIDR";
      };
    };

    ftl = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      description = "Advanced FTL (Faster Than Light) DNS engine options. See https://docs.pi-hole.net/ftldns/configfile for all options. Common: `LOCAL_IPV4`, `PRIVACYLEVEL`, `BLOCK_ICLOUD_PR`, `RATE_LIMIT`.";
      example = lib.literalExpression ''{ LOCAL_IPV4 = "192.168.0.100"; PRIVACYLEVEL = "0"; }'';
      default = { };
    };

    dhcp = {
      enable = mkContainerEnvOption {
        type = lib.types.bool;
        description = "Enable Pi-hole's built-in DHCP server. Requires `start`, `end`, `router`, and `container.dhcpPort = 67`. WARNING: Disable your router's DHCP first - only one DHCP server should run on a network.";
        default = false;
        example = true;
        envVar = "DHCP_ACTIVE";
      };

      start = mkContainerEnvOption {
        type = lib.types.nullOr lib.types.str;
        description = "Starting IP address for DHCP range. Required when DHCP is enabled.";
        default = null;
        example = "192.168.1.10";
        envVar = "DHCP_START";
      };

      end = mkContainerEnvOption {
        type = lib.types.nullOr lib.types.str;
        description = "Ending IP address for DHCP range. Required when DHCP is enabled.";
        default = null;
        example = "192.168.1.250";
        envVar = "DHCP_END";
      };

      router = mkContainerEnvOption {
        type = lib.types.nullOr lib.types.str;
        description = "Router (gateway) IP address provided to DHCP clients. Required when DHCP is enabled.";
        default = null;
        example = "192.168.1.1";
        envVar = "DHCP_ROUTER";
      };

      leasetime = mkContainerEnvOption {
        type = lib.types.int;
        description = "DHCP lease duration in hours. Common values: 12 (dynamic networks), 24 (default), 168 (1 week for stable networks).";
        default = 24;
        example = 12;
        envVar = "DHCP_LEASETIME";
      };

      domain = mkContainerEnvOption {
        type = lib.types.str;
        description = "Local domain name provided to DHCP clients (e.g., `\"lan\"`, `\"home.arpa\"`).";
        default = "lan";
        example = "home.arpa";
        envVar = "PIHOLE_DOMAIN";
      };

      ipv6 = mkContainerEnvOption {
        type = lib.types.bool;
        description = "Enable IPv6 support in DHCP server (SLAAC + Router Advertisement).";
        default = false;
        example = true;
        envVar = "DHCP_IPv6";
      };

      rapid-commit = mkContainerEnvOption {
        type = lib.types.bool;
        description = "Enable DHCPv4 rapid commit for faster address assignment (reduces negotiation from 4 to 2 messages).";
        default = false;
        example = true;
        envVar = "DHCP_rapid_commit";
      };
    };

    queryLogging = mkContainerEnvOption {
      type = lib.types.bool;
      description = "Enable logging of all DNS queries. Disable for privacy or to reduce disk I/O on high-traffic networks.";
      default = true;
      example = false;
      envVar = "QUERY_LOGGING";
    };

    temperatureUnit = mkContainerEnvOption {
      type = lib.types.enum [
        "c"
        "k"
        "f"
      ];
      description = "Temperature unit for system temperature display in web interface (Celsius, Kelvin, or Fahrenheit).";
      default = "c";
      example = "f";
      envVar = "TEMPERATUREUNIT";
    };
  };
}
