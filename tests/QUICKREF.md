# Quick Test Reference

## Run Tests

```bash
# All tests
nix flake check

# Specific test
nix build .#checks.x86_64-linux.basic
nix build .#checks.x86_64-linux.containerOptions
nix build .#checks.x86_64-linux.dhcpConfiguration
nix build .#checks.x86_64-linux.flattenedStructure

# Interactive mode (for debugging)
nix build .#checks.x86_64-linux.basic.driver
./result/bin/nixos-test-driver
```

## Test Coverage

| Test                 | What it validates                                     |
| -------------------- | ----------------------------------------------------- |
| `basic`              | User setup, systemd service, lingering, podman        |
| `containerOptions`   | Custom user, volumes, ports, various Pi-hole settings |
| `dhcpConfiguration`  | DHCP server, reverse DNS, FTL options                 |
| `flattenedStructure` | New config structure (container vs hostConfig)        |
| `assertions`         | Error handling for invalid configurations             |

## What's Tested

✅ Module structure and imports
✅ Container options (renamed from hostConfig)
✅ Flattened configuration (no piholeConfig wrapper)
✅ Systemd service generation
✅ User permissions and isolation
✅ Port mappings (DNS, DHCP, Web)
✅ Volume persistence
✅ Environment variable extraction
✅ All Pi-hole configuration options

## CI Integration

Tests run automatically on:
- Every push to any branch
- All pull requests
- `nix flake check` command

See `.github/workflows/ci.yml` for CI configuration.
