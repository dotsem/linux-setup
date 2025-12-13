#!/bin/bash
# NVIDIA GPU Setup Module
# Supports: Single GPU, Optimus/Prime hybrid GPU, performance mode

source "$(dirname "${BASH_SOURCE[0]}")/../helpers/ui.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../helpers/logging.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../vars.sh"

setup_nvidia() {
    section "NVIDIA GPU SETUP" "$GREEN"
    log "INFO" "Configuring NVIDIA drivers"
    
    if ! lspci | grep -qi nvidia; then
        log "INFO" "No NVIDIA GPU detected"
        echo -e "${YELLOW}No NVIDIA GPU detected, skipping...${NC}"
        return 0
    fi
    
    case "$DETECTED_PKG_MANAGER" in
        dnf)
            setup_nvidia_fedora
            ;;
        pacman)
            setup_nvidia_arch
            ;;
        apt)
            setup_nvidia_debian
            ;;
    esac
    
    if is_hybrid_gpu; then
        setup_optimus
    fi
    
    setup_nvidia_performance
}

setup_nvidia_fedora() {
    log "INFO" "Installing NVIDIA drivers for Fedora"
    
    sudo -n dnf install -y akmod-nvidia xorg-x11-drv-nvidia-cuda nvidia-settings 2>>"$LOG_FILE"
    
    echo -e "${YELLOW}Waiting for NVIDIA kernel module to build (this may take a few minutes)...${NC}"
    sudo akmods --force 2>>"$LOG_FILE"
    sudo dracut --force 2>>"$LOG_FILE"
    
    sudo grubby --update-kernel=ALL --args='nvidia-drm.modeset=1' 2>>"$LOG_FILE"
    
    log "INFO" "NVIDIA drivers installed for Fedora"
    echo -e "${GREEN}NVIDIA drivers installed!${NC}"
}

setup_nvidia_arch() {
    log "INFO" "Installing NVIDIA drivers for Arch"
    
    sudo -n pacman -S --noconfirm nvidia nvidia-utils nvidia-settings 2>>"$LOG_FILE"
    
    local current_modules=$(grep "^MODULES=" /etc/mkinitcpio.conf | cut -d'=' -f2 | tr -d '()')
    if ! echo "$current_modules" | grep -q "nvidia"; then
        if [ -n "$current_modules" ]; then
            sudo -n sed -i "s/^MODULES=($current_modules)/MODULES=($current_modules nvidia nvidia_modeset nvidia_uvm nvidia_drm)/" /etc/mkinitcpio.conf
        else
            sudo -n sed -i 's/^MODULES=()/MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' /etc/mkinitcpio.conf
        fi
        sudo -n mkinitcpio -P 2>>"$LOG_FILE"
    fi
    
    local grub_file="/etc/default/grub"
    if [ -f "$grub_file" ] && ! grep -q "nvidia-drm.modeset=1" "$grub_file"; then
        sudo -n sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="\([^"]*\)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 nvidia-drm.modeset=1"/' "$grub_file"
        sudo -n grub-mkconfig -o /boot/grub/grub.cfg 2>>"$LOG_FILE"
    fi
    
    log "INFO" "NVIDIA drivers installed for Arch"
    echo -e "${GREEN}NVIDIA drivers installed!${NC}"
}

setup_nvidia_debian() {
    log "INFO" "Installing NVIDIA drivers for Debian/Ubuntu"
    
    sudo -n apt-get install -y nvidia-driver nvidia-settings 2>>"$LOG_FILE"
    
    local grub_file="/etc/default/grub"
    if [ -f "$grub_file" ] && ! grep -q "nvidia-drm.modeset=1" "$grub_file"; then
        sudo -n sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="\([^"]*\)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 nvidia-drm.modeset=1"/' "$grub_file"
        sudo -n update-grub 2>>"$LOG_FILE"
    fi
    
    log "INFO" "NVIDIA drivers installed for Debian/Ubuntu"
    echo -e "${GREEN}NVIDIA drivers installed!${NC}"
}

setup_optimus() {
    section "NVIDIA OPTIMUS (Hybrid GPU) SETUP" "$CYAN"
    log "INFO" "Setting up hybrid GPU support"
    
    case "$DETECTED_PKG_MANAGER" in
        dnf)
            sudo -n dnf install -y switcheroo-control 2>>"$LOG_FILE"
            sudo -n systemctl enable --now switcheroo-control 2>>"$LOG_FILE"
            pip install envycontrol --user 2>>"$LOG_FILE" || true
            ;;
        pacman)
            sudo -n pacman -S --noconfirm nvidia-prime 2>>"$LOG_FILE"
            yay -S --noconfirm envycontrol 2>>"$LOG_FILE" || true
            ;;
        apt)
            sudo -n apt-get install -y nvidia-prime 2>>"$LOG_FILE"
            pip install envycontrol --user 2>>"$LOG_FILE" || true
            ;;
    esac
    
    log "INFO" "Hybrid GPU support configured"
    echo -e "${GREEN}Hybrid GPU (Optimus) support configured!${NC}"
    echo -e "${YELLOW}Use 'prime-run <app>' to run apps on NVIDIA GPU${NC}"
    echo -e "${YELLOW}Use 'envycontrol -s nvidia' to switch to dedicated GPU${NC}"
}

setup_nvidia_performance() {
    section "NVIDIA PERFORMANCE MODE" "$YELLOW"
    log "INFO" "Configuring NVIDIA for maximum performance on AC power"
    
    sudo tee /etc/udev/rules.d/80-nvidia-pm.rules > /dev/null << 'EOF'
# Enable full performance (P0) on AC power
ACTION=="change", SUBSYSTEM=="power_supply", ATTR{type}=="Mains", ATTR{online}=="1", RUN+="/usr/bin/nvidia-smi -pm 1"
ACTION=="change", SUBSYSTEM=="power_supply", ATTR{type}=="Mains", ATTR{online}=="1", RUN+="/usr/bin/nvidia-smi -lgc 300,2100"

# Enable power saving on battery
ACTION=="change", SUBSYSTEM=="power_supply", ATTR{type}=="Mains", ATTR{online}=="0", RUN+="/usr/bin/nvidia-smi -pm 0"
EOF

    sudo tee /etc/modprobe.d/nvidia-power.conf > /dev/null << 'EOF'
# Enable power management features
options nvidia NVreg_DynamicPowerManagement=0x02
EOF

    sudo udevadm control --reload-rules 2>>"$LOG_FILE"
    
    log "INFO" "NVIDIA performance mode configured"
    echo -e "${GREEN}NVIDIA will use maximum performance (P0) when on AC power!${NC}"
}

is_hybrid_gpu() {
    local nvidia_count=$(lspci | grep -ci 'nvidia')
    local intel_count=$(lspci | grep -ci 'intel.*graphics\|intel.*vga')
    local amd_count=$(lspci | grep -ci 'amd.*graphics\|radeon')
    
    if [ "$nvidia_count" -gt 0 ] && [ $((intel_count + amd_count)) -gt 0 ]; then
        log "INFO" "Hybrid GPU detected (NVIDIA + Intel/AMD)"
        return 0
    fi
    return 1
}

verify_nvidia() {
    section "NVIDIA VERIFICATION" "$BLUE"
    
    if command -v nvidia-smi &>/dev/null; then
        echo -e "${GREEN}NVIDIA driver loaded:${NC}"
        nvidia-smi --query-gpu=name,driver_version,power.draw --format=csv,noheader 2>/dev/null
        return 0
    else
        echo -e "${RED}nvidia-smi not found - driver may not be installed correctly${NC}"
        return 1
    fi
}
