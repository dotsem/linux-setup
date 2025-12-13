#!/bin/bash
# Audio Configuration Module (PipeWire)
# Multi-distro support

source "$(dirname "${BASH_SOURCE[0]}")/../helpers/ui.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../helpers/logging.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../vars.sh"

setup_pipewire() {
    section "PIPEWIRE AUDIO SETUP" "$CYAN"
    
    check_pipewire_installed() {
        case "$DETECTED_PKG_MANAGER" in
            pacman)
                pacman -Qi pipewire > /dev/null 2>&1
                ;;
            dnf)
                rpm -q pipewire > /dev/null 2>&1
                ;;
            apt)
                dpkg -l pipewire > /dev/null 2>&1
                ;;
        esac
    }
    
    if ! check_pipewire_installed; then
        log "WARN" "PipeWire not installed, installing..."
        case "$DETECTED_PKG_MANAGER" in
            pacman)
                sudo -n pacman -S --noconfirm pipewire pipewire-pulse pipewire-jack wireplumber 2>>"$LOG_FILE"
                ;;
            dnf)
                sudo -n dnf install -y pipewire pipewire-pulseaudio pipewire-jack-audio-connection-kit wireplumber 2>>"$LOG_FILE"
                ;;
            apt)
                sudo -n apt-get install -y pipewire pipewire-pulse pipewire-jack wireplumber 2>>"$LOG_FILE"
                ;;
        esac
    fi

    setup_pipewire_services() {
        local services=("wireplumber" "pipewire" "pipewire-pulse")
        local failed=0
        
        for service in "${services[@]}"; do
            log "INFO" "Enabling and starting $service"
            if systemctl --user enable --now "$service" >> "$LOG_FILE" 2>&1; then
                log "INFO" "Successfully enabled $service"
                echo -e "${GREEN}Enabled and started $service${NC}"
                sleep 1
            else
                log "WARN" "Failed to enable $service"
                failed=$((failed + 1))
            fi
        done
        
        return $failed
    }

    setup_audio_priority() {
        log "INFO" "Configuring audio priority settings"
        
        local conf_dir="/etc/security/limits.d"
        local conf_file="$conf_dir/audio_priority.conf"
        local content="@audio - nice -10"
        
        sudo -n mkdir -p "$conf_dir" 2>>"$LOG_FILE"
        
        if [ -f "$conf_file" ] && grep -qxF "$content" "$conf_file"; then
            log "INFO" "Audio priority already configured"
            return 0
        fi
        
        echo "$content" | sudo -n tee "$conf_file" > /dev/null
        log "INFO" "Audio priority configuration saved"
    }

    check_audio_group() {
        log "INFO" "Checking if user is in audio group"
        
        if groups | grep -q '\baudio\b'; then
            log "INFO" "User is in audio group"
            return 0
        else
            log "INFO" "Adding user to audio group"
            sudo -n usermod -aG audio "$USER" >> "$LOG_FILE" 2>&1
        fi
    }

    local overall_success=0
    
    setup_pipewire_services || overall_success=1
    setup_audio_priority || overall_success=1
    check_audio_group || overall_success=1
    
    if [ $overall_success -eq 0 ]; then
        log "INFO" "PipeWire setup completed successfully"
        echo -e "${GREEN}PipeWire audio configured!${NC}"
    else
        log "WARN" "PipeWire setup completed with some issues"
        echo -e "${YELLOW}PipeWire setup completed with warnings${NC}"
    fi
    
    return $overall_success
}