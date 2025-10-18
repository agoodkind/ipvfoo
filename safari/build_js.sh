#!/bin/bash
# This script builds the JavaScript files using esbuild.

# For Homebrew on Apple Silicon
export PATH="/opt/homebrew/bin:$PATH"

# For Homebrew on Intel
export PATH="/usr/local/bin:$PATH"

PNPM="$(which pnpm)"
if [ -z "$PNPM" ]; then
  echo "pnpm is not installed. Please install pnpm and try again."
  exit 1
fi

# Navigate to the project directory
cd "$(realpath "$(dirname "$0")/..")" || exit
echo "Changed directory to $(pwd)"
echo "Using Node.js version: $(node -v)"
echo "Using pnpm version: $("$PNPM" -v)"
echo "Using esbuild version: $("$PNPM" exec esbuild --version)"
echo "Current Xcode configuration: $CONFIGURATION"

echo "Installing dependencies (if needed)..."
if ! "$PNPM" install; then
  echo "Failed to install dependencies with pnpm." >&2
  exit 1
fi

# Build the project
# check xcode configuration
if [ "$CONFIGURATION" == "Debug" ]; then
  echo "Building in Debug mode..."
  BUILD_CMD="DEBUG=1 RELEASE=0 LOG_VERBOSITY=5 make build-safari-pnpm"
else
  echo "Building in Release mode..."
  BUILD_CMD="DEBUG=0 RELEASE=1 LOG_VERBOSITY=0 make build-safari-pnpm"
fi

echo "Running command: $BUILD_CMD"
if ! bash -c "$BUILD_CMD"; then
  echo "Build failed." >&2
  exit 1
fi

echo "JS build script completed successfully." 
