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

echo "✅ Build complete! Binaries:"
echo "  ./build/whisperer  - Main FN key audio transcription app"
echo "  ./build/recorder   - Audio recording utility"
echo ""
echo "To run:"
echo "  ./build/whisperer              # Start FN key transcription"
echo "  ./build/recorder output.wav    # Record audio to file"
echo "  ./build/recorder --help        # See recording options"
echo ""
echo "⚠️  Note: This application requires accessibility permissions to monitor keyboard events."
echo "   Go to System Preferences → Security & Privacy → Privacy → Accessibility"
echo "   and add your terminal application to the list."