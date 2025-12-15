#!/bin/bash
# Distro-specific loader
# Sources optimizations for the detected distro

DISTROS_DIR="$(dirname "${BASH_SOURCE[0]}")"

source "$DISTROS_DIR/../vars.sh"
source "$DISTROS_DIR/../helpers/logging.sh"

load_distro_optimizations() {
    local distro_file="$DISTROS_DIR/${DETECTED_DISTRO_ID}/optimizations.sh"
    local family_file="$DISTROS_DIR/${DETECTED_DISTRO_FAMILY}/optimizations.sh"
    
    if [ -f "$distro_file" ]; then
        log "INFO" "Loading optimizations for $DETECTED_DISTRO_ID"
        source "$distro_file"
        return 0
    elif [ -f "$family_file" ]; then
        log "INFO" "Loading optimizations for $DETECTED_DISTRO_FAMILY family"
        source "$family_file"
        return 0
    else
        log "WARN" "No distro-specific optimizations found for $DETECTED_DISTRO_ID"
        return 1
    fi
}

distro_has_optimization() {
    local optimization="$1"
    
    case "$DETECTED_DISTRO_ID" in
        cachyos)
            case "$optimization" in
                sched-ext|bore-scheduler|optimized-kernel|ananicy-cpp)
                    return 0
                    ;;
            esac
            ;;
    esac
    return 1
}
