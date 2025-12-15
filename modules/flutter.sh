#!/bin/bash
# Flutter & Android Development Setup Module
# Supports: Android SDK without Android Studio, AVD (Android Virtual Device)

source "$(dirname "${BASH_SOURCE[0]}")/../helpers/ui.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../helpers/logging.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../vars.sh"

ANDROID_SDK_ROOT="$HOME/Android/Sdk"
ANDROID_CMDLINE_TOOLS_URL="https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip"

setup_virtualization() {
    section "VIRTUALIZATION SETUP (KVM)" "$GREEN"
    log "INFO" "Setting up virtualization for Android emulator"
    
    case "$DETECTED_PKG_MANAGER" in
        dnf)
            sudo -n dnf install -y @virtualization qemu-kvm libvirt virt-manager bridge-utils 2>>"$LOG_FILE"
            ;;
        pacman)
            sudo -n pacman -S --noconfirm qemu-full libvirt virt-manager dnsmasq bridge-utils edk2-ovmf 2>>"$LOG_FILE"
            ;;
        apt)
            sudo -n apt-get install -y qemu-kvm libvirt-daemon-system virt-manager bridge-utils 2>>"$LOG_FILE"
            ;;
    esac
    
    sudo -n systemctl enable --now libvirtd 2>>"$LOG_FILE"
    sudo -n usermod -aG libvirt "$USER" 2>>"$LOG_FILE"
    sudo -n usermod -aG kvm "$USER" 2>>"$LOG_FILE"
    
    if [ ! -c /dev/kvm ]; then
        log "WARN" "KVM not available - check BIOS virtualization settings"
        echo -e "${YELLOW}Warning: KVM not available. Enable VT-x/AMD-V in BIOS.${NC}"
    else
        log "INFO" "KVM is available"
        echo -e "${GREEN}KVM virtualization ready!${NC}"
    fi
}

setup_android_sdk() {
    section "ANDROID SDK SETUP (No Android Studio)" "$GREEN"
    log "INFO" "Setting up Android SDK via command-line tools"
    
    mkdir -p "$ANDROID_SDK_ROOT/cmdline-tools"
    
    local tools_zip="/tmp/cmdline-tools.zip"
    if [ ! -d "$ANDROID_SDK_ROOT/cmdline-tools/latest" ]; then
        print_status info "Downloading Android command-line tools..."
        wget -O "$tools_zip" "$ANDROID_CMDLINE_TOOLS_URL" 2>>"$LOG_FILE"
        
        unzip -o "$tools_zip" -d "/tmp" 2>>"$LOG_FILE"
        mv /tmp/cmdline-tools "$ANDROID_SDK_ROOT/cmdline-tools/latest"
        rm -f "$tools_zip"
        
        log "INFO" "Android command-line tools installed"
    fi
    
    export PATH="$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:$ANDROID_SDK_ROOT/platform-tools:$ANDROID_SDK_ROOT/emulator:$PATH"
    export ANDROID_HOME="$ANDROID_SDK_ROOT"
    export ANDROID_SDK_ROOT="$ANDROID_SDK_ROOT"
    
    print_status info "Accepting Android SDK licenses..."
    yes | sdkmanager --licenses 2>>"$LOG_FILE" || true
    
    print_status info "Installing Android SDK components..."
    sdkmanager "platform-tools" 2>>"$LOG_FILE"
    sdkmanager "platforms;android-34" 2>>"$LOG_FILE"
    sdkmanager "build-tools;34.0.0" 2>>"$LOG_FILE"
    sdkmanager "emulator" 2>>"$LOG_FILE"
    sdkmanager "system-images;android-34;google_apis;x86_64" 2>>"$LOG_FILE"
    
    log "INFO" "Android SDK installed successfully"
    echo -e "${GREEN}Android SDK ready!${NC}"
}

setup_android_avd() {
    section "ANDROID VIRTUAL DEVICE (AVD) SETUP" "$CYAN"
    log "INFO" "Creating Android Virtual Device"
    
    export PATH="$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:$ANDROID_SDK_ROOT/platform-tools:$ANDROID_SDK_ROOT/emulator:$PATH"
    export ANDROID_HOME="$ANDROID_SDK_ROOT"
    
    if avdmanager list avd 2>/dev/null | grep -q "flutter_emulator"; then
        log "INFO" "AVD 'flutter_emulator' already exists"
        echo -e "${GREEN}AVD 'flutter_emulator' already exists!${NC}"
        return 0
    fi
    
    print_status info "Creating AVD 'flutter_emulator'..."
    echo "no" | avdmanager create avd \
        -n "flutter_emulator" \
        -k "system-images;android-34;google_apis;x86_64" \
        -d "pixel_6" \
        --force 2>>"$LOG_FILE"
    
    if avdmanager list avd 2>/dev/null | grep -q "flutter_emulator"; then
        log "INFO" "AVD created successfully"
        echo -e "${GREEN}AVD 'flutter_emulator' created!${NC}"
        echo -e "${YELLOW}Run 'emulator -avd flutter_emulator' to start the emulator${NC}"
    else
        log "ERROR" "Failed to create AVD"
        echo -e "${RED}Failed to create AVD${NC}"
        return 1
    fi
}

