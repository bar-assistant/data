#!/bin/bash

# Script to rename ingredient and cocktail folders by removing numbers after underscore
# This script processes folders in data/ingredients/ and data/cocktails/ and removes the _NUMBER suffix

INGREDIENTS_DIR="data/ingredients"
COCKTAILS_DIR="data/cocktails"

# Check if the directories exist
if [ ! -d "$INGREDIENTS_DIR" ]; then
    echo "Error: Directory '$INGREDIENTS_DIR' not found!"
    exit 1
fi

if [ ! -d "$COCKTAILS_DIR" ]; then
    echo "Error: Directory '$COCKTAILS_DIR' not found!"
    exit 1
fi

echo "Starting to rename folders..."
echo "Removing numbers after underscore from folder names in $INGREDIENTS_DIR and $COCKTAILS_DIR"
echo

# Counter for tracking renames
renamed_count=0
skipped_count=0

# Function to process folders in a directory
process_directory() {
    local dir="$1"
    local dir_name="$2"
    
    echo "Processing $dir_name folders..."
    
    # Process each folder in the directory
    for folder in "$dir"/*; do
        # Check if it's actually a directory
        if [ -d "$folder" ]; then
            # Get the folder name without path
            folder_name=$(basename "$folder")
            
            # Check if folder name contains an underscore followed by numbers
            if [[ $folder_name =~ ^(.+)_[0-9]+$ ]]; then
                # Extract the part before the underscore and numbers
                new_name="${BASH_REMATCH[1]}"
                new_path="$dir/$new_name"
                
                # Check if target folder already exists and find available name
                final_name="$new_name"
                final_path="$new_path"
                counter=1
                
                while [ -d "$final_path" ]; do
                    final_name="${new_name}-${counter}"
                    final_path="$dir/$final_name"
                    ((counter++))
                done
                
                # Rename the folder
                if [ "$final_name" != "$new_name" ]; then
                    echo "Renaming '$folder_name' -> '$final_name' (original name existed)"
                else
                    echo "Renaming '$folder_name' -> '$final_name'"
                fi
                
                mv "$folder" "$final_path"
                if [ $? -eq 0 ]; then
                    ((renamed_count++))
                else
                    echo "Error: Failed to rename '$folder_name'"
                fi
            else
                echo "Skipping '$folder_name' (no underscore+number pattern found)"
                ((skipped_count++))
            fi
        fi
    done
}

# Process both directories
process_directory "$INGREDIENTS_DIR" "ingredient"
process_directory "$COCKTAILS_DIR" "cocktail"


echo "Renaming complete!"
echo "Folders renamed: $renamed_count"
echo "Folders skipped: $skipped_count"