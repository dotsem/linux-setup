#!/bin/bash
# Gaming Setup Module
# Supports: Steam, Lutris, Gamemode, Vulkan

source "$(dirname "${BASH_SOURCE[0]}")/../helpers/ui.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../helpers/logging.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../vars.sh"

setup_gaming() {
    section "GAMING SETUP" "$MAGENTA"
    log "INFO" "Setting up gaming environment"
    
    setup_vulkan
    setup_steam
    setup_lutris
    setup_gamemode
    setup_emulation
    
    log "INFO" "Gaming environment ready"
    echo -e "${GREEN}Gaming setup complete!${NC}"
    echo -e "${YELLOW}Tested games: Phasmophobia, Fallout 4, GeoGuessr (Steam/Proton)${NC}"
}

setup_vulkan() {
    section "VULKAN SETUP" "$BLUE"
    log "INFO" "Installing Vulkan drivers"
    
    case "$DETECTED_PKG_MANAGER" in
        dnf)
            sudo dnf install -y mesa-vulkan-drivers vulkan-loader vulkan-tools 2>>"$LOG_FILE"
            ;;
        pacman)
            sudo pacman -S --noconfirm vulkan-icd-loader vulkan-tools lib32-vulkan-icd-loader lib32-mesa lib32-gcc-libs 2>>"$LOG_FILE"
            if lspci | grep -qi nvidia; then
                sudo pacman -S --noconfirm nvidia-utils lib32-nvidia-utils 2>>"$LOG_FILE"
            fi
            if lspci | grep -qi "intel.*graphics"; then
                sudo pacman -S --noconfirm vulkan-intel lib32-vulkan-intel 2>>"$LOG_FILE"
            fi
            if lspci | grep -qi "amd.*graphics\|radeon"; then
                sudo pacman -S --noconfirm vulkan-radeon lib32-vulkan-radeon 2>>"$LOG_FILE"
            fi
            ;;
        apt)
            sudo apt-get install -y mesa-vulkan-drivers libvulkan1 vulkan-tools 2>>"$LOG_FILE"
            ;;
    esac
    
    log "INFO" "Vulkan installed"
    echo -e "${GREEN}Vulkan drivers installed!${NC}"
}

setup_steam() {
    section "STEAM SETUP" "$GREEN"
    log "INFO" "Installing Steam"
    
    if flatpak list 2>/dev/null | grep -q "com.valvesoftware.Steam"; then
        log "INFO" "Steam already installed via Flatpak"
        echo -e "${GREEN}Steam already installed!${NC}"
    else
        print_status info "Installing Steam via Flatpak..."
        flatpak install -y flathub com.valvesoftware.Steam 2>>"$LOG_FILE"
    fi
    
    # Allow Steam access to Discord for rich presence
    flatpak override --user --filesystem=xdg-run/app/com.discordapp.Discord:create com.valvesoftware.Steam 2>>"$LOG_FILE" || true
    
    # Setup automatic gamemode for Steam games
    setup_steam_gamemode
    
    log "INFO" "Steam installed with gamemode integration"
    echo -e "${GREEN}Steam installed via Flatpak with gamemode!${NC}"
}

setup_steam_gamemode() {
    section "STEAM GAMEMODE INTEGRATION" "$CYAN"
    log "INFO" "Configuring automatic gamemode for Steam games"
    
    # Allow Steam Flatpak to access gamemode socket
    flatpak override --user --filesystem=/run/gamemode com.valvesoftware.Steam 2>>"$LOG_FILE" || true
    flatpak override --user --socket=system-bus com.valvesoftware.Steam 2>>"$LOG_FILE" || true
    flatpak override --user --talk-name=com.feralinteractive.GameMode com.valvesoftware.Steam 2>>"$LOG_FILE" || true
    
    # Create Steam compatibility tools folder
    local steam_compat_dir="$HOME/.var/app/com.valvesoftware.Steam/.steam/steam/compatibilitytools.d"
    mkdir -p "$steam_compat_dir"
    
    # Create wrapper script for gamemoderun
    local wrapper_dir="$HOME/.local/share/steam-gamemode"
    mkdir -p "$wrapper_dir"
    
    cat > "$wrapper_dir/gamemode-wrapper.sh" << 'WRAPPER'
#!/bin/bash
# Wrapper to run Steam games with gamemode
# Usage: Set Steam launch options to: ~/.local/share/steam-gamemode/gamemode-wrapper.sh %command%

if command -v gamemoderun &>/dev/null; then
    exec gamemoderun "$@"
else
    exec "$@"
fi
WRAPPER
    chmod +x "$wrapper_dir/gamemode-wrapper.sh"
    
    # Create Desktop entry for Steam with gamemode
    local desktop_dir="$HOME/.local/share/applications"
    mkdir -p "$desktop_dir"
    
    cat > "$desktop_dir/steam-gamemode.desktop" << 'DESKTOP'
[Desktop Entry]
Name=Steam (Gamemode)
Comment=Steam with automatic gamemode
Exec=gamemoderun flatpak run com.valvesoftware.Steam
Icon=steam
Terminal=false
Type=Application
Categories=Game;
DESKTOP
    
    log "INFO" "Gamemode integration configured"
    echo -e "${GREEN}Gamemode integration configured!${NC}"
    echo ""
    echo -e "${YELLOW}To run games with gamemode (choose one method):${NC}"
    echo -e "  ${BLUE}Method 1 (Recommended):${NC} Use 'Steam (Gamemode)' desktop entry"
    echo -e "  ${BLUE}Method 2:${NC} Set Steam launch options to:"
    echo -e "           ${CYAN}gamemoderun %command%${NC}"
    echo -e "  ${BLUE}Method 3:${NC} Run Steam from terminal with:"
    echo -e "           ${CYAN}gamemoderun flatpak run com.valvesoftware.Steam${NC}"
}

