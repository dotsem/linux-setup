#!/bin/bash
# Installation wrapper script - Multi-distro support

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/vars.sh"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

show_menu() {
    clear
    echo -e "${BLUE}╔═══════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║                                                   ║${NC}"
    echo -e "${BLUE}║           LINUX SYSTEM SETUP                      ║${NC}"
    echo -e "${BLUE}║                                                   ║${NC}"
    echo -e "${BLUE}║   Multi-distro: Arch, Fedora, Debian/Ubuntu       ║${NC}"
    echo -e "${BLUE}║                                                   ║${NC}"
    echo -e "${BLUE}╚═══════════════════════════════════════════════════╝${NC}\n"
    
    echo -e "${CYAN}Detected: ${GREEN}$DETECTED_DISTRO_NAME${NC} (${DETECTED_PKG_MANAGER})\n"
    
    echo -e "${CYAN}What would you like to do?${NC}\n"
    echo -e "  ${GREEN}1)${NC} Fresh Installation (Recommended)"
    echo -e "     → Install essential packages only"
    echo -e "     → Fast and reliable"
    echo -e "     → Can add more later with apres-setup\n"
    
    echo -e "  ${GREEN}2)${NC} Continue/Resume Non-Essential Installation"
    echo -e "     → Install optional packages"
    echo -e "     → Can pause and resume anytime\n"
    
    echo -e "  ${GREEN}3)${NC} System Test"
    echo -e "     → Validate your system configuration"
    echo -e "     → Check if everything works\n"
    
    echo -e "  ${GREEN}4)${NC} Check Installation Status"
    echo -e "     → View installation progress\n"
    
    echo -e "  ${GREEN}5)${NC} Development Environment Setup"
    echo -e "     → Setup Flutter, Node, Rust, Go, etc.\n"
    
    echo -e "  ${GREEN}6)${NC} View Documentation"
    echo -e "     → README, Migration Guide, etc.\n"
    
    echo -e "  ${GREEN}q)${NC} Quit\n"
    
    echo -ne "${YELLOW}Enter your choice:${NC} "
}

fresh_installation() {
    echo -e "\n${BLUE}Starting fresh installation...${NC}\n"
    
    if [ ! -f "$SCRIPT_DIR/install-essential.sh" ]; then
        echo -e "${RED}Error: install-essential.sh not found!${NC}"
        return 1
    fi
    
    bash "$SCRIPT_DIR/install-essential.sh"
}

resume_nonessential() {
    echo -e "\n${BLUE}Starting/resuming non-essential installation...${NC}\n"
    
    if [ ! -f "$SCRIPT_DIR/bin/apres-setup" ]; then
        echo -e "${RED}Error: apres-setup not found!${NC}"
        return 1
    fi
    
    bash "$SCRIPT_DIR/bin/apres-setup" start
}

system_test() {
    echo -e "\n${BLUE}Running system tests...${NC}\n"
    
    if [ ! -f "$SCRIPT_DIR/bin/sysunit" ]; then
        echo -e "${RED}Error: sysunit not found!${NC}"
        return 1
    fi
    
    bash "$SCRIPT_DIR/bin/sysunit"
}

check_status() {
    echo -e "\n${BLUE}Checking installation status...${NC}\n"
    
    echo -e "${CYAN}Detected distro:${NC} $DETECTED_DISTRO_NAME"
    echo -e "${CYAN}Package manager:${NC} $DETECTED_PKG_MANAGER\n"
    
    if [ -f "$HOME/arch_setup.log" ]; then
        echo -e "${GREEN}✓${NC} Installation log exists"
        local log_size=$(du -h "$HOME/arch_setup.log" | cut -f1)
        echo -e "  Log size: $log_size"
    else
        echo -e "${YELLOW}⚠${NC} No installation log found"
    fi
    
    echo ""
    
    if [ -f "$SCRIPT_DIR/bin/apres-setup" ]; then
        bash "$SCRIPT_DIR/bin/apres-setup" status
    fi
    
    echo ""
    
    if command -v sysunit &>/dev/null || [ -f "$SCRIPT_DIR/bin/sysunit" ]; then
        echo -e "${GREEN}✓${NC} System test tool (sysunit) available"
    fi
}

development_setup() {
    echo -e "\n${BLUE}Development Environment Setup${NC}\n"
    
    source "$SCRIPT_DIR/modules/development.sh"
    source "$SCRIPT_DIR/modules/flutter.sh"
    
    echo -e "  ${GREEN}1)${NC} All development tools"
    echo -e "  ${GREEN}2)${NC} Flutter + Android SDK only"
    echo -e "  ${GREEN}3)${NC} Node.js + PNPM only"
    echo -e "  ${GREEN}4)${NC} Rust only"
    echo -e "  ${GREEN}5)${NC} Go only"
    echo -e "  ${GREEN}6)${NC} Back to main menu\n"
    
    echo -ne "${YELLOW}Enter your choice:${NC} "
    read -r dev_choice
    
    case $dev_choice in
        1) setup_all_development && setup_flutter_environment ;;
        2) setup_flutter_environment ;;
        3) setup_node ;;
        4) setup_rust ;;
        5) setup_go ;;
        6) return ;;
        *) echo -e "${RED}Invalid choice${NC}" ;;
    esac
}

view_docs() {
    clear
    echo -e "${BLUE}╔═══════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║              DOCUMENTATION                        ║${NC}"
    echo -e "${BLUE}╚═══════════════════════════════════════════════════╝${NC}\n"
    
    echo -e "${CYAN}Available documentation:${NC}\n"
    echo -e "  ${GREEN}1)${NC} README.md - Main documentation"
    echo -e "  ${GREEN}2)${NC} CHANGELOG.md - Version history"
    echo -e "  ${GREEN}3)${NC} Back to main menu\n"
    
    echo -ne "${YELLOW}Enter your choice:${NC} "
    read -r doc_choice
    
    case $doc_choice in
        1)
            if [ -f "$SCRIPT_DIR/README.md" ]; then
                less "$SCRIPT_DIR/README.md"
            else
                echo -e "${RED}README.md not found${NC}"
            fi
            ;;
        2)
            if [ -f "$SCRIPT_DIR/CHANGELOG.md" ]; then
                less "$SCRIPT_DIR/CHANGELOG.md"
            else
                echo -e "${RED}CHANGELOG.md not found${NC}"
            fi
            ;;
        3)
            return
            ;;
        *)
            echo -e "${RED}Invalid choice${NC}"
            ;;
    esac
    
    echo -e "\n${YELLOW}Press Enter to continue...${NC}"
    read
}

main() {
    while true; do
        show_menu
        read -r choice
        
        case $choice in
            1)
                fresh_installation
                echo -e "\n${YELLOW}Press Enter to continue...${NC}"
                read
                ;;
            2)
                resume_nonessential
                echo -e "\n${YELLOW}Press Enter to continue...${NC}"
                read
                ;;
            3)
                system_test
                echo -e "\n${YELLOW}Press Enter to continue...${NC}"
                read
                ;;
            4)
                check_status
                echo -e "\n${YELLOW}Press Enter to continue...${NC}"
                read
                ;;
            5)
                development_setup
                echo -e "\n${YELLOW}Press Enter to continue...${NC}"
                read
                ;;
            6)
                view_docs
                ;;
            q|Q)
                echo -e "\n${GREEN}Goodbye!${NC}\n"
                exit 0
                ;;
            *)
                echo -e "\n${RED}Invalid choice. Press Enter to try again...${NC}"
                read
                ;;
        esac
    done
}

main
