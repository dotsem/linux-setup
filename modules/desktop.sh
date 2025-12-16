#!/bin/bash
# Desktop Environment Setup Module
# Supports: SDDM, KDE Plasma, Hyprland, cross-DE keyring

source "$(dirname "${BASH_SOURCE[0]}")/../helpers/ui.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../helpers/logging.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../vars.sh"

setup_sddm() {
    section "SDDM DISPLAY MANAGER" "$BLUE"
    log "INFO" "Configuring SDDM"
    
    local display_managers=("gdm" "lightdm" "ly" "lxdm" "slim")
    for dm in "${display_managers[@]}"; do
        if systemctl is-enabled "$dm" &>/dev/null; then
            log "INFO" "Disabling conflicting display manager: $dm"
            sudo systemctl disable "$dm" 2>>"$LOG_FILE" || true
        fi
    done
    
    case "$DETECTED_PKG_MANAGER" in
        dnf)
            sudo dnf install -y sddm 2>>"$LOG_FILE"
            ;;
        pacman)
            sudo pacman -S --noconfirm sddm 2>>"$LOG_FILE"
            ;;
        apt)
            sudo apt-get install -y sddm 2>>"$LOG_FILE"
            ;;
    esac
    
    if sudo systemctl enable sddm 2>>"$LOG_FILE"; then
        log "INFO" "SDDM enabled"
        echo -e "${GREEN}SDDM display manager enabled!${NC}"
        return 0
    else
        log "ERROR" "Failed to enable SDDM"
        echo -e "${RED}Failed to enable SDDM!${NC}"
        return 1
    fi
}

setup_kde_plasma() {
    section "KDE PLASMA SETUP (Backup DE)" "$CYAN"
    log "INFO" "Configuring KDE Plasma on X11"
    
    case "$DETECTED_PKG_MANAGER" in
        dnf)
            sudo dnf install -y @kde-desktop-environment plasma-workspace-wayland 2>>"$LOG_FILE"
            ;;
        pacman)
            sudo pacman -S --noconfirm plasma-desktop plasma-wayland-protocols 2>>"$LOG_FILE"
            ;;
        apt)
            sudo apt-get install -y kde-plasma-desktop plasma-workspace-wayland 2>>"$LOG_FILE"
            ;;
    esac
    
    if command -v plasmashell &>/dev/null; then
        log "INFO" "KDE Plasma is installed"
        echo -e "${GREEN}KDE Plasma is ready as backup DE!${NC}"
    else
        log "WARN" "KDE Plasma not found"
        echo -e "${YELLOW}KDE Plasma may need reboot to be available${NC}"
    fi
}

setup_hyprland() {
    section "HYPRLAND SETUP (Primary DE)" "$MAGENTA"
    log "INFO" "Configuring Hyprland on Wayland"
    
    case "$DETECTED_PKG_MANAGER" in
        dnf)
            if ! sudo dnf copr list 2>/dev/null | grep -q "solopasha/hyprland"; then
                print_status info "Enabling Hyprland COPR..."
                sudo dnf copr enable -y solopasha/hyprland 2>>"$LOG_FILE"
            fi
            sudo dnf install -y hyprland xdg-desktop-portal-hyprland 2>>"$LOG_FILE"
            sudo dnf install -y hypridle hyprlock hyprpaper hyprpicker 2>>"$LOG_FILE" || true
            ;;
        pacman)
            sudo pacman -S --noconfirm hyprland xdg-desktop-portal-hyprland 2>>"$LOG_FILE"
            sudo pacman -S --noconfirm hypridle hyprlock hyprpaper hyprpicker hyprshot hyprutils 2>>"$LOG_FILE" || true
            ;;
        apt)
            echo -e "${YELLOW}Hyprland on Ubuntu requires manual build or PPA${NC}"
            echo -e "${YELLOW}Check: https://wiki.hyprland.org/Getting-Started/Installation/${NC}"
            log "WARN" "Hyprland requires manual installation on Ubuntu"
            return 1
            ;;
    esac
    
    log "INFO" "Hyprland installed"
    echo -e "${GREEN}Hyprland is ready as primary DE!${NC}"
}

setup_keyring() {
    section "OS KEYRING SETUP" "$GREEN"
    log "INFO" "Configuring cross-DE keyring"
    
    case "$DETECTED_PKG_MANAGER" in
        dnf)
            sudo dnf install -y gnome-keyring seahorse libsecret 2>>"$LOG_FILE"
            ;;
        pacman)
            sudo pacman -S --noconfirm gnome-keyring seahorse libsecret 2>>"$LOG_FILE"
            ;;
        apt)
            sudo apt-get install -y gnome-keyring seahorse libsecret-1-0 2>>"$LOG_FILE"
            ;;
    esac
    
    local pam_login="/etc/pam.d/login"
    if [ -f "$pam_login" ] && ! grep -q "pam_gnome_keyring" "$pam_login"; then
        echo "auth       optional     pam_gnome_keyring.so" | sudo tee -a "$pam_login" >/dev/null
        echo "session    optional     pam_gnome_keyring.so auto_start" | sudo tee -a "$pam_login" >/dev/null
        log "INFO" "Added gnome-keyring to PAM login"
    fi
    
    local pam_sddm="/etc/pam.d/sddm"
    if [ -f "$pam_sddm" ] && ! grep -q "pam_gnome_keyring" "$pam_sddm"; then
        echo "auth       optional     pam_gnome_keyring.so" | sudo tee -a "$pam_sddm" >/dev/null
        echo "session    optional     pam_gnome_keyring.so auto_start" | sudo tee -a "$pam_sddm" >/dev/null
        log "INFO" "Added gnome-keyring to PAM sddm"
    fi
    
    local pam_passwd="/etc/pam.d/passwd"
    if [ -f "$pam_passwd" ] && ! grep -q "pam_gnome_keyring" "$pam_passwd"; then
        echo "password   optional     pam_gnome_keyring.so" | sudo tee -a "$pam_passwd" >/dev/null
        log "INFO" "Added gnome-keyring to PAM passwd"
    fi
    
    log "INFO" "Keyring configured for cross-DE use"
    echo -e "${GREEN}Keyring configured! Chrome credentials will work across DEs.${NC}"
}

setup_wayland_env() {
    section "WAYLAND ENVIRONMENT" "$BLUE"
    log "INFO" "Configuring Wayland environment variables"
    
    local shell_config="$HOME/.config/fish/conf.d/wayland.fish"
    mkdir -p "$(dirname "$shell_config")"
    if [ ! -f "$shell_config" ]; then
        cat > "$shell_config" << 'EOF'
# Wayland environment (for Hyprland)
if test "$XDG_SESSION_TYPE" = "wayland"
    set -gx MOZ_ENABLE_WAYLAND 1
    set -gx QT_QPA_PLATFORM wayland
    set -gx GDK_BACKEND wayland,x11
    set -gx SDL_VIDEODRIVER wayland
    set -gx CLUTTER_BACKEND wayland
end
EOF
        log "INFO" "Added Wayland variables to shell config"
    fi
    
    echo -e "${GREEN}Wayland environment configured!${NC}"
}

setup_desktop_environment() {
    section "DESKTOP ENVIRONMENT SETUP" "$BLUE"
    
    setup_sddm
    setup_kde_plasma
    setup_hyprland
    setup_keyring
    setup_wayland_env
    
    log "INFO" "Desktop environment setup complete"
    echo -e "${GREEN}Desktop environment ready!${NC}"
    echo -e "${YELLOW}After reboot, you can switch between Hyprland and KDE Plasma in SDDM${NC}"
}
