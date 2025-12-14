#!/bin/bash
# Boot Configuration Module
# Multi-distro support with GRUB and systemd-boot options

source "$(dirname "${BASH_SOURCE[0]}")/../helpers/ui.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../helpers/logging.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../vars.sh"

setup_nvidia_modules() {
    [ "$DETECTED_PKG_MANAGER" != "pacman" ] && return 0
    
    local mkinitcpio_conf="/etc/mkinitcpio.conf"
    if ! grep -q "nvidia" "$mkinitcpio_conf"; then
        local nvidia_modules="nvidia nvidia_modeset nvidia_uvm nvidia_drm"
        
        if grep -q "^MODULES=()" "$mkinitcpio_conf"; then
            sudo -n sed -i "s/^MODULES=()/MODULES=($nvidia_modules)/" "$mkinitcpio_conf"
        elif grep -q "^MODULES=(" "$mkinitcpio_conf"; then
            sudo -n sed -i "/^MODULES=(/s/)/ $nvidia_modules)/" "$mkinitcpio_conf"
        fi
        log "INFO" "Added NVIDIA modules to mkinitcpio"
    fi
}

setup_grub() {
    section "GRUB BOOTLOADER SETUP" "$BLUE"
    log "INFO" "Configuring GRUB bootloader"
    
    local grub_file="/etc/default/grub"
    
    if [ ! -f "$grub_file" ]; then
        log "WARN" "GRUB config not found at $grub_file"
        echo -e "${YELLOW}GRUB not detected, skipping GRUB configuration${NC}"
        return 1
    fi
    
    local kernel_params=""
    
    if lspci | grep -qi nvidia; then
        kernel_params="nvidia-drm.modeset=1"
    fi
    
    if [ -n "$kernel_params" ] && ! grep -q "$kernel_params" "$grub_file"; then
        sudo -n sed -i "s/GRUB_CMDLINE_LINUX_DEFAULT=\"\([^\"]*\)\"/GRUB_CMDLINE_LINUX_DEFAULT=\"\1 $kernel_params\"/" "$grub_file"
        log "INFO" "Added kernel parameters to GRUB: $kernel_params"
    fi
    
    case "$DETECTED_PKG_MANAGER" in
        pacman)
            sudo -n grub-mkconfig -o /boot/grub/grub.cfg 2>>"$LOG_FILE"
            ;;
        dnf)
            sudo -n grub2-mkconfig -o /boot/grub2/grub.cfg 2>>"$LOG_FILE" || \
            sudo -n grub2-mkconfig -o /boot/efi/EFI/fedora/grub.cfg 2>>"$LOG_FILE"
            ;;
        apt)
            sudo -n update-grub 2>>"$LOG_FILE"
            ;;
    esac
    
    log "INFO" "GRUB configuration updated"
    echo -e "${GREEN}GRUB bootloader configured!${NC}"
}