setup_lutris() {
    section "LUTRIS SETUP" "$YELLOW"
    log "INFO" "Installing Lutris"
    
    if flatpak list 2>/dev/null | grep -q "net.lutris.Lutris"; then
        log "INFO" "Lutris already installed via Flatpak"
        echo -e "${GREEN}Lutris already installed!${NC}"
        return 0
    fi
    
    print_status info "Installing Lutris via Flatpak..."
    flatpak install -y flathub net.lutris.Lutris 2>>"$LOG_FILE"
    
    log "INFO" "Lutris installed"
    echo -e "${GREEN}Lutris installed!${NC}"
}

setup_gamemode() {
    section "GAMEMODE SETUP" "$CYAN"
    log "INFO" "Installing gamemode"
    
    case "$DETECTED_PKG_MANAGER" in
        dnf)
            sudo dnf install -y gamemode mangohud 2>>"$LOG_FILE"
            ;;
        pacman)
            sudo pacman -S --noconfirm gamemode lib32-gamemode mangohud lib32-mangohud 2>>"$LOG_FILE"
            ;;
        apt)
            sudo apt-get install -y gamemode 2>>"$LOG_FILE"
            ;;
    esac
    
    if getent group gamemode &>/dev/null; then
        sudo usermod -aG gamemode "$USER" 2>>"$LOG_FILE"
        log "INFO" "Added user to gamemode group"
    fi
    
    log "INFO" "Gamemode installed"
    echo -e "${GREEN}Gamemode configured!${NC}"
    echo -e "${YELLOW}Use 'gamemoderun <game>' for better performance${NC}"
}

setup_emulation() {
    section "GAME EMULATION" "$MAGENTA"
    log "INFO" "Installing RetroArch"
    
    if flatpak list 2>/dev/null | grep -q "org.libretro.RetroArch"; then
        log "INFO" "RetroArch already installed"
        echo -e "${GREEN}RetroArch already installed!${NC}"
        return 0
    fi
    
    print_status info "Installing RetroArch via Flatpak..."
    flatpak install -y flathub org.libretro.RetroArch 2>>"$LOG_FILE"
    
    log "INFO" "RetroArch installed"
    echo -e "${GREEN}RetroArch emulator installed!${NC}"
}

setup_obs() {
    section "OBS STUDIO SETUP" "$BLUE"
    log "INFO" "Installing OBS Studio"
    
    if flatpak list 2>/dev/null | grep -q "com.obsproject.Studio"; then
        log "INFO" "OBS already installed"
        echo -e "${GREEN}OBS Studio already installed!${NC}"
        return 0
    fi
    
    print_status info "Installing OBS Studio via Flatpak..."
    flatpak install -y flathub com.obsproject.Studio 2>>"$LOG_FILE"
    
    log "INFO" "OBS Studio installed"
    echo -e "${GREEN}OBS Studio installed!${NC}"
}

verify_gaming() {
    section "GAMING VERIFICATION" "$CYAN"
    
    echo -e "${BLUE}Vulkan info:${NC}"
    if command -v vulkaninfo &>/dev/null; then
        vulkaninfo --summary 2>/dev/null | head -20
    else
        echo -e "${YELLOW}vulkaninfo not found${NC}"
    fi
    
    echo -e "\n${BLUE}Gamemode status:${NC}"
    if command -v gamemoded &>/dev/null; then
        gamemoded -t 2>/dev/null && echo -e "${GREEN}Gamemode working!${NC}" || echo -e "${YELLOW}Gamemode test failed${NC}"
    fi
}
