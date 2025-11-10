# Installation Guide

This guide walks you through installing and configuring pihole-flake on your NixOS system.

## Prerequisites

- NixOS 25.05 or later
- Nix flakes enabled
- Basic understanding of NixOS configuration
- A user account for running the Pi-hole container

## Installation Methods

- [Flake-based Configuration](#flake-based-configuration) (Recommended)
- [Traditional Configuration](#traditional-configuration)

## Flake-based Configuration

### Step 1: Add pihole-flake to Your Flake Inputs

Edit your `flake.nix`:

```nix
{
  description = "My NixOS configuration";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    
    pihole = {
      url = "github:Mistyttm/pihole-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, pihole, ... }: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        pihole.nixosModules.default
        ./configuration.nix
      ];
    };
  };
}
```

### Step 2: Configure Pi-hole

Add to your `configuration.nix`:

```nix
{ config, pkgs, ... }:

{
  # Enable Pi-hole
  services.pihole = {
    enable = true;
    
    hostConfig = {
      # User to run the container
      user = "pihole";
      
      # Enable lingering (keeps service running when user logs out)
      enableLingeringForUser = true;
      
      # Port configuration (using unprivileged ports)
      dnsPort = 5335;
      webPort = 8080;
      
      # Optional: Enable persistent storage
      persistVolumes = true;
      volumesPath = "/var/lib/pihole-data";
    };
    
    piholeConfig = {
      # Set admin password
      web.password = "change-me-please";
      
      # Optional: Configure DNS upstream servers
      dns.upstreamServers = [ "1.1.1.1" "8.8.8.8" ];
    };
  };
  
  # Create the Pi-hole user
  users.users.pihole = {
    isNormalUser = true;
    description = "Pi-hole service user";
    # Automatically configure subuid/subgid for rootless containers
    autoSubUidGidRange = true;
  };
  
  # Open firewall ports
  networking.firewall = {
    allowedTCPPorts = [ 5335 8080 ];
    allowedUDPPorts = [ 5335 ];
  };
  
  # Clean /tmp on boot (recommended for rootless podman)
  boot.tmp.cleanOnBoot = true;
}
```

### Step 3: Verify Installation

Check the service status:
```bash
systemctl status pihole-rootless-container.service
```

Access the web interface:
```
http://your-server-ip:8080/admin
```

## Traditional Configuration

If you're not using flakes, you can still use pihole-flake:

### Step 1: Fetch the Flake

```nix
{ config, pkgs, ... }:

let
  pihole-flake = builtins.getFlake "github:Mistyttm/pihole-flake";
in {
  imports = [
    pihole-flake.nixosModules.${pkgs.system}.default
  ];
  
  # ... rest of configuration as above
}
```

Note: This method is not recommended as it doesn't pin versions.

## Using Privileged Ports

If you want to use standard DNS port 53 and HTTP port 80:

### Option 1: Lower Privileged Port Start

```nix
{
  services.pihole.hostConfig = {
    dnsPort = 53;
    webPort = 80;
  };
  
  # Allow unprivileged users to bind to ports 53 and above
  boot.kernel.sysctl."net.ipv4.ip_unprivileged_port_start" = 53;
  
  networking.firewall = {
    allowedTCPPorts = [ 53 80 ];
    allowedUDPPorts = [ 53 ];
  };
}
```

### Option 2: Port Forwarding with iptables

```nix
{
  services.pihole.hostConfig = {
    dnsPort = 5335;
    webPort = 8080;
  };
  
  networking.firewall = {
    allowedTCPPorts = [ 53 80 5335 8080 ];
    allowedUDPPorts = [ 53 5335 ];
    
    extraCommands = ''
      # Forward port 53 to 5335
      iptables -t nat -A PREROUTING -p tcp --dport 53 -j REDIRECT --to-port 5335
      iptables -t nat -A PREROUTING -p udp --dport 53 -j REDIRECT --to-port 5335
      
      # Forward port 80 to 8080
      iptables -t nat -A PREROUTING -p tcp --dport 80 -j REDIRECT --to-port 8080
    '';
  };
}
```

## Secure Password Configuration

Instead of hardcoding passwords, use a password file:

```nix
{
  services.pihole.piholeConfig.web.passwordFile = "/run/secrets/pihole-password";
  
  # Using sops-nix
  sops.secrets.pihole-password = {
    owner = "pihole";
    mode = "0400";
  };
  
  # Or using agenix
  age.secrets.pihole-password = {
    file = ./secrets/pihole-password.age;
    owner = "pihole";
  };
}
```

Manual password file:
```bash
# Create the password file
echo "your-secure-password" | sudo tee /run/secrets/pihole-password
sudo chown pihole:pihole /run/secrets/pihole-password
sudo chmod 400 /run/secrets/pihole-password
```

## Post-Installation

### 1. Configure Your Devices

Point your devices to use the Pi-hole DNS server:

**Router Method (Recommended):**
- Set your router's DNS to the Pi-hole IP
- All devices will automatically use Pi-hole

**Per-Device Method:**
- Manually configure each device's DNS settings
- Set DNS to `your-server-ip:5335` (or port 53 if using privileged ports)

### 2. Initial Pi-hole Setup

1. Access the web interface: `http://your-server-ip:8080/admin`
2. Login with your password
3. Update gravity (block lists): Settings → Update Gravity
4. Configure additional blocklists if desired
5. Review statistics dashboard

### 3. Test DNS Blocking

```bash
# Should resolve normally
dig @your-server-ip -p 5335 example.com

# Should be blocked (returns 0.0.0.0 or your server IP)
dig @your-server-ip -p 5335 doubleclick.net
```

### 4. Optional: Enable DHCP

If you want Pi-hole to manage DHCP for your network:

```nix
{
  services.pihole = {
    hostConfig.dhcpPort = 67;
    
    piholeConfig.dhcp = {
      enable = true;
      start = "192.168.1.100";
      end = "192.168.1.200";
      router = "192.168.1.1";
      leasetime = 24;
      domain = "home.lan";
    };
  };
  
  networking.firewall.allowedUDPPorts = [ 67 ];
}
```

Remember to disable DHCP on your router first!

## Troubleshooting

If you encounter issues:

1. **Check service logs:**
   ```bash
   journalctl -u pihole-rootless-container.service -b
   ```

2. **Verify container is running:**
   ```bash
   sudo -u pihole podman ps
   ```

3. **Check firewall rules:**
   ```bash
   sudo iptables -L -n
   ```

4. **See the [Troubleshooting Guide](Troubleshooting.md)** for more help

## Next Steps

- Browse [Configuration Examples](Examples.md) for advanced setups
- Review all [Configuration Options](Configuration-Options.md)
- Set up [monitoring and maintenance](Troubleshooting.md)

## Complete Example

Here's a complete, production-ready configuration:

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
    };
    
    piholeConfig = {
      tz = "America/New_York";
      
      web = {
        passwordFile = "/run/secrets/pihole-password";
        virtualHost = "pi.hole";
        theme = "default-dark";
      };
      
      dns = {
        upstreamServers = [ "1.1.1.1" "1.0.0.1" ];
        dnssec = true;
        bogusPriv = true;
        fqdnRequired = true;
      };
      
      revServer = {
        enable = true;
        domain = "home.lan";
        target = "192.168.1.1";
        cidr = "192.168.1.0/24";
      };
      
      ftl.LOCAL_IPV4 = "192.168.1.2";
      queryLogging = true;
    };
  };
  
  users.users.pihole = {
    isNormalUser = true;
    description = "Pi-hole DNS server";
    autoSubUidGidRange = true;
  };
  
  boot.kernel.sysctl."net.ipv4.ip_unprivileged_port_start" = 53;
  boot.tmp.cleanOnBoot = true;
  
  networking.firewall = {
    allowedTCPPorts = [ 53 80 ];
    allowedUDPPorts = [ 53 ];
  };
  
  systemd.tmpfiles.rules = [
    "d /var/lib/pihole-data 0755 pihole pihole -"
  ];
}
```
