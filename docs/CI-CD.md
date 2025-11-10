# CI/CD Documentation

This document describes the continuous integration and deployment setup for pihole-flake.

## Workflows

### 1. CI Workflow (`ci.yml`)

**Trigger:** Push to `main`, Pull Requests, Manual dispatch

**Jobs:**

- **nix-flake-check**: Runs `nix flake check --all-systems` to validate the flake structure
- **build-x86_64**: Builds the Pi-hole image for x86_64-linux architecture
- **build-aarch64**: Builds the Pi-hole image for aarch64-linux architecture using QEMU
- **test-module**: Tests that the NixOS module can be evaluated and the example configuration is valid
- **format-check**: Checks Nix code formatting and linting
  - `nixpkgs-fmt` - Code formatting (required)
  - `statix` - Linting for best practices (required)
  - `deadnix` - Dead code detection (required)
- **security-scan**: Scans for known vulnerabilities using vulnix (non-blocking)
- **summary**: Aggregates results from all jobs and reports final status

**Features:**
- Uses Determinate Systems Nix installer for fast, reliable Nix setup
- Caches Nix builds using magic-nix-cache for faster subsequent runs
- Tests both architectures (x86_64 and aarch64) using QEMU emulation
- Enforces code quality standards
- Provides clear pass/fail summary

### 2. Format Check Workflow (`format.yml`)

**Trigger:** Push to `main`, Pull Requests, Manual dispatch

**Jobs:**

- **nixpkgs-fmt**: Primary formatter check (required to pass)
- **alejandra**: Alternative formatter check (informational)
- **nixfmt**: RFC-style formatter check (informational)
- **statix**: Lints for Nix best practices and anti-patterns (required to pass)
- **deadnix**: Checks for unused Nix code (required to pass)
- **summary**: Provides fix instructions if checks fail

**Features:**
- Multiple formatter checks for comprehensive coverage
- Clear error messages with fix instructions
- Can be run locally before pushing
- Auto-fix capabilities for most issues

### 3. Update Pi-hole Workflow (`update-pihole.yml`)

**Trigger:** Weekly (Monday 00:00 UTC), Manual dispatch

**Jobs:**

- **check-updates**: 
  - Compares current Pi-hole version with latest from Docker Hub
  - Uses skopeo to inspect the latest image
  - Outputs whether an update is available

- **update-images** (only if update available):
  - Runs the `update-pihole-image-info` script for both amd64 and arm64
  - Tests that the new images build successfully
  - Creates a pull request with the updated image info files

**Features:**
- Fully automated version checking
- Automatically creates PRs with new versions
- Includes testing before PR creation
- PR includes detailed information about the update
- Labels PRs for easy filtering (`automated`, `dependencies`, `pihole-update`)

### 3. Dependabot Configuration

**Purpose:** Keep GitHub Actions dependencies up to date

**Settings:**
- Weekly updates for GitHub Actions
- Automatic PR creation for action version bumps
- Labeled with `dependencies` and `github-actions`
- Commit messages prefixed with `ci:`

## GitHub Actions Used

### Core Actions
- `actions/checkout@v4` - Checks out the repository
- `DeterminateSystems/nix-installer-action@v9` - Installs Nix with optimal settings
- `DeterminateSystems/magic-nix-cache-action@v3` - Provides intelligent Nix build caching
- `peter-evans/create-pull-request@v6` - Creates PRs for automated updates

### Why These Actions?

**Determinate Systems actions** provide:
- Faster Nix installation (< 1 second vs minutes)
- Better caching strategy
- More reliable in CI environments
- Active maintenance and support

## Running CI Locally

You can run most CI checks locally before pushing:

