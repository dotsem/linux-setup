#!/bin/bash
# Fish Shell Setup Module
# Multi-distro support

source "$(dirname "${BASH_SOURCE[0]}")/../helpers/ui.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../helpers/logging.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../vars.sh"

setup_fish() {
    section "FISH SHELL SETUP" "$GREEN"
    
    if ! command -v fish >/dev/null 2>&1; then
        log "INFO" "Installing fish..."
        case "$DETECTED_PKG_MANAGER" in
            pacman)
                sudo pacman -S --noconfirm fish 2>>"$LOG_FILE"
                ;;
            dnf)
                sudo dnf install -y fish 2>>"$LOG_FILE"
                ;;
            apt)
                sudo apt-get install -y fish 2>>"$LOG_FILE"
                ;;
        esac
    else
        log "INFO" "Fish is already installed"
        echo -e "${GREEN}Fish is already installed${NC}"
    fi
    
    if ! command -v fish >/dev/null 2>&1; then
        log "ERROR" "Fish not installed"
        return 1
    fi
    
    local current_shell=$(getent passwd "$USER" | cut -d: -f7)
    local fish_path=$(which fish)
    
    if [ "$current_shell" = "$fish_path" ]; then
        log "INFO" "Fish is already the default shell"
        echo -e "${GREEN}Fish is already the default shell${NC}"
        return 0
    fi
    
    # Ensure fish is in /etc/shells
    if ! grep -q "$fish_path" /etc/shells 2>/dev/null; then
        log "INFO" "Adding fish to /etc/shells"
        echo "$fish_path" | sudo tee -a /etc/shells >/dev/null
    fi
    
    log "INFO" "Setting Fish as default shell"
    # Use usermod instead of chsh - works better on locked root systems
    if sudo usermod --shell "$fish_path" "$USER" 2>>"$LOG_FILE"; then
        log "INFO" "Successfully set Fish as default shell"
        echo -e "${GREEN}Fish set as default shell!${NC}"
        echo -e "${YELLOW}Note: Log out required for changes to take effect${NC}"
        return 0
    else
        log "ERROR" "Failed to set Fish as default shell"
        echo -e "${RED}Failed to set Fish as default shell${NC}"
        echo -e "${YELLOW}Try manually: chsh -s $fish_path${NC}"
        return 1
    fi
}
