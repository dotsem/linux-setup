#!/bin/bash
# Main Setup Script - Multi-Distro Essential Installation
# Supports: Arch Linux, Fedora, Debian/Ubuntu, CachyOS
# Note: Errors are tracked but don't stop execution - check summary at end

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/vars.sh"
source "$SCRIPT_DIR/helpers/colors.sh"
source "$SCRIPT_DIR/helpers/logging.sh"
source "$SCRIPT_DIR/helpers/ui.sh"

source "$SCRIPT_DIR/lib/package-manager.sh"

source "$SCRIPT_DIR/modules/setup.sh"
source "$SCRIPT_DIR/modules/audio.sh"
source "$SCRIPT_DIR/modules/python.sh"
source "$SCRIPT_DIR/modules/boot.sh"
source "$SCRIPT_DIR/modules/font.sh"
source "$SCRIPT_DIR/modules/maintenance.sh"
source "$SCRIPT_DIR/modules/neovim.sh"
source "$SCRIPT_DIR/modules/performance.sh"
source "$SCRIPT_DIR/modules/security.sh"
source "$SCRIPT_DIR/modules/fish.sh"
source "$SCRIPT_DIR/modules/usb.sh"
source "$SCRIPT_DIR/modules/flutter.sh"
source "$SCRIPT_DIR/modules/development.sh"
source "$SCRIPT_DIR/modules/nvidia.sh"
source "$SCRIPT_DIR/modules/desktop.sh"
source "$SCRIPT_DIR/modules/gaming.sh"

declare -g ERRORS=0
declare -ga FAILED_STEPS=()

load_package_lists() {
    case "$DETECTED_PKG_MANAGER" in
        pacman)
            source "$SCRIPT_DIR/config/packages-essential.sh"
            ;;
        dnf)
            source "$SCRIPT_DIR/config/packages-essential-fedora.sh"
            ;;
        apt)
            source "$SCRIPT_DIR/config/packages-essential-apt.sh"
            ;;
        *)
            log "ERROR" "Unknown package manager: $DETECTED_PKG_MANAGER"
            exit 1
            ;;
    esac
}

track_failure() {
    local step="$1"
    FAILED_STEPS+=("$step")
    ((ERRORS++))
}

execute_step() {
    local step_name="$1"
    local step_function="$2"
    
    log "INFO" "Executing: $step_name"
    
    if $step_function; then
        log "INFO" "$step_name completed successfully"
        return 0
    else
        log "ERROR" "$step_name failed"
        track_failure "$step_name"
        return 1
    fi
}

preflight_checks() {
    section "Pre-flight Checks" "$YELLOW"
    
    echo -e "${BLUE}Detected: $DETECTED_DISTRO_NAME${NC}"
    echo -e "${BLUE}Package Manager: $DETECTED_PKG_MANAGER${NC}"
    
    if [ "$(id -u)" -eq 0 ]; then
        echo -e "${RED}ERROR: Do not run as root!${NC}"
        echo -e "${YELLOW}Run this script as a regular user with sudo privileges.${NC}"
        exit 1
    fi
    
    sudo -K
    
    echo -e "${YELLOW}Enter your sudo password to begin installation${NC}"
    if ! sudo -v; then
        echo -e "${RED}Authentication failed!${NC}"
        exit 1
    fi
    
    (
        while true; do
            sudo true
            sleep 60
            kill -0 "$$" 2>/dev/null || exit
        done
    ) 2>/dev/null &
    SUDO_KEEPALIVE_PID=$!
    
    trap 'sudo -K; kill $SUDO_KEEPALIVE_PID 2>/dev/null; exit' EXIT INT TERM
    
    case "$DETECTED_PKG_MANAGER" in
        pacman)
            if sudo fuser /var/lib/pacman/db.lck >/dev/null 2>&1; then
                echo -e "${RED}ERROR: Pacman database is locked${NC}"
                exit 1
            fi
            ;;
        dnf)
            if sudo fuser /var/lib/dnf/repos >/dev/null 2>&1; then
                echo -e "${YELLOW}Warning: DNF may have an active process${NC}"
            fi
            ;;
        apt)
            if sudo fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; then
                echo -e "${RED}ERROR: APT database is locked${NC}"
                exit 1
            fi
            ;;
    esac
    
    local test_host="google.com"
    if ! ping -c 1 -W 5 "$test_host" &>/dev/null; then
        echo -e "${RED}ERROR: No network connectivity${NC}"
        exit 1
    fi
    
    local avail_kb=$(df --output=avail "$HOME" | tail -1)
    if [ "$avail_kb" -lt 5000000 ]; then
        echo -e "${RED}ERROR: Insufficient disk space${NC}"
        echo -e "${YELLOW}At least 5GB free space required${NC}"
        exit 1
    fi
    
    if [ -z "$GIT_NAME" ] || [ -z "$GIT_EMAIL" ]; then
        echo -e "${RED}ERROR: Critical variables missing${NC}"
        echo -e "${YELLOW}Please configure GIT_NAME and GIT_EMAIL in vars.sh${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}All pre-flight checks passed!${NC}\n"
}

