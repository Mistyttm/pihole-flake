# Migration Guide

This guide helps you migrate from older versions of pihole-flake to the latest version.

## Table of Contents

- [From linger-flake to Built-in Lingering](#from-linger-flake-to-built-in-lingering)
- [From Per-System to System-Agnostic Modules](#from-per-system-to-system-agnostic-modules)
- [Breaking Changes by Version](#breaking-changes-by-version)

## From linger-flake to Built-in Lingering

**Affected:** All users who were using the external `linger-flake` dependency.

### What Changed

NixOS now has built-in support for systemd user lingering through the `users.users.<username>.linger` option. The pihole-flake has been updated to use this native option instead of the external `linger-flake` dependency.

### Migration Steps

#### 1. Update Your Flake Inputs

**Before:**
```nix
{
  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    
    linger = {
      url = "github:mindsbackyard/linger-flake";
      inputs.flake-utils.follows = "flake-utils";
    };
    
    pihole = {
      url = "github:Mistyttm/pihole-flake";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
      inputs.linger.follows = "linger";
    };
  };
}
```

**After:**
```nix
{
  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    
    pihole = {
      url = "github:Mistyttm/pihole-flake";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };
  };
}
```

#### 2. Update Your Outputs

**Before:**
```nix
outputs = {
  self,
  nixpkgs,
  linger,
  pihole,
  ...
}: {
  # ...
}
```

**After:**
```nix
outputs = {
  nixpkgs,
  pihole,
  ...
}: {
  # ...
}
```

#### 3. Update Your NixOS Modules

**Before:**
```nix
nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
  modules = [
    linger.nixosModules.${system}.default
    pihole.nixosModules.${system}.default
    # ... other modules
  ];
};
```

**After:**
```nix
nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
  modules = [
    pihole.nixosModules.default
    # ... other modules
  ];
};
```

#### 4. Update flake.lock

```bash
nix flake lock --update-input pihole
```

### Configuration Remains the Same

The `services.pihole.hostConfig.enableLingeringForUser` option works exactly as before. The implementation has changed to use the native NixOS option, but your configuration doesn't need to change:

```nix
services.pihole.hostConfig.enableLingeringForUser = true;
```

This now translates to:
```nix
users.users.<username>.linger = true;
```

## From Per-System to System-Agnostic Modules

**Affected:** Users referencing `pihole.nixosModules.${system}.default`

### What Changed

The nixosModules output structure was modernized to be system-agnostic, following the standard pattern used by most NixOS flakes.

### Migration Steps

Simply update your module reference:

**Before:**
```nix
nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
  inherit system;
  modules = [
    pihole.nixosModules.${system}.default
  ];
};
```

**After:**
```nix
nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
  inherit system;
  modules = [
    pihole.nixosModules.default
  ];
};
```

### Why This Change?

- **Standard Pattern:** Most NixOS flakes use system-agnostic modules
- **Simpler:** No need to pass system variable
- **Cleaner:** Works the same on all architectures

## Breaking Changes by Version

### Version 2.0 (November 2025)

#### Removed Dependencies
- ❌ Removed `linger-flake` dependency
- ✅ Now uses built-in NixOS `users.users.<name>.linger`

#### Module Structure
- ❌ Old: `pihole.nixosModules.${system}.default`
- ✅ New: `pihole.nixosModules.default`

#### Migration Required
- Update flake inputs to remove linger-flake
- Update module references to use system-agnostic path

#### No Breaking Changes To
- Configuration options (all remain the same)
- Service behavior
- Container functionality

### Version 1.x (Legacy)

If you're migrating from a very old version:

1. Check that you're using the new option structure
2. Verify your user has subuid/subgid configured
3. Update image info files if builds fail

## Complete Migration Example

Here's a complete before/after example:

### Before (Version 1.x)

```nix
{
  description = "My NixOS config";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    
    linger = {
      url = "github:mindsbackyard/linger-flake";
      inputs.flake-utils.follows = "flake-utils";
    };
    
    pihole = {
      url = "github:Mistyttm/pihole-flake";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
      inputs.linger.follows = "linger";
    };
  };

  outputs = { self, nixpkgs, linger, pihole, ... }:
    let
      system = "x86_64-linux";
    in {
      nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          linger.nixosModules.${system}.default
          pihole.nixosModules.${system}.default
          ./configuration.nix
        ];
      };
    };
}
```

### After (Version 2.0+)

```nix
{
  description = "My NixOS config";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    
    pihole = {
      url = "github:Mistyttm/pihole-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, pihole, ... }:
    let
      system = "x86_64-linux";
    in {
      nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          pihole.nixosModules.default
          ./configuration.nix
        ];
      };
    };
}
```

## Testing Your Migration

After migration, verify everything works:

```bash
# Update flake.lock
nix flake lock --update-input pihole

# Check flake structure
nix flake show

# Test build (don't activate yet)
nixos-rebuild build --flake .#myhost

# Check the service will work
systemctl --user status pihole-rootless-container.service || true

# If everything looks good, switch
nixos-rebuild switch --flake .#myhost
```

## Rollback Plan

If you encounter issues:

### Quick Rollback
```bash
# Rollback to previous generation
nixos-rebuild switch --rollback
```

### Revert Flake Changes
```bash
# Restore old flake.nix from git
git checkout HEAD~1 flake.nix flake.lock

# Rebuild
nixos-rebuild switch --flake .#myhost
```

## Need Help?

If you encounter issues during migration:

1. Check the [Troubleshooting Guide](Troubleshooting.md)
2. Review your configuration against the [examples](Examples.md)
3. Open an [issue on GitHub](https://github.com/Mistyttm/pihole-flake/issues)

Include:
- Your old configuration
- What you changed
- Error messages
- NixOS version
