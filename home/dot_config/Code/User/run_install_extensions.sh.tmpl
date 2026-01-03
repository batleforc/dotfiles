#!/bin/bash

# Script to install all VS Code extensions from extensions.json
# Run by chezmoi at each apply

# Get the directory where the script is located
SCRIPT_DIR="{{ joinPath .chezmoi.sourceDir "home/dot_config/Code/User" }}"
EXTENSIONS_FILE="$SCRIPT_DIR/extensions.json"

# Check if extensions.json exists
if [ ! -f "$EXTENSIONS_FILE" ]; then
    echo "Error: extensions.json not found at $EXTENSIONS_FILE"
    exit 1
fi

# Check if code command is available
if ! command -v code &> /dev/null; then
    echo "Error: 'code' command not found. Please ensure VS Code is installed and in your PATH."
    exit 1
fi

# Check if jq is available for JSON parsing
if ! command -v jq &> /dev/null; then
    echo "Warning: 'jq' not found. Attempting to parse JSON with grep and sed..."
    # Fallback method without jq
    extensions=$(grep -oP '"\K[^"]+(?=")' "$EXTENSIONS_FILE" | grep '\.')
else
    # Use jq for proper JSON parsing
    extensions=$(jq -r '.recommendations[]' "$EXTENSIONS_FILE")
fi

# Install each extension
echo "Installing VS Code extensions..."
echo "================================"

installed=0
failed=0

for extension in $extensions; do
    echo "Installing: $extension"
    if code --install-extension "$extension"; then
        ((installed++))
    else
        echo "Failed to install: $extension"
        ((failed++))
    fi
    echo ""
done

echo "================================"
echo "Installation complete!"
echo "Installed: $installed"
echo "Failed: $failed"

