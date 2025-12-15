#!/usr/bin/env bash

# ===== USER CONFIGURATION =====
GIT_NAME="Sem VB"
GIT_EMAIL="sem.van.broekhoven@gmail.com"
DOTFILES_URL="https://github.com/dotsem/dotfiles.git"
DOTFILES_DIR="$HOME/.dotfiles"
USB_MOUNT_PATH="/mnt/usb"
KERNEL_TYPE="linux"
LOG_LEVEL="INFO"
AUDIO_NAMING_FILE="$HOME/.config/audio-naming/pc.cfg"

# Package manager target: "auto", "pacman", "dnf", "apt"
# "auto" will detect based on distro
TARGET_PACKAGE_MANAGER="auto"

# Desktop environment
PRIMARY_DE="hyprland"
DISPLAY_MANAGER="sddm"

# Bootloader: "grub" or "systemd-boot" (Arch only for systemd-boot)
BOOTLOADER="systemd-boot"

# Development versions
FLUTTER_CHANNEL="stable"
JAVA_VERSION="21"
PYTHON_VERSION="3.13"
NODE_VERSION="lts"

# ==============================

# Distro detection function
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        case "$ID" in
            fedora|rhel|centos)
                echo "dnf"
                ;;
            arch|manjaro|endeavouros|cachyos)
                echo "pacman"
                ;;
            ubuntu|debian|pop|linuxmint)
                echo "apt"
                ;;
            *)
                echo "unknown"
                ;;
        esac
    else
        echo "unknown"
    fi
}

# Get active package manager
get_package_manager() {
    if [ "$TARGET_PACKAGE_MANAGER" = "auto" ]; then
        detect_distro
    else
        echo "$TARGET_PACKAGE_MANAGER"
    fi
}

# Get distro ID
get_distro_id() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "$ID"
    else
        echo "unknown"
    fi
}

# Get distro name
get_distro_name() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "$NAME"
    else
        echo "Unknown"
    fi
}

# Get distro family (groups related distros)
get_distro_family() {
    local distro_id="${1:-$(get_distro_id)}"
    case "$distro_id" in
        arch|manjaro|endeavouros|cachyos)
            echo "arch"
            ;;
        fedora|rhel|centos)
            echo "fedora"
            ;;
        ubuntu|debian|pop|linuxmint)
            echo "debian"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

# Detected values (set at source time)
DETECTED_PKG_MANAGER=$(get_package_manager)
DETECTED_DISTRO_ID=$(get_distro_id)
DETECTED_DISTRO_NAME=$(get_distro_name)
DETECTED_DISTRO_FAMILY=$(get_distro_family)
