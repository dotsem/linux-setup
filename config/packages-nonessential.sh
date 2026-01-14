#!/usr/bin/env bash
# Non-essential packages for après-setup (Arch Linux / Manjaro)
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
  docker
  docker-compose
  github-cli
  libsoup
  webkit2gtk
  webkit2gtk-4.1
  gtk3

  # Java (JDK 21)
  jdk21-openjdk

  # .NET SDK
  dotnet-sdk

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
  qalculate-gtk

  # Image viewer
  gwenview

  # Photo editing
  rawtherapee

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

  # Multimedia
  ffmpeg
  vlc

  # Gaming dependencies
  vulkan-icd-loader
  vulkan-tools
  lib32-vulkan-icd-loader
  gamemode
  lib32-gamemode
  mangohud
)

NONESSENTIAL_AUR_PACKAGES=(
  # Browsers
  google-chrome
  zen-browser-bin

  # Development
  visual-studio-code-bin
  antigravity-bin
  android-sdk
  android-sdk-cmdline-tools-latest
  angular-cli
  xampp

  # Communication
  vesktop-bin

  # Gaming
  steam
  lutris
  obs-studio
  retroarch

  # Music
  tuxguitar
  spotify-launcher

  # Utilities
  # xwaylandvideobridge
  fastfetch
  # yay-bin

  # System monitors
  btop

  # Additional tools
  postman-bin
  insomnia-bin
)

NONESSENTIAL_FLATPAK_PACKAGES=(
  org.gnome.Mahjongg
  com.github.wwmm.easyeffects
  md.obsidian.Obsidian
)
