#!/bin/bash
# GRUB Configuration Script with Logging
source "$(dirname "${BASH_SOURCE[0]}")/../helpers/ui.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../helpers/logging.sh"

setup_grub() {
    section_header "Configuring GRUB for Windows"
    log "INFO" "Starting Windows bootloader detection"

    # Step 1: Find Windows EFI partition
    local WIN_EFI_PARTITION=""
    local WIN_EFI_UUID=""
    local FOUND_EFI_PATH=""
    local MOUNT_POINT=$(mktemp -d)
    log "DEBUG" "Created temp mount point at $MOUNT_POINT"

    # List of possible Windows EFI bootloader paths
    local EFI_PATHS=(
        "EFI/Microsoft/Boot/bootmgfw.efi"
        "EFI/Boot/bootx64.efi"
        "EFI/Microsoft/Boot/bootmgr.efi"
    )

    # Function to safely mount and check partition
    check_efi_partition() {
        local part="$1"
        
        # Skip if already mounted
        if mount | grep -q "$part"; then
            log "DEBUG" "Partition $part is already mounted, skipping"
            return 1
        fi

        # Try mounting read-only
        if ! sudo mount -o ro "$part" "$MOUNT_POINT" 2>/dev/null; then
            log "WARN" "Could not mount $part (might be locked or encrypted)"
            return 1
        fi

        # Check for EFI bootloaders
        for efi_path in "${EFI_PATHS[@]}"; do
            if [ -f "$MOUNT_POINT/$efi_path" ]; then
                WIN_EFI_PARTITION="$part"
                WIN_EFI_UUID=$(sudo blkid -s UUID -o value "$part")
                FOUND_EFI_PATH="$efi_path"
                log "INFO" "Found Windows bootloader at $part (UUID: $WIN_EFI_UUID, Path: $efi_path)"
                sudo umount "$MOUNT_POINT"
                return 0
            fi
        done

        # If we get here, no bootloader found
        log "DEBUG" "No Windows EFI bootloader found in $part"
        sudo umount "$MOUNT_POINT"
        return 1
    }

    # Check all potential EFI partitions
    log "INFO" "Scanning for EFI partitions..."
    while IFS= read -r part; do
        log "DEBUG" "Checking partition $part"
        if check_efi_partition "$part"; then
            break
        fi
    done < <(sudo lsblk -rno NAME,FSTYPE,PARTTYPE | awk '/vfat|c12a7328-f81f-11d2-ba4b-00a0c93ec93b/ {print "/dev/"$1}')

    # Clean up mount point
    rmdir "$MOUNT_POINT"

    # If not found, show detailed debug info
    if [ -z "$WIN_EFI_PARTITION" ]; then
        log "ERROR" "Windows EFI partition not found"
        echo -e "${RED}ERROR: Windows EFI partition not found!${NC}"
        echo -e "${YELLOW}Debug information:${NC}"
        
        # Show all potential EFI partitions
        echo -e "\n${YELLOW}All potential EFI partitions:${NC}"
        sudo lsblk -o NAME,FSTYPE,PARTTYPE,LABEL,UUID,MOUNTPOINT | grep -E 'vfat|c12a7328-f81f-11d2-ba4b-00a0c93ec93b' || true
        
        # Show mounted partitions
        echo -e "\n${YELLOW}Currently mounted partitions:${NC}"
        mount | grep -E 'vfat|fat32' || true
        
        return 1
    fi

    # Step 2: Configure GRUB
    log "INFO" "Creating GRUB custom entry"
    local GRUB_CUSTOM_FILE="/etc/grub.d/40_custom"
    
    # Create backup of existing file
    sudo cp "$GRUB_CUSTOM_FILE" "${GRUB_CUSTOM_FILE}.bak" 2>/dev/null || true
    
    cat <<EOF | sudo tee "$GRUB_CUSTOM_FILE" >/dev/null
#!/bin/sh
exec tail -n +3 \$0

menuentry "Windows Boot Manager" {
    insmod part_gpt
    insmod fat
    insmod chain
    search --fs-uuid --no-floppy --set=root ${WIN_EFI_UUID}
    chainloader /${FOUND_EFI_PATH}
}
EOF

    sudo chmod +x "$GRUB_CUSTOM_FILE"
    log "DEBUG" "Set executable permissions on $GRUB_CUSTOM_FILE"

    # Step 3: Update GRUB config (non-interactive)
    log "INFO" "Generating new GRUB configuration"
    if sudo grub-mkconfig -o /boot/grub/grub.cfg; then
        log "INFO" "GRUB configuration updated successfully"
        echo -e "${GREEN}Success! Windows added to GRUB.${NC}"
        echo -e "${YELLOW}Reboot to see changes.${NC}"
        return 0
    else
        log "ERROR" "Failed to update GRUB configuration"
        echo -e "${RED}ERROR: GRUB configuration failed!${NC}"
        
        # Restore backup if available
        if [ -f "${GRUB_CUSTOM_FILE}.bak" ]; then
            sudo mv "${GRUB_CUSTOM_FILE}.bak" "$GRUB_CUSTOM_FILE"
            log "INFO" "Restored original GRUB custom file from backup"
        fi
        
        return 1
    fi
}