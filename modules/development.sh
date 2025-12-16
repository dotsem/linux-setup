#!/bin/bash
# Development Environment Setup Module

source "$(dirname "${BASH_SOURCE[0]}")/../helpers/ui.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../helpers/logging.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../vars.sh"

setup_rust() {
    section "RUST DEVELOPMENT SETUP" "$YELLOW"
    log "INFO" "Setting up Rust development environment"
    
    if command -v rustc &>/dev/null; then
        log "INFO" "Rust already installed"
        echo -e "${GREEN}Rust already installed!${NC}"
        rustup update 2>>"$LOG_FILE"
        return 0
    fi
    
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y 2>>"$LOG_FILE"
    source "$HOME/.cargo/env"
    
    # Install all necessary components (equivalent to arch rust + rust-src)
    rustup component add rustfmt clippy rust-analyzer rust-src llvm-tools-preview 2>>"$LOG_FILE"
    
    # Install useful cargo tools
    cargo install cargo-edit cargo-watch sccache cargo-expand cargo-outdated 2>>"$LOG_FILE"
    
    log "INFO" "Rust development environment ready"
    echo -e "${GREEN}Rust development environment configured!${NC}"
}

setup_go() {
    section "GO DEVELOPMENT SETUP" "$CYAN"
    log "INFO" "Setting up Go development environment"
    
    if ! command -v go &>/dev/null; then
        log "ERROR" "Go not installed"
        echo -e "${RED}Go not found - install via package manager first${NC}"
        return 1
    fi
    
    mkdir -p "$HOME/go/{bin,src,pkg}"
    
    local shell_config="$HOME/.config/fish/conf.d/go.fish"
    mkdir -p "$(dirname "$shell_config")"
    if [ ! -f "$shell_config" ]; then
        cat > "$shell_config" << 'EOF'
# Go environment
set -gx GOPATH $HOME/go
fish_add_path $GOPATH/bin
EOF
    fi
    
    go install golang.org/x/tools/gopls@latest 2>>"$LOG_FILE"
    go install github.com/go-delve/delve/cmd/dlv@latest 2>>"$LOG_FILE"
    
    log "INFO" "Go development environment ready"
    echo -e "${GREEN}Go development environment configured!${NC}"
}

setup_node() {
    section "NODE.JS DEVELOPMENT SETUP" "$GREEN"
    log "INFO" "Setting up Node.js with PNPM"
    
    if ! command -v node &>/dev/null; then
        case "$DETECTED_PKG_MANAGER" in
            dnf)
                sudo dnf install -y nodejs npm 2>>"$LOG_FILE"
                ;;
            pacman)
                sudo pacman -S --noconfirm nodejs npm 2>>"$LOG_FILE"
                ;;
            apt)
                sudo apt-get install -y nodejs npm 2>>"$LOG_FILE"
                ;;
        esac
    fi
    
    if ! command -v pnpm &>/dev/null; then
        case "$DETECTED_PKG_MANAGER" in
            pacman)
                sudo pacman -S --noconfirm pnpm 2>>"$LOG_FILE"
                ;;
            *)
                npm install -g pnpm 2>>"$LOG_FILE"
                ;;
        esac
    fi
    
    pnpm setup 2>>"$LOG_FILE"
    
    log "INFO" "Node.js with PNPM ready"
    echo -e "${GREEN}Node.js with PNPM configured!${NC}"
}

setup_java() {
    section "JAVA DEVELOPMENT SETUP" "$RED"
    log "INFO" "Setting up Java JDK $JAVA_VERSION"
    
    if ! command -v java &>/dev/null; then
        log "INFO" "Java not found, installing..."
        case "$DETECTED_PKG_MANAGER" in
            dnf)
                sudo dnf install -y java-$JAVA_VERSION-openjdk-devel 2>>"$LOG_FILE"
                ;;
            pacman)
                sudo pacman -S --noconfirm jdk$JAVA_VERSION-openjdk 2>>"$LOG_FILE"
                ;;
            apt)
                sudo apt-get install -y openjdk-$JAVA_VERSION-jdk 2>>"$LOG_FILE"
                ;;
        esac
    fi
    
    if ! command -v java &>/dev/null; then
        log "ERROR" "Failed to install Java"
        return 1
    fi
    
    local java_home=""
    # Try to auto-detect JAVA_HOME
    if [ -d "/usr/lib/jvm/java-$JAVA_VERSION-openjdk" ]; then
        java_home="/usr/lib/jvm/java-$JAVA_VERSION-openjdk"
    elif [ -d "/usr/lib/jvm/java-${JAVA_VERSION}" ]; then
        java_home="/usr/lib/jvm/java-${JAVA_VERSION}"
    else
        # Fallback: find any java directory
        java_home=$(dirname $(dirname $(readlink -f $(which java)))) 2>/dev/null || true
    fi
    
    if [ -z "$java_home" ] || [ ! -d "$java_home" ]; then
        log "WARN" "Could not determine JAVA_HOME, using default"
        java_home="/usr/lib/jvm/default"
    fi
    
    local shell_config="$HOME/.config/fish/conf.d/java.fish"
    mkdir -p "$(dirname "$shell_config")"
    if [ ! -f "$shell_config" ]; then
        cat > "$shell_config" << EOF
