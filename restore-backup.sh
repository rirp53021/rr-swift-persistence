#!/bin/bash

# Restore RRPersistence configuration from backup files
# This script restores the previous configuration from backup files

echo "🔄 Restoring RRPersistence configuration from backup..."

# Check if we're in the right directory
if [ ! -f "Package.swift" ]; then
    echo "❌ Error: Please run this script from the rr-swift-persistence directory"
    exit 1
fi

# Check if backup files exist
if [ ! -f "Package.swift.backup" ] || [ ! -f "project.yml.backup" ]; then
    echo "❌ Error: Backup files not found. Please run a switch script first."
    exit 1
fi

# Restore from backup
echo "📦 Restoring from backup..."
cp Package.swift.backup Package.swift
cp project.yml.backup project.yml

# Regenerate Xcode project
echo "🔨 Regenerating Xcode project..."
xcodegen generate

echo "✅ Successfully restored configuration from backup!"
echo "🔧 Use 'switch-to-local.sh' to switch to local dependencies"
echo "🔧 Use 'switch-to-remote.sh' to switch to remote dependencies"
