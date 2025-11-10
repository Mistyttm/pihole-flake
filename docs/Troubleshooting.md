# Troubleshooting

This page contains solutions to common issues you might encounter when using pihole-flake.

## Table of Contents

- [Installation Issues](#installation-issues)
- [Service Startup Issues](#service-startup-issues)
- [Network & DNS Issues](#network--dns-issues)
- [Container Issues](#container-issues)
- [Performance Issues](#performance-issues)
- [Debugging](#debugging)

## Installation Issues

### Flake Evaluation Fails

**Symptoms:**
```
error: cannot find flake 'flake:pihole' in the flake registries
```

**Solution:**
Ensure you're using the correct flake reference:
```nix
inputs.pihole.url = "github:Mistyttm/pihole-flake";
```

### Module Not Found

**Symptoms:**
```
error: attribute 'nixosModules' missing
```

**Solution:**
Make sure you're using the system-agnostic module path:
```nix
# Correct (new)
pihole.nixosModules.default

# Incorrect (old, pre-modernization)
pihole.nixosModules.${system}.default
```

### Build Fails Due to Missing Hash

**Symptoms:**
```
error: hash mismatch in fixed-output derivation
```

**Solution:**
The Pi-hole image info files may be outdated. Update them:
```bash
nix develop
update-pihole-image-info --arch amd64
update-pihole-image-info --arch arm64
```

## Service Startup Issues

### Service Fails to Start

**Check the service status:**
```bash
systemctl status pihole-rootless-container.service
```

**View logs:**
```bash
journalctl -u pihole-rootless-container.service -b
```

### "User Does Not Have Lingering Enabled"

**Symptoms:**
Service stops when user session ends.

**Solution:**
Enable lingering in your configuration:
```nix
services.pihole.hostConfig.enableLingeringForUser = true;
```

Or manually:
```bash
loginctl enable-linger <username>
```

### "Permission Denied" When Starting Container

**Symptoms:**
```
Error: cannot set up namespace using newuidmap: permission denied
```

**Solution:**
Ensure the user has subuid/subgid ranges configured:
```nix
users.users.pihole = {
  # ... other config
  subUidRanges = [{ startUid = 100000; count = 65536; }];
  subGidRanges = [{ startGid = 100000; count = 65536; }];
};
```

Or use automatic configuration:
```nix
users.users.pihole.autoSubUidGidRange = true;
```

### Podman Fails with "/tmp" Issues

**Symptoms:**
```
Error: error configuring CNI network plugin
Error: tmpfs: /tmp/...
```

**Solution:**
Clean `/tmp` on boot:
```nix
boot.tmp.cleanOnBoot = true;
# or
boot.tmpOnTmpfs = true;
```

### Cannot Bind to Privileged Ports

**Symptoms:**
```
Error: rootlessport cannot expose privileged port 53
```

**Solution:**

**Option 1:** Use unprivileged ports
```nix
services.pihole.hostConfig = {
  dnsPort = 5335;
  webPort = 8080;
};
```

**Option 2:** Lower privileged port start
```nix
boot.kernel.sysctl."net.ipv4.ip_unprivileged_port_start" = 53;
```

**Option 3:** Use port forwarding (firewall rules)
```nix
networking.firewall.extraCommands = ''
  iptables -t nat -A PREROUTING -p tcp --dport 53 -j REDIRECT --to-port 5335
  iptables -t nat -A PREROUTING -p udp --dport 53 -j REDIRECT --to-port 5335
'';
```

## Network & DNS Issues

### Pi-hole Web Interface Not Accessible

**Check if the service is running:**
```bash
podman ps --all
```

**Verify ports are exposed:**
```bash
ss -tulpn | grep -E ':(53|80|8080)'
```

**Check firewall:**
```nix
networking.firewall.allowedTCPPorts = [ 53 80 8080 ];
networking.firewall.allowedUDPPorts = [ 53 ];
```

### DNS Queries Not Being Blocked

**Verify upstream DNS servers:**
```nix
services.pihole.piholeConfig.dns.upstreamServers = [ "1.1.1.1" "8.8.8.8" ];
```

**Check if query logging is enabled:**
```nix
services.pihole.piholeConfig.queryLogging = true;
```

**Test DNS resolution:**
```bash
dig @localhost -p 5335 example.com
dig @localhost -p 5335 doubleclick.net  # Should be blocked
```

### IPv6 Not Working

**Ensure IPv6 is enabled in the container:**
```nix
services.pihole.piholeConfig.dhcp.ipv6 = true;
```

**Check system IPv6 support:**
```bash
sysctl net.ipv6.conf.all.disable_ipv6
```

## Container Issues

### Container Keeps Restarting

**Check logs:**
```bash
journalctl -u pihole-rootless-container.service -f
```

**Common causes:**
- Password file doesn't exist
- Volume permissions incorrect
- Port conflicts

### Cannot Access Persistent Volumes

**Symptoms:**
Configuration changes don't persist after restart.

**Solution:**
Enable persistent volumes:
```nix
services.pihole.hostConfig = {
  persistVolumes = true;
  volumesPath = "/home/pihole/pihole-volumes";
};
```

**Check permissions:**
```bash
ls -la /home/pihole/pihole-volumes
# Should be owned by the pihole user
```

### Old Container Won't Stop

**Symptoms:**
```
Error: container already exists
```

**Solution:**
Manually remove the container:
```bash
sudo -u pihole podman rm -f pihole_<username>
```

## Performance Issues

### High Memory Usage

**Check container stats:**
```bash
sudo -u pihole podman stats
```

**Limit memory in systemd service:**
Add to your configuration:
```nix
systemd.services."pihole-rootless-container".serviceConfig = {
  MemoryLimit = "512M";
};
```

### Slow DNS Resolution

**Use faster upstream DNS:**
```nix
services.pihole.piholeConfig.dns.upstreamServers = [
  "1.1.1.1"  # Cloudflare
  "1.0.0.1"
];
```

**Enable DNSSEC:**
```nix
services.pihole.piholeConfig.dns.dnssec = true;
```

## Debugging

### Enable Debug Logging

Add to your systemd service:
```nix
systemd.services."pihole-rootless-container".environment = {
  PODMAN_DEBUG = "1";
};
```

### Check Container Internals

**Enter the running container:**
```bash
sudo -u pihole podman exec -it pihole_<username> /bin/bash
```

**Check Pi-hole specific logs inside container:**
```bash
tail -f /var/log/pihole.log
tail -f /var/log/pihole-FTL.log
```

### Verify Module Configuration

**Check what values are being used:**
```bash
nixos-option services.pihole
```

### Test the Flake Locally

```bash
# Check flake structure
nix flake show

# Evaluate the module
nix eval .#nixosModules.default

# Build the image
nix build .#packages.x86_64-linux.piholeImage
```

### Network Debugging

**Check if Pi-hole is listening:**
```bash
sudo -u pihole podman exec pihole_<username> netstat -tulpn
```

**Test DNS from inside container:**
```bash
sudo -u pihole podman exec pihole_<username> dig @127.0.0.1 example.com
```

**Check podman network configuration:**
```bash
sudo -u pihole podman network ls
sudo -u pihole podman network inspect <network-name>
```

## Getting Help

If you're still experiencing issues:

1. Check the [GitHub Issues](https://github.com/Mistyttm/pihole-flake/issues)
2. Search for similar problems in closed issues
3. Review the [Pi-hole documentation](https://docs.pi-hole.net/)
4. Open a new issue with:
   - Your NixOS version (`nixos-version`)
   - Your configuration (sanitized)
   - Full error messages
   - Relevant logs

## Common Error Messages Reference

| Error                          | Cause                 | Solution                               |
| ------------------------------ | --------------------- | -------------------------------------- |
| `newuidmap: permission denied` | Missing subuid/subgid | Configure subUidRanges/subGidRanges    |
| `cannot bind to port 53`       | Privileged port       | Use unprivileged port or adjust sysctl |
| `container already exists`     | Leftover container    | Remove with `podman rm -f`             |
| `tmpfs error`                  | /tmp not cleaned      | Enable boot.tmp.cleanOnBoot            |
| `hash mismatch`                | Outdated image info   | Run update-pihole-image-info           |
| `lingering not enabled`        | Session ends          | Enable lingering                       |
| `volume permission denied`     | Wrong ownership       | chown to container user                |
