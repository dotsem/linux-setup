#!/usr/bin/env bash
# git-checker - Recursively find git repositories with uncommitted changes
# Usage: git-checker <scan_directory>

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers/colors.sh"

usage() {
    echo "Usage: git-checker <scan_directory>"
    echo ""
    echo "Recursively scans for git repositories with uncommitted changes"
    echo ""
    echo "Arguments:"
    echo "  scan_directory     Directory to scan for git repositories"
    echo ""
    echo "Example:"
    echo "  git-checker ~/prog"
    echo ""
    echo "Note: Only shows repositories with uncommitted changes"
}

if [ $# -ne 1 ]; then
    echo -e "${RED}Error: Invalid number of arguments${NC}\n"
    usage
    exit 1
fi

SCAN_DIR="$1"

if [ "$SCAN_DIR" = "-h" ] || [ "$SCAN_DIR" = "--help" ]; then
    usage
    exit 0
fi

SCAN_DIR=$(realpath -m "$SCAN_DIR" 2>/dev/null || echo "$SCAN_DIR")

if [ ! -d "$SCAN_DIR" ]; then
    echo -e "${RED}Error: Scan directory does not exist: $SCAN_DIR${NC}"
    exit 1
fi

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                      GIT CHECKER                           ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}\n"

echo -e "${CYAN}Scanning:${NC} $SCAN_DIR\n"

found_repos_with_changes=0

while IFS= read -r -d '' git_dir; do
    repo_dir=$(dirname "$git_dir")
    
    cd "$repo_dir" || continue
    
    if ! git rev-parse --git-dir &>/dev/null; then
        continue
    fi
    
    status_output=$(git status --porcelain 2>/dev/null)
    
    if [ -n "$status_output" ]; then
        ((found_repos_with_changes++))
        
        echo -e "${YELLOW}Repository:${NC} ${CYAN}$repo_dir${NC}"
        
        modified=$(echo "$status_output" | grep -c '^ M' || true)
        untracked=$(echo "$status_output" | grep -c '^??' || true)
        staged=$(echo "$status_output" | grep -c '^[MADRC]' || true)
        
        if [ $modified -gt 0 ]; then
            echo -e "  ${RED}Modified:${NC} $modified file(s)"
        fi
        
        if [ $staged -gt 0 ]; then
            echo -e "  ${GREEN}Staged:${NC} $staged file(s)"
        fi
        
        if [ $untracked -gt 0 ]; then
            echo -e "  ${YELLOW}Untracked:${NC} $untracked file(s)"
        fi
        
        echo ""
    fi
    
done < <(find "$SCAN_DIR" -name ".git" -type d -print0 2>/dev/null)

if [ $found_repos_with_changes -eq 0 ]; then
    echo -e "${GREEN}All repositories are clean${NC}"
else
    echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}Found $found_repos_with_changes repository(ies) with uncommitted changes${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
fi
