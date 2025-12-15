#!/bin/bash
# Core Setup Module
# Handles: directories, git, network, dotfiles (via stow), display manager

source "$(dirname "${BASH_SOURCE[0]}")/../helpers/ui.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../helpers/logging.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../vars.sh"

setup_directories() {
    log "INFO" "Creating standard user directories"
    
    local dirs=(
        # Standard XDG directories
        "$HOME/.config"
        "$HOME/.local/bin"
        "$HOME/.local/share"
        "$HOME/Documents"
        "$HOME/Downloads"
        "$HOME/Music"
        "$HOME/Pictures"
        "$HOME/Videos"
        "$HOME/Desktop"
        
        # Programming project folders
        "$HOME/prog"
        "$HOME/prog/c"
        "$HOME/prog/c++"
        "$HOME/prog/csharp"
        "$HOME/prog/di"
        "$HOME/prog/flutter"
        "$HOME/prog/go"
        "$HOME/prog/web"
        "$HOME/prog/java"
        "$HOME/prog/linux-web-services"
        "$HOME/prog/php"
        "$HOME/prog/python"
        "$HOME/prog/rust"
        "$HOME/prog/shell"
        "$HOME/prog/sin"
    )
    
    local failed=0
    
    for dir in "${dirs[@]}"; do
        if [ -d "$dir" ]; then
            log "INFO" "Directory already exists: $dir"
            continue
        fi
        
        if mkdir -p "$dir"; then
            log "INFO" "Created directory: $dir"
        else
            log "ERROR" "Failed to create directory: $dir"
            failed=$((failed + 1))
        fi
    done
    
    if [ "$failed" -eq 0 ]; then
        echo -e "${GREEN}Directories created successfully!${NC}"
        return 0
    else
        echo -e "${RED}Failed to create $failed directories${NC}"
        return 1
    fi
}

setup_git() {
    log "INFO" "Setting up Git configuration"
    
    if [ -z "$GIT_NAME" ] || [ -z "$GIT_EMAIL" ]; then
        log "ERROR" "Git configuration missing - need GIT_NAME and GIT_EMAIL"
        echo -e "${RED}Error: GIT_NAME and GIT_EMAIL must be set${NC}"
        return 1
    fi
    
    if git config --global user.name "$GIT_NAME" && \
       git config --global user.email "$GIT_EMAIL"; then
        git config --global init.defaultBranch main
        git config --global pull.rebase false
        log "INFO" "Git configured for $GIT_NAME <$GIT_EMAIL>"
        echo -e "${GREEN}Git configured successfully!${NC}"
        return 0
    else
        log "ERROR" "Failed to configure Git"
        echo -e "${RED}Failed to configure Git!${NC}"
        return 1
    fi
}