setup_flutter_sdk() {
    section "FLUTTER SDK SETUP" "$CYAN"
    log "INFO" "Setting up Flutter SDK"
    
    local flutter_dir="$HOME/.local/share/flutter"
    
    if [ -d "$flutter_dir" ]; then
        log "INFO" "Flutter already installed, updating..."
        cd "$flutter_dir"
        git pull 2>>"$LOG_FILE"
        cd - >/dev/null
    else
        print_status info "Cloning Flutter SDK..."
        git clone https://github.com/flutter/flutter.git -b "$FLUTTER_CHANNEL" "$flutter_dir" 2>>"$LOG_FILE"
    fi
    
    export PATH="$flutter_dir/bin:$PATH"
    
    flutter precache 2>>"$LOG_FILE"
    
    log "INFO" "Flutter SDK installed"
    echo -e "${GREEN}Flutter SDK installed!${NC}"
}

setup_flutter_shell_config() {
    local shell_config="$HOME/.config/fish/conf.d/flutter.fish"
    mkdir -p "$(dirname "$shell_config")"
    
    if [ ! -f "$shell_config" ]; then
        cat > "$shell_config" << 'EOF'
# Android SDK
set -gx ANDROID_HOME $HOME/Android/Sdk
set -gx ANDROID_SDK_ROOT $ANDROID_HOME
fish_add_path $ANDROID_HOME/cmdline-tools/latest/bin
fish_add_path $ANDROID_HOME/platform-tools
fish_add_path $ANDROID_HOME/emulator

# Flutter
fish_add_path $HOME/.local/share/flutter/bin
EOF
        log "INFO" "Added Android/Flutter to shell config"
    fi
}

setup_flutter_environment() {
    section "FLUTTER ENVIRONMENT SETUP" "$MAGENTA"
    log "INFO" "Setting up complete Flutter development environment"
    
    setup_virtualization
    setup_android_sdk
    setup_android_avd
    setup_flutter_sdk
    setup_flutter_shell_config
    
    export PATH="$HOME/.local/share/flutter/bin:$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:$ANDROID_SDK_ROOT/platform-tools:$ANDROID_SDK_ROOT/emulator:$PATH"
    export ANDROID_HOME="$ANDROID_SDK_ROOT"
    
    print_status info "Accepting Flutter/Android licenses..."
    yes | flutter doctor --android-licenses 2>>"$LOG_FILE" || true
    
    print_status info "Running Flutter doctor..."
    flutter doctor -v 2>&1 | tee -a "$LOG_FILE"
    
    log "INFO" "Flutter environment setup completed"
    echo -e "${GREEN}Flutter environment ready!${NC}"
    echo -e "${YELLOW}Commands available after logout/login:${NC}"
    echo -e "  ${BLUE}flutter doctor${NC} - Check Flutter installation"
    echo -e "  ${BLUE}emulator -avd flutter_emulator${NC} - Start Android emulator"
    echo -e "  ${BLUE}virt-manager${NC} - Virtual Machine Manager GUI"
}

setup_kolibri_shell() {
    section "KOLIBRI SHELL SETUP" "$MAGENTA"
    log "INFO" "Setting up Kolibri Shell taskbar"
    
    local kolibri_dir="$HOME/.local/share/kolibri-shell"
    local kolibri_repo="https://github.com/dotsem/kolibri-shell.git"
    
    if ! command -v flutter &>/dev/null; then
        log "ERROR" "Flutter is required for Kolibri Shell"
        print_status error "Flutter not available - install Flutter first"
        return 1
    fi
    
    if [ -d "$kolibri_dir" ]; then
        log "INFO" "Kolibri Shell already exists, updating..."
        print_status info "Updating Kolibri Shell..."
        cd "$kolibri_dir"
        if git pull origin main 2>>"$LOG_FILE"; then
            log "INFO" "Kolibri Shell updated"
        else
            log "WARN" "Failed to update Kolibri Shell"
            cd - > /dev/null
            return 1
        fi
        cd - > /dev/null
    else
        log "INFO" "Cloning Kolibri Shell from $kolibri_repo"
        print_status info "Cloning Kolibri Shell..."
        
        mkdir -p "$(dirname "$kolibri_dir")"
        if git clone "$kolibri_repo" "$kolibri_dir" 2>>"$LOG_FILE"; then
            log "INFO" "Kolibri Shell cloned successfully"
            print_status success "Kolibri Shell cloned"
        else
            log "ERROR" "Failed to clone Kolibri Shell"
            print_status error "Failed to clone Kolibri Shell"
            return 1
        fi
    fi
    
    log "INFO" "Building Kolibri Shell (this may take a while)..."
    print_status info "Building Kolibri Shell... (please wait)"
    
    cd "$kolibri_dir"
    if flutter pub get 2>>"$LOG_FILE" && \
       flutter build linux --release 2>>"$LOG_FILE"; then
        log "INFO" "Kolibri Shell built successfully"
        print_status success "Kolibri Shell built successfully"
        
        local bin_dir="$HOME/.local/bin"
        mkdir -p "$bin_dir"
        
        local executable="$kolibri_dir/build/linux/x64/release/bundle/kolibri_shell"
        local symlink="$bin_dir/kolibri-shell"
        
        if [ -f "$executable" ]; then
            ln -sf "$executable" "$symlink"
            log "INFO" "Created symlink at $symlink"
            print_status success "Kolibri Shell ready to use"
            echo -e "${GREEN}Run 'kolibri-shell' to start the taskbar${NC}"
        else
            log "ERROR" "Executable not found at expected location"
            print_status error "Build completed but executable not found"
            cd - >/dev/null
            return 1
        fi
        
        cd - >/dev/null
        return 0
    else
        log "ERROR" "Failed to build Kolibri Shell"
        print_status error "Build failed"
        cd - >/dev/null
        return 1
    fi
}
