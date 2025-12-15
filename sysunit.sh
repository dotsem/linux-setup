#!/usr/bin/env bash
# System Unit Test - Multi-distro system validation
# Supports: Arch Linux, Fedora, Debian/Ubuntu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/colors.sh"

TESTS_PASSED=0
TESTS_FAILED=0
TESTS_WARNED=0
FAILED_TESTS=()
WARNING_TESTS=()
TEST_RESULTS=()

JSON_OUTPUT=""
JSON_FILE=""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../vars.sh" 2>/dev/null || {
    detect_distro() {
        if [ -f /etc/os-release ]; then
            . /etc/os-release
            case "$ID" in
                fedora|rhel|centos) echo "dnf" ;;
                arch|manjaro|endeavouros) echo "pacman" ;;
                ubuntu|debian|pop) echo "apt" ;;
                *) echo "unknown" ;;
            esac
        else
            echo "unknown"
        fi
    }
    DETECTED_PKG_MANAGER=$(detect_distro)
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -j|--json)
                JSON_FILE="$2"
                shift 2
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

show_help() {
    cat << EOF
Usage: sysunit [OPTIONS]

System Unit Test - Multi-distro system validation
Supports: Arch Linux, Fedora, Debian/Ubuntu

OPTIONS:
    -j, --json <file>    Save results to JSON file
    -h, --help          Show this help message

EXAMPLES:
    sysunit                           # Run tests (normal output)
    sysunit -j results.json          # Run tests and save JSON
EOF
}

setup_sudo() {
    if ! sudo -n true 2>/dev/null; then
        echo -e "${YELLOW}Some tests require sudo access.${NC}"
        echo -e "${YELLOW}Please enter your password:${NC}"
        if ! sudo -v; then
            echo -e "${RED}Failed to get sudo access. Some tests will be skipped.${NC}"
            return 1
        fi
    fi
    
    (
        while true; do
            sudo -n true
            sleep 60
            kill -0 "$$" 2>/dev/null || exit
        done
    ) 2>/dev/null &
    SUDO_KEEPALIVE_PID=$!
    
    trap "sudo -K; kill $SUDO_KEEPALIVE_PID 2>/dev/null" EXIT INT TERM
    
    return 0
}

print_header() {
    echo -e "\n${BLUE}=====================================${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}=====================================${NC}"
}

test_result() {
    local test_name="$1"
    local result="$2"
    local details="${3:-}"
    local category="${4:-general}"
    
    TEST_RESULTS+=("{\"name\":\"$test_name\",\"status\":\"$result\",\"category\":\"$category\",\"details\":\"$details\"}")
    
    case "$result" in
        pass|0)
            echo -e "${GREEN}✓${NC} $test_name"
            ((TESTS_PASSED++))
            ;;
        fail|1)
            echo -e "${RED}✗${NC} $test_name${details:+ - $details}"
            ((TESTS_FAILED++))
            FAILED_TESTS+=("$test_name")
            ;;
        warn)
            echo -e "${YELLOW}⚠${NC} $test_name${details:+ - $details}"
            ((TESTS_WARNED++))
            WARNING_TESTS+=("$test_name")
            ;;
        skip)
            echo -e "${CYAN}○${NC} $test_name (skipped)"
            ;;
    esac
}

test_kernel() {
    print_header "Kernel Tests"
    
    local kernel_version=$(uname -r 2>/dev/null)
    if [ -n "$kernel_version" ]; then
        test_result "Kernel is running" "pass" "$kernel_version" "kernel"
    else
        test_result "Kernel is running" "fail" "" "kernel"
    fi
    
    local module_count=$(lsmod 2>/dev/null | tail -n +2 | wc -l)
    if [ "$module_count" -gt 0 ]; then
        test_result "Kernel modules loaded" "pass" "$module_count modules" "kernel"
    else
        test_result "Kernel modules loaded" "fail" "" "kernel"
    fi
    
    local uptime=$(uptime -p 2>/dev/null || echo "unknown")
    test_result "System uptime" "pass" "$uptime" "kernel"
}

