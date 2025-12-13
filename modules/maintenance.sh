#!/bin/bash
# System Maintenance Module
# Multi-distro support

source "$(dirname "${BASH_SOURCE[0]}")/../helpers/ui.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../helpers/logging.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../vars.sh"

setup_maintenance() {
    section "SYSTEM MAINTENANCE" "$CYAN"
    
    if sudo -n systemctl enable --now fstrim.timer 2>>"$LOG_FILE"; then
        log "INFO" "Enabled SSD trimming service"
        print_status success "Automatic SSD trimming enabled"
    else
        log "WARN" "Failed to enable SSD trimming"
        print_status warning "Failed to enable SSD trimming"
    fi

    case "$DETECTED_PKG_MANAGER" in
        pacman)
            if sudo -n pacman -S --noconfirm pacman-contrib 2>>"$LOG_FILE"; then
                sudo -n systemctl enable --now paccache.timer
                log "INFO" "Configured package cache cleaning"
                print_status success "Automatic package cache cleaning enabled"
            fi
            ;;
        dnf)
            sudo -n dnf install -y dnf-automatic 2>>"$LOG_FILE"
            sudo -n systemctl enable --now dnf-automatic.timer 2>>"$LOG_FILE"
            log "INFO" "Configured DNF automatic updates"
            print_status success "DNF automatic updates enabled"
            ;;
        apt)
            sudo -n apt-get install -y unattended-upgrades 2>>"$LOG_FILE"
            sudo -n dpkg-reconfigure -plow unattended-upgrades 2>>"$LOG_FILE" || true
            log "INFO" "Configured unattended upgrades"
            print_status success "Unattended upgrades enabled"
            ;;
    esac

    sudo -n sed -i 's/^#SystemMaxUse=/SystemMaxUse=100M/' /etc/systemd/journald.conf 2>>"$LOG_FILE"
    log "INFO" "Configured journal log limits"
    print_status info "Journal logs limited to 100MB"
}