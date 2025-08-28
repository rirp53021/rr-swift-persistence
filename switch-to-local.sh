#!/bin/bash

# Switch RRPersistence to use local dependencies
# This script copies the local configuration files to the main configuration

echo "🔄 Switching RRPersistence to local dependencies..."

# Check if we're in the right directory
if [ ! -f "Package.swift" ]; then
    echo "❌ Error: Please run this script from the rr-swift-persistence directory"
    exit 1
fi

# Create backup of current configuration
echo "📦 Creating backup of current configuration..."
cp Package.swift Package.swift.backup
cp project.yml project.yml.backup

# Switch to local configuration
echo "📁 Switching to local configuration..."
cp Package-local.swift Package.swift
cp project-local.yml project.yml

# Regenerate Xcode project
echo "🔨 Regenerating Xcode project..."
xcodegen generate

echo "✅ Successfully switched to local dependencies!"
echo "📁 RRFoundation: ../rr-swift-foundation (local path)"
echo "🔧 Use 'switch-to-remote.sh' to switch back to remote dependencies"
echo "🔧 Use 'restore-backup.sh' to restore the previous configuration"
