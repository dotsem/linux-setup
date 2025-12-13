#!/bin/bash
source "$(dirname "${BASH_SOURCE[0]}")/../vars.sh"

# Log file
LOG_FILE="$HOME/linux_setup.log"
echo -e "${YELLOW}Installation log: ${LOG_FILE}${NC}"


# Initialize log file
mkdir -p "$(dirname "$LOG_FILE")"
touch "$LOG_FILE"

# Logging function
log() {
    local level=$1
    local message=$2
    local timestamp=$(date +"%Y-%m-%d %T")
    
    # Log level numeric values
    local -A log_levels=(
        ["DEBUG"]=0
        ["INFO"]=1
        ["WARN"]=2
        ["ERROR"]=3
    )
    
    # Check if message level is at or above threshold
    if [[ ${log_levels[$level]} -ge ${log_levels[$LOG_LEVEL]} ]]; then
        echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
        
        # For errors, also print to stderr
        if [ "$level" = "ERROR" ]; then
            echo "[$timestamp] [$level] $message" >&2
        fi
    fi
}