install_essential_packages() {
    case "$DETECTED_PKG_MANAGER" in
        pacman)
            detect_and_add_nvidia ESSENTIAL_PACMAN_PACKAGES
            ESSENTIAL_PACMAN_PACKAGES+=("${KERNEL_TYPE}-headers")
            
            section "Installing Essential Packages (Pacman)" "$BLUE"
            for pkg in "${ESSENTIAL_PACMAN_PACKAGES[@]}"; do
                if ! install_package "pacman" "$pkg"; then
                    track_failure "pacman:$pkg"
                fi
            done
            
            section "Installing Essential Packages (AUR)" "$YELLOW"
            for pkg in "${ESSENTIAL_AUR_PACKAGES[@]}"; do
                if ! install_package "yay" "$pkg"; then
                    track_failure "aur:$pkg"
                fi
            done
            ;;
            
        dnf)
            section "Installing Essential Packages (DNF)" "$BLUE"
            for pkg in "${ESSENTIAL_DNF_PACKAGES[@]}"; do
                if ! install_package "dnf" "$pkg"; then
                    track_failure "dnf:$pkg"
                fi
            done
            
            section "Installing Hyprland (COPR)" "$YELLOW"
            for copr_pkg in "${ESSENTIAL_COPR_PACKAGES[@]}"; do
                if ! install_package "copr" "$copr_pkg"; then
                    track_failure "copr:$copr_pkg"
                fi
            done
            ;;
            
        apt)
            section "Installing Essential Packages (APT)" "$BLUE"
            sudo apt-get update 2>>"$LOG_FILE"
            for pkg in "${ESSENTIAL_APT_PACKAGES[@]}"; do
                if ! install_package "apt" "$pkg"; then
                    track_failure "apt:$pkg"
                fi
            done
            ;;
    esac
    
    if [ ${#ESSENTIAL_FLATPAK_PACKAGES[@]} -gt 0 ]; then
        section "Installing Essential Packages (Flatpak)" "$MAGENTA"
        for pkg in "${ESSENTIAL_FLATPAK_PACKAGES[@]}"; do
            if ! install_package "flatpak" "$pkg"; then
                track_failure "flatpak:$pkg"
            fi
        done
    fi
}

configure_system() {
    section "System Configuration" "$CYAN"
    
    execute_step "Directory setup" setup_directories
    execute_step "Git configuration" setup_git
    execute_step "Network setup" setup_network
    execute_step "Audio setup (PipeWire)" setup_pipewire
    execute_step "Fish setup" setup_fish
    execute_step "Python environment" setup_python_environment
    execute_step "Font installation" install_fonts
    execute_step "Display manager (SDDM)" setup_sddm
    execute_step "USB configuration" disable_usb_autosuspend
    execute_step "Performance tweaks" tweak_performance
    execute_step "Security setup" setup_security
    execute_step "Maintenance setup" setup_maintenance
    
    if [ -n "$DOTFILES_URL" ]; then
        execute_step "Dotfiles" clone_dotfiles
    fi
    
    execute_step "Desktop environment" setup_desktop_environment || true
    execute_step "NVIDIA setup" setup_nvidia || true
    
    if [ "$DETECTED_PKG_MANAGER" = "pacman" ]; then
        if [ "$BOOTLOADER" = "grub" ]; then
            execute_step "GRUB configuration" setup_grub || true
        fi
        execute_step "Boot configuration" setup_boot || true
    fi
}

setup_development_if_needed() {
    section "Development Environment" "$MAGENTA"
    
    execute_step "Node.js + PNPM" setup_node
    execute_step "Go environment" setup_go
    execute_step "Java environment" setup_java
}

setup_flutter_if_available() {
    section "Flutter Setup" "$MAGENTA"
    execute_step "Flutter environment" setup_flutter_environment
}

cleanup() {
    section "Cleanup" "$CYAN"
    log "INFO" "Running system cleanup"
    
    case "$DETECTED_PKG_MANAGER" in
        pacman)
            yay -Yc --noconfirm 2>>"$LOG_FILE" || true
            sudo pacman -Sc --noconfirm 2>>"$LOG_FILE" || true
            local orphans=$(pacman -Qtdq 2>/dev/null)
            if [ -n "$orphans" ]; then
                sudo pacman -Rns $orphans --noconfirm 2>>"$LOG_FILE" || true
            fi
            ;;
        dnf)
            sudo dnf autoremove -y 2>>"$LOG_FILE" || true
            sudo dnf clean all 2>>"$LOG_FILE" || true
            ;;
        apt)
            sudo apt-get autoremove -y 2>>"$LOG_FILE" || true
            sudo apt-get autoclean 2>>"$LOG_FILE" || true
            ;;
    esac
    
    echo -e "${GREEN}Cleanup completed!${NC}"
}

