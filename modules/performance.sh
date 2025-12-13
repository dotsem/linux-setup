#!/bin/bash
# Performance Tweaks Module
# Multi-distro support

source "$(dirname "${BASH_SOURCE[0]}")/../helpers/ui.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../helpers/logging.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../vars.sh"

tweak_performance() {
    section "PERFORMANCE TWEAKS" "$CYAN"
    
    case "$DETECTED_PKG_MANAGER" in
        pacman)
            if sudo -n pacman -S --noconfirm cpupower 2>>"$LOG_FILE"; then
                echo 'GOVERNOR="performance"' | sudo -n tee /etc/default/cpupower > /dev/null
                sudo -n systemctl enable --now cpupower 2>>"$LOG_FILE"
                log "INFO" "Configured CPU performance governor"
                print_status success "CPU performance governor enabled"
            fi
            ;;
        dnf)
            sudo -n dnf install -y power-profiles-daemon 2>>"$LOG_FILE"
            sudo -n systemctl enable --now power-profiles-daemon 2>>"$LOG_FILE"
            log "INFO" "Enabled power-profiles-daemon"
            print_status success "Power profiles daemon enabled"
            ;;
        apt)
            sudo -n apt-get install -y cpufrequtils 2>>"$LOG_FILE"
            echo 'GOVERNOR="performance"' | sudo -n tee /etc/default/cpufrequtils > /dev/null
            log "INFO" "Configured CPU governor"
            print_status success "CPU governor configured"
            ;;
    esac

    local ram_gb=$(free -g | awk '/Mem:/ {print $2}')
    if [ "$ram_gb" -ge 16 ]; then
        echo "vm.swappiness=10" | sudo -n tee /etc/sysctl.d/99-swappiness.conf > /dev/null
        sudo -n sysctl -p /etc/sysctl.d/99-swappiness.conf 2>>"$LOG_FILE"
        log "INFO" "Optimized swappiness for ${ram_gb}GB RAM system"
        print_status success "Memory swappiness optimized"
    else
        log "INFO" "Skipping swappiness tweak (RAM < 16GB)"
        print_status info "Skipped swappiness tweak (${ram_gb}GB RAM)"
    fi
    
    if lspci | grep -qi nvidia && [ "$ram_gb" -ge 8 ]; then
        echo "vm.dirty_background_ratio=5" | sudo -n tee -a /etc/sysctl.d/99-performance.conf > /dev/null
        echo "vm.dirty_ratio=10" | sudo -n tee -a /etc/sysctl.d/99-performance.conf > /dev/null
        sudo -n sysctl -p /etc/sysctl.d/99-performance.conf 2>>"$LOG_FILE"
        log "INFO" "Applied gaming performance tweaks"
        print_status success "Gaming performance tweaks applied"
    fi
}