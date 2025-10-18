#!/bin/bash
set -e

PROJECT_FILE="safari/ipvfoo-safari.xcodeproj/project.pbxproj"
RESOURCES_DIR="safari/Shared (Extension)/Resources"

echo "Scanning Resources directory for files to add to membershipExceptions..."

# Find all files in Resources directory (relative to Resources/)
if [ ! -d "$RESOURCES_DIR" ]; then
  echo "⚠️  Resources directory not found. Run 'make safari' first to build extension files."
  exit 1
fi

# Get all files, make paths relative to "Shared (Extension)/"
FILES=()
while IFS= read -r file; do
  # Convert absolute path to relative path from Resources
  rel_path="${file#$RESOURCES_DIR/}"
  FILES+=("Resources/$rel_path")
done < <(find "$RESOURCES_DIR" -type f ! -name ".DS_Store" | sort)

if [ ${#FILES[@]} -eq 0 ]; then
  echo "⚠️  No files found in Resources directory"
  exit 1
fi

echo "Found ${#FILES[@]} files to add to exceptions"

# Backup
cp "$PROJECT_FILE" "$PROJECT_FILE.backup"

# First, remove any existing Resources entries to prevent duplicates
for file in "${FILES[@]}"; do
  escaped_file=$(echo "$file" | sed 's/[\/]/\\&/g')
  sed -i '' "/${escaped_file},/d" "$PROJECT_FILE"
done

# Build the insert text
INSERT_TEXT=""
for file in "${FILES[@]}"; do
  INSERT_TEXT="${INSERT_TEXT}\\
				${file},"
done

# Add to iOS extension
sed -i '' '/B2C2F82F2EA2ACB90051EEFB.*Shared.*Extension.*iOS/,/target = B2C2F7ED2EA2ACB90051EEFB/ {
  /DNSResolver.swift,/a\
'"${INSERT_TEXT}"'
}' "$PROJECT_FILE"

# Add to macOS extension
sed -i '' '/B2C2F8302EA2ACB90051EEFB.*Shared.*Extension.*macOS/,/target = B2C2F7F72EA2ACB90051EEFB/ {
  /DNSResolver.swift,/a\
'"${INSERT_TEXT}"'
}' "$PROJECT_FILE"

echo "✅ All Resources files added to membershipExceptions (no duplicates)"
echo "Backup: $PROJECT_FILE.backup"
