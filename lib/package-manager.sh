#!/bin/bash
# Multi-Distro Package Management
# Supports: pacman/yay (Arch), dnf (Fedora), apt (Debian/Ubuntu)

source "$(dirname "${BASH_SOURCE[0]}")/../helpers/ui.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../helpers/logging.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../vars.sh"

install_package() {
    local installer="$1"
    local package="$2"
    local max_attempts="${3:-2}"

    for attempt in $(seq 1 $max_attempts); do
        log "INFO" "Installation attempt $attempt/$max_attempts for $package"

        case $installer in
            pacman)
                if sudo pacman -S --noconfirm --needed "$package" 2>>"$LOG_FILE"; then
                    log "INFO" "Successfully installed $package via pacman"
                    return 0
                fi
                ;;
            yay)
                if yay -S --noconfirm --needed --sudoloop "$package" 2>>"$LOG_FILE"; then
                    log "INFO" "Successfully installed $package via yay"
                    return 0
                fi
                ;;
            dnf)
                if sudo dnf install -y "$package" 2>>"$LOG_FILE"; then
                    log "INFO" "Successfully installed $package via dnf"
                    return 0
                fi
                ;;
            apt)
                if sudo apt-get install -y "$package" 2>>"$LOG_FILE"; then
                    log "INFO" "Successfully installed $package via apt"
                    return 0
                fi
                ;;
            flatpak)
                if flatpak install -y flathub "$package" 2>>"$LOG_FILE"; then
                    log "INFO" "Successfully installed $package via Flatpak"
                    return 0
                fi
                ;;
            copr)
                local repo="${package%%/*}"
                local pkg="${package##*/}"
                if sudo dnf copr enable -y "$repo" 2>>"$LOG_FILE" && \
                   sudo dnf install -y "$pkg" 2>>"$LOG_FILE"; then
                    log "INFO" "Successfully installed $pkg from COPR $repo"
                    return 0
                fi
                ;;
            ppa)
                local repo="${package%%/*}"
                local pkg="${package##*/}"
                if sudo add-apt-repository -y "ppa:$repo" 2>>"$LOG_FILE" && \
                   sudo apt-get update 2>>"$LOG_FILE" && \
                   sudo apt-get install -y "$pkg" 2>>"$LOG_FILE"; then
                    log "INFO" "Successfully installed $pkg from PPA $repo"
                    return 0
                fi
                ;;
        esac
        
        log "WARN" "Attempt $attempt failed for $package"
        [ $attempt -lt $max_attempts ] && sleep 2
    done

    log "ERROR" "All installation attempts failed for $package"
    return 1
}

install_yay() {
    [ "$DETECTED_PKG_MANAGER" != "pacman" ] && return 0
    
    section "Installing YAY AUR Helper" "$GREEN"
    log "INFO" "Starting YAY installation"

    if command -v yay &>/dev/null; then
        log "INFO" "YAY already installed"
        echo -e "${GREEN}Yay already installed!${NC}"
        return 0
    fi

    log "DEBUG" "Installing YAY dependencies"
    sudo pacman -S --needed --noconfirm git base-devel || {
        log "ERROR" "Failed to install YAY dependencies"
        return 1
    }

    rm -rf /tmp/yay
    log "INFO" "Cloning YAY repository"
    
    if ! git clone https://aur.archlinux.org/yay.git /tmp/yay 2>>"$LOG_FILE"; then
        log "ERROR" "Failed to clone YAY repo"
        return 1
    fi

    cd /tmp/yay
    
    if [ "$(id -u)" -eq 0 ]; then
        log "ERROR" "makepkg should NOT be run as root"
        cd - >/dev/null
        return 1
    fi

    log "INFO" "Building YAY package"
    if makepkg -s --noconfirm 2>>"$LOG_FILE"; then
        local pkg_file=$(ls -1 yay-*.pkg.tar.zst 2>/dev/null | head -1)
        if [ -z "$pkg_file" ]; then
            pkg_file=$(ls -1 yay-*.pkg.tar.xz 2>/dev/null | head -1)
        fi
        
        if [ -n "$pkg_file" ] && sudo pacman -U --noconfirm "$pkg_file" 2>>"$LOG_FILE"; then
            cd - >/dev/null
            log "INFO" "YAY installed successfully"
            echo -e "${GREEN}Yay installed successfully!${NC}"
            return 0
        else
            log "ERROR" "YAY package installation failed"
            cd - >/dev/null
            return 1
        fi
    else
        log "ERROR" "YAY build failed"
        cd - >/dev/null
        return 1
    fi
}

