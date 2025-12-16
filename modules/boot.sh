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
            sudo sed -i "s/^MODULES=()/MODULES=($nvidia_modules)/" "$mkinitcpio_conf"
        elif grep -q "^MODULES=(" "$mkinitcpio_conf"; then
            sudo sed -i "/^MODULES=(/s/)/ $nvidia_modules)/" "$mkinitcpio_conf"
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
        sudo sed -i "s/GRUB_CMDLINE_LINUX_DEFAULT=\"\([^\"]*\)\"/GRUB_CMDLINE_LINUX_DEFAULT=\"\1 $kernel_params\"/" "$grub_file"
        log "INFO" "Added kernel parameters to GRUB: $kernel_params"
    fi
    
    case "$DETECTED_PKG_MANAGER" in
        pacman)
            sudo grub-mkconfig -o /boot/grub/grub.cfg 2>>"$LOG_FILE"
            ;;
        dnf)
            sudo grub2-mkconfig -o /boot/grub2/grub.cfg 2>>"$LOG_FILE" || \
            sudo grub2-mkconfig -o /boot/efi/EFI/fedora/grub.cfg 2>>"$LOG_FILE"
            ;;
        apt)
            sudo update-grub 2>>"$LOG_FILE"
            ;;
    esac
    
    log "INFO" "GRUB configuration updated"
    echo -e "${GREEN}GRUB bootloader configured!${NC}"
}

setup_systemd_boot() {
    section "SYSTEMD-BOOT SETUP" "$BLUE"
    log "INFO" "Configuring systemd-boot bootloader"
    
    if [ "$DETECTED_DISTRO_ID" = "cachyos" ]; then
        log "INFO" "CachyOS detected - skipping manual systemd-boot entry creation (handled by distro)"
        echo -e "${GREEN}CachyOS systemd-boot management detected. Skipping manual entry creation.${NC}"
        return 0
    fi
    
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
        if ! sudo bootctl install --esp-path="$esp" 2>>"$LOG_FILE"; then
            log "ERROR" "Failed to install systemd-boot"
            echo -e "${RED}Failed to install systemd-boot${NC}"
            return 1
        fi
    else
        log "INFO" "systemd-boot already installed, updating..."
        sudo bootctl update --esp-path="$esp" 2>>"$LOG_FILE" || true
    fi
    
    local loader_conf="$esp/loader/loader.conf"
    local entries_dir="$esp/loader/entries"
    
    sudo mkdir -p "$esp/loader" 2>>"$LOG_FILE"
    sudo mkdir -p "$entries_dir" 2>>"$LOG_FILE"
    
    # Determine entry filename based on distro
    local entry_basename="arch"
    [ "$DETECTED_DISTRO_ID" = "cachyos" ] && entry_basename="cachyos"
    [ "$DETECTED_DISTRO_ID" = "manjaro" ] && entry_basename="manjaro"
    [ "$DETECTED_DISTRO_ID" = "endeavouros" ] && entry_basename="endeavouros"
    
    local entry_file="$entries_dir/${entry_basename}.conf"
    local fallback_entry="$entries_dir/${entry_basename}-fallback.conf"
    
    # Only create loader.conf if it doesn't exist to avoid overwriting user's config
    if [ ! -f "$loader_conf" ]; then
        log "INFO" "Creating loader.conf at $loader_conf"
        sudo tee "$loader_conf" > /dev/null << EOF
default ${entry_basename}.conf
timeout 3
console-mode max
editor no
EOF
    else
        log "INFO" "loader.conf already exists, not overwriting"
    fi
    
    local root_partuuid
    local root_param
    
    root_partuuid=$(findmnt -no PARTUUID /)
    if [ -n "$root_partuuid" ]; then
        root_param="root=PARTUUID=$root_partuuid"
    else
        root_partuuid=$(findmnt -no UUID /)
        if [ -n "$root_partuuid" ]; then
            root_param="root=UUID=$root_partuuid"
        else
            log "ERROR" "Could not determine root partition UUID or PARTUUID"
            echo -e "${RED}ERROR: Cannot determine root partition identifier${NC}"
            return 1
        fi
    fi
    
    local kernel_params="rw quiet"
    if lspci | grep -qi nvidia; then
        kernel_params="$kernel_params nvidia-drm.modeset=1"
    fi
    
    local kernel_image="vmlinuz-${KERNEL_TYPE}"
    local initramfs_image="initramfs-${KERNEL_TYPE}.img"
    
    local distro_title="Arch Linux"
    [ "$DETECTED_DISTRO_ID" = "cachyos" ] && distro_title="CachyOS"
    [ "$DETECTED_DISTRO_ID" = "manjaro" ] && distro_title="Manjaro"
    [ "$DETECTED_DISTRO_ID" = "endeavouros" ] && distro_title="EndeavourOS"
    
    # Create main boot entry (overwrite to ensure correct config)
    log "INFO" "Creating boot entry at $entry_file"
    sudo tee "$entry_file" > /dev/null << EOF
title   $distro_title
linux   /$kernel_image
initrd  /$initramfs_image
options $root_param $kernel_params
EOF
    
    # Create fallback boot entry
    sudo tee "$fallback_entry" > /dev/null << EOF
title   $distro_title (fallback)
linux   /$kernel_image
initrd  /initramfs-${KERNEL_TYPE}-fallback.img
options $root_param $kernel_params
EOF
    
    # Add Windows boot entry if Windows is detected
    setup_windows_boot_entry "$esp"
    
    log "INFO" "systemd-boot configured successfully"
    echo -e "${GREEN}systemd-boot bootloader configured!${NC}"
    echo -e "${YELLOW}Boot entries created: ${entry_basename}.conf, ${entry_basename}-fallback.conf${NC}"
}

setup_windows_boot_entry() {
    local esp="$1"
    local entries_dir="$esp/loader/entries"
    local windows_entry="$entries_dir/windows.conf"
    
    # Check if Windows EFI exists
    local windows_efi="$esp/EFI/Microsoft/Boot/bootmgfw.efi"
    if [ ! -f "$windows_efi" ]; then
        log "INFO" "Windows boot manager not found, skipping Windows entry"
        return 0
    fi
    
    log "INFO" "Windows detected, creating boot entry"
    sudo tee "$windows_entry" > /dev/null << 'EOF'
title   Windows
efi     /EFI/Microsoft/Boot/bootmgfw.efi
EOF
    
    log "INFO" "Windows boot entry created"
    echo -e "${GREEN}Windows boot entry added!${NC}"
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
        if sudo mkinitcpio -P 2>>"$LOG_FILE"; then
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
