# Pi-hole Flake

[![CI](https://github.com/Mistyttm/pihole-flake/actions/workflows/ci.yml/badge.svg)](https://github.com/Mistyttm/pihole-flake/actions/workflows/ci.yml)

A NixOS flake providing a [Pi-hole](https://pi-hole.net) container & NixOS module for running it in a (rootless) podman container.

The flake provides a container image for Pi-hole by fetching the `pihole/pihole` image version defined in `pihole-image-base-info.nix`.
Currently the container image can be built for `x64_64-linux` and `aarch64-linux` systems.

Further the flake comes with a NixOS module that can be used to configure & run Pi-hole as a `systemd` service.
Contrary to NixOS' oci-container support this flake allows to run Pi-hole in a rootless container environment---which is also the main reason why this flake exists.
Another benefit of using the provided NixOS module is that it explicitly exposes the supported configuration options of the Pi-hole container.

## Usage

To use this flake in your NixOS configuration, add it as an input and import the module:

```nix
{
  inputs.pihole.url = "github:Mistyttm/pihole-flake";
  
  outputs = { nixpkgs, pihole, ... }: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      modules = [
        pihole.nixosModules.default
        # ... your other modules
      ];
    };
  };
}
```

## Configuring Pi-hole

All configuration options can be found under the key `service.pihole`.
The Pi-hole service can be enabled by setting `services.pihole.enable = true`.
Full descriptions of the configuration options can be found in the module.
Example configurations can be found in the `examples` folder.

> **Note:** The module structure has been updated. See [MIGRATION.md](./MIGRATION.md) for migration guide from older versions.

The module options are separated into two parts:

* **Container options** (`services.pihole.container`) which define how the Pi-hole container should be run on the host
* **Pi-hole application options** (directly under `services.pihole`) which configure the Pi-hole service in the container

### Container Options

All container runtime options are contained in `services.pihole.container`.
Among others, the `container` section contains the options for exposing the ports of Pi-hole's DNS, DHCP, and web UI components.
Remember that if you run the service in a rootless container, binding to privileged ports is by default not possible.

To handle this limitation you can either:

* *Access the components on non-privileged ports:* This should be easily possible for the web & DNS components---if your DHCP server supports DNS servers with non-standard ports or if you configure your DNS resolvers to use a non-default port by other means.
  If you use Pi-hole's DHCP server then lookup your DHCP client's documentation on how to send DHCP requests to non-standard ports.
* *Use port-fowarding from a privileged to an unprivileged port*
* *Change the range of privileged ports:* see `sysctl net.ipv4.ip_unprivileged_port_start`

Also do not forget to open the exposed ports in NixOS' firewall otherwise you won't be able to access the services.

As the Pi-hole container supports being run rootless, you need to configure which user should run the Pi-hole container via `services.pihole.container.user`.
This user needs a [subuid](https://nixos.org/manual/nixos/stable/options.html#opt-users.users._name_.subUidRanges)/[subgid](https://nixos.org/manual/nixos/stable/options.html#opt-users.users._name_.subGidRanges) ranges defined or [automatically configured](https://nixos.org/manual/nixos/stable/options.html#opt-users.users._name_.autoSubUidGidRange) so they can run rootless podman containers.

If you want to persist your Pi-hole configuration (the changes you made via the UI) between container restarts, take a look at `services.pihole.container.persistVolumes` and `services.pihole.container.volumesPath`.

Running rootless podman containers can be unstable and the systemd service can fail if certain precautions are not taken:

* The user running the Pi-hole container should be allowed to linger after all their sessions are closed.
  See `services.pihole.container.enableLingering` for details. This uses the built-in NixOS `users.users.<name>.linger` option.
* The temporary directory used by rootless podman should be cleaned of any remains on system start.
  See `services.pihole.container.suppressTmpDirWarning` for details.

### Pi-hole Application Options

All options for configuring Pi-hole itself can be found directly under `services.pihole` (e.g., `services.pihole.web`, `services.pihole.dns`, `services.pihole.dhcp`).
The exposed options are mainly those listed as the environment variables of the [Docker image](https://github.com/pi-hole/docker-pi-hole#environment-variables) or of [FTLDNS](https://docs.pi-hole.net/ftldns/configfile/).
The options have been grouped logically to provide more structure (see the option declarations in the module for details).

## Updating[^1] the Pi-hole Image

Because this is a NixOS flake, when building the flake the Pi-hole container image that is used must be fixed.
Otherwise the hash of image cannot be known and the flake build would fail.
Therefore the used version of the image must be pinned before building the flake.

The image information is stored in `./pihole-image-info.ARCH.nix` where `ARCH` is either `amd64` or `arm64`.
To update both architectures to the newest Pi-hole image version execute:

```bash
nix develop
update-pihole-image-info --arch amd64
update-pihole-image-info --arch arm64
```

The `update-pihole-image-info` command determines the newest image digest available, pre-fetches the images into the nix-store, and updates the respective `./pihole-image-info.ARCH.nix` files.

[^1]: The image in the upstream repository is not updated regularly. Please use & update your local clone of the flake, instead of using the vanilla upstream version.

## Testing

The flake includes comprehensive NixOS integration tests that verify the module works correctly.

### Run all tests:
```bash
nix flake check
```

### Run specific tests:
```bash
nix build .#checks.x86_64-linux.basic
nix build .#checks.x86_64-linux.containerOptions
nix build .#checks.x86_64-linux.dhcpConfiguration
nix build .#checks.x86_64-linux.flattenedStructure
```

### Available tests:
- **basic** - Core functionality (user creation, service configuration, lingering)
- **containerOptions** - Container-specific settings (ports, volumes, custom names)
- **dhcpConfiguration** - DHCP server and reverse DNS configuration
- **flattenedStructure** - Verifies new flattened config structure works
- **assertions** - Tests module assertions and error handling

See [`tests/README.md`](./tests/README.md) for detailed test documentation.

## Development

### CI/CD Pipeline

This project uses GitHub Actions for continuous integration and automated updates:

- **CI Workflow** (`.github/workflows/ci.yml`):
  - Runs on every push and pull request
  - Tests `nix flake check` on all systems
  - Builds Pi-hole images for both x86_64-linux and aarch64-linux
  - Validates the NixOS module and example configuration
  - Performs security scanning and format checking

- **Automated Pi-hole Updates** (`.github/workflows/update-pihole.yml`):
  - Runs weekly to check for new Pi-hole releases
  - Automatically updates image info files for both architectures
  - Creates a pull request when a new version is available
  - Includes automated testing before PR creation

### Running Tests Locally

```bash
# Run all checks
nix flake check --all-systems

# Build for specific architecture
nix build .#packages.x86_64-linux.piholeImage
nix build .#packages.aarch64-linux.piholeImage

# Test the module
nix eval .#nixosModules.default --apply 'x: "success"'

# Check code formatting
nix-shell -p nixpkgs-fmt --run "nixpkgs-fmt --check ."

# Auto-fix formatting issues
nix-shell -p nixpkgs-fmt --run "nixpkgs-fmt ."

# Run linter
nix-shell -p statix --run "statix check ."

# Auto-fix linting issues
nix-shell -p statix --run "statix fix ."

# Check for dead code
nix-shell -p deadnix --run "deadnix ."

# Enter development shell
nix develop
```

### Code Formatting

This project uses **nixpkgs-fmt** as the standard Nix code formatter. All Nix files should be formatted before committing.

**Format all Nix files:**
```bash
nix-shell -p nixpkgs-fmt --run "nixpkgs-fmt ."
```

**Check formatting in CI:**
The CI pipeline automatically checks code formatting using:
- `nixpkgs-fmt` - Official nixpkgs formatter (required)
- `statix` - Nix linter for best practices (required)
- `deadnix` - Detects unused code (required)
- `alejandra` - Alternative formatter (informational)
- `nixfmt-rfc-style` - RFC-style formatter (informational)

### Contributing

When contributing:

1. Ensure `nix flake check` passes
2. **Format your code** with `nixpkgs-fmt .`
3. Run `statix check .` to verify code quality
4. Update documentation if needed
5. Test on both architectures when possible
6. Follow conventional commit messages

