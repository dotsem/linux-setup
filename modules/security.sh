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
                sudo pacman -S --noconfirm ufw 2>>"$LOG_FILE"
                ;;
            dnf)
                sudo dnf install -y ufw 2>>"$LOG_FILE"
                ;;
            apt)
                sudo apt-get install -y ufw 2>>"$LOG_FILE"
                ;;
        esac
        
        if command -v ufw &>/dev/null; then
            sudo ufw default deny incoming 2>>"$LOG_FILE"
            sudo ufw default allow outgoing 2>>"$LOG_FILE"
            sudo ufw allow ssh 2>>"$LOG_FILE"
            sudo ufw --force enable 2>>"$LOG_FILE"
            sudo systemctl enable ufw 2>>"$LOG_FILE"
            log "INFO" "Configured UFW firewall"
            print_status success "Firewall configured (UFW)"
        else
            log "WARN" "UFW installation failed, trying firewalld"
            
            if [ "$DETECTED_PKG_MANAGER" = "dnf" ]; then
                sudo systemctl enable --now firewalld 2>>"$LOG_FILE"
                sudo firewall-cmd --set-default-zone=public 2>>"$LOG_FILE"
                sudo firewall-cmd --add-service=ssh --permanent 2>>"$LOG_FILE"
                sudo firewall-cmd --reload 2>>"$LOG_FILE"
                log "INFO" "Configured firewalld"
                print_status success "Firewall configured (firewalld)"
            fi
        fi
    }
    
    setup_fail2ban() {
        case "$DETECTED_PKG_MANAGER" in
            pacman)
                sudo pacman -S --noconfirm fail2ban 2>>"$LOG_FILE"
                ;;
            dnf)
                sudo dnf install -y fail2ban 2>>"$LOG_FILE"
                ;;
            apt)
                sudo apt-get install -y fail2ban 2>>"$LOG_FILE"
                ;;
        esac
        
        if command -v fail2ban-client &>/dev/null; then
            sudo systemctl enable --now fail2ban 2>>"$LOG_FILE"
            log "INFO" "Enabled fail2ban"
            print_status success "Fail2ban enabled"
        fi
    }
    
    setup_firewall
    setup_fail2ban
}