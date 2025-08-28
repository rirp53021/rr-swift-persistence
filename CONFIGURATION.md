# RRPersistence Configuration Guide

This document explains how to configure RRPersistence for different development scenarios.

## Configuration Options

RRPersistence supports two configuration modes:

1. **Local Development**: Uses local path dependencies for faster iteration
2. **Remote Dependencies**: Uses published versions from GitHub for production use

## File Structure

```
rr-swift-persistence/
├── Package.swift              # Current SPM configuration
├── project.yml               # Current XcodeGen configuration
├── Package-local.swift       # Local development template
├── Package-remote.swift      # Remote dependencies template
├── project-local.yml         # Local development template
├── project-remote.yml        # Remote dependencies template
├── switch-to-local.sh        # Switch to local configuration
├── switch-to-remote.sh       # Switch to remote configuration
└── restore-backup.sh         # Restore from backup
```

## Switching Between Configurations

### Switch to Local Development

```bash
./switch-to-local.sh
```

This will:
- Create backups of current configuration
- Switch to local path dependencies
- Regenerate the Xcode project

### Switch to Remote Dependencies

```bash
./switch-to-remote.sh
```

This will:
- Create backups of current configuration
- Switch to remote GitHub dependencies
- Regenerate the Xcode project

### Restore Previous Configuration

```bash
./restore-backup.sh
```

This will:
- Restore the previous configuration from backup
- Regenerate the Xcode project

## Configuration Details

### Local Development

- **Package.swift**: Uses `path: ../rr-swift-foundation`
- **project.yml**: References local RRFoundation package
- **Benefits**: Faster development, no need to publish versions
- **Use Case**: Active development, testing changes

### Remote Dependencies

- **Package.swift**: Uses `url: https://github.com/rirp53021/rr-swift-foundation.git`
- **project.yml**: References remote RRFoundation package
- **Benefits**: Stable, published versions
- **Use Case**: Production builds, CI/CD, external consumers

## Workflow Examples

### Development Workflow

1. Start with local configuration for active development
2. Make changes to both projects
3. Test integration locally
4. When ready, publish RRFoundation
5. Switch to remote configuration
6. Test with published version
7. Publish RRPersistence

### CI/CD Workflow

1. Always use remote configuration in CI/CD
2. Ensure dependencies are published before building
3. Use semantic versioning for releases

## Troubleshooting

### Common Issues

1. **Missing Package Product**: Run `xcodegen generate` to resynchronize
2. **Build Failures**: Check that RRFoundation is built and accessible
3. **Dependency Resolution**: Use `swift package resolve` to refresh dependencies

### Reset Configuration

If configuration gets corrupted:

```bash
# Restore from backup
./restore-backup.sh

# Or manually regenerate
xcodegen generate
```

## Dependencies

- **RRFoundation**: Core utilities and extensions
- **Swift Testing**: Unit testing framework
- **Foundation**: Basic Swift types
- **Security**: Keychain operations

## Notes

- Always run `xcodegen generate` after switching configurations
- Keep backups of working configurations
- Test both configurations before publishing
- Use semantic versioning for releases