install_cli_tools() {
    section "Installing Command-Line Tools" "$BLUE"
    
    local bin_dir="$HOME/.local/bin"
    mkdir -p "$bin_dir"
    
    local sysunit_src="$SCRIPT_DIR/bin/sysunit"
    local sysunit_dst="$bin_dir/sysunit"
    
    if [ -f "$sysunit_src" ]; then
        cp "$sysunit_src" "$sysunit_dst"
        chmod +x "$sysunit_dst"
        log "INFO" "Installed sysunit to $sysunit_dst"
        echo -e "${GREEN}✓ sysunit command installed${NC}"
    fi
    
    local apres_src="$SCRIPT_DIR/bin/apres-setup"
    local apres_dst="$bin_dir/apres-setup"
    
    if [ -f "$apres_src" ]; then
        cp "$apres_src" "$apres_dst"
        chmod +x "$apres_dst"
        log "INFO" "Installed apres-setup to $apres_dst"
        echo -e "${GREEN}✓ apres-setup command installed${NC}"
    fi
    
    if ! echo "$PATH" | grep -q "$bin_dir"; then
        echo -e "${YELLOW}Note: Add $bin_dir to your PATH${NC}"
    fi
}

print_summary() {
    echo ""
    section "Installation Complete" "$GREEN"
    
    if [ $ERRORS -eq 0 ]; then
        echo -e "${GREEN}╔═══════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║                                       ║${NC}"
        echo -e "${GREEN}║   ✓ ALL STEPS COMPLETED SUCCESSFULLY  ║${NC}"
        echo -e "${GREEN}║                                       ║${NC}"
        echo -e "${GREEN}╚═══════════════════════════════════════╝${NC}"
    else
        echo -e "${YELLOW}╔═══════════════════════════════════════╗${NC}"
        echo -e "${YELLOW}║                                       ║${NC}"
        printf "${YELLOW}║   ⚠ COMPLETED WITH %-2d ERRORS          ║${NC}\n" $ERRORS
        echo -e "${YELLOW}║                                       ║${NC}"
        echo -e "${YELLOW}╚═══════════════════════════════════════╝${NC}"
        
        echo -e "\n${YELLOW}Failed steps:${NC}"
        for step in "${FAILED_STEPS[@]}"; do
            echo -e "  ${RED}✗${NC} $step"
        done
    fi
    
    echo -e "\n${BLUE}Next Steps:${NC}"
    echo -e "  1. ${GREEN}Reboot your system${NC} to apply all changes"
    echo -e "  2. Run ${YELLOW}sysunit${NC} to verify system configuration"
    echo -e "  3. Run ${YELLOW}apres-setup start${NC} to install non-essential packages"
    echo -e "  4. Check the log file: ${BLUE}$LOG_FILE${NC}"
    
    if [ $ERRORS -gt 0 ]; then
        echo -e "\n${YELLOW}Some steps failed. Review the log for details.${NC}"
    fi
}

main() {
    echo -e "${BLUE}"
    echo "╔═══════════════════════════════════════════════════╗"
    echo "║                                                   ║"
    echo "║         LINUX SYSTEM SETUP                        ║"
    echo "║                                                   ║"
    echo "║  Multi-distro installer for:                      ║"
    echo "║    • Arch Linux / Manjaro                         ║"
    echo "║    • Fedora                                       ║"
    echo "║    • Debian / Ubuntu                              ║"
    echo "║                                                   ║"
    echo "╚═══════════════════════════════════════════════════╝"
    echo -e "${NC}\n"
    
    load_package_lists
    preflight_checks
    system_update
    
    case "$DETECTED_PKG_MANAGER" in
        pacman)
            execute_step "YAY installation" install_yay
            ;;
        dnf)
            execute_step "RPM Fusion setup" setup_rpm_fusion
            ;;
    esac
    
    execute_step "Flatpak setup" setup_flatpak
    install_essential_packages
    configure_system
    setup_development_if_needed
    setup_flutter_if_available
    install_cli_tools
    cleanup
    print_summary
}

main "$@"
