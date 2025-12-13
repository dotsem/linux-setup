#!/bin/bash
# Zsh Setup Module
# Multi-distro support

source "$(dirname "${BASH_SOURCE[0]}")/../helpers/ui.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../helpers/logging.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../vars.sh"

setup_zsh() {
    section "ZSH SHELL SETUP" "$GREEN"
    
    if ! command -v zsh >/dev/null 2>&1; then
        log "INFO" "Installing zsh..."
        case "$DETECTED_PKG_MANAGER" in
            pacman)
                sudo -n pacman -S --noconfirm zsh 2>>"$LOG_FILE"
                ;;
            dnf)
                sudo -n dnf install -y zsh 2>>"$LOG_FILE"
                ;;
            apt)
                sudo -n apt-get install -y zsh 2>>"$LOG_FILE"
                ;;
        esac
    fi
    
    local usb_zshrc="${USB_MOUNT_PATH}/.zshrc"
    local home_zshrc="$HOME/.zshrc"
    
    if [ -n "$USB_MOUNT_PATH" ] && [ -f "$usb_zshrc" ]; then
        log "INFO" "Copying .zshrc from USB"
        if cp "$usb_zshrc" "$home_zshrc"; then
            log "INFO" "Successfully copied .zshrc from USB"
            echo -e "${GREEN}Copied .zshrc from USB!${NC}"
        else
            log "ERROR" "Failed to copy .zshrc from USB"
        fi
    fi
    
    if [ ! -d "$HOME/.oh-my-zsh" ]; then
        log "INFO" "Installing Oh My Zsh"
        echo -e "${YELLOW}Installing Oh My Zsh...${NC}"
        
        RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" 2>>"$LOG_FILE"
        
        if [ -d "$HOME/.oh-my-zsh" ]; then
            log "INFO" "Oh My Zsh installed successfully"
            echo -e "${GREEN}Oh My Zsh installed!${NC}"
        else
            log "ERROR" "Failed to install Oh My Zsh"
            return 1
        fi
    else
        log "INFO" "Oh My Zsh already installed"
        echo -e "${GREEN}Oh My Zsh already installed${NC}"
    fi
    
    if ! command -v zsh >/dev/null 2>&1; then
        log "ERROR" "Zsh not installed"
        return 1
    fi
    
    local current_shell=$(getent passwd "$USER" | cut -d: -f7)
    local zsh_path=$(which zsh)
    
    if [ "$current_shell" = "$zsh_path" ]; then
        log "INFO" "Zsh is already the default shell"
        echo -e "${GREEN}Zsh is already the default shell${NC}"
        return 0
    fi
    
    log "INFO" "Setting Zsh as default shell"
    if sudo -n chsh -s "$zsh_path" "$USER" 2>>"$LOG_FILE"; then
        log "INFO" "Successfully set Zsh as default shell"
        echo -e "${GREEN}Zsh set as default shell!${NC}"
        echo -e "${YELLOW}Note: Log out required for changes to take effect${NC}"
        return 0
    else
        log "ERROR" "Failed to set Zsh as default shell"
        echo -e "${RED}Failed to set Zsh as default shell${NC}"
        return 1
    fi
}

setup_zsh_plugins() {
    section "Configuring Zsh Plugins" "$YELLOW"
    
    if [ ! -d "$HOME/.oh-my-zsh" ]; then
        log "WARN" "Oh My Zsh not installed, skipping plugins"
        return 0
    fi
    
    local plugins=(
        "zsh-autosuggestions https://github.com/zsh-users/zsh-autosuggestions"
        "zsh-syntax-highlighting https://github.com/zsh-users/zsh-syntax-highlighting"
    )
    
    for plugin in "${plugins[@]}"; do
        local name=${plugin%% *}
        local url=${plugin#* }
        local target_dir="$HOME/.oh-my-zsh/custom/plugins/$name"
        
        if [ ! -d "$target_dir" ]; then
            log "INFO" "Installing plugin: $name"
            if git clone "$url" "$target_dir" 2>>"$LOG_FILE"; then
                log "INFO" "Successfully installed $name"
                echo -e "${GREEN}Installed: $name${NC}"
            else
                log "ERROR" "Failed to install $name"
                echo -e "${RED}Failed to install: $name${NC}"
            fi
        else
            log "INFO" "Plugin already exists: $name"
            echo -e "${YELLOW}$name already installed${NC}"
        fi
    done
    
    if [ -f "$HOME/.zshrc" ]; then
        if ! grep -q "zsh-autosuggestions" "$HOME/.zshrc" 2>/dev/null; then
            log "INFO" "Updating .zshrc plugins"
            sed -i '/^plugins=(/ {
                /zsh-autosuggestions/! s/)/ zsh-autosuggestions)/
            }' "$HOME/.zshrc" 2>>"$LOG_FILE"
        fi
        
        if ! grep -q "zsh-syntax-highlighting" "$HOME/.zshrc" 2>/dev/null; then
            sed -i '/^plugins=(/ {
                /zsh-syntax-highlighting/! s/)/ zsh-syntax-highlighting)/
            }' "$HOME/.zshrc" 2>>"$LOG_FILE"
        fi
        
        echo -e "${GREEN}Zsh plugins configured${NC}"
    fi
}
