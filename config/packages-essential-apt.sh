#!/usr/bin/env bash
# Essential Debian/Ubuntu packages

ESSENTIAL_APT_PACKAGES=(
    # Base development
    build-essential
    linux-headers-generic
    linux-firmware
    
    # Display server and Wayland
    wayland-protocols
    libwayland-dev
    xorg
    xinit
    xauth
    
    # Display manager
    sddm
    
    # KDE Plasma (backup DE)
    kde-plasma-desktop
    plasma-workspace-wayland
    
    # Terminal and shell
    alacritty
    zsh
    zsh-syntax-highlighting
    zsh-autosuggestions
    
    # Audio (PipeWire)
    pipewire
    pipewire-pulse
    pipewire-jack
    wireplumber
    pavucontrol
    
    # Network
    network-manager
    network-manager-openvpn
    openssh-server
    
    # File management
    udiskie
    
    # Essential utilities
    nano
    neovim
    git
    curl
    wget
    unzip
    p7zip-full
    jq
    xxd
    htop
    stow
    rsync
    
    # Brightness and power
    brightnessctl
    tlp
    tlp-rdw
    
    # Notifications
    dunst
    
    # File systems
    exfatprogs
    ntfs-3g
    btrfs-progs
    
    # Qt/GTK
    qtbase5-dev
    qt6-base-dev
    libgtk-layer-shell-dev
    
    # Application launcher
    wofi
    
    # Flatpak
    flatpak
    
    # Keyring
    gnome-keyring
    seahorse
    libsecret-1-0
    
    # Virtualization for Android emulator
    qemu-kvm
    qemu-system-x86
    libvirt-daemon-system
    virt-manager
    bridge-utils
    ovmf
    
    # Polkit
    policykit-1-gnome
)

ESSENTIAL_PPA_PACKAGES=(
    # Hyprland needs to be built from source on Ubuntu
    # or installed via a PPA when available
)

ESSENTIAL_FLATPAK_PACKAGES=(
)
