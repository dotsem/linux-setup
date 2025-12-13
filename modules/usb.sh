#!/bin/bash
# USB Configuration Module

source "$(dirname "${BASH_SOURCE[0]}")/../helpers/ui.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../helpers/logging.sh"

# Disable USB autosuspend for better device reliability
disable_usb_autosuspend() {
    section "USB CONFIGURATION" "$CYAN"
    log "INFO" "Disabling USB autosuspend"
    
    local udev_rules_file="/etc/udev/rules.d/50-usb-power.rules"
    local sysctl_conf="/etc/sysctl.d/99-usb.conf"
    
    # Create udev rule to disable USB autosuspend
    local udev_content='# Disable USB autosuspend
ACTION=="add", SUBSYSTEM=="usb", TEST=="power/control", ATTR{power/control}="on"'
    
    if echo "$udev_content" | sudo -n tee "$udev_rules_file" > /dev/null; then
        log "INFO" "Created udev rule to disable USB autosuspend"
        print_status success "USB autosuspend disabled via udev"
    else
        log "ERROR" "Failed to create udev rule"
        print_status error "Failed to configure USB autosuspend"
        return 1
    fi
    
    # Also set kernel parameters
    local sysctl_content='# Disable USB autosuspend
kernel.usb.autosuspend = -1'
    
    if echo "$sysctl_content" | sudo -n tee "$sysctl_conf" > /dev/null; then
        log "INFO" "Created sysctl configuration for USB"
        sudo -n sysctl -p "$sysctl_conf" 2>> "$LOG_FILE" || true
    fi
    
    # Reload udev rules
    if sudo -n udevadm control --reload-rules && sudo -n udevadm trigger; then
        log "INFO" "Reloaded udev rules"
        print_status success "USB configuration applied"
        return 0
    else
        log "ERROR" "Failed to reload udev rules"
        print_status error "Failed to apply USB configuration"
        return 1
    fi
}
