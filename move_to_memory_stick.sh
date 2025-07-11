#!/bin/bash

# Script to move files to memory stick and fill it halfway to capacity
# Usage: ./move_to_memory_stick.sh [source_directory] [target_directory_on_memory_stick]

echo "=== Memory Stick File Transfer Script ==="
echo ""

# Check if memory stick is connected
echo "Checking for connected memory sticks..."
echo ""

# List all mounted volumes
echo "Currently mounted volumes:"
df -h | grep "/Volumes" || echo "No external volumes found"
echo ""

# Function to find memory stick
find_memory_stick() {
    # Look for common memory stick mount points
    local possible_mounts=("/Volumes"/*)
    
    for mount in "${possible_mounts[@]}"; do
        if [[ -d "$mount" && "$mount" != "/Volumes/Preboot" && "$mount" != "/Volumes/Update" ]]; then
            # Check if it's likely a memory stick (not system volume)
            if [[ ! "$mount" =~ "Macintosh" && ! "$mount" =~ "Simulator" && ! "$mount" =~ "Unity" ]]; then
                echo "Found potential memory stick: $mount"
                return 0
            fi
        fi
    done
    return 1
}

# Function to format bytes to human readable
format_bytes() {
    local bytes=$1
    if [[ $bytes -gt 1073741824 ]]; then
        echo "$(echo "scale=2; $bytes/1073741824" | bc)GB"
    elif [[ $bytes -gt 1048576 ]]; then
        echo "$(echo "scale=2; $bytes/1048576" | bc)MB"
    elif [[ $bytes -gt 1024 ]]; then
        echo "$(echo "scale=2; $bytes/1024" | bc)KB"
    else
        echo "${bytes}B"
    fi
}

# Function to calculate space needed
calculate_space_needed() {
    local total_space=$(df "$1" | awk 'NR==2 {print $2}')
    local used_space=$(df "$1" | awk 'NR==2 {print $3}')
    local available_space=$(df "$1" | awk 'NR==2 {print $4}')
    
    echo "Memory stick space analysis:"
    echo "  Total space: $(format_bytes $((total_space * 1024)))"
    echo "  Used space: $(format_bytes $((used_space * 1024)))"
    echo "  Available space: $(format_bytes $((available_space * 1024)))"
    
    # Calculate 50% of total capacity
    local half_capacity=$((total_space / 2))
    space_to_fill=$((half_capacity - used_space))
    
    echo "  Space to fill (50% capacity): $(format_bytes $((space_to_fill * 1024)))"
    echo ""
}

# Function to copy files
copy_files() {
    local source_dir="$1"
    local target_dir="$2"
    local space_needed="$3"
    
    echo "Copying files from '$source_dir' to '$target_dir'..."
    echo "Target space to fill: $(format_bytes $((space_needed * 1024)))"
    echo ""
    
    # Create target directory if it doesn't exist
    mkdir -p "$target_dir"
    
    # Copy files with progress
    local copied_size=0
    local files_copied=0
    
    # Find all files in source directory
    while IFS= read -r -d '' file; do
        if [[ -f "$file" ]]; then
            local file_size=$(stat -f%z "$file" 2>/dev/null || echo "0")
            
            # Check if adding this file would exceed our target
            if [[ $((copied_size + file_size)) -le $((space_needed * 1024)) ]]; then
                local relative_path="${file#$source_dir/}"
                local target_path="$target_dir/$relative_path"
                local target_dir_path=$(dirname "$target_path")
                
                # Create subdirectories if needed
                mkdir -p "$target_dir_path"
                
                # Copy the file
                if cp "$file" "$target_path" 2>/dev/null; then
                    copied_size=$((copied_size + file_size))
                    files_copied=$((files_copied + 1))
                    echo "✓ Copied: $relative_path ($(format_bytes $file_size))"
                else
                    echo "✗ Failed to copy: $relative_path"
                fi
            else
                echo "⏹  Stopping - target space reached"
                break
            fi
        fi
    done < <(find "$source_dir" -type f -print0 2>/dev/null)
    
    echo ""
    echo "Copy operation completed:"
    echo "  Files copied: $files_copied"
    echo "  Total size copied: $(format_bytes $copied_size)"
    echo "  Target was: $(format_bytes $((space_needed * 1024)))"
}

# Main execution
if find_memory_stick; then
    # Get the first memory stick found
    memory_stick=$(find /Volumes -maxdepth 1 -type d 2>/dev/null | grep -v "/Volumes$" | grep -v "Macintosh" | grep -v "Simulator" | grep -v "Unity" | head -1)
    
    if [[ -n "$memory_stick" ]]; then
        echo "Using memory stick: $memory_stick"
        echo ""
        
        # Calculate space needed
        calculate_space_needed "$memory_stick"
        
        # Set source and target directories
        source_dir="${1:-.}"
        target_dir="${2:-$memory_stick/Faith_Journal_Backup}"
        
        echo "Source directory: $source_dir"
        echo "Target directory: $target_dir"
        echo ""
        
        # Ask for confirmation
        read -p "Do you want to proceed with copying files? (y/N): " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            copy_files "$source_dir" "$target_dir" "$space_to_fill"
        else
            echo "Operation cancelled."
        fi
    else
        echo "No suitable memory stick found."
    fi
else
    echo "No memory stick detected. Please:"
    echo "1. Connect your memory stick"
    echo "2. Wait for it to mount"
    echo "3. Run this script again"
    echo ""
    echo "To check for newly connected devices, run:"
    echo "  diskutil list"
    echo "  df -h"
fi

echo ""
echo "Script completed." 