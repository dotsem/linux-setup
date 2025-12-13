#!/usr/bin/env bash
# Non-essential Debian/Ubuntu packages for après-setup

NONESSENTIAL_APT_PACKAGES=(
    # Development tools
    clang
    cmake
    gcc
    g++
    
    # Go
    golang
    
    # Node.js
    nodejs
    npm
    
    # Python
    python3
    python3-pip
    python3-venv
    python3-tk
    
    # PHP
    php
    php-cli
    php-json
    php-mbstring
    php-xml
    
    # Java (JDK 21)
    openjdk-21-jdk
    
    # .NET SDK
    dotnet-sdk-8.0
    
    # Docker (from docker repo)
    docker-ce
    docker-ce-cli
    containerd.io
    docker-compose-plugin
    
    # GitHub CLI
    gh
    
    # WebKit for Tauri/GTK apps
    libwebkit2gtk-4.1-dev
    libgtk-3-dev
    libsoup-3.0-dev
    
    # Entertainment
    cava
    cowsay
    feh
    neofetch
    
    # Bluetooth
    blueman
    bluez
    
    # Audio production
    ardour
    helvum
    
    # Office and productivity
    libreoffice
    qalculate-gtk
    
    # Image viewer
    gwenview
    
    # Photo editing
    rawtherapee
    
    # Games
    openttd
    
    # Appearance
    lxappearance
    
    # Boot
    os-prober
    
    # Window managers (additional)
    i3
    polybar
    
    # Android phone
    android-tools-adb
    android-tools-fastboot
    gvfs-backends
    
    # Hardware info
    hwinfo
    lshw
    
    # Disk usage
    baobab
    
    # Multimedia
    ffmpeg
    vlc
    
    # Gaming dependencies
    mesa-vulkan-drivers
    libvulkan1
    vulkan-tools
    gamemode
    
    # System monitors
    btop
)

NONESSENTIAL_PPA_PACKAGES=(
    # Add PPAs as needed
)

NONESSENTIAL_FLATPAK_PACKAGES=(
    # Browsers
    com.google.Chrome
    io.github.nickvision.webview
    io.github.nickvision.zen
    
    # Development
    com.visualstudio.code
    rest.insomnia.Insomnia
    com.getpostman.Postman
    io.gitlab.ArcticAquila.antigravity
    
    # Communication
    dev.vencord.Vesktop
    
    # Gaming
    com.valvesoftware.Steam
    net.lutris.Lutris
    com.obsproject.Studio
    org.libretro.RetroArch
    
    # Music
    com.spotify.Client
    
    # Music production
    org.tuxguitar.TuxGuitar
    
    # Productivity
    md.obsidian.Obsidian
    
    # Games
    org.gnome.Mahjongg
    
    # Audio
    com.github.wwmm.easyeffects
)
