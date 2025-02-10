#!/bin/bash

# Check if at least one argument is provided
if [[ $# -eq 0 ]]; then
    echo "Usage: $0 --key1 value1 --key2 value2 ..."
    exit 1
fi

# Parse named arguments dynamically
while [[ $# -gt 0 ]]; do
    case "$1" in
        --*)
            key=$(echo "$1" | sed 's/^--//')  # Convert to uppercase for consistency
            value="$2"
            shift 2
            ;;
        *)
            echo "Unknown argument: $1"
            exit 1
            ;;
    esac

    # Export to GITHUB_ENV
    echo "$key=$value" >> "$GITHUB_OUTPUT"
    echo "Exported: $key=$value"
done
