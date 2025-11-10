# Configuration Examples

This page provides detailed configuration examples for common Pi-hole setups.

## Table of Contents

- [Basic Setup](#basic-setup)
- [IPv6 Configuration](#ipv6-configuration)
- [Custom Upstream DNS Servers](#custom-upstream-dns-servers)
- [DHCP Server Setup](#dhcp-server-setup)
- [Advanced Configurations](#advanced-configurations)
- [Complete Examples](#complete-examples)

## Basic Setup

### Minimal Configuration

The simplest possible Pi-hole setup with unprivileged ports:

```nix
{
  services.pihole = {
    enable = true;
    
    hostConfig = {
      user = "pihole";
      enableLingeringForUser = true;
      
      dnsPort = 5335;
      webPort = 8080;
    };
    
    piholeConfig.web.password = "admin123";  # Change this!
  };
  
  # Create the user
  users.users.pihole = {
    isNormalUser = true;
    description = "Pi-hole service user";
    autoSubUidGidRange = true;
  };
  
  # Open firewall
  networking.firewall = {
    allowedTCPPorts = [ 5335 8080 ];
    allowedUDPPorts = [ 5335 ];
  };
}
```

### With Persistent Storage

Keep your Pi-hole configuration across reboots:

```nix
{
  services.pihole = {
    enable = true;
    
    hostConfig = {
      user = "pihole";
      enableLingeringForUser = true;
      
      # Enable persistent volumes
      persistVolumes = true;
      volumesPath = "/var/lib/pihole-data";
      
      dnsPort = 5335;
      webPort = 8080;
    };
    
    piholeConfig.web.password = "admin123";
  };
  
  # Ensure directory exists
  systemd.tmpfiles.rules = [
    "d /var/lib/pihole-data 0755 pihole pihole -"
  ];
}
```

### Using Password File

More secure than hardcoding passwords:

```nix
{
  services.pihole = {
    enable = true;
    
    hostConfig = {
      user = "pihole";
      enableLingeringForUser = true;
      dnsPort = 5335;
      webPort = 8080;
    };
    
    piholeConfig.web.passwordFile = "/run/secrets/pihole-password";
  };
  
  # Using sops-nix or agenix
  sops.secrets.pihole-password = {
    owner = "pihole";
    mode = "0400";
  };
}
```

## IPv6 Configuration

### Basic IPv6 Support

Enable IPv6 DNS and DHCP:

```nix
{
  services.pihole = {
    enable = true;
    
    hostConfig = {
      user = "pihole";
      enableLingeringForUser = true;
      dnsPort = 5335;
      webPort = 8080;
    };
    
    piholeConfig = {
      # IPv6 upstream DNS
      dns.upstreamServers = [
        "1.1.1.1"           # IPv4
        "8.8.8.8"           # IPv4
        "2606:4700:4700::1111"  # IPv6 Cloudflare
        "2001:4860:4860::8888"  # IPv6 Google
      ];
      
      # Enable IPv6 DHCP
      dhcp.ipv6 = true;
      
      # FTL configuration for IPv6
      ftl = {
        # Listen on IPv6
        SOCKET_LISTENING = "all";
      };
    };
  };
  
  # Ensure IPv6 is enabled on the system
  networking.enableIPv6 = true;
}
```

### IPv6-Only Setup

For environments using only IPv6:

```nix
{
  services.pihole = {
    enable = true;
    
    hostConfig = {
      user = "pihole";
      enableLingeringForUser = true;
      
      # Bind to IPv6 address
      dnsPort = "[::]:5335";
      webPort = "[::]:8080";
    };
    
    piholeConfig = {
      dns.upstreamServers = [
        "2606:4700:4700::1111"  # Cloudflare
        "2606:4700:4700::1001"  # Cloudflare
        "2001:4860:4860::8888"  # Google
        "2001:4860:4860::8844"  # Google
      ];
      
      dhcp = {
        enable = true;
        ipv6 = true;
      };
      
      ftl = {
        LOCAL_IPV6 = "fd00::1";  # Your IPv6 address
      };
    };
  };
}
```

## Custom Upstream DNS Servers

### Using Multiple Upstream Servers

```nix
{
  services.pihole.piholeConfig.dns = {
    # Multiple upstream servers
    upstreamServers = [
      "1.1.1.1"        # Cloudflare
      "1.0.0.1"        # Cloudflare
      "8.8.8.8"        # Google
      "8.8.4.4"        # Google
    ];
    
    # Enable DNSSEC validation
    dnssec = true;
    
    # Never forward reverse lookups for private IP ranges
    bogusPriv = true;
    
    # Never forward non-FQDNs
    fqdnRequired = true;
  };
}
```

### Using Custom DNS with Non-Standard Ports

```nix
{
  services.pihole.piholeConfig.dns = {
    upstreamServers = [
      "127.0.0.1#5053"     # Local DNS on custom port
      "192.168.1.1#5353"   # Router DNS on custom port
      "1.1.1.1"            # Standard Cloudflare
    ];
  };
}
```

### Using DNS over HTTPS (via Upstream)

Set up a local DoH proxy and point Pi-hole to it:

```nix
{
  # Install and configure cloudflared or similar
  services.cloudflared = {
    enable = true;
    tunnels.dns = {
      credentialsFile = "/etc/cloudflared/credentials";
      default = "dns";
    };
  };
  
  services.pihole.piholeConfig.dns = {
    upstreamServers = [
      "127.0.0.1#5053"  # cloudflared proxy
    ];
  };
}
```

### Conditional Forwarding for Local Network

```nix
{
  services.pihole.piholeConfig = {
    dns.upstreamServers = [ "1.1.1.1" "8.8.8.8" ];
    
    # Forward local domain queries to your router
    revServer = {
      enable = true;
      domain = "home.lan";
      target = "192.168.1.1";
      cidr = "192.168.1.0/24";
    };
  };
}
```

## DHCP Server Setup

### Basic DHCP Configuration

```nix
{
  services.pihole.piholeConfig.dhcp = {
    enable = true;
    
    # IP range to assign
    start = "192.168.1.100";
    end = "192.168.1.200";
    
    # Gateway (usually your router)
    router = "192.168.1.1";
    
    # Lease time in hours
    leasetime = 24;
    
    # Domain name for the network
    domain = "home.lan";
    
    # Enable rapid commit for faster assignments
    rapid-commit = true;
  };
  
  # Ensure DHCP port is exposed
  services.pihole.hostConfig.dhcpPort = 67;
  
  networking.firewall.allowedUDPPorts = [ 67 ];
}
```

### DHCP with IPv6 (Dual Stack)

```nix
{
  services.pihole.piholeConfig.dhcp = {
    enable = true;
    
    # IPv4 settings
    start = "192.168.1.100";
    end = "192.168.1.200";
    router = "192.168.1.1";
    leasetime = 24;
    domain = "home.lan";
    
    # Enable IPv6 DHCP (SLAAC + RA)
    ipv6 = true;
    rapid-commit = true;
  };
  
  services.pihole.piholeConfig.ftl = {
    # Your server's IPv6 address
    LOCAL_IPV6 = "fd00::1";
  };
}
```

### DHCP with Static Leases

Static leases are configured via custom dnsmasq configuration:

```nix
{
  services.pihole = {
    enable = true;
    
    hostConfig = {
      user = "pihole";
      enableLingeringForUser = true;
      persistVolumes = true;
      volumesPath = "/var/lib/pihole-data";
    };
    
    piholeConfig.dhcp = {
      enable = true;
      start = "192.168.1.100";
      end = "192.168.1.200";
      router = "192.168.1.1";
    };
  };
  
  # Create static DHCP configuration file
  systemd.tmpfiles.rules = [
    "d /var/lib/pihole-data/etc-dnsmasq.d 0755 pihole pihole -"
  ];
  
  environment.etc."pihole-static-dhcp.conf" = {
    text = ''
      # Static DHCP leases
      dhcp-host=aa:bb:cc:dd:ee:ff,192.168.1.10,workstation
      dhcp-host=11:22:33:44:55:66,192.168.1.20,server
      dhcp-host=aa:bb:cc:dd:ee:00,192.168.1.30,printer
    '';
    target = "/var/lib/pihole-data/etc-dnsmasq.d/04-pihole-static-dhcp.conf";
    user = "pihole";
  };
}
```

## Advanced Configurations

### High-Performance Setup

Optimized for high query volume:

```nix
{
  services.pihole = {
    enable = true;
    
    hostConfig = {
      user = "pihole";
      enableLingeringForUser = true;
      persistVolumes = true;
      
      # Privileged ports for production
      dnsPort = 53;
      webPort = 80;
    };
    
    piholeConfig = {
      dns = {
        upstreamServers = [
          "1.1.1.1"
          "1.0.0.1"
        ];
        dnssec = true;
      };
      
      # FTL performance tuning
      ftl = {
        # Increase cache size
        CACHE_SIZE = "10000";
        
        # Optimize database
        MAXDBDAYS = "30";
        
        # Rate limiting
        RATE_LIMIT = "1000/60";
        
        # Performance
        BLOCK_ICLOUD_PR = "false";
        MOZILLA_CANARY = "false";
      };
    };
  };
  
  # Allow privileged ports for rootless containers
  boot.kernel.sysctl."net.ipv4.ip_unprivileged_port_start" = 53;
  
  # System performance tuning
  systemd.services."pihole-rootless-container".serviceConfig = {
    MemoryLimit = "1G";
    CPUQuota = "200%";
  };
}
```

### Multi-Network Setup

Pi-hole serving multiple networks:

```nix
{
  services.pihole = {
    enable = true;
    
    hostConfig = {
      user = "pihole";
      enableLingeringForUser = true;
      
      # Bind to specific interface
      dnsPort = "192.168.1.2:53";
      webPort = "192.168.1.2:80";
    };
    
    piholeConfig = {
      interface = "eth0";
      
      ftl = {
        # Listen on specific interface
        LOCAL_IPV4 = "192.168.1.2";
        
        # Allow queries from multiple networks
        PIHOLE_INTERFACE = "eth0";
      };
      
      dns.upstreamServers = [ "1.1.1.1" ];
    };
  };
  
  # Firewall rules for specific interfaces
  networking.firewall.interfaces = {
    eth0.allowedTCPPorts = [ 53 80 ];
    eth0.allowedUDPPorts = [ 53 ];
    
    wlan0.allowedTCPPorts = [ 53 80 ];
    wlan0.allowedUDPPorts = [ 53 ];
  };
}
```

### Dark Theme with Custom Settings

```nix
{
  services.pihole.piholeConfig.web = {
    password = "admin123";
    virtualHost = "pi.hole";
    
    # Dark theme
    theme = "default-dark";
    
    # Boxed layout for large screens
    layout = "boxed";
  };
  
  services.pihole.piholeConfig = {
    # Temperature display
    temperatureUnit = "c";  # or "f" or "k"
    
    # Query logging
    queryLogging = true;
  };
}
```

## Complete Examples

### Home Network (Recommended)

Complete setup for a typical home network:

```nix
{ config, pkgs, ... }:

{
  # Pi-hole configuration
  services.pihole = {
    enable = true;
    
    hostConfig = {
      user = "pihole";
      enableLingeringForUser = true;
      
      persistVolumes = true;
      volumesPath = "/var/lib/pihole-data";
      
      dnsPort = 53;
      webPort = 80;
    };
    
    piholeConfig = {
      # Timezone
      tz = "America/New_York";
      
      # Web interface
      web = {
        passwordFile = "/run/secrets/pihole-password";
        virtualHost = "pi.hole";
        theme = "default-dark";
        layout = "boxed";
      };
      
      # DNS settings
      dns = {
        upstreamServers = [
          "1.1.1.1"
          "1.0.0.1"
        ];
        dnssec = true;
        bogusPriv = true;
        fqdnRequired = true;
      };
      
      # Conditional forwarding for local network
      revServer = {
        enable = true;
        domain = "home.lan";
        target = "192.168.1.1";
        cidr = "192.168.1.0/24";
      };
      
      # FTL settings
      ftl = {
        LOCAL_IPV4 = "192.168.1.2";
        CACHE_SIZE = "10000";
      };
      
      # Enable query logging
      queryLogging = true;
      temperatureUnit = "c";
    };
  };
  
  # User configuration
  users.users.pihole = {
    isNormalUser = true;
    description = "Pi-hole service user";
    autoSubUidGidRange = true;
  };
  
  # Allow privileged ports
  boot.kernel.sysctl."net.ipv4.ip_unprivileged_port_start" = 53;
  
  # Firewall
  networking.firewall = {
    allowedTCPPorts = [ 53 80 ];
    allowedUDPPorts = [ 53 ];
  };
  
  # Clean /tmp on boot
  boot.tmp.cleanOnBoot = true;
  
  # Ensure data directory exists
  systemd.tmpfiles.rules = [
    "d /var/lib/pihole-data 0755 pihole pihole -"
  ];
}
```

### Small Office/Business Setup

With DHCP and IPv6:

```nix
{ config, pkgs, ... }:

{
  services.pihole = {
    enable = true;
    
    hostConfig = {
      user = "pihole";
      enableLingeringForUser = true;
      persistVolumes = true;
      volumesPath = "/var/lib/pihole-data";
      
      dnsPort = 53;
      webPort = 80;
      dhcpPort = 67;
    };
    
    piholeConfig = {
      tz = "America/New_York";
      
      web = {
        passwordFile = "/run/secrets/pihole-password";
        virtualHost = "dns.office.local";
        theme = "default-light";
      };
      
      dns = {
        upstreamServers = [
          "1.1.1.1"
          "8.8.8.8"
          "2606:4700:4700::1111"
          "2001:4860:4860::8888"
        ];
        dnssec = true;
        bogusPriv = true;
      };
      
      # DHCP server
      dhcp = {
        enable = true;
        start = "10.0.1.100";
        end = "10.0.1.200";
        router = "10.0.1.1";
        leasetime = 12;  # 12 hours
        domain = "office.local";
        ipv6 = true;
        rapid-commit = true;
      };
      
      ftl = {
        LOCAL_IPV4 = "10.0.1.2";
        LOCAL_IPV6 = "fd00::2";
        CACHE_SIZE = "20000";
        RATE_LIMIT = "1000/60";
      };
      
      queryLogging = true;
    };
  };
  
  # System configuration
  users.users.pihole = {
    isNormalUser = true;
    autoSubUidGidRange = true;
  };
  
  boot.kernel.sysctl."net.ipv4.ip_unprivileged_port_start" = 53;
  networking.enableIPv6 = true;
  boot.tmp.cleanOnBoot = true;
  
  networking.firewall = {
    allowedTCPPorts = [ 53 80 ];
    allowedUDPPorts = [ 53 67 ];
  };
  
  # Performance tuning
  systemd.services."pihole-rootless-container".serviceConfig = {
    MemoryLimit = "2G";
    CPUQuota = "300%";
  };
}
```

See also:
- [Troubleshooting Guide](Troubleshooting.md)
- [Migration Guide](Migration-Guide.md)
- [CI/CD Documentation](CI-CD.md)
