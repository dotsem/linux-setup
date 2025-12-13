#!/bin/bash
# Legacy package file - kept for backward compatibility
# New installations should use lib/package-manager.sh and config/packages-*.sh

# Load the new package manager
source "$(dirname "${BASH_SOURCE[0]}")/../lib/package-manager.sh"

# Load package lists
source "$(dirname "${BASH_SOURCE[0]}")/../config/packages-essential.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../config/packages-nonessential.sh"

# Legacy variables for backward compatibility
PACMAN_PACKAGES=("${ESSENTIAL_PACMAN_PACKAGES[@]}" "${NONESSENTIAL_PACMAN_PACKAGES[@]}")
AUR_PACKAGES=("${ESSENTIAL_AUR_PACKAGES[@]}" "${NONESSENTIAL_AUR_PACKAGES[@]}")
FLATPAK_PACKAGES=("${ESSENTIAL_FLATPAK_PACKAGES[@]}" "${NONESSENTIAL_FLATPAK_PACKAGES[@]}")

# Detect NVIDIA GPU and add drivers if needed
detect_and_add_nvidia PACMAN_PACKAGES
