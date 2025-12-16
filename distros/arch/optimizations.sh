#!/bin/bash
# Arch Linux specific optimizations

source "$(dirname "${BASH_SOURCE[0]}")/../common.sh"

apply_arch_optimizations() {
    log "INFO" "Applying Arch Linux optimizations"
    
    apply_sysctl_tweaks
    apply_power_udev_rules
}

apply_sysctl_tweaks() {
    local ram_gb=$(free -g | awk '/Mem:/ {print $2}')
    
    if [ "$ram_gb" -ge 16 ]; then
        echo "vm.swappiness=10" | sudo tee /etc/sysctl.d/99-swappiness.conf > /dev/null
        sudo sysctl -p /etc/sysctl.d/99-swappiness.conf 2>>"$LOG_FILE"
        log "INFO" "Optimized swappiness for ${ram_gb}GB RAM system"
        print_status success "Memory swappiness optimized"
    fi
    
    if lspci | grep -qi nvidia && [ "$ram_gb" -ge 8 ]; then
        echo "vm.dirty_background_ratio=5" | sudo tee /etc/sysctl.d/99-performance.conf > /dev/null
        echo "vm.dirty_ratio=10" | sudo tee -a /etc/sysctl.d/99-performance.conf > /dev/null
        sudo sysctl -p /etc/sysctl.d/99-performance.conf 2>>"$LOG_FILE"
        log "INFO" "Applied gaming performance tweaks"
        print_status success "Gaming performance tweaks applied"
    fi
}

apply_power_udev_rules() {
    log "INFO" "Creating CPU power switching udev rules"
    
    local cpu_script="/usr/local/bin/cpu-power-switch"
    sudo tee "$cpu_script" > /dev/null << 'SCRIPT'
#!/bin/bash
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
    
    if lspci | grep -qi nvidia; then
        apply_nvidia_power_rules
    fi
}

apply_nvidia_power_rules() {
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
