#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(dirname "$(realpath "$0")")"

# help message
for ARGUMENT in "$@"; do
    if [ "$ARGUMENT" == "-h" ] || [ "$ARGUMENT" == "--help" ]; then
        echo "usage: $(basename "$0")"
        echo "Run all scripts in the same folder."
        echo "All arguments are passed to the build scripts."
        exit
    fi
done

mapfile -t BUILD_SCRIPTS -d '' < <(find "$SCRIPT_DIR" -name '*.sh' -not -name "$(basename "$0")")
for BUILD_SCRIPT in "${BUILD_SCRIPTS[@]}"; do
    echo "Start \"$(basename "${BUILD_SCRIPT}")\""
    "$BUILD_SCRIPT" "$@"
    echo "Finished \"$(basename "${BUILD_SCRIPT}")\""
done
