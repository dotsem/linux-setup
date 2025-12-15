#!/usr/bin/env bash
# Essential Fedora packages

ESSENTIAL_DNF_PACKAGES=(
    # Base development
    "@development-tools"
    kernel-devel
    kernel-headers
    
    # Display server and Wayland
    wayland-devel
    xorg-x11-server-Xorg
    xorg-x11-xinit
    xorg-x11-xauth
    
    # Display manager
    sddm
    
    # KDE Plasma (backup DE)
    @kde-desktop-environment
    plasma-workspace-wayland
    
    # Terminal and shell
    alacritty
    fish
    
    # Audio (PipeWire)
    pipewire
    pipewire-pulseaudio
    pipewire-jack-audio-connection-kit
    wireplumber
    pavucontrol
    
    # Network
    NetworkManager
    NetworkManager-openvpn
    openssh-server
    
    # File management
    lf
    udiskie
    
    # Essential utilities
    nano
    neovim
    git
    curl
    wget
    which
    unzip
    p7zip
    p7zip-plugins
    jq
    vim-common
    htop
    stow
    rsync
    
    # Brightness and power
    brightnessctl
    tlp
    tlp-rdw
    power-profiles-daemon
    
    # Notifications
    dunst
    
    # File systems
    exfatprogs
    ntfs-3g
    btrfs-progs
    
    # Qt/GTK
    qt5-qtbase
    qt6-qtbase
    gtk-layer-shell
    
    # Application launcher
    wofi
    
    # Flatpak
    flatpak
    
    # Keyring
    gnome-keyring
    seahorse
    libsecret
    
    # Virtualization for Android emulator
    @virtualization
    qemu-kvm
    libvirt
    virt-manager
    bridge-utils
    edk2-ovmf
    
    # Firmware
    linux-firmware
)

ESSENTIAL_COPR_PACKAGES=(
    "solopasha/hyprland/hyprland"
    "solopasha/hyprland/xdg-desktop-portal-hyprland"
    "solopasha/hyprland/hypridle"
    "solopasha/hyprland/hyprlock"
    "solopasha/hyprland/hyprpaper"
    "solopasha/hyprland/hyprpicker"
    "solopasha/hyprland/hyprutils"
    "solopasha/hyprland/hyprpolkitagent"
)

ESSENTIAL_FLATPAK_PACKAGES=(
)
