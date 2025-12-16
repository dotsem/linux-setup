#!/bin/bash
# Virtualization Setup Module
# Supports: KVM, QEMU, Virt-Manager

source "$(dirname "${BASH_SOURCE[0]}")/../helpers/ui.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../helpers/logging.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../vars.sh"

setup_virtualization() {
    section "VIRTUALIZATION SETUP" "$MAGENTA"
    log "INFO" "Setting up virtualization (KVM/QEMU)"
    
    # Check for virtualization support
    if ! grep -E -c '(vmx|svm)' /proc/cpuinfo > /dev/null; then
        log "WARN" "CPU does not support virtualization (VT-x/AMD-V missing)"
        echo -e "${YELLOW}Warning: Hardware virtualization not detected${NC}"
    fi

    case "$DETECTED_PKG_MANAGER" in
        pacman)
            sudo pacman -S --noconfirm qemu-full virt-manager virt-viewer dnsmasq vde2 bridge-utils openbsd-netcat iptables-nft ipset dmidecode 2>>"$LOG_FILE"
            ;;
        dnf)
            sudo dnf groupinstall -y "Virtualization" 2>>"$LOG_FILE"
            sudo dnf install -y virt-install virt-viewer 2>>"$LOG_FILE"
            ;;
        apt)
            sudo apt-get install -y qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils virt-manager 2>>"$LOG_FILE"
            ;;
    esac
    
    # Enable and start libvirtd
    log "INFO" "Enabling libvirtd service"
    sudo systemctl enable --now libvirtd 2>>"$LOG_FILE"
    
    # User configuration
    log "INFO" "Adding user to libvirt group"
    sudo usermod -aG libvirt "$USER" 2>>"$LOG_FILE"
    
    # Arch specific config
    if [ "$DETECTED_PKG_MANAGER" = "pacman" ]; then
        # Edit /etc/libvirt/libvirtd.conf to unleash unix_sock_group
        if [ -f "/etc/libvirt/libvirtd.conf" ]; then
            sudo sed -i 's/#unix_sock_group = "libvirt"/unix_sock_group = "libvirt"/' /etc/libvirt/libvirtd.conf
            sudo sed -i 's/#unix_sock_rw_perms = "0770"/unix_sock_rw_perms = "0770"/' /etc/libvirt/libvirtd.conf
            sudo systemctl restart libvirtd 2>>"$LOG_FILE"
        fi
    fi
    
    log "INFO" "Virtualization setup complete"
    echo -e "${GREEN}Virtualization stack installed & enabled!${NC}"
    echo -e "${YELLOW}Note: You may need to relogin for group changes to take effect.${NC}"
}
