#!/bin/bash
# Legacy installation script - kept for backward compatibility
# 
# For new installations, use install-essential.sh instead:
#   ./install-essential.sh
#
# This script installs ALL packages (essential + non-essential) at once.
# The new approach separates them for better control and error recovery.

echo -e "\033[1;33m╔═══════════════════════════════════════════════════╗\033[0m"
echo -e "\033[1;33m║                                                   ║\033[0m"
echo -e "\033[1;33m║              LEGACY INSTALLATION MODE             ║\033[0m"
echo -e "\033[1;33m║                                                   ║\033[0m"
echo -e "\033[1;33m║  This is the old installation method.            ║\033[0m"
echo -e "\033[1;33m║  Consider using the new method instead:          ║\033[0m"
echo -e "\033[1;33m║    1. ./install-essential.sh                      ║\033[0m"
echo -e "\033[1;33m║    2. apres-setup start                           ║\033[0m"
echo -e "\033[1;33m║                                                   ║\033[0m"
echo -e "\033[1;33m╚═══════════════════════════════════════════════════╝\033[0m\n"

read -p "Continue with legacy installation? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Installation cancelled. Run ./install-essential.sh for the new method."
    exit 0
fi

# ===== USER CONFIGURATION =====
GIT_NAME="Sem VB"
GIT_EMAIL="sem.van.broekhoven@gmail.com"
DOTFILES_URL="https://github.com/dotsem/.config.git"
USB_MOUNT_PATH="/mnt/usb"
KERNEL_TYPE="linux-lts"
# ==============================

source "$(dirname "${BASH_SOURCE[0]}")/helpers/colors.sh"
source "$(dirname "${BASH_SOURCE[0]}")/helpers/ui.sh"
source "$(dirname "${BASH_SOURCE[0]}")/modules/packages.sh"
source "$(dirname "${BASH_SOURCE[0]}")/modules/grub.sh"
source "$(dirname "${BASH_SOURCE[0]}")/modules/setup.sh"
source "$(dirname "${BASH_SOURCE[0]}")/modules/font.sh"
source "$(dirname "${BASH_SOURCE[0]}")/modules/audio.sh"
source "$(dirname "${BASH_SOURCE[0]}")/modules/python.sh"
source "$(dirname "${BASH_SOURCE[0]}")/modules/boot.sh"
source "$(dirname "${BASH_SOURCE[0]}")/modules/game.sh"
source "$(dirname "${BASH_SOURCE[0]}")/modules/cloud.sh"
source "$(dirname "${BASH_SOURCE[0]}")/modules/maintenance.sh"
source "$(dirname "${BASH_SOURCE[0]}")/modules/neovim.sh"
source "$(dirname "${BASH_SOURCE[0]}")/modules/performance.sh"
source "$(dirname "${BASH_SOURCE[0]}")/modules/security.sh"
source "$(dirname "${BASH_SOURCE[0]}")/modules/zsh.sh"





