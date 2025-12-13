#!/bin/bash
# Security Setup Module
# Multi-distro support

source "$(dirname "${BASH_SOURCE[0]}")/../helpers/ui.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../helpers/logging.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../vars.sh"

setup_security() {
    section "SECURITY SETUP" "$CYAN"
    
    setup_firewall() {
        case "$DETECTED_PKG_MANAGER" in
            pacman)
                sudo -n pacman -S --noconfirm ufw 2>>"$LOG_FILE"
                ;;
            dnf)
                sudo -n dnf install -y ufw 2>>"$LOG_FILE"
                ;;
            apt)
                sudo -n apt-get install -y ufw 2>>"$LOG_FILE"
                ;;
        esac
        
        if command -v ufw &>/dev/null; then
            sudo -n ufw default deny incoming 2>>"$LOG_FILE"
            sudo -n ufw default allow outgoing 2>>"$LOG_FILE"
            sudo -n ufw allow ssh 2>>"$LOG_FILE"
            sudo -n ufw --force enable 2>>"$LOG_FILE"
            sudo -n systemctl enable ufw 2>>"$LOG_FILE"
            log "INFO" "Configured UFW firewall"
            print_status success "Firewall configured (UFW)"
        else
            log "WARN" "UFW installation failed, trying firewalld"
            
            if [ "$DETECTED_PKG_MANAGER" = "dnf" ]; then
                sudo -n systemctl enable --now firewalld 2>>"$LOG_FILE"
                sudo -n firewall-cmd --set-default-zone=public 2>>"$LOG_FILE"
                sudo -n firewall-cmd --add-service=ssh --permanent 2>>"$LOG_FILE"
                sudo -n firewall-cmd --reload 2>>"$LOG_FILE"
                log "INFO" "Configured firewalld"
                print_status success "Firewall configured (firewalld)"
            fi
        fi
    }
    
    setup_fail2ban() {
        case "$DETECTED_PKG_MANAGER" in
            pacman)
                sudo -n pacman -S --noconfirm fail2ban 2>>"$LOG_FILE"
                ;;
            dnf)
                sudo -n dnf install -y fail2ban 2>>"$LOG_FILE"
                ;;
            apt)
                sudo -n apt-get install -y fail2ban 2>>"$LOG_FILE"
                ;;
        esac
        
        if command -v fail2ban-client &>/dev/null; then
            sudo -n systemctl enable --now fail2ban 2>>"$LOG_FILE"
            log "INFO" "Enabled fail2ban"
            print_status success "Fail2ban enabled"
        fi
    }
    
    setup_firewall
    setup_fail2ban
}