test_network() {
    print_header "Network Tests"
    
    if systemctl is-active NetworkManager > /dev/null 2>&1; then
        test_result "NetworkManager is active" "pass" "" "network"
    else
        test_result "NetworkManager is active" "fail" "Service not running" "network"
    fi
    
    if ping -c 1 -W 2 google.com > /dev/null 2>&1; then
        test_result "Internet connectivity" "pass" "" "network"
    else
        test_result "Internet connectivity" "fail" "Cannot reach google.com" "network"
    fi
    
    if nslookup google.com > /dev/null 2>&1; then
        test_result "DNS resolution" "pass" "" "network"
    else
        test_result "DNS resolution" "fail" "DNS lookup failed" "network"
    fi
}

test_audio() {
    print_header "Audio Tests"
    
    if pgrep -x pipewire > /dev/null 2>&1; then
        test_result "PipeWire is running" "pass" "" "audio"
    else
        test_result "PipeWire is running" "fail" "" "audio"
    fi
    
    if pgrep -x wireplumber > /dev/null 2>&1; then
        test_result "WirePlumber is running" "pass" "" "audio"
    else
        test_result "WirePlumber is running" "fail" "" "audio"
    fi
    
    if pactl list sinks short 2>/dev/null | grep -q .; then
        test_result "Audio devices detected" "pass" "" "audio"
    else
        test_result "Audio devices detected" "warn" "No audio devices" "audio"
    fi
}

test_display() {
    print_header "Display Tests"
    
    if [ -n "$WAYLAND_DISPLAY" ]; then
        test_result "Wayland display active" "pass" "$WAYLAND_DISPLAY" "display"
    elif [ -n "$DISPLAY" ]; then
        test_result "X11 display active" "pass" "$DISPLAY" "display"
    else
        test_result "Display variable set" "warn" "No display detected" "display"
    fi
    
    if [ -f "$HOME/.config/hypr/hyprland.conf" ]; then
        test_result "Hyprland config exists" "pass" "" "display"
    else
        test_result "Hyprland config exists" "warn" "Not found" "display"
    fi
    
    if systemctl is-enabled sddm > /dev/null 2>&1; then
        test_result "SDDM is enabled" "pass" "" "display"
    else
        test_result "SDDM is enabled" "warn" "Not enabled" "display"
    fi
}

test_shell() {
    print_header "Shell Tests"
    
    if command -v fish > /dev/null 2>&1; then
        local fish_version=$(fish --version 2>/dev/null | awk '{print $NF}')
        test_result "Fish is installed" "pass" "$fish_version" "shell"
    else
        test_result "Fish is installed" "fail" "" "shell"
    fi
    
    local current_shell=$(getent passwd "$USER" | cut -d: -f7)
    local fish_path=$(command -v fish 2>/dev/null)
    if [ "$current_shell" = "$fish_path" ]; then
        test_result "Fish is default shell" "pass" "" "shell"
    else
        test_result "Fish is default shell" "warn" "Current: $current_shell" "shell"
    fi
    
    if [ -f "$HOME/.config/fish/config.fish" ]; then
        test_result "Fish config exists" "pass" "" "shell"
    else
        test_result "Fish config exists" "warn" "Not found" "shell"
    fi
}

test_git() {
    print_header "Git Tests"
    
    if command -v git > /dev/null 2>&1; then
        test_result "Git is installed" "pass" "" "git"
    else
        test_result "Git is installed" "fail" "" "git"
        return
    fi
    
    if git config --global user.name > /dev/null 2>&1; then
        test_result "Git user.name configured" "pass" "" "git"
    else
        test_result "Git user.name configured" "fail" "" "git"
    fi
    
    if git config --global user.email > /dev/null 2>&1; then
        test_result "Git user.email configured" "pass" "" "git"
    else
        test_result "Git user.email configured" "fail" "" "git"
    fi
}