# Main installation process
main() {
    local errors=0
    local failed_steps=()

    # Root check
    if [ "$(id -u)" -eq 0 ]; then
        echo -e "${RED}Run as regular user, not root!${NC}"
        exit 1
    fi

    # Revoke any cached sudo credentials
    sudo -K

    # Cache sudo credentials
    section "Authentication" $NC
    echo -e "${YELLOW}Enter your sudo password once for the entire installation${NC}"
    sudo -v
    if [ $? -ne 0 ]; then
        echo -e "${RED}Authentication failed! Exiting...${NC}"
        exit 1
    fi

    # Start sudo keep-alive process
    (
        while true; do
            sudo -n true
            sleep 60
            kill -0 "$$" 2>/dev/null || exit
        done
    ) 2>/dev/null &
    local keep_alive_pid=$!

    # Trap to clean up sudo keep-alive process
    trap 'sudo -K; kill $keep_alive_pid 2>/dev/null' EXIT

    # Check for pacman database lock
    if sudo -n fuser /var/lib/pacman/db.lck >/dev/null 2>&1; then
        log "ERROR" "Pacman database is locked. Another pacman process may be running."
        failed_steps+=("pacman_lock")
        ((errors++))
        echo -e "${RED}Pacman database is locked. Exiting...${NC}"
        exit 1
    fi

    # Check for network connectivity
    if ! ping -c 1 archlinux.org &>/dev/null; then
        log "ERROR" "No network connectivity."
        failed_steps+=("network_connectivity")
        ((errors++))
        echo -e "${RED}No network connectivity. Exiting...${NC}"
        exit 1
    fi

    # Check for sufficient disk space (at least 2GB free)
    local avail_kb=$(df --output=avail "$HOME" | tail -1)
    if [ "$avail_kb" -lt 2000000 ]; then
        log "ERROR" "Insufficient disk space (<2GB free)."
        failed_steps+=("disk_space")
        ((errors++))
        echo -e "${RED}Insufficient disk space. Exiting...${NC}"
        exit 1
    fi

    # Check for critical user variables
    if [ -z "$GIT_NAME" ] || [ -z "$GIT_EMAIL" ] || [ -z "$DOTFILES_URL" ]; then
        log "ERROR" "Critical user variables (GIT_NAME, GIT_EMAIL, DOTFILES_URL) are missing."
        failed_steps+=("user_vars")
        ((errors++))
        echo -e "${RED}Critical user variables missing. Exiting...${NC}"
        exit 1
    fi

    # Start setup
    section "Starting System Update" $GREEN
    sudo -n pacman-mirrors --fasttrack && sudo -n pacman -Syy
    sudo -n pacman -Syu --noconfirm

    # Install components
    if ! install_yay; then
        log "ERROR" "YAY installation failed"
        failed_steps+=("install_yay")
        ((errors++))
    fi
    if ! setup_flatpak; then
        log "ERROR" "Flatpak setup failed"
        failed_steps+=("setup_flatpak")
        ((errors++))
    fi
    if ! setup_directories; then
        log "ERROR" "Directory creation failed"
        failed_steps+=("setup_directories")
        ((errors++))
    fi

    # Install packages
    section "Installing Official Packages" $BLUE
    for pkg in "${PACMAN_PACKAGES[@]}"; do
        if ! install_package "pacman" "$pkg"; then
            log "ERROR" "Failed to install $pkg via pacman"
            failed_steps+=("pacman:$pkg")
            ((errors++))
        fi
    done

    section "Installing AUR Packages" $YELLOW
    for pkg in "${AUR_PACKAGES[@]}"; do
        if ! install_package "yay" "$pkg"; then
            log "ERROR" "Failed to install $pkg via yay"
            failed_steps+=("yay:$pkg")
            ((errors++))
        fi
    done

    # System configuration (all steps continue even if previous fail)
    for step in setup_grub setup_pipewire setup_git setup_network setup_steam clone_dotfiles setup_zsh setup_zsh_plugins install_fonts setup_moncon setup_python_environment setup_ly setup_maintenance tweak_performance setup_security setup_emulation setup_ui_enhancements setup_cloud; do
        if ! $step; then
            log "ERROR" "$step failed"
            failed_steps+=("$step")
            ((errors++))
        fi
    done

    # Optionally, run setup_boot if you want to include it
    if ! setup_boot; then
        log "ERROR" "setup_boot failed"
        failed_steps+=("setup_boot")
        ((errors++))
    fi

    # Run cleanup before completion
    cleanup

    # Completion
    section "Setup Complete" $GREEN
    if [ $errors -eq 0 ]; then
        echo -e "${GREEN}Environment ready! No errors encountered.${NC}"
    else
        echo -e "${RED}Setup completed with $errors errors.${NC}"
        echo -e "${YELLOW}Failed steps/packages:${NC} ${failed_steps[*]}"
        echo -e "${YELLOW}Review log for issues: ${LOG_FILE}${NC}"
    fi
    echo -e "${YELLOW}Log out to finalize changes${NC}"

    hyprctl reload

    # Kill sudo keep-alive (handled by trap)
}

cleanup() {
    yay -Yc --noconfirm
    sudo -n pacman -Rns $(pacman -Qtdq) --noconfirm 2>/dev/null || true
    sudo -n sed -i '/^SystemdCron/d' /etc/pacman.conf 2>> "$LOG_FILE"
}

# Set log level to ERROR only
export LOG_LEVEL=ERROR

main
