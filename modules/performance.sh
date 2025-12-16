#!/bin/bash
# Performance & Power Management Module
# Automatic power-aware CPU/GPU switching with distro-specific optimizations

source "$(dirname "${BASH_SOURCE[0]}")/../helpers/ui.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../helpers/logging.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../vars.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../distros/common.sh"

setup_power_management() {
    section "POWER MANAGEMENT" "$CYAN"
    log "INFO" "Setting up power-aware CPU/GPU management"
    
    case "$DETECTED_PKG_MANAGER" in
        pacman)
            sudo pacman -S --noconfirm power-profiles-daemon 2>>"$LOG_FILE" || \
            sudo pacman -S --noconfirm cpupower 2>>"$LOG_FILE"
            ;;
        dnf)
            sudo dnf install -y power-profiles-daemon 2>>"$LOG_FILE"
            ;;
        apt)
            sudo apt-get install -y power-profiles-daemon 2>>"$LOG_FILE" || \
            sudo apt-get install -y cpufrequtils 2>>"$LOG_FILE"
            ;;
    esac
    
    if command -v powerprofilesctl &>/dev/null; then
        sudo systemctl enable --now power-profiles-daemon 2>>"$LOG_FILE"
        log "INFO" "power-profiles-daemon enabled"
        print_status success "Power Profiles Daemon enabled (use 'powerprofilesctl' to switch)"
    fi
}

tweak_performance() {
    section "PERFORMANCE TWEAKS" "$CYAN"
    
    setup_power_management
    
    log "INFO" "Detected distro: $DETECTED_DISTRO_ID (family: $DETECTED_DISTRO_FAMILY)"
    
    if load_distro_optimizations; then
        case "$DETECTED_DISTRO_ID" in
            cachyos)
                apply_cachyos_optimizations
                ;;
            arch|manjaro|endeavouros)
                apply_arch_optimizations
                ;;
            *)
                log "WARN" "No specific optimizations for $DETECTED_DISTRO_ID"
                ;;
        esac
    fi
    
    echo -e "\n${BLUE}Power Management Summary:${NC}"
    echo -e "  ${GREEN}•${NC} CPU: performance (AC) / powersave (battery)"
    echo -e "  ${GREEN}•${NC} GPU: max power (AC) / low power (battery)"
    echo -e "  ${YELLOW}Tip:${NC} Use 'powerprofilesctl' to manually switch profiles"
}