test_package_managers() {
    print_header "Package Manager Tests"
    
    case "$DETECTED_PKG_MANAGER" in
        pacman)
            if pacman --version > /dev/null 2>&1; then
                test_result "Pacman is working" "pass" "" "package"
            else
                test_result "Pacman is working" "fail" "" "package"
            fi
            
            if command -v yay > /dev/null 2>&1; then
                test_result "Yay is installed" "pass" "" "package"
            else
                test_result "Yay is installed" "warn" "AUR helper not installed" "package"
            fi
            ;;
        dnf)
            if dnf --version > /dev/null 2>&1; then
                test_result "DNF is working" "pass" "" "package"
            else
                test_result "DNF is working" "fail" "" "package"
            fi
            
            if dnf repolist 2>/dev/null | grep -qi rpmfusion; then
                test_result "RPM Fusion enabled" "pass" "" "package"
            else
                test_result "RPM Fusion enabled" "warn" "Not enabled" "package"
            fi
            ;;
        apt)
            if apt --version > /dev/null 2>&1; then
                test_result "APT is working" "pass" "" "package"
            else
                test_result "APT is working" "fail" "" "package"
            fi
            ;;
    esac
    
    if command -v flatpak > /dev/null 2>&1; then
        test_result "Flatpak is installed" "pass" "" "package"
        
        if flatpak remotes | grep -q flathub; then
            test_result "Flathub remote configured" "pass" "" "package"
        else
            test_result "Flathub remote configured" "warn" "" "package"
        fi
    else
        test_result "Flatpak is installed" "warn" "Not installed" "package"
    fi
}

test_development() {
    print_header "Development Environment Tests"
    
    if command -v node > /dev/null 2>&1; then
        local node_version=$(node --version 2>/dev/null)
        test_result "Node.js installed" "pass" "$node_version" "dev"
    else
        test_result "Node.js installed" "warn" "Not installed" "dev"
    fi
    
    if command -v pnpm > /dev/null 2>&1; then
        local pnpm_version=$(pnpm --version 2>/dev/null)
        test_result "PNPM installed" "pass" "$pnpm_version" "dev"
    else
        test_result "PNPM installed" "warn" "Not installed" "dev"
    fi
    
    if command -v go > /dev/null 2>&1; then
        local go_version=$(go version 2>/dev/null | awk '{print $3}')
        test_result "Go installed" "pass" "$go_version" "dev"
    else
        test_result "Go installed" "warn" "Not installed" "dev"
    fi
    
    if command -v rustc > /dev/null 2>&1; then
        local rust_version=$(rustc --version 2>/dev/null | awk '{print $2}')
        test_result "Rust installed" "pass" "$rust_version" "dev"
    else
        test_result "Rust installed" "warn" "Not installed" "dev"
    fi
    
    if command -v java > /dev/null 2>&1; then
        local java_version=$(java --version 2>/dev/null | head -1)
        test_result "Java installed" "pass" "$java_version" "dev"
    else
        test_result "Java installed" "warn" "Not installed" "dev"
    fi
    
    if command -v dotnet > /dev/null 2>&1; then
        local dotnet_version=$(dotnet --version 2>/dev/null)
        test_result ".NET SDK installed" "pass" "$dotnet_version" "dev"
    else
        test_result ".NET SDK installed" "warn" "Not installed" "dev"
    fi
    
    if command -v docker > /dev/null 2>&1; then
        test_result "Docker installed" "pass" "" "dev"
    else
        test_result "Docker installed" "warn" "Not installed" "dev"
    fi
}

