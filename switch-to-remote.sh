#!/bin/bash

# Switch RRPersistence to use remote dependencies
# This script copies the remote configuration files to the main configuration

echo "🔄 Switching RRPersistence to remote dependencies..."

# Check if we're in the right directory
if [ ! -f "Package.swift" ]; then
    echo "❌ Error: Please run this script from the rr-swift-persistence directory"
    exit 1
fi

# Create backup of current configuration
echo "📦 Creating backup of current configuration..."
cp Package.swift Package.swift.backup
cp project.yml project.yml.backup

# Switch to remote configuration
echo "🔗 Switching to remote configuration..."
cp Package-remote.swift Package.swift
cp project-remote.yml project.yml

# Regenerate Xcode project
echo "🔨 Regenerating Xcode project..."
xcodegen generate

echo "✅ Successfully switched to remote dependencies!"
echo "🔗 RRFoundation: https://github.com/rirp53021/rr-swift-foundation.git (remote URL)"
echo "🔧 Use 'switch-to-local.sh' to switch back to local dependencies"
echo "🔧 Use 'restore-backup.sh' to restore the previous configuration"
