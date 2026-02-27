# CI/CD Pipeline Guide

## Overview

DICOMKit uses GitHub Actions for automated continuous integration, testing, and deployment. This guide explains the CI/CD infrastructure and how to maintain it.

## Workflows

### 1. Main CI Pipeline (`ci.yml`)

**Triggers**: Push/PR to `main` or `develop` branches

**Jobs**:
- **test-macos**: Builds and tests on macOS 15 with multiple Xcode versions
  - Matrix: Xcode 16.0 and 16.2
  - Caches Swift Package Manager dependencies
  - Runs parallel tests
  - Builds in both debug and release modes
  
- **build-documentation**: Validates DocC builds without errors
  
- **code-quality**: Checks for compiler warnings and validates Package.swift
  
- **validate-platforms**: Tests on iOS, macOS, and visionOS simulators
  
- **security-scan**: Checks for dependency vulnerabilities
  
- **summary**: Aggregates results and reports overall status

**Expected Runtime**: 5-10 minutes

### 2. Scheduled Tests (`scheduled-tests.yml`)

**Triggers**: Weekly on Mondays at 9 AM UTC, or manual dispatch

**Jobs**:
- **comprehensive-test**: Full test suite with verbose output
- **memory-leak-check**: Builds and tests with Address Sanitizer
- **performance-benchmark**: Runs performance tests in release mode
- **dependency-update-check**: Checks for available dependency updates
- **build-matrix**: Tests with multiple Swift versions and configurations

**Expected Runtime**: 15-30 minutes

### 3. Documentation Deployment (`docs.yml`)

**Triggers**: Push to `main` branch (when sources or docs change)

**Jobs**:
- **build-docs**: Builds DocC for all 5 modules
  - Creates static hosting-friendly documentation
  - Generates index page with links to all modules
  
- **deploy**: Deploys to GitHub Pages

**Expected Runtime**: 3-5 minutes

**Documentation URLs** (after deployment):
- Main: `https://raster-lab.github.io/DICOMKit/`
- Modules: 
  - `https://raster-lab.github.io/DICOMKit/DICOMKit/documentation/dicomkit/`
  - `https://raster-lab.github.io/DICOMKit/DICOMCore/documentation/dicomcore/`
  - `https://raster-lab.github.io/DICOMKit/DICOMNetwork/documentation/dicomnetwork/`
  - `https://raster-lab.github.io/DICOMKit/DICOMWeb/documentation/dicomweb/`
  - `https://raster-lab.github.io/DICOMKit/DICOMDictionary/documentation/dicomdictionary/`

### 4. Release Workflow (`release.yml`)

**Triggers**: 
- Git tag push matching `v*.*.*` (e.g., `v1.0.0`)
- Manual workflow dispatch with tag input

**Jobs**:
- **validate-release**: Validates tag format and runs full test suite
- **build-cli-tools**: Builds all 29 CLI tools and creates macOS ARM64 tarball
- **build-documentation**: Builds and archives documentation
- **create-release**: Creates GitHub Release with artifacts
- **notify-success**: Success notification

**Expected Runtime**: 10-15 minutes

## Maintenance Tasks

### Updating Xcode Versions

When new Xcode versions are released:

1. Edit `.github/workflows/ci.yml`
2. Update the `matrix.xcode` array in `test-macos` job
3. Update the Xcode selection in other jobs (use latest stable)

```yaml
matrix:
  xcode: ['15.3', '15.4']  # Add new version
```

### Adding New CLI Tools

When adding new CLI tools:

1. Update `.github/workflows/release.yml`
2. Add a new build command in the `build-cli-tools` job

```yaml
- name: Build CLI tools for release
  run: |
    # ... existing builds ...
    swift build -c release --product dicom-newtool
```

### Updating Test Expectations

If the number of tests changes significantly:

1. Update `.github/workflows/scheduled-tests.yml`
2. Modify the expected test count in the `comprehensive-test` job

```yaml
if [ $TEST_COUNT -lt 1500 ]; then
  echo "::warning::Test count seems low (${TEST_COUNT}), expected 1500+"
fi
```

### Configuring Caches

Cache keys use `Package.resolved` hash. If builds become slow:

1. Check cache hit rates in workflow logs
2. Consider adding more cache paths (e.g., build artifacts)

```yaml
- name: Cache Swift Package Manager
  uses: actions/cache@v4
  with:
    path: |
      .build
      ~/Library/Developer/Xcode/DerivedData
      ~/.swiftpm/cache  # Additional cache location
    key: ${{ runner.os }}-spm-${{ hashFiles('**/Package.resolved') }}
```

## Troubleshooting

### CI Failures

**Test failures**:
1. Check the test output in the workflow logs
2. Run locally: `swift test -v`
3. Fix the failing tests
4. Push the fix

**Build failures**:
1. Check for compiler errors in logs
2. Verify Swift 6.2 compatibility
3. Run locally: `swift build`

**Documentation build failures**:
1. Check for malformed doc comments
2. Run locally: `swift package generate-documentation --target DICOMKit`
3. Fix any errors in doc comments

### Memory Leaks Detected

If `memory-leak-check` job fails:
1. Review the sanitizer output
2. Run locally with sanitizers: `swift test -Xswiftc -sanitize=address`
3. Fix memory issues (usually retain cycles or unsafe memory access)

### Slow Builds

If CI builds take too long:
1. Check cache hit rates
2. Consider reducing matrix size (fewer Xcode versions)
3. Use workflow concurrency to cancel outdated runs

```yaml
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true
```

## Best Practices

### Before Committing

Always run locally before pushing:
```bash
# Build
swift build

# Run tests
swift test

# Build in release mode
swift build -c release

# Check for warnings
swift build 2>&1 | grep warning
```

### Pull Requests

- CI must pass before merging
- Review workflow logs for warnings
- Address any performance regressions
- Ensure test count doesn't decrease unexpectedly

### Releases

Creating a new release:
```bash
# Tag the release
git tag v1.2.3

# Push the tag
git push origin v1.2.3

# The release workflow will automatically:
# - Build CLI tools
# - Create GitHub release
# - Upload artifacts
# - Generate release notes
```

### Monitoring

Check CI health regularly:
- Review failed workflow runs
- Monitor build times (should stay under 10 minutes for main CI)
- Watch for flaky tests
- Keep dependencies updated

## Security

### Secrets and Tokens

- `GITHUB_TOKEN`: Automatically provided by GitHub Actions
- No additional secrets required for basic workflows
- If adding third-party integrations, use repository secrets

### Permissions

Workflows use minimal permissions:
- `contents: read` - Read repository contents
- `contents: write` - Create releases (release workflow only)
- `pages: write` - Deploy to GitHub Pages (docs workflow only)
- `id-token: write` - OIDC token for Pages deployment

## Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Swift Package Manager CI](https://docs.swift.org/package-manager/)
- [DocC Documentation](https://www.swift.org/documentation/docc/)

---

**Last Updated**: February 2026  
**Maintained By**: DICOMKit Team
