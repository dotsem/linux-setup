#!/bin/bash
# Python Environment Module
# Multi-distro support

source "$(dirname "${BASH_SOURCE[0]}")/../helpers/ui.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../helpers/logging.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../vars.sh"

setup_python_environment() {
    section "Python Environment Setup" "$YELLOW"
    
    check_python_installed() {
        if ! command -v python3 &> /dev/null; then
            log "ERROR" "Python3 is not installed"
            echo -e "${RED}Error: Python3 is not installed${NC}"
            return 1
        fi
        
        local python_version=$(python3 --version 2>&1 | awk '{print $2}')
        log "INFO" "Found Python version $python_version"
        echo -e "${GREEN}Python $python_version detected${NC}"
        return 0
    }

    ensure_pip() {
        if python3 -m pip --version &> /dev/null; then
            log "INFO" "pip is available"
            return 0
        fi
        
        log "INFO" "Installing pip..."
        case "$DETECTED_PKG_MANAGER" in
            pacman)
                sudo pacman -S --noconfirm python-pip 2>>"$LOG_FILE"
                ;;
            dnf)
                sudo dnf install -y python3-pip 2>>"$LOG_FILE"
                ;;
            apt)
                sudo apt-get install -y python3-pip 2>>"$LOG_FILE"
                ;;
        esac
    }

    install_tkinter() {
        if python3 -c "import tkinter" &> /dev/null; then
            log "INFO" "tkinter is already available"
            return 0
        fi

        log "INFO" "Installing tkinter"
        case "$DETECTED_PKG_MANAGER" in
            pacman)
                sudo pacman -S --noconfirm tk 2>>"$LOG_FILE"
                ;;
            dnf)
                sudo dnf install -y python3-tkinter 2>>"$LOG_FILE"
                ;;
            apt)
                sudo apt-get install -y python3-tk 2>>"$LOG_FILE"
                ;;
        esac

        if python3 -c "import tkinter" &> /dev/null; then
            log "INFO" "tkinter installed successfully"
            echo -e "${GREEN}tkinter installed!${NC}"
            return 0
        else
            log "WARN" "Failed to install tkinter"
            return 1
        fi
    }

    test_python() {
        log "INFO" "Testing basic Python functionality"
        
        if ! python3 -c "print('Python test successful')"; then
            log "ERROR" "Basic Python test failed"
            return 1
        fi

        if ! python3 -m pip --version; then
            log "ERROR" "Pip test failed"
            return 1
        fi

        log "INFO" "Python tests passed"
        echo -e "${GREEN}Python basic tests passed!${NC}"
        return 0
    }

    test_venv() {
        local test_dir=$(mktemp -d)
        log "INFO" "Testing virtual environment creation"
        
        if python3 -m venv "$test_dir/test_venv"; then
            if source "$test_dir/test_venv/bin/activate"; then
                deactivate
                rm -rf "$test_dir"
                echo -e "${GREEN}Virtual environment test passed!${NC}"
                return 0
            fi
        fi
        
        rm -rf "$test_dir"
        echo -e "${YELLOW}Virtual environment test failed${NC}"
        return 1
    }

    local overall_success=0
    
    check_python_installed || overall_success=1
    ensure_pip || overall_success=1
    install_tkinter || overall_success=1
    test_python || overall_success=1
    test_venv || overall_success=1
    
    if [ "$overall_success" -eq 0 ]; then
        log "INFO" "Python environment setup completed successfully"
        echo -e "\n${GREEN}Python environment is ready!${NC}"
    else
        log "WARN" "Python environment setup encountered issues"
        echo -e "\n${YELLOW}Python setup completed with some warnings${NC}"
    fi
    
    return $overall_success
}