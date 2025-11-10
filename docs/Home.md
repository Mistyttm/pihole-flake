# Home

Welcome to the **pihole-flake** documentation!

## What is pihole-flake?

pihole-flake is a NixOS flake that provides [Pi-hole](https://pi-hole.net) as a rootless Podman container with a comprehensive NixOS module for easy configuration and deployment.

## Features

- 🐳 **Rootless Container**: Run Pi-hole in a rootless Podman container for enhanced security
- 🔧 **Declarative Configuration**: Configure Pi-hole entirely through NixOS options
- 🏗️ **Multiple Architectures**: Supports both x86_64-linux and aarch64-linux
- 🔄 **Built-in Lingering**: Uses native NixOS lingering support (no external dependencies)
- 💾 **Persistent Storage**: Optional volume persistence for configuration
- 🚀 **CI/CD Ready**: Automated testing and Pi-hole version updates
- 📦 **Flakes Native**: Modern Nix flakes for reproducible builds

## Quick Start

### 1. Add to Your Flake

```nix
{
  inputs.pihole.url = "github:Mistyttm/pihole-flake";
  
  outputs = { nixpkgs, pihole, ... }: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      modules = [
        pihole.nixosModules.default
        ./configuration.nix
      ];
    };
  };
}
```

### 2. Configure Pi-hole

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
    
    piholeConfig.web.password = "your-secure-password";
  };
  
  users.users.pihole = {
    isNormalUser = true;
    autoSubUidGidRange = true;
  };
  
  networking.firewall = {
    allowedTCPPorts = [ 5335 8080 ];
    allowedUDPPorts = [ 5335 ];
  };
}
```

### 3. Deploy

```bash
nixos-rebuild switch --flake .#myhost
```

### 4. Access

Visit `http://your-server:8080/admin` with password from step 2.

## Documentation

### Getting Started
- **[Installation Guide](Installation.md)** - Detailed setup instructions
- **[Configuration Examples](Examples.md)** - IPv6, DHCP, custom DNS, and more
- **[Migration Guide](Migration-Guide.md)** - Upgrade from older versions

### Reference
- **[Configuration Options](Configuration-Options.md)** - All available options
- **[Troubleshooting](Troubleshooting.md)** - Common issues and solutions
- **[CI/CD Documentation](CI-CD.md)** - Automated testing and updates

### Development
- **[Contributing](../README.md#contributing)** - How to contribute
- **[Code Formatting](CI-CD.md#code-quality-standards)** - Format and lint standards

## Architecture

```
┌─────────────────────────────────────────┐
│         NixOS System                    │
│                                         │
│  ┌───────────────────────────────────┐  │
│  │  Systemd Service                  │  │
│  │  (pihole-rootless-container)      │  │
│  └───────────────┬───────────────────┘  │
│                  │                       │
│  ┌───────────────▼───────────────────┐  │
│  │  Rootless Podman Container        │  │
│  │  ┌─────────────────────────────┐  │  │
│  │  │  Pi-hole                    │  │  │
│  │  │  - DNS Server (port 53)     │  │  │
│  │  │  - Web UI (port 80)         │  │  │
│  │  │  - DHCP Server (optional)   │  │  │
│  │  └─────────────────────────────┘  │  │
│  └─────────────────────────────────┘  │
│                                         │
│  ┌───────────────────────────────────┐  │
│  │  Persistent Volumes (optional)    │  │
│  │  - /etc/pihole                    │  │
│  │  - /etc/dnsmasq.d                 │  │
│  └───────────────────────────────────┘  │
└─────────────────────────────────────────┘
```

## Why pihole-flake?

### vs Native Pi-hole Installation
- ✅ Container isolation
- ✅ Declarative configuration
- ✅ Easy rollback with NixOS generations
- ✅ Rootless for better security

### vs Docker Compose
- ✅ Integrated with NixOS configuration
- ✅ Systemd management
- ✅ Declarative firewall rules
- ✅ Reproducible builds

### vs Other NixOS Pi-hole Modules
- ✅ Rootless container support
- ✅ Explicit configuration options
- ✅ Multi-architecture support
- ✅ Active maintenance
- ✅ Automated updates

## Support

- 📖 **Documentation**: You're reading it!
- 🐛 **Bug Reports**: [GitHub Issues](https://github.com/Mistyttm/pihole-flake/issues)
- 💬 **Discussions**: [GitHub Discussions](https://github.com/Mistyttm/pihole-flake/discussions)
- 🔧 **Contributing**: See [README](../README.md#contributing)

## Quick Links

| Topic           | Link                                       |
| --------------- | ------------------------------------------ |
| Installation    | [Guide](Installation.md)                   |
| Basic Setup     | [Examples](Examples.md#basic-setup)        |
| IPv6 Setup      | [Examples](Examples.md#ipv6-configuration) |
| DHCP Setup      | [Examples](Examples.md#dhcp-server-setup)  |
| Troubleshooting | [Guide](Troubleshooting.md)                |
| Migration       | [Guide](Migration-Guide.md)                |
| All Options     | [Reference](Configuration-Options.md)      |

## Status

[![CI](https://github.com/Mistyttm/pihole-flake/actions/workflows/ci.yml/badge.svg)](https://github.com/Mistyttm/pihole-flake/actions/workflows/ci.yml)

- ✅ Stable and production-ready
- ✅ Automated testing on x86_64 and aarch64
- ✅ Weekly Pi-hole version checks
- ✅ Active maintenance

## License

MIT License - see [LICENSE](../LICENSE) file for details.

---

**Next Steps:**
1. Check the [Installation Guide](Installation.md) for detailed setup
2. Browse [Configuration Examples](Examples.md) for your use case
3. Review [Configuration Options](Configuration-Options.md) for all settings
