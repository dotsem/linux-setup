#!/bin/bash

source "$(dirname "${BASH_SOURCE[0]}")/../helpers/ui.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../helpers/logging.sh"

setup_steam() {
    sudo systemctl enable --now steam-media-proxy
}

setup_emulation() {
    section "GAME EMULATION" "$MAGENTA"
    
    if yay -S --noconfirm retroarch 2>> "$LOG_FILE"; then
        # Install common cores
        yay -S --noconfirm libretro-core-info libretro-common 2>> "$LOG_FILE"
        
        mkdir -p ~/.config/retroarch/cores
        log "INFO" "Installed RetroArch with cores"
        print_status success "RetroArch emulator installed"
        
        # Add desktop shortcut
        cp /usr/share/applications/retroarch.desktop ~/Desktop/
        chmod +x ~/Desktop/retroarch.desktop
    else
        log "ERROR" "Failed to install RetroArch"
        print_status error "Emulator installation failed"
    fi
}