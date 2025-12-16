#!/usr/bin/env bash
# env-catcher - Recursively find and backup .env files
# Usage: env-catcher <scan_directory> <backup_directory>

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers/colors.sh"

usage() {
    echo "Usage: env-catcher <scan_directory> <backup_directory>"
    echo ""
    echo "Recursively scans for .env files and backs them up with clear naming"
    echo ""
    echo "Arguments:"
    echo "  scan_directory     Directory to scan for .env files"
    echo "  backup_directory   Directory to store backup copies"
    echo ""
    echo "Example:"
    echo "  env-catcher ~/prog /mnt/usb/env-backups"
    echo ""
    echo "Files will be renamed for easy tracing:"
    echo "  ~/prog/web/myapp/.env → prog_web_myapp.env"
}

if [ $# -ne 2 ]; then
    echo -e "${RED}Error: Invalid number of arguments${NC}\n"
    usage
    exit 1
fi

SCAN_DIR="$1"
BACKUP_DIR="$2"

if [ "$SCAN_DIR" = "-h" ] || [ "$SCAN_DIR" = "--help" ]; then
    usage
    exit 0
fi

SCAN_DIR=$(realpath -m "$SCAN_DIR" 2>/dev/null || echo "$SCAN_DIR")

if [ ! -d "$SCAN_DIR" ]; then
    echo -e "${RED}Error: Scan directory does not exist: $SCAN_DIR${NC}"
    exit 1
fi

if [ ! -d "$BACKUP_DIR" ]; then
    echo -e "${YELLOW}Backup directory does not exist. Creating: $BACKUP_DIR${NC}"
    mkdir -p "$BACKUP_DIR" || {
        echo -e "${RED}Error: Failed to create backup directory${NC}"
        exit 1
    }
fi

BACKUP_DIR=$(realpath "$BACKUP_DIR")

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                       ENV CATCHER                          ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}\n"

echo -e "${CYAN}Scanning directory:${NC} $SCAN_DIR"
echo -e "${CYAN}Backup destination:${NC} $BACKUP_DIR\n"

declare -a found_files
count=0

while IFS= read -r -d '' file; do
    found_files+=("$file")
    ((count++))
done < <(find "$SCAN_DIR" -name ".env" -type f -print0 2>/dev/null)

if [ $count -eq 0 ]; then
    echo -e "${YELLOW}No .env files found${NC}"
    exit 0
fi

echo -e "${GREEN}Found $count .env file(s)${NC}\n"

copied=0
failed=0

for file in "${found_files[@]}"; do
    relative_path="${file#$SCAN_DIR/}"
    
    dir_part=$(dirname "$relative_path")
    
    if [ "$dir_part" = "." ]; then
        backup_name=".env"
    else
        backup_name="${dir_part//\//_}.env"
    fi
    
    backup_path="$BACKUP_DIR/$backup_name"
    
    echo -e "${CYAN}Copying:${NC} $file"
    echo -e "  ${YELLOW}→${NC} $backup_name"
    
    if cp "$file" "$backup_path" 2>/dev/null; then
        echo -e "  ${GREEN}✓ Copied${NC}"
        ((copied++))
    else
        echo -e "  ${RED}✗ Failed${NC}"
        ((failed++))
    fi
    echo ""
done

echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}Summary:${NC}"
echo -e "  Files found:  $count"
echo -e "  Successfully copied: $copied"

if [ $failed -gt 0 ]; then
    echo -e "  ${RED}Failed: $failed${NC}"
fi

echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