test_flutter() {
    print_header "Flutter & Android Tests"
    
    if command -v flutter > /dev/null 2>&1; then
        local flutter_version=$(flutter --version 2>/dev/null | head -1 | awk '{print $2}')
        test_result "Flutter installed" "pass" "$flutter_version" "flutter"
    else
        test_result "Flutter installed" "warn" "Not installed" "flutter"
        return
    fi
    
    if [ -d "$HOME/Android/Sdk" ]; then
        test_result "Android SDK directory exists" "pass" "" "flutter"
    else
        test_result "Android SDK directory exists" "warn" "Not found" "flutter"
    fi
    
    if [ -d "$HOME/Android/Sdk/cmdline-tools/latest" ]; then
        test_result "Android cmdline-tools installed" "pass" "" "flutter"
    else
        test_result "Android cmdline-tools installed" "warn" "Not found" "flutter"
    fi
    
    if command -v emulator > /dev/null 2>&1 || [ -x "$HOME/Android/Sdk/emulator/emulator" ]; then
        test_result "Android emulator available" "pass" "" "flutter"
    else
        test_result "Android emulator available" "warn" "Not found" "flutter"
    fi
    
    if [ -c /dev/kvm ]; then
        test_result "KVM virtualization available" "pass" "" "flutter"
    else
        test_result "KVM virtualization available" "warn" "Not available - enable VT-x in BIOS" "flutter"
    fi
}

test_nvidia() {
    print_header "NVIDIA Tests"
    
    if ! lspci | grep -qi nvidia; then
        echo -e "${CYAN}ℹ${NC} No NVIDIA GPU detected"
        return
    fi
    
    if command -v nvidia-smi > /dev/null 2>&1; then
        test_result "nvidia-smi available" "pass" "" "nvidia"
        
        if nvidia-smi > /dev/null 2>&1; then
            local gpu_name=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1)
            test_result "NVIDIA driver working" "pass" "$gpu_name" "nvidia"
        else
            test_result "NVIDIA driver working" "fail" "Driver not responding" "nvidia"
        fi
    else
        test_result "nvidia-smi available" "fail" "NVIDIA driver not installed" "nvidia"
    fi
}

test_gaming() {
    print_header "Gaming Tests"
    
    if command -v vulkaninfo > /dev/null 2>&1; then
        if vulkaninfo --summary > /dev/null 2>&1; then
            test_result "Vulkan working" "pass" "" "gaming"
        else
            test_result "Vulkan working" "fail" "" "gaming"
        fi
    else
        test_result "Vulkan working" "warn" "vulkaninfo not installed" "gaming"
    fi
    
    if flatpak list 2>/dev/null | grep -q "com.valvesoftware.Steam"; then
        test_result "Steam installed" "pass" "" "gaming"
    else
        test_result "Steam installed" "warn" "Not installed" "gaming"
    fi
    
    if command -v gamemoded > /dev/null 2>&1; then
        test_result "Gamemode installed" "pass" "" "gaming"
    else
        test_result "Gamemode installed" "warn" "Not installed" "gaming"
    fi
}

test_virtualization() {
    print_header "Virtualization Tests"
    
    if command -v virt-manager > /dev/null 2>&1; then
        test_result "virt-manager installed" "pass" "" "virt"
    else
        test_result "virt-manager installed" "warn" "Not installed" "virt"
    fi
    
    if systemctl is-active libvirtd > /dev/null 2>&1; then
        test_result "libvirtd running" "pass" "" "virt"
    else
        test_result "libvirtd running" "warn" "Not running" "virt"
    fi
    
    if [ -c /dev/kvm ]; then
        test_result "KVM available" "pass" "" "virt"
    else
        test_result "KVM available" "warn" "Not available" "virt"
    fi
}

test_hardware() {
    print_header "Hardware Tests"
    
    local cpu_cores=$(nproc 2>/dev/null)
    test_result "CPU information" "pass" "$cpu_cores cores" "hardware"
    
    local mem_total=$(free -h 2>/dev/null | awk '/^Mem:/ {print $2}')
    test_result "Memory" "pass" "$mem_total total" "hardware"
    
    local disk_usage=$(df -h / 2>/dev/null | awk 'NR==2 {print $5}' | tr -d '%')
    if [ "$disk_usage" -lt 90 ]; then
        test_result "Root filesystem" "pass" "${disk_usage}% used" "hardware"
    else
        test_result "Root filesystem" "warn" "${disk_usage}% used (high)" "hardware"
    fi
}

