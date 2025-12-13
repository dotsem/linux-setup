#!/usr/bin/env bash
# Essential packages needed for a functional system
# These packages are installed first and are critical for basic operation

# Core system packages (Arch Linux / Manjaro)
ESSENTIAL_PACMAN_PACKAGES=(
    # Kernel and base
    base-devel
    linux-firmware
    
    # Display server and window managers
    wayland
    xorg-server
    xorg-xinit
    xorg-xauth
    hyprland
    xdg-desktop-portal-hyprland
    
    # Display manager
    sddm
    
    # KDE Plasma (backup DE)
    plasma-desktop
    plasma-wayland-protocols
    
    # Terminal and shell
    alacritty
    zsh
    zsh-syntax-highlighting
    zsh-autosuggestions
    
    # Audio
    pipewire
    pipewire-pulse
    pipewire-jack
    wireplumber
    pavucontrol
    
    # Network
    networkmanager
    networkmanager-openvpn
    openssh
    
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
    7zip
    jq
    xxd
    htop
    stow
    rsync
    
    # Brightness and power
    brightnessctl
    tlp
    
    # Notifications
    dunst
    
    # File systems
    exfat-utils
    ntfs-3g
    btrfs-progs
    
    # Qt/GTK
    qt5-base
    qt6-base
    gtk-layer-shell
    
    # Hyprland ecosystem
    hyprpicker
    hypridle
    hyprlock
    hyprpaper
    hyprshot
    hyprutils
    hyprpolkitagent
    
    # Application launcher
    wofi
    
    # Flatpak
    flatpak
    
    # Keyring
    gnome-keyring
    seahorse
    libsecret
    
    # Virtualization for Android emulator
    qemu-full
    libvirt
    virt-manager
    dnsmasq
    bridge-utils
    edk2-ovmf
)

ESSENTIAL_AUR_PACKAGES=(
    # Shell
    oh-my-zsh-git
    
    # Wayland tools
    rofi-wayland
    
    # Hyprland extras
    hyprshell
    hyprsunset
)

ESSENTIAL_FLATPAK_PACKAGES=(
)
