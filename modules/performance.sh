#!/bin/bash
# Performance & Power Management Module
# Automatic power-aware CPU/GPU switching

source "$(dirname "${BASH_SOURCE[0]}")/../helpers/ui.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../helpers/logging.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../vars.sh"

setup_power_management() {
    section "POWER MANAGEMENT" "$CYAN"
    log "INFO" "Setting up power-aware CPU/GPU management"
    
    case "$DETECTED_PKG_MANAGER" in
        pacman)
            sudo -n pacman -S --noconfirm power-profiles-daemon 2>>"$LOG_FILE" || \
            sudo -n pacman -S --noconfirm cpupower 2>>"$LOG_FILE"
            ;;
        dnf)
            sudo -n dnf install -y power-profiles-daemon 2>>"$LOG_FILE"
            ;;
        apt)
            sudo -n apt-get install -y power-profiles-daemon 2>>"$LOG_FILE" || \
            sudo -n apt-get install -y cpufrequtils 2>>"$LOG_FILE"
            ;;
    esac
    
    if command -v powerprofilesctl &>/dev/null; then
        sudo -n systemctl enable --now power-profiles-daemon 2>>"$LOG_FILE"
        log "INFO" "power-profiles-daemon enabled"
        print_status success "Power Profiles Daemon enabled (use 'powerprofilesctl' to switch)"
    fi
    
    setup_cpu_power_udev
    setup_gpu_power_udev
}

setup_cpu_power_udev() {
    log "INFO" "Creating CPU power switching udev rules"
    
    local cpu_script="/usr/local/bin/cpu-power-switch"
    sudo tee "$cpu_script" > /dev/null << 'SCRIPT'
#!/bin/bash
# CPU power switching based on AC status

POWER_STATUS="$1"

set_governor() {
    local governor="$1"
    for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        [ -f "$cpu" ] && echo "$governor" > "$cpu" 2>/dev/null
    done
}

set_turbo() {
    local state="$1"
    local intel_pstate="/sys/devices/system/cpu/intel_pstate/no_turbo"
    local amd_boost="/sys/devices/system/cpu/cpufreq/boost"
    
    if [ -f "$intel_pstate" ]; then
        echo "$state" > "$intel_pstate" 2>/dev/null
    fi
    if [ -f "$amd_boost" ]; then
        [ "$state" = "0" ] && echo "1" > "$amd_boost" 2>/dev/null || echo "0" > "$amd_boost" 2>/dev/null
    fi
}

if command -v powerprofilesctl &>/dev/null; then
    if [ "$POWER_STATUS" = "ac" ]; then
        powerprofilesctl set performance
    else
        powerprofilesctl set power-saver
    fi
else
    if [ "$POWER_STATUS" = "ac" ]; then
        set_governor "performance"
        set_turbo 0
    else
        set_governor "powersave"
        set_turbo 1
    fi
fi
SCRIPT
    sudo chmod +x "$cpu_script"
    
    sudo tee /etc/udev/rules.d/85-power-cpu.rules > /dev/null << 'EOF'
# CPU performance on AC power
ACTION=="change", SUBSYSTEM=="power_supply", ATTR{type}=="Mains", ATTR{online}=="1", RUN+="/usr/local/bin/cpu-power-switch ac"

# CPU powersave on battery
ACTION=="change", SUBSYSTEM=="power_supply", ATTR{type}=="Mains", ATTR{online}=="0", RUN+="/usr/local/bin/cpu-power-switch battery"
EOF
    
    sudo udevadm control --reload-rules 2>>"$LOG_FILE"
    log "INFO" "CPU power udev rules created"
    print_status success "CPU auto-switching: performance on AC, powersave on battery"
}

setup_gpu_power_udev() {
    if ! lspci | grep -qi nvidia; then
        log "INFO" "No NVIDIA GPU detected, skipping GPU power management"
        return 0
    fi
    
    log "INFO" "Creating NVIDIA GPU power switching udev rules"
    
    sudo tee /etc/udev/rules.d/85-power-nvidia.rules > /dev/null << 'EOF'
# NVIDIA performance on AC power
ACTION=="change", SUBSYSTEM=="power_supply", ATTR{type}=="Mains", ATTR{online}=="1", RUN+="/usr/bin/nvidia-smi -pm 1"
ACTION=="change", SUBSYSTEM=="power_supply", ATTR{type}=="Mains", ATTR{online}=="1", RUN+="/usr/bin/nvidia-smi -pl 300"

# NVIDIA powersave on battery
ACTION=="change", SUBSYSTEM=="power_supply", ATTR{type}=="Mains", ATTR{online}=="0", RUN+="/usr/bin/nvidia-smi -pm 0"
ACTION=="change", SUBSYSTEM=="power_supply", ATTR{type}=="Mains", ATTR{online}=="0", RUN+="/usr/bin/nvidia-smi -pl 50"
EOF
    
    sudo tee /etc/modprobe.d/nvidia-power.conf > /dev/null << 'EOF'
# Enable dynamic power management for hybrid GPUs
options nvidia NVreg_DynamicPowerManagement=0x02
EOF
    
    sudo udevadm control --reload-rules 2>>"$LOG_FILE"
    log "INFO" "NVIDIA power udev rules created"
    print_status success "GPU auto-switching: max power on AC, powersave on battery"
}

tweak_performance() {
    section "PERFORMANCE TWEAKS" "$CYAN"
    
    setup_power_management
    
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
    
    echo -e "\n${BLUE}Power Management Summary:${NC}"
    echo -e "  ${GREEN}•${NC} CPU: performance (AC) / powersave (battery)"
    echo -e "  ${GREEN}•${NC} GPU: max power (AC) / low power (battery)"
    echo -e "  ${YELLOW}Tip:${NC} Use 'powerprofilesctl' to manually switch profiles"
}