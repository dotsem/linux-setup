#!/bin/bash
# Pre-installation system requirements checker

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

CHECKS_PASSED=0
CHECKS_FAILED=0
WARNINGS=0

print_check() {
    local status="$1"
    local message="$2"
    
    case "$status" in
        pass)
            echo -e "${GREEN}✓${NC} $message"
            ((CHECKS_PASSED++))
            ;;
        fail)
            echo -e "${RED}✗${NC} $message"
            ((CHECKS_FAILED++))
            ;;
        warn)
            echo -e "${YELLOW}⚠${NC} $message"
            ((WARNINGS++))
            ;;
        info)
            echo -e "${BLUE}ℹ${NC} $message"
            ;;
    esac
}

echo -e "${BLUE}╔═══════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                                                   ║${NC}"
echo -e "${BLUE}║     ARCH LINUX SETUP - REQUIREMENTS CHECK        ║${NC}"
echo -e "${BLUE}║                                                   ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════╝${NC}\n"

# Check 1: Running on Arch-based system
echo -e "${YELLOW}Checking system...${NC}"
if [ -f /etc/arch-release ] || grep -qi "arch\|manjaro" /etc/os-release 2>/dev/null; then
    distro=$(grep "^ID=" /etc/os-release | cut -d= -f2 | tr -d '"')
    print_check "pass" "Running on Arch-based system ($distro)"
else
    print_check "fail" "Not running on an Arch-based system"
fi

# Check 2: Not running as root
if [ "$(id -u)" -eq 0 ]; then
    print_check "fail" "Do not run as root (use a regular user with sudo)"
else
    print_check "pass" "Running as regular user ($(whoami))"
fi

# Check 3: Sudo access
if sudo -n true 2>/dev/null; then
    print_check "pass" "Sudo access available (cached)"
elif sudo -v 2>/dev/null; then
    print_check "pass" "Sudo access available"
else
    print_check "fail" "No sudo access"
fi

# Check 4: Internet connectivity
echo -e "\n${YELLOW}Checking network...${NC}"
if ping -c 1 -W 5 archlinux.org &>/dev/null; then
    print_check "pass" "Internet connectivity working"
else
    print_check "fail" "No internet connectivity"
fi

# Check 5: DNS resolution
if nslookup archlinux.org &>/dev/null; then
    print_check "pass" "DNS resolution working"
else
    print_check "warn" "DNS resolution issues detected"
fi

# Check 6: Pacman availability
echo -e "\n${YELLOW}Checking package management...${NC}"
if command -v pacman &>/dev/null; then
    print_check "pass" "Pacman available"
    
    # Check pacman lock
    if sudo -n fuser /var/lib/pacman/db.lck &>/dev/null; then
        print_check "fail" "Pacman database is locked (another process running)"
    else
        print_check "pass" "Pacman database not locked"
    fi
else
    print_check "fail" "Pacman not found"
fi

# Check 7: Disk space
echo -e "\n${YELLOW}Checking disk space...${NC}"
avail_gb=$(df -BG --output=avail "$HOME" | tail -1 | tr -d 'G')
if [ "$avail_gb" -ge 10 ]; then
    print_check "pass" "Sufficient disk space (${avail_gb}GB available)"
elif [ "$avail_gb" -ge 5 ]; then
    print_check "warn" "Limited disk space (${avail_gb}GB available, 10GB+ recommended)"
else
    print_check "fail" "Insufficient disk space (${avail_gb}GB available, minimum 5GB required)"
fi

# Check 8: Memory
echo -e "\n${YELLOW}Checking system resources...${NC}"
mem_gb=$(free -g | awk '/Mem:/ {print $2}')
if [ "$mem_gb" -ge 4 ]; then
    print_check "pass" "Sufficient memory (${mem_gb}GB RAM)"
elif [ "$mem_gb" -ge 2 ]; then
    print_check "warn" "Limited memory (${mem_gb}GB RAM, 4GB+ recommended)"
else
    print_check "warn" "Low memory (${mem_gb}GB RAM)"
fi

# Check 9: CPU cores
cpu_cores=$(nproc)
if [ "$cpu_cores" -ge 4 ]; then
    print_check "pass" "Good CPU (${cpu_cores} cores)"
elif [ "$cpu_cores" -ge 2 ]; then
    print_check "warn" "Limited CPU (${cpu_cores} cores, 4+ recommended for faster builds)"
else
    print_check "warn" "Single core CPU (compilation will be slow)"
fi

# Check 10: Essential commands
echo -e "\n${YELLOW}Checking required tools...${NC}"
required_cmds=("git" "curl" "wget" "base-devel")
for cmd in git curl wget; do
    if command -v "$cmd" &>/dev/null; then
        print_check "pass" "$cmd is installed"
    else
        print_check "warn" "$cmd not installed (will be installed)"
    fi
done

# Check base-devel
if pacman -Qg base-devel &>/dev/null; then
    print_check "pass" "base-devel group installed"
else
    print_check "warn" "base-devel not installed (required for AUR, will be installed)"
fi

# Check 11: Git configuration
echo -e "\n${YELLOW}Checking configuration...${NC}"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$script_dir/vars.sh" ]; then
    print_check "pass" "Configuration file (vars.sh) exists"
    
    source "$script_dir/vars.sh" 2>/dev/null
    
    if [ -n "$GIT_NAME" ] && [ -n "$GIT_EMAIL" ]; then
        print_check "pass" "Git credentials configured"
        print_check "info" "  Name: $GIT_NAME"
        print_check "info" "  Email: $GIT_EMAIL"
    else
        print_check "warn" "Git credentials not configured in vars.sh"
    fi
    
    if [ -n "$DOTFILES_URL" ]; then
        print_check "info" "Dotfiles URL: $DOTFILES_URL"
    else
        print_check "info" "No dotfiles URL configured (optional)"
    fi
else
    print_check "warn" "Configuration file (vars.sh) not found"
fi

# Check 12: GPU Detection
echo -e "\n${YELLOW}Checking hardware...${NC}"
if lspci | grep -qi nvidia; then
    print_check "info" "NVIDIA GPU detected (drivers will be installed)"
elif lspci | grep -qi amd; then
    print_check "info" "AMD GPU detected"
elif lspci | grep -qi intel; then
    print_check "info" "Intel GPU detected"
else
    print_check "info" "GPU not detected or unknown"
fi

# Summary
echo -e "\n${BLUE}═══════════════════════════════════════════════════${NC}"
echo -e "${GREEN}Passed:${NC} $CHECKS_PASSED"
echo -e "${YELLOW}Warnings:${NC} $WARNINGS"
echo -e "${RED}Failed:${NC} $CHECKS_FAILED"
echo -e "${BLUE}═══════════════════════════════════════════════════${NC}\n"

if [ $CHECKS_FAILED -gt 0 ]; then
    echo -e "${RED}⚠ Critical issues detected!${NC}"
    echo -e "Please fix the failed checks before running installation.\n"
    exit 1
elif [ $WARNINGS -gt 0 ]; then
    echo -e "${YELLOW}⚠ Warnings detected!${NC}"
    echo -e "Installation can proceed but some issues should be addressed.\n"
    exit 0
else
    echo -e "${GREEN}✓ All checks passed!${NC}"
    echo -e "Your system is ready for installation.\n"
    echo -e "Run ${BLUE}./setup-menu.sh${NC} or ${BLUE}./install-essential.sh${NC} to begin.\n"
    exit 0
fi
