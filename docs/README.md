# pihole-flake Documentation

This directory contains comprehensive documentation for pihole-flake, formatted for use as a GitHub Wiki.

## Documentation Structure

### Getting Started
- **[Home](Home.md)** - Introduction and quick start guide
- **[Installation](Installation.md)** - Detailed installation instructions
- **[Examples](Examples.md)** - Configuration examples (IPv6, DHCP, custom DNS)

### Reference
- **[Troubleshooting](Troubleshooting.md)** - Common issues and solutions
- **[Migration Guide](Migration-Guide.md)** - Upgrading from older versions

### Development
- **[CI/CD](CI-CD.md)** - Continuous integration documentation

## Using These Docs as a GitHub Wiki

### Option 1: Link from Main README

Add links in your main README.md to these documentation files.

### Option 2: Copy to GitHub Wiki

1. Go to your repository's Wiki tab
2. Create new pages for each document
3. Copy content from these markdown files
4. Update internal links if needed

### Option 3: Automated Wiki Sync

Use GitHub Actions to automatically sync these docs to the wiki:

```yaml
name: Sync Wiki
on:
  push:
    branches: [main]
    paths:
      - 'docs/**'

jobs:
  sync:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Sync to Wiki
        uses: Andrew-Chen-Wang/github-wiki-action@v4
        env:
          WIKI_DIR: docs/
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          GH_MAIL: github-actions@github.com
          GH_NAME: github-actions
```

## Documentation Contents

### Home.md
- Overview of pihole-flake
- Features and benefits
- Quick start guide
- Architecture diagram
- Comparison with alternatives

### Installation.md
- Prerequisites
- Flake-based installation
- Traditional configuration
- Privileged port setup
- Secure password configuration
- Post-installation steps
- Complete example

### Examples.md
- Basic setup
- IPv6 configuration
- Custom upstream DNS servers
- DHCP server setup
- Advanced configurations
- Complete production examples

### Troubleshooting.md
- Installation issues
- Service startup issues
- Network & DNS issues
- Container issues
- Performance issues
- Debugging techniques
- Common error reference

### Migration-Guide.md
- Migrating from linger-flake
- Migrating to system-agnostic modules
- Breaking changes by version
- Complete migration example
- Testing and rollback

### CI-CD.md
- Workflow documentation
- Code quality standards
- Running checks locally
- Maintenance procedures

## Contributing to Documentation

### Style Guide

- Use clear, concise language
- Include code examples for all features
- Add troubleshooting for common issues
- Keep examples up to date
- Use proper markdown formatting

### Adding New Documentation

1. Create new `.md` file in `docs/`
2. Add table of contents
3. Link from `Home.md`
4. Update this README

### Testing Documentation

Before committing documentation changes:

```bash
# Check markdown syntax
markdownlint docs/

# Check for broken links
markdown-link-check docs/*.md

# Preview locally
# Use any markdown preview tool or GitHub's preview
```

## Markdown Linting

Note: These documentation files may show markdown linting warnings. These are mostly:
- Formatting preferences (blank lines around lists/code blocks)
- Style preferences (dash vs asterisk for lists)

These warnings don't affect functionality on GitHub's markdown renderer.

## Local Development

To preview documentation locally:

```bash
# Using Python
cd docs
python -m http.server 8000

# Using mdbook (if installed)
mdbook serve

# Using grip (GitHub-flavored markdown)
grip Home.md
```

## Feedback

Found an error or have a suggestion? Please:
1. Open an issue
2. Submit a pull request
3. Start a discussion

---

**Last Updated:** November 10, 2025
