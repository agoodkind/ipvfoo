#!/bin/bash

# Script to sync files from src/ (except safari folder) to safari/Shared (Extension)/Resources/
# and update Xcode project target membership

set -e

SOURCE_DIR="src"
TARGET_DIR="src/safari/Shared (Extension)/Resources"
PROJECT_FILE="src/safari/ipvfoo-safari.xcodeproj/project.pbxproj"

echo "Syncing files from $SOURCE_DIR to $TARGET_DIR..."

# Create target directory if it doesn't exist
mkdir -p "$TARGET_DIR"

# Copy all files from src except the safari folder
rsync -av --delete \
    --exclude='safari/' \
    --exclude='.DS_Store' \
    --exclude='manifest/' \
    "$SOURCE_DIR/" "$TARGET_DIR/"

echo "Files synced successfully."

# Update Xcode project target membership
echo "Updating Xcode project target membership..."

# Create a temporary script to update the project file
cat > /tmp/update_xcode_project.py << 'EOF'
#!/usr/bin/env python3

import re
import sys
import os

def update_project_file(project_path):
    with open(project_path, 'r') as f:
        content = f.read()
    
    # Find the current file list in the target membership exceptions
    ios_exception_pattern = r'(B2C2F82F2EA2ACB90051EEFB /\* Exceptions for "Shared \(Extension\)" folder in "ipvfoo-safari Extension \(iOS\)" target \*/ = \{[^}]+membershipExceptions = \()[^)]+(\);)'
    macos_exception_pattern = r'(B2C2F8302EA2ACB90051EEFB /\* Exceptions for "Shared \(Extension\)" folder in "ipvfoo-safari Extension \(macOS\)" target \*/ = \{[^}]+membershipExceptions = \()[^)]+(\);)'
    
    # Get list of files in Resources directory (excluding directories and some files)
    resources_dir = "src/safari/Shared (Extension)/Resources"
    files_to_include = []
    
    if os.path.exists(resources_dir):
        for item in sorted(os.listdir(resources_dir)):
            if item.startswith('.'):
                continue
            item_path = os.path.join(resources_dir, item)
            if os.path.isdir(item_path):
                files_to_include.append(f'Resources/{item}')
            else:
                files_to_include.append(f'Resources/{item}')
    
    # Add SafariWebExtensionHandler.swift
    files_to_include.append('SafariWebExtensionHandler.swift')
    
    # Format the file list for Xcode
    formatted_files = ',\n\t\t\t\t'.join(f'"{f}"' for f in files_to_include)
    new_exceptions = f'\n\t\t\t\t{formatted_files},\n\t\t\t'
    
    # Update both iOS and macOS target exceptions
    content = re.sub(ios_exception_pattern, r'\1' + new_exceptions + r'\2', content)
    content = re.sub(macos_exception_pattern, r'\1' + new_exceptions + r'\2', content)
    
    with open(project_path, 'w') as f:
        f.write(content)
    
    print("Xcode project file updated successfully.")

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python3 update_xcode_project.py <project_file_path>")
        sys.exit(1)
    
    update_project_file(sys.argv[1])
EOF

# Run the Python script to update the project file
python3 /tmp/update_xcode_project.py "$PROJECT_FILE"

# Clean up temporary script
rm /tmp/update_xcode_project.py

echo "Safari resources sync completed successfully!"
echo ""
echo "Files synced to: $TARGET_DIR"
echo "Xcode project updated: $PROJECT_FILE"