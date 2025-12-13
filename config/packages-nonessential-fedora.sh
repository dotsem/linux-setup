#!/usr/bin/env bash
# Non-essential Fedora packages for après-setup

NONESSENTIAL_DNF_PACKAGES=(
    # Development tools
    clang
    cmake
    gcc
    gcc-c++
    
    # Go
    golang
    
    # Node.js
    nodejs
    npm
    
    # Python
    python3
    python3-pip
    python3-virtualenv
    python3-tkinter
    
    # PHP
    php
    php-cli
    php-json
    php-mbstring
    php-xml
    
    # Java (JDK 21)
    java-21-openjdk
    java-21-openjdk-devel
    
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
    webkit2gtk4.1
    gtk3
    libsoup3
    
    # Entertainment
    cava
    cowsay
    feh
    neofetch
    
    # Bluetooth
    blueman
    bluez
    bluez-tools
    
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
    nwg-look
    
    # Boot
    os-prober
    
    # Window managers (additional)
    i3
    polybar
    
    # Android phone
    android-tools
    gvfs-mtp
    
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
    mesa-vulkan-drivers.i686
    vulkan-loader
    vulkan-tools
    gamemode
    mangohud
    
    # System monitors
    btop
    
    # Xwayland video bridge (for screen share)
    xwaylandvideobridge
)

NONESSENTIAL_COPR_PACKAGES=(
    "solopasha/hyprland/hyprsunset"
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