setup_rpm_fusion() {
    [ "$DETECTED_PKG_MANAGER" != "dnf" ] && return 0
    
    section "Enabling RPM Fusion" "$GREEN"
    log "INFO" "Setting up RPM Fusion repositories"
    
    local fedora_version=$(rpm -E %fedora)
    
    sudo dnf install -y \
        "https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-${fedora_version}.noarch.rpm" \
        "https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${fedora_version}.noarch.rpm" \
        2>>"$LOG_FILE"
    
    sudo dnf groupupdate -y core 2>>"$LOG_FILE"
    
    log "INFO" "RPM Fusion enabled"
    echo -e "${GREEN}RPM Fusion enabled!${NC}"
}

setup_flatpak() {
    section "Setting up Flatpak" "$BLUE"
    log "INFO" "Installing Flatpak if missing"
    
    case "$DETECTED_PKG_MANAGER" in
        pacman)
            sudo pacman -S --needed --noconfirm flatpak || {
                log "ERROR" "Failed to install Flatpak"
                return 1
            }
            ;;
        dnf)
            sudo dnf install -y flatpak || {
                log "ERROR" "Failed to install Flatpak"
                return 1
            }
            ;;
        apt)
            sudo apt-get install -y flatpak || {
                log "ERROR" "Failed to install Flatpak"
                return 1
            }
            ;;
    esac

    if ! flatpak remotes | grep -q flathub; then
        log "INFO" "Adding Flathub remote"
        flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
        echo -e "${GREEN}Flathub remote added!${NC}"
    else
        log "INFO" "Flathub already configured"
        echo -e "${GREEN}Flathub already configured!${NC}"
    fi
    
    return 0
}

install_package_array() {
    local installer="$1"
    shift
    local packages=("$@")
    local failed=0
    local failed_packages=()
    
    for pkg in "${packages[@]}"; do
        if ! install_package "$installer" "$pkg"; then
            ((failed++))
            failed_packages+=("$pkg")
        fi
    done
    
    if [ $failed -gt 0 ]; then
        log "WARN" "$failed packages failed to install via $installer"
        return 1
    fi
    
    return 0
}

detect_and_add_nvidia() {
    local -n pkg_array=$1
    
    if lspci | grep -qi nvidia; then
        log "INFO" "NVIDIA GPU detected, adding drivers"
        
        local has_nvidia=false
        for pkg in "${pkg_array[@]}"; do
            if [[ "$pkg" == *"nvidia"* ]]; then
                has_nvidia=true
                break
            fi
        done
        
        if ! $has_nvidia; then
            case "$DETECTED_PKG_MANAGER" in
                pacman)
                    pkg_array+=(nvidia nvidia-utils nvidia-settings)
                    ;;
                dnf)
                    pkg_array+=(akmod-nvidia xorg-x11-drv-nvidia-cuda nvidia-settings)
                    ;;
                apt)
                    pkg_array+=(nvidia-driver nvidia-settings)
                    ;;
            esac
            log "INFO" "Added NVIDIA packages to installation list"
        fi
    fi
}

is_hybrid_gpu() {
    local nvidia_count=$(lspci | grep -ci 'nvidia')
    local intel_count=$(lspci | grep -ci 'intel.*graphics\|intel.*vga')
    local amd_count=$(lspci | grep -ci 'amd.*graphics\|radeon')
    
    if [ "$nvidia_count" -gt 0 ] && [ $((intel_count + amd_count)) -gt 0 ]; then
        return 0
    fi
    return 1
}

system_update() {
    section "System Update" "$GREEN"
    log "INFO" "Updating system packages"
    
    case "$DETECTED_PKG_MANAGER" in
        pacman)
            if command -v pacman-mirrors &>/dev/null; then
                sudo pacman-mirrors --fasttrack 2>>"$LOG_FILE" || true
            fi
            sudo pacman -Syy 2>>"$LOG_FILE"
            sudo pacman -Syu --noconfirm 2>>"$LOG_FILE"
            ;;
        dnf)
            sudo dnf check-update 2>>"$LOG_FILE" || true
            sudo dnf upgrade -y 2>>"$LOG_FILE"
            ;;
        apt)
            sudo apt-get update 2>>"$LOG_FILE"
            sudo apt-get upgrade -y 2>>"$LOG_FILE"
            ;;
    esac
    
    echo -e "${GREEN}System updated!${NC}"
}

get_native_installer() {
    case "$DETECTED_PKG_MANAGER" in
        pacman) echo "pacman" ;;
        dnf) echo "dnf" ;;
        apt) echo "apt" ;;
        *) echo "unknown" ;;
    esac
}

get_aur_installer() {
    case "$DETECTED_PKG_MANAGER" in
        pacman) echo "yay" ;;
        dnf) echo "copr" ;;
        apt) echo "ppa" ;;
        *) echo "unknown" ;;
    esac
}
