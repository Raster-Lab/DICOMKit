# .github Directory

This directory contains GitHub-specific configuration files for the DICOMKit repository.

## Contents

### `/workflows/`
GitHub Actions workflow definitions for CI/CD automation:

- **`ci.yml`** - Main continuous integration pipeline
  - Runs on every push and pull request
  - Tests on macOS with multiple Xcode versions
  - Validates code quality and platform compatibility
  
- **`scheduled-tests.yml`** - Weekly comprehensive testing
  - Memory leak detection with sanitizers
  - Performance benchmarking
  - Dependency update checks
  
- **`docs.yml`** - Documentation deployment
  - Builds DocC documentation for all modules
  - Deploys to GitHub Pages
  
- **`release.yml`** - Release automation
  - Triggered by version tags
  - Builds CLI tools
  - Creates GitHub releases with artifacts

### `/scripts/`
Helper scripts for local development:

- **`local-ci.sh`** - Run CI checks locally before pushing
  - Validates builds
  - Runs tests
  - Checks for warnings
  - Usage: `./.github/scripts/local-ci.sh [--with-docs]`

### `/ISSUE_TEMPLATE/`
Issue templates for bug reports, feature requests, and questions.

### Documentation

- **`CI_CD_GUIDE.md`** - Comprehensive guide to the CI/CD pipeline
  - Workflow descriptions
  - Maintenance instructions
  - Troubleshooting tips

- **`copilot-instructions.md`** - GitHub Copilot coding guidelines

## Quick Start

### Run Local CI Checks

Before pushing changes, run the local CI script to catch issues early:

```bash
./.github/scripts/local-ci.sh
```

Add `--with-docs` to include documentation build validation:

```bash
./.github/scripts/local-ci.sh --with-docs
```

### View CI Status

Check the status of CI workflows:
- Visit: https://github.com/Raster-Lab/DICOMKit/actions

### Deploy Documentation

Documentation is automatically deployed to GitHub Pages when changes are pushed to the `main` branch.

View deployed docs at: https://raster-lab.github.io/DICOMKit/

### Create a Release

To create a new release:

```bash
# Tag the release
git tag v1.2.3

# Push the tag
git push origin v1.2.3
```

The release workflow will automatically:
1. Build all CLI tools
2. Create a GitHub release
3. Upload build artifacts
4. Generate release notes

## Maintenance

See **`CI_CD_GUIDE.md`** for detailed maintenance instructions including:
- Updating Xcode versions
- Adding new CLI tools to builds
- Troubleshooting workflow failures
- Best practices

## Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Swift Package Manager](https://swift.org/package-manager/)
- [DocC Documentation](https://www.swift.org/documentation/docc/)