# Java environment
set -gx JAVA_HOME $java_home
fish_add_path \$JAVA_HOME/bin
EOF
    fi
    
    log "INFO" "Java JDK configured (JAVA_HOME=$java_home)"
    echo -e "${GREEN}Java JDK configured!${NC}"
}

setup_php() {
    section "PHP DEVELOPMENT SETUP" "$BLUE"
    log "INFO" "Setting up PHP development environment"
    
    local xampp_url="https://sourceforge.net/projects/xampp/files/XAMPP%20Linux/8.2.12/xampp-linux-x64-8.2.12-0-installer.run/download"
    local xampp_installer="/tmp/xampp-installer.run"
    
    if [ -d "/opt/lampp" ]; then
        log "INFO" "XAMPP already installed"
        echo -e "${GREEN}XAMPP already installed!${NC}"
    else
        print_status info "Downloading XAMPP..."
        wget -O "$xampp_installer" "$xampp_url" 2>>"$LOG_FILE"
        chmod +x "$xampp_installer"
        
        print_status info "Installing XAMPP..."
        sudo "$xampp_installer" --mode unattended 2>>"$LOG_FILE"
        rm -f "$xampp_installer"
        
        echo -e "${GREEN}XAMPP installed!${NC}"
    fi
    
    if command -v docker &>/dev/null; then
        sudo usermod -aG docker "$USER" 2>>"$LOG_FILE"
        log "INFO" "Added user to docker group for Laravel Sail"
    fi
    
    log "INFO" "PHP development environment ready"
    echo -e "${GREEN}PHP development environment configured!${NC}"
}

setup_dotnet() {
    section "C# / .NET DEVELOPMENT SETUP" "$MAGENTA"
    log "INFO" "Setting up .NET SDK"
    
    if ! command -v dotnet &>/dev/null; then
        case "$DETECTED_PKG_MANAGER" in
            dnf)
                sudo dnf install -y dotnet-sdk-8.0 2>>"$LOG_FILE"
                ;;
            pacman)
                sudo pacman -S --noconfirm dotnet-sdk 2>>"$LOG_FILE"
                ;;
            apt)
                sudo apt-get install -y dotnet-sdk-8.0 2>>"$LOG_FILE"
                ;;
        esac
    fi
    
    local shell_config="$HOME/.config/fish/conf.d/dotnet.fish"
    mkdir -p "$(dirname "$shell_config")"
    if [ ! -f "$shell_config" ]; then
        cat > "$shell_config" << 'EOF'
# .NET environment
set -gx DOTNET_ROOT /usr/lib64/dotnet
fish_add_path $HOME/.dotnet/tools
EOF
    fi
    
    log "INFO" ".NET SDK ready"
    echo -e "${GREEN}.NET SDK configured!${NC}"
}

setup_docker() {
    section "DOCKER SETUP" "$CYAN"
    log "INFO" "Setting up Docker"
    
    case "$DETECTED_PKG_MANAGER" in
        dnf)
            sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo 2>>"$LOG_FILE"
            sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin 2>>"$LOG_FILE"
            ;;
        pacman)
            sudo pacman -S --noconfirm docker docker-compose 2>>"$LOG_FILE"
            ;;
        apt)
            curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg 2>>"$LOG_FILE"
            echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
            sudo apt-get update 2>>"$LOG_FILE"
            sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin 2>>"$LOG_FILE"
            ;;
    esac
    
    sudo systemctl enable --now docker 2>>"$LOG_FILE"
    sudo usermod -aG docker "$USER" 2>>"$LOG_FILE"
    
    log "INFO" "Docker configured"
    echo -e "${GREEN}Docker configured!${NC}"
    echo -e "${YELLOW}Note: Log out and back in for docker group to take effect${NC}"
}

setup_all_development() {
    section "DEVELOPMENT ENVIRONMENT SETUP" "$BLUE"
    
    setup_node
    setup_go
    setup_rust
    setup_java
    setup_php
    setup_dotnet
    setup_docker
    
    log "INFO" "All development environments configured"
    echo -e "${GREEN}All development environments ready!${NC}"
}
