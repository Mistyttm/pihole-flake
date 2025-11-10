# Pi-hole Flake Tests

This directory contains NixOS integration tests for the Pi-hole flake module.

## Available Tests

### 1. `basic`
Tests basic module functionality:
- User creation with subuid/subgid ranges
- Systemd service configuration
- Lingering enablement
- Podman availability

### 2. `containerOptions`
Tests container-specific configuration:
- Custom user configuration
- Persistent volumes
- Custom container name
- Multiple port exposures (DNS, DHCP, Web)
- Various Pi-hole options (theme, layout, timezone)

### 3. `dhcpConfiguration`
Tests DHCP server configuration:
- DHCP enable/disable
- IP range configuration
- Reverse DNS server setup
- FTL options

### 4. `flattenedStructure`
Tests the new flattened configuration structure:
- Verifies `services.pihole.container.*` works (not `hostConfig`)
- Verifies `services.pihole.web.*` works (not `piholeConfig.web`)
- Confirms old structure is NOT accepted

### 5. `assertions`
Tests module assertions:
- Verifies that missing subuid/subgid ranges are caught
- Demonstrates proper error handling

## Running Tests

### Run all tests:
```bash
nix-build tests/default.nix
```

### Run a specific test:
```bash
nix-build tests/default.nix -A basic
nix-build tests/default.nix -A containerOptions
nix-build tests/default.nix -A dhcpConfiguration
nix-build tests/default.nix -A flattenedStructure
```

### Run tests from the flake:
```bash
nix flake check
```

### Interactive testing:
```bash
# Run test and keep VM open for inspection
nix-build tests/default.nix -A basic.driver
./result/bin/nixos-test-driver
```

## Test Output

Successful tests will:
- Build a NixOS VM configuration
- Boot the VM
- Run Python test scripts
- Verify all assertions pass
- Print success messages

Failed tests will show:
- Which assertion failed
- VM logs for debugging
- Error messages from the test script

## What's Tested

✅ **Module Structure**
- Proper imports and option definitions
- Flattened configuration hierarchy
- Renamed options (container vs hostConfig)

✅ **Systemd Integration**
- Service generation
- User configuration
- Lingering setup

✅ **Container Configuration**
- Rootless podman support
- Port mappings
- Volume persistence
- Environment variables

✅ **Pi-hole Options**
- DNS configuration
- DHCP settings
- Web interface options
- FTL options

✅ **Security**
- Subuid/subgid validation
- User isolation
- Proper permissions

## Adding New Tests

To add a new test:

1. Add a new test to `tests/default.nix`:
```nix
myNewTest = makeTest {
  name = "pihole-my-feature";
  
  nodes.machine = { config, pkgs, lib, ... }: {
    imports = [ piholeModule ];
    # ... configuration ...
  };
  
  testScript = ''
    machine.wait_for_unit("multi-user.target")
    # ... test commands ...
  '';
} { inherit pkgs; };
```

2. Run the test:
```bash
nix-build tests/default.nix -A myNewTest
```

## Troubleshooting

### Test hangs at boot
- Increase `virtualisation.memorySize`
- Check VM logs with `--show-trace`

### Service fails to start
- Check systemd logs in test output
- Verify user has proper subuid/subgid ranges
- Ensure all required options are set

### Assertion failures
- Read the assertion message carefully
- Check module configuration in the test
- Verify option types and defaults

## CI Integration

These tests run automatically in CI via `nix flake check`. See `.github/workflows/ci.yml` for details.