clone_dotfiles() {
    section "DOTFILES SETUP (GNU Stow)" "$CYAN"
    
    if [ -z "$DOTFILES_URL" ]; then
        log "WARN" "No DOTFILES_URL specified, skipping dotfiles setup"
        echo -e "${YELLOW}Skipping dotfiles setup (no URL specified)${NC}"
        return 0
    fi
    
    log "INFO" "Cloning dotfiles from $DOTFILES_URL"
    
    if ! command -v git &>/dev/null; then
        log "INFO" "Installing git..."
        case "$DETECTED_PKG_MANAGER" in
            pacman) sudo -n pacman -S --noconfirm git 2>>"$LOG_FILE" ;;
            dnf) sudo -n dnf install -y git 2>>"$LOG_FILE" ;;
            apt) sudo -n apt-get install -y git 2>>"$LOG_FILE" ;;
        esac
    fi
    
    if ! command -v stow &>/dev/null; then
        log "INFO" "Installing stow..."
        case "$DETECTED_PKG_MANAGER" in
            pacman) sudo -n pacman -S --noconfirm stow 2>>"$LOG_FILE" ;;
            dnf) sudo -n dnf install -y stow 2>>"$LOG_FILE" ;;
            apt) sudo -n apt-get install -y stow 2>>"$LOG_FILE" ;;
        esac
    fi
    
    if [ -d "$DOTFILES_DIR" ]; then
        log "INFO" "Dotfiles already exist, pulling updates..."
        cd "$DOTFILES_DIR"
        git pull 2>>"$LOG_FILE" || log "WARN" "Failed to pull updates"
        cd - >/dev/null
    else
        git clone "$DOTFILES_URL" "$DOTFILES_DIR" 2>>"$LOG_FILE" || {
            log "ERROR" "Failed to clone dotfiles"
            echo -e "${RED}Failed to clone dotfiles!${NC}"
            return 1
        }
    fi
    
    cd "$DOTFILES_DIR"
    
    local stowed=0
    local failed=0
    
    for pkg in */; do
        pkg="${pkg%/}"
        [ -d "$pkg" ] || continue
        [[ "$pkg" == .* ]] && continue
        [[ "$pkg" == "README"* ]] && continue
        
        log "INFO" "Stowing $pkg..."
        if stow -v --target="$HOME" "$pkg" 2>>"$LOG_FILE"; then
            stowed=$((stowed + 1))
        else
            log "WARN" "Failed to stow $pkg"
            failed=$((failed + 1))
        fi
    done
    
    cd - >/dev/null
    
    log "INFO" "Dotfiles installed via stow ($stowed packages, $failed failed)"
    echo -e "${GREEN}Dotfiles installed! ($stowed packages stowed)${NC}"
    
    if [ $failed -gt 0 ]; then
        echo -e "${YELLOW}$failed packages failed to stow (check for conflicts)${NC}"
    fi
}

setup_network() {
    section "NETWORK CONFIGURATION" "$BLUE"
    log "INFO" "Configuring NetworkManager"
    
    case "$DETECTED_PKG_MANAGER" in
        dnf)
            sudo -n systemctl enable --now NetworkManager 2>>"$LOG_FILE"
            ;;
        pacman)
            sudo -n systemctl enable --now NetworkManager 2>>"$LOG_FILE"
            ;;
        apt)
            sudo -n systemctl enable --now NetworkManager 2>>"$LOG_FILE"
            ;;
    esac
    
    if systemctl is-active NetworkManager &>/dev/null; then
        log "INFO" "NetworkManager enabled and started"
        echo -e "${GREEN}NetworkManager configured!${NC}"
        return 0
    else
        log "ERROR" "Failed to enable NetworkManager"
        echo -e "${RED}Failed to configure NetworkManager!${NC}"
        return 1
    fi
}



setup_ly() {
    log "INFO" "Setting up ly display manager (Arch only)"
    
    [ "$DETECTED_PKG_MANAGER" != "pacman" ] && {
        log "INFO" "ly is Arch-specific, using SDDM instead"
        setup_sddm
        return $?
    }
    
    local display_managers=("gdm" "sddm" "lightdm" "lxdm" "slim")
    for dm in "${display_managers[@]}"; do
        if systemctl is-enabled "$dm" &>/dev/null; then
            log "INFO" "Disabling conflicting display manager: $dm"
            sudo -n systemctl disable "$dm" 2>>"$LOG_FILE" || true
        fi
    done
    
    if sudo -n systemctl enable ly.service 2>>"$LOG_FILE"; then
        log "INFO" "Successfully enabled ly service"
        echo -e "${GREEN}ly display manager enabled!${NC}"
        return 0
    else
        log "ERROR" "Failed to enable ly service"
        echo -e "${RED}Failed to enable ly service!${NC}"
        return 1
    fi
}

setup_moncon() {
    if [ -f "$HOME/.config/hypr/hyprmoncon/hyprmoncon.sh" ]; then
        sh "$HOME/.config/hypr/hyprmoncon/hyprmoncon.sh"
    fi
}
