#!/usr/bin/env bash
# Non-essential packages for après-setup
# These can be installed after the system is functional

NONESSENTIAL_PACMAN_PACKAGES=(
    # Development tools
    clang
    cmake
    gcc
    rust
    rust-src
    go
    nodejs
    npm
    python
    python-pip
    php
    mysql
    docker
    docker-compose
    github-cli
    libsoup
    webkit2gtk
    webkit2gtk-4.1
    gtk3
    
    # Entertainment
    cava
    cowsay
    feh
    
    # Bluetooth
    blueman
    
    # Audio production
    ardour
    helvum
    
    # Office and productivity
    libreoffice-still
    obsidian
    qalculate-gtk
    
    # Image viewer
    gwenview
    
    # Games
    openttd
    
    # Appearance
    nwg-look
    
    # Boot
    os-prober
    
    # Window managers (additional)
    i3-wm
    polybar

    # Android phone
    android-udev
    gvfs-mtp
    
    # Hardware info
    hwinfo

    baobab
)

NONESSENTIAL_AUR_PACKAGES=(
    # Browsers (-bin for faster installation)
    google-chrome
    zen-browser-bin
    
    # Development (-bin packages where available)
    visual-studio-code-bin
    antigravity-bin
    android-sdk
    angular-cli
    flutter  # or flutter-bin for faster install
    xampp
    
    # Communication
    vesktop-bin
    
    # Gaming
    steam
    lutris
    gamemode
    obs-studio
    retroarch
    
    # Music
    tuxguitar
    spotify-bin
    
    # Utilities (-bin for efficiency)
    neofetch-bin
    quickshell-git
    xwaylandvideobridge
    yay-bin  # Use binary version of yay itself
    
    # System monitors
    btop-bin
    
    # Additional tools
    postman-bin
    insomnia-bin
)

NONESSENTIAL_FLATPAK_PACKAGES=(
    org.gnome.Mahjongg
    com.github.wwmm.easyeffects
)
