#!/bin/bash

# Script to set "updated_at" and "created_at" keys to null in all data.json files
# This script recursively finds all data.json files and updates the timestamp fields

echo "Starting to update data.json files..."
echo "Setting 'updated_at' and 'created_at' keys to null in all data.json files"
echo

# Counter for tracking updates
updated_count=0
error_count=0

# Find all data.json files recursively
find data/ -name "data.json" -type f | while read -r json_file; do
    echo "Processing: $json_file"
    
    # Check if file exists and is readable
    if [ ! -r "$json_file" ]; then
        echo "Error: Cannot read file '$json_file'"
        ((error_count++))
        continue
    fi
    
    # Create a temporary file for the updated JSON
    temp_file=$(mktemp)
    
    # Use jq to update both updated_at and created_at fields to null
    if jq '.updated_at = null | .created_at = null' "$json_file" > "$temp_file" 2>/dev/null; then
        # If jq succeeded, replace the original file
        if mv "$temp_file" "$json_file"; then
            echo "✓ Updated: $json_file"
            ((updated_count++))
        else
            echo "✗ Error: Failed to replace '$json_file'"
            rm -f "$temp_file"
            ((error_count++))
        fi
    else
        echo "✗ Error: Failed to parse JSON in '$json_file'"
        rm -f "$temp_file"
        ((error_count++))
    fi
done

echo
echo "Update complete!"
echo "Files updated: $updated_count"
echo "Errors encountered: $error_count"

# Check if jq is available
if ! command -v jq &> /dev/null; then
    echo
    echo "Note: This script requires 'jq' to be installed."
    echo "Install it with: sudo apt-get install jq (Ubuntu/Debian) or brew install jq (macOS)"
fi
