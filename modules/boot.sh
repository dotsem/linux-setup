#!/bin/bash
# Boot Configuration Module
# Multi-distro support

source "$(dirname "${BASH_SOURCE[0]}")/../helpers/ui.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../helpers/logging.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../vars.sh"

setup_boot() {
    section "BOOT CUSTOMIZATION" "$WHITE"
    local errors=0

    if lspci | grep -qi nvidia; then
        log "INFO" "NVIDIA GPU detected - configuring boot parameters"
        
        case "$DETECTED_PKG_MANAGER" in
            pacman)
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
                ;;
            dnf)
                sudo akmods --force 2>>"$LOG_FILE" || true
                sudo dracut --force 2>>"$LOG_FILE" || true
                log "INFO" "Rebuilt initramfs for Fedora"
                ;;
        esac
    fi

    configure_kernel_params() {
        local grub_file="/etc/default/grub"
        local boot_entry="/boot/loader/entries/arch.conf"

        if [ -f "$grub_file" ]; then
            if lspci | grep -qi nvidia; then
                if ! grep -q "nvidia-drm.modeset=1" "$grub_file"; then
                    sudo -n sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="\([^"]*\)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 nvidia-drm.modeset=1"/' "$grub_file"
                    log "INFO" "Added nvidia-drm.modeset=1 to GRUB"
                fi
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
            
        elif [ -f "$boot_entry" ]; then
            if lspci | grep -qi nvidia; then
                if ! grep -q "nvidia-drm.modeset=1" "$boot_entry"; then
                    sudo -n sed -i 's/options \(.*\)/options \1 nvidia-drm.modeset=1/' "$boot_entry"
                    log "INFO" "Added nvidia-drm.modeset=1 to systemd-boot"
                fi
            fi
        else
            log "INFO" "Bootloader configuration handled by distro"
        fi
    }
    configure_kernel_params

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
