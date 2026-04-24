#!/bin/bash
# MajuRun Pre-push Verification Script
# This script mimics the CI environment to ensure your build will pass.

set -e # Exit on error

echo "🚀 Starting MajuRun local verification..."

echo "📦 Getting dependencies..."
flutter pub get

echo "🔍 Running static analysis..."
flutter analyze

echo "🧪 Running unit tests..."
flutter test

echo "✅ All checks passed! You are safe to push."