generate_json() {
    local timestamp=$(date -Iseconds)
    local hostname=$(hostname)
    local username=$(whoami)
    local total_tests=$((TESTS_PASSED + TESTS_FAILED + TESTS_WARNED))
    
    cat > "$JSON_FILE" << EOF
{
  "metadata": {
    "timestamp": "$timestamp",
    "hostname": "$hostname",
    "username": "$username",
    "distro": "$DETECTED_PKG_MANAGER",
    "sysunit_version": "3.0"
  },
  "summary": {
    "total": $total_tests,
    "passed": $TESTS_PASSED,
    "failed": $TESTS_FAILED,
    "warned": $TESTS_WARNED,
    "success_rate": $(awk "BEGIN {printf \"%.2f\", ($TESTS_PASSED/$total_tests)*100}")
  },
  "results": [
    $(IFS=,; echo "${TEST_RESULTS[*]}")
  ]
}
EOF
}

main() {
    parse_args "$@"
    
    echo -e "${BLUE}╔═══════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║                                       ║${NC}"
    echo -e "${BLUE}║   SYSTEM UNIT TESTS (sysunit v3.0)    ║${NC}"
    echo -e "${BLUE}║                                       ║${NC}"
    echo -e "${BLUE}╚═══════════════════════════════════════╝${NC}"
    
    echo -e "${CYAN}Distro: $DETECTED_PKG_MANAGER${NC}"
    
    setup_sudo
    
    test_kernel
    test_hardware
    test_network
    test_audio
    test_display
    test_shell
    test_git
    test_package_managers
    test_development
    test_flutter
    test_nvidia
    test_gaming
    test_virtualization
    
    echo -e "\n${BLUE}=====================================${NC}"
    echo -e "${BLUE}  TEST SUMMARY${NC}"
    echo -e "${BLUE}=====================================${NC}"
    echo -e "${GREEN}Passed:${NC}  $TESTS_PASSED"
    echo -e "${RED}Failed:${NC}  $TESTS_FAILED"
    echo -e "${YELLOW}Warnings:${NC} $TESTS_WARNED"
    
    local total=$((TESTS_PASSED + TESTS_FAILED + TESTS_WARNED))
    local success_rate=$(awk "BEGIN {printf \"%.1f\", ($TESTS_PASSED/$total)*100}")
    echo -e "${CYAN}Success Rate:${NC} $success_rate%"
    
    if [ $TESTS_FAILED -gt 0 ]; then
        echo -e "\n${RED}Failed tests:${NC}"
        for test in "${FAILED_TESTS[@]}"; do
            echo -e "  ${RED}✗${NC} $test"
        done
    fi
    
    if [ $TESTS_WARNED -gt 0 ]; then
        echo -e "\n${YELLOW}Warnings:${NC}"
        for test in "${WARNING_TESTS[@]}"; do
            echo -e "  ${YELLOW}⚠${NC} $test"
        done
    fi
    
    if [ -n "$JSON_FILE" ]; then
        generate_json
        echo -e "\n${GREEN}Results saved to:${NC} $JSON_FILE"
    fi
    
    if [ $TESTS_FAILED -gt 0 ]; then
        echo -e "\n${YELLOW}Some tests failed. Review the output above for details.${NC}"
        return 1
    elif [ $TESTS_WARNED -gt 0 ]; then
        echo -e "\n${YELLOW}All critical tests passed, but some warnings were raised.${NC}"
        return 0
    else
        echo -e "\n${GREEN}All tests passed! System is configured correctly.${NC}"
        return 0
    fi
}

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi
