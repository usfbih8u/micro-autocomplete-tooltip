#!/bin/bash

# This script MUST be executed from its directory.

readonly PLUGINS_DIR="$HOME/.config/micro/plug"
CURRENT_DIR="$(pwd)"
readonly CURRENT_DIR

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR

if [ ! "$SCRIPT_DIR" == "$CURRENT_DIR" ]; then
    echo -e "\e[31mERROR: current dir '${CURRENT_DIR}' is not '${SCRIPT_DIR}'.\e[0m"
    echo "ENABLE_FOR_MICRO.sh MUST be executed from its own directory."
    exit 1
fi

ln --symbolic "$CURRENT_DIR" "$PLUGINS_DIR"