setup_systemd_boot() {
    section "SYSTEMD-BOOT SETUP" "$BLUE"
    log "INFO" "Configuring systemd-boot bootloader"
    
    if [ "$DETECTED_PKG_MANAGER" != "pacman" ]; then
        log "WARN" "systemd-boot setup is only supported on Arch Linux"
        echo -e "${YELLOW}systemd-boot is only supported on Arch Linux${NC}"
        echo -e "${YELLOW}Falling back to GRUB...${NC}"
        setup_grub
        return $?
    fi
    
    if [ ! -d "/sys/firmware/efi" ]; then
        log "ERROR" "EFI not detected - systemd-boot requires UEFI"
        echo -e "${RED}ERROR: systemd-boot requires UEFI boot mode${NC}"
        echo -e "${YELLOW}Falling back to GRUB...${NC}"
        setup_grub
        return $?
    fi
    
    local esp="/boot"
    if mountpoint -q /boot/efi 2>/dev/null; then
        esp="/boot/efi"
    fi
    
    if ! bootctl is-installed 2>/dev/null; then
        log "INFO" "Installing systemd-boot to $esp"
        if ! sudo -n bootctl install --esp-path="$esp" 2>>"$LOG_FILE"; then
            log "ERROR" "Failed to install systemd-boot"
            echo -e "${RED}Failed to install systemd-boot${NC}"
            return 1
        fi
    else
        log "INFO" "systemd-boot already installed, updating..."
        sudo -n bootctl update --esp-path="$esp" 2>>"$LOG_FILE" || true
    fi
    
    local loader_conf="$esp/loader/loader.conf"
    log "INFO" "Creating loader.conf at $loader_conf"
    sudo -n mkdir -p "$esp/loader" 2>>"$LOG_FILE"
    sudo tee "$loader_conf" > /dev/null << 'EOF'
default arch.conf
timeout 3
console-mode max
editor no
EOF
    
    local entries_dir="$esp/loader/entries"
    local entry_file="$entries_dir/arch.conf"
    
    sudo -n mkdir -p "$entries_dir" 2>>"$LOG_FILE"
    
    local root_partuuid=$(findmnt -no PARTUUID /)
    if [ -z "$root_partuuid" ]; then
        root_partuuid=$(findmnt -no UUID /)
        local root_param="root=UUID=$root_partuuid"
    else
        local root_param="root=PARTUUID=$root_partuuid"
    fi
    
    local kernel_params="rw quiet"
    if lspci | grep -qi nvidia; then
        kernel_params="$kernel_params nvidia-drm.modeset=1"
    fi
    
    local kernel_image="vmlinuz-${KERNEL_TYPE}"
    local initramfs_image="initramfs-${KERNEL_TYPE}.img"
    
    log "INFO" "Creating boot entry at $entry_file"
    sudo tee "$entry_file" > /dev/null << EOF
title   Arch Linux
linux   /$kernel_image
initrd  /$initramfs_image
options $root_param $kernel_params
EOF
    
    local fallback_entry="$entries_dir/arch-fallback.conf"
    sudo tee "$fallback_entry" > /dev/null << EOF
title   Arch Linux (fallback)
linux   /$kernel_image
initrd  /initramfs-${KERNEL_TYPE}-fallback.img
options $root_param $kernel_params
EOF
    
    log "INFO" "systemd-boot configured successfully"
    echo -e "${GREEN}systemd-boot bootloader configured!${NC}"
    echo -e "${YELLOW}Boot entries created: arch.conf, arch-fallback.conf${NC}"
}

setup_boot() {
    section "BOOT CUSTOMIZATION" "$WHITE"
    local errors=0

    if lspci | grep -qi nvidia; then
        log "INFO" "NVIDIA GPU detected - configuring boot parameters"
        
        case "$DETECTED_PKG_MANAGER" in
            pacman)
                setup_nvidia_modules
                ;;
            dnf)
                sudo akmods --force 2>>"$LOG_FILE" || true
                sudo dracut --force 2>>"$LOG_FILE" || true
                log "INFO" "Rebuilt initramfs for Fedora"
                ;;
        esac
    fi

    case "$BOOTLOADER" in
        systemd-boot)
            setup_systemd_boot || ((errors++))
            ;;
        grub|*)
            setup_grub || ((errors++))
            ;;
    esac

    if [ "$DETECTED_PKG_MANAGER" = "pacman" ]; then
        log "INFO" "Rebuilding initramfs"
        if sudo -n mkinitcpio -P 2>>"$LOG_FILE"; then
            log "INFO" "Initramfs rebuilt successfully"
        else
            log "ERROR" "Failed to rebuild initramfs"
            ((errors++))
        fi
    fi

    if [ $errors -eq 0 ]; then
        print_status success "Boot setup complete - REBOOT to see changes"
    else
        print_status warning "Boot setup completed with $errors errors"
    fi

    return $errors
}