```bash
# Run flake check
nix flake check --all-systems

# Build for x86_64
nix build .#packages.x86_64-linux.piholeImage

# Build for aarch64 (requires QEMU setup)
nix build .#packages.aarch64-linux.piholeImage

# Test module evaluation
nix eval .#nixosModules.default --apply 'x: "success"'

# Check example configuration
cd examples
nix flake check --no-build

# Format checks
nix-shell -p nixpkgs-fmt --run "nixpkgs-fmt --check ."
nix-shell -p statix --run "statix check ."
nix-shell -p deadnix --run "deadnix ."

# Auto-fix formatting
nix-shell -p nixpkgs-fmt --run "nixpkgs-fmt ."
nix-shell -p statix --run "statix fix ."
```

## Code Quality Standards

### Formatting

This project uses **nixpkgs-fmt** as the standard Nix formatter. All code must be formatted before merging.

**Why nixpkgs-fmt?**
- Official formatter used by nixpkgs
- Consistent style across the Nix ecosystem
- Well-maintained and widely adopted
- Fast and reliable

**Format all files:**
```bash
nix-shell -p nixpkgs-fmt --run "nixpkgs-fmt ."
```

### Linting

**statix** checks for:
- Anti-patterns in Nix code
- Deprecated syntax
- Performance issues
- Best practice violations

**deadnix** checks for:
- Unused function arguments
- Unused let bindings
- Dead code paths

**Run linters:**
```bash
nix-shell -p statix --run "statix check ."
nix-shell -p deadnix --run "deadnix --fail ."
```

### Pre-commit Hook (Recommended)

Consider setting up a pre-commit hook to automatically format code:

```bash
# .git/hooks/pre-commit
#!/usr/bin/env bash
nix-shell -p nixpkgs-fmt --run "nixpkgs-fmt --check ." || {
  echo "Code is not formatted. Running nixpkgs-fmt..."
  nix-shell -p nixpkgs-fmt --run "nixpkgs-fmt ."
  git add -u
}
```

Make it executable:
```bash
chmod +x .git/hooks/pre-commit
```

## Maintenance

### Updating Workflow Actions

Dependabot will automatically create PRs to update GitHub Actions. Review and merge these PRs to keep the workflows up to date.

### Modifying CI Checks

When adding new checks:
1. Add the job to `ci.yml`
2. Update the `summary` job's `needs` array if it's a required check
3. Test the workflow on a feature branch first
4. Document any new requirements in this file

### Pi-hole Update Process

The automated update workflow will:
1. Run weekly on Monday at midnight UTC
2. Check if a new Pi-hole version is available
3. If available, update both architecture image files
4. Create a PR with the changes
5. Run CI tests on the PR

**Manual update process:**
```bash
nix develop
update-pihole-image-info --arch amd64
update-pihole-image-info --arch arm64
git commit -am "chore: update Pi-hole to version X.Y.Z"
```

## Troubleshooting

### aarch64 Builds Failing

If aarch64 builds fail in CI:
- Check that QEMU is properly set up in the workflow
- Verify `extra-platforms` is configured in `/etc/nix/nix.conf`
- Consider if the build needs more memory/time

### Flake Check Failures

Common causes:
- Syntax errors in Nix files
- Missing dependencies
- Module evaluation errors
- Lock file out of sync (run `nix flake lock` locally)

### Update Workflow Not Creating PRs

Check:
- GitHub token has necessary permissions
- Branch protection rules allow bot PRs
- No existing PR for the same version
- Workflow has `contents: write` and `pull-requests: write` permissions

## Security Considerations

- The update workflow uses `GITHUB_TOKEN` with minimal required permissions
- Security scanning is non-blocking to avoid false positives stopping releases
- All dependencies are pinned in the lock file
- Automated PRs require manual review before merging

## Future Improvements

Potential enhancements:
- [ ] Add NixOS VM tests for the module
- [ ] Implement integration tests with actual DNS queries
- [ ] Add performance benchmarking
- [ ] Create release automation
- [ ] Add changelog generation
- [ ] Implement semantic versioning based on Pi-hole versions
