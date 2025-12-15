#!/bin/bash
# CachyOS specific optimizations
# CachyOS already ships with many performance optimizations, so we skip those

source "$(dirname "${BASH_SOURCE[0]}")/../common.sh"

apply_cachyos_optimizations() {
    log "INFO" "Applying CachyOS-specific optimizations"
    
    echo -e "${CYAN}CachyOS detected - using distro defaults where possible${NC}"
    
    log "INFO" "Skipping sched-ext setup (CachyOS default)"
    log "INFO" "Skipping BORE scheduler setup (CachyOS default)"
    log "INFO" "Skipping ananicy-cpp setup (CachyOS default)"
    
    apply_cachyos_power_rules
    apply_cachyos_sysctl_tweaks
}

apply_cachyos_sysctl_tweaks() {
    local ram_gb=$(free -g | awk '/Mem:/ {print $2}')
    
    # CachyOS already has good defaults, only apply NVIDIA-specific tweaks
    if lspci | grep -qi nvidia && [ "$ram_gb" -ge 8 ]; then
        if [ ! -f /etc/sysctl.d/99-performance.conf ]; then
            echo "vm.dirty_background_ratio=5" | sudo -n tee /etc/sysctl.d/99-performance.conf > /dev/null
            echo "vm.dirty_ratio=10" | sudo -n tee -a /etc/sysctl.d/99-performance.conf > /dev/null
            sudo -n sysctl -p /etc/sysctl.d/99-performance.conf 2>>"$LOG_FILE"
            log "INFO" "Applied NVIDIA gaming performance tweaks"
            print_status success "NVIDIA gaming tweaks applied"
        else
            log "INFO" "Performance sysctl already configured"
            print_status info "Sysctl tweaks already present"
        fi
    fi
}

apply_cachyos_power_rules() {
    # CachyOS has power-profiles-daemon by default, only add udev if missing
    if [ ! -f /etc/udev/rules.d/85-power-cpu.rules ]; then
        log "INFO" "Adding power switching udev rules"
        
        local cpu_script="/usr/local/bin/cpu-power-switch"
        if [ ! -f "$cpu_script" ]; then
            sudo tee "$cpu_script" > /dev/null << 'SCRIPT'
#!/bin/bash
POWER_STATUS="$1"

if command -v powerprofilesctl &>/dev/null; then
    if [ "$POWER_STATUS" = "ac" ]; then
        powerprofilesctl set performance
    else
        powerprofilesctl set power-saver
    fi
fi
SCRIPT
            sudo chmod +x "$cpu_script"
        fi
        
        sudo tee /etc/udev/rules.d/85-power-cpu.rules > /dev/null << 'EOF'
ACTION=="change", SUBSYSTEM=="power_supply", ATTR{type}=="Mains", ATTR{online}=="1", RUN+="/usr/local/bin/cpu-power-switch ac"
ACTION=="change", SUBSYSTEM=="power_supply", ATTR{type}=="Mains", ATTR{online}=="0", RUN+="/usr/local/bin/cpu-power-switch battery"
EOF
        sudo udevadm control --reload-rules 2>>"$LOG_FILE"
        print_status success "Power switching rules added"
    else
        log "INFO" "Power udev rules already present"
        print_status info "Power rules already configured"
    fi
    
    if lspci | grep -qi nvidia && [ ! -f /etc/udev/rules.d/85-power-nvidia.rules ]; then
        apply_nvidia_power_rules
    fi
}

apply_nvidia_power_rules() {
    log "INFO" "Creating NVIDIA GPU power switching udev rules"
    
    sudo tee /etc/udev/rules.d/85-power-nvidia.rules > /dev/null << 'EOF'
ACTION=="change", SUBSYSTEM=="power_supply", ATTR{type}=="Mains", ATTR{online}=="1", RUN+="/usr/bin/nvidia-smi -pm 1"
ACTION=="change", SUBSYSTEM=="power_supply", ATTR{type}=="Mains", ATTR{online}=="1", RUN+="/usr/bin/nvidia-smi -pl 300"
ACTION=="change", SUBSYSTEM=="power_supply", ATTR{type}=="Mains", ATTR{online}=="0", RUN+="/usr/bin/nvidia-smi -pm 0"
ACTION=="change", SUBSYSTEM=="power_supply", ATTR{type}=="Mains", ATTR{online}=="0", RUN+="/usr/bin/nvidia-smi -pl 50"
EOF
    
    if [ ! -f /etc/modprobe.d/nvidia-power.conf ]; then
        sudo tee /etc/modprobe.d/nvidia-power.conf > /dev/null << 'EOF'
options nvidia NVreg_DynamicPowerManagement=0x02
EOF
    fi
    
    sudo udevadm control --reload-rules 2>>"$LOG_FILE"
    print_status success "NVIDIA power rules added"
}
