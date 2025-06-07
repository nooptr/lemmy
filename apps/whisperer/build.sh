#!/bin/bash

set -e

echo "🔨 Building Whisperer..."

# Create build directory
mkdir -p build
cd build

# Run CMake configuration with Ninja generator
echo "⚙️  Configuring CMake..."
cmake -G Ninja ..

# Build the project
echo "🔨 Compiling..."
ninja

echo "✅ Build complete! Binary: ./build/whisperer"
echo ""
echo "To run:"
echo "  ./build/whisperer"
echo ""
echo "⚠️  Note: This application requires accessibility permissions to monitor keyboard events."
echo "   Go to System Preferences → Security & Privacy → Privacy → Accessibility"
echo "   and add your terminal application to the list."