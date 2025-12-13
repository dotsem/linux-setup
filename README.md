# Arch Linux Setup Script

A comprehensive, modular setup script for Arch Linux that handles everything from essential system configuration to non-essential package installation.

## Features

- ✅ **Two-phase installation**: Essential packages first, optional packages later
- ✅ **Resume support**: Interrupted installations can be resumed
- ✅ **Error handling**: Continues on errors, tracks failures
- ✅ **System testing**: Built-in system unittest tool (`sysunit`)
- ✅ **Background installation**: Non-essential packages install in background
- ✅ **Modular design**: Easy to customize and extend
- ✅ **Progress tracking**: See installation progress at any time
- ✅ **USB configuration**: Disables USB autosuspend for reliability
- ✅ **Flutter support**: Automatically sets up Flutter and Kolibri Shell

## Quick Start

### Fresh Arch Install

```bash
# 1. Clone this repository
git clone <your-repo-url> ~/arch-setup
cd ~/arch-setup

# 2. Edit configuration
nano vars.sh  # Set your name, email, dotfiles URL, etc.

# 3. Check system requirements (recommended)
./check-requirements.sh

# 4. Run installation (interactive menu)
./setup-menu.sh

# OR run essential installation directly
chmod +x install-essential.sh
./install-essential.sh

# 5. Log out and back in

# 6. Verify system
sysunit

# 7. Install non-essential packages (optional)
apres-setup start
```

## Project Structure

```
arch-setup/
├── setup-menu.sh           # Interactive menu (recommended entry point)
├── install-essential.sh    # Main installation script (essential packages only)
├── check-requirements.sh   # Pre-installation system checker
├── arch-setup.sh          # Legacy script (kept for compatibility)
├── vars.sh                # User configuration
│
├── bin/                   # Command-line tools
│   ├── sysunit           # System unit test tool
│   └── apres-setup       # Non-essential package installer
│
├── config/               # Package lists
│   ├── packages-essential.sh     # Essential packages
│   └── packages-nonessential.sh  # Optional packages
│
├── lib/                  # Shared libraries
│   └── package-manager.sh  # Package installation logic
│
├── modules/              # Feature modules
│   ├── audio.sh          # PipeWire/audio setup
│   ├── boot.sh           # Boot configuration
│   ├── cloud.sh          # Cloud storage setup
│   ├── flutter.sh        # Flutter & Kolibri Shell
│   ├── font.sh           # Font installation
│   ├── game.sh           # Gaming setup
│   ├── grub.sh           # GRUB configuration
│   ├── maintenance.sh    # System maintenance
│   ├── neovim.sh         # Neovim setup
│   ├── performance.sh    # Performance tweaks
│   ├── python.sh         # Python environment
│   ├── security.sh       # Security configuration
│   ├── setup.sh          # Basic system setup
│   ├── usb.sh            # USB configuration
│   └── zsh.sh            # Zsh shell setup
│
└── helpers/              # Helper utilities
    ├── colors.sh         # Color definitions
    ├── logging.sh        # Logging functions
    └── ui.sh             # UI functions
```

## Configuration

Edit `vars.sh` to customize your installation:

```bash
# User information
GIT_NAME="Your Name"
GIT_EMAIL="your.email@example.com"

# Dotfiles
DOTFILES_URL="https://github.com/yourusername/.config.git"

# Kernel type
KERNEL_TYPE="linux"  # or "linux-lts", "linux-zen", etc.

# Logging
LOG_LEVEL="INFO"  # DEBUG, INFO, WARN, ERROR

# Optional: USB mount path for config files
USB_MOUNT_PATH="/mnt/usb"
```

## Commands

### `setup-menu.sh` (Interactive Menu)
User-friendly interactive menu for all installation options.

```bash
./setup-menu.sh

# Options:
# 1. Fresh Installation (essential packages)
# 2. Continue/Resume Non-Essential Installation
# 3. System Test (sysunit)
# 4. Check Installation Status
# 5. Legacy Installation (all at once)
# 6. View Documentation
```

### `check-requirements.sh`
Pre-installation system requirements checker.

```bash
./check-requirements.sh

# Checks:
# - Arch-based system
# - User privileges (not root, has sudo)
# - Internet connectivity
# - Disk space (minimum 5GB, recommended 10GB+)
# - Memory (warns if <4GB)
# - CPU cores
# - Required tools
# - Configuration file
# - Hardware detection
```

### `sysunit`
System unit test tool - validates your system configuration.

```bash
# Run all tests
sysunit

# Tests include:
# - Kernel functionality
# - Network connectivity
# - Audio system (PipeWire)
# - Display configuration
# - Shell setup (Zsh)
# - Git configuration
# - Package managers
# - Python environment
# - Directory structure
# - Boot configuration
# - Security (firewall)
```

### `apres-setup`
Non-essential package installer with progress tracking.

```bash
# Start/resume installation
apres-setup start

# Check status
apres-setup status

# Stop installation (can resume later)
apres-setup stop

# Reset progress and start over
apres-setup reset

# View installation log
apres-setup log
```

## Package Categories

### Essential Packages
Installed during initial setup. Required for a functional system:
- **Display**: Hyprland, Wayland, display manager (ly)
- **Terminal**: Alacritty, Zsh
- **Audio**: PipeWire, WirePlumber
- **Network**: NetworkManager
- **Basic tools**: Git, Neovim, file managers

### Non-Essential Packages
Installed via `apres-setup`. Optional but useful:
- **Development**: VSCode, Docker, Android SDK, Flutter
- **Browsers**: Chrome, Zen Browser
- **Gaming**: Steam, Lutris, RetroArch
- **Productivity**: LibreOffice, Obsidian
- **Communication**: Vesktop

## Customization

### Adding Packages

Edit the appropriate file in `config/`:

```bash
# For essential packages
nano config/packages-essential.sh

# For non-essential packages
nano config/packages-nonessential.sh
```

### Adding Modules

1. Create a new module in `modules/`:
```bash
nano modules/myfeature.sh
```

2. Add your functions:
```bash
#!/bin/bash
source "$(dirname "${BASH_SOURCE[0]}")/../helpers/ui.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../helpers/logging.sh"

setup_myfeature() {
    section "MY FEATURE" "$BLUE"
    # Your setup code here
}
```

3. Source it in `install-essential.sh`:
```bash
source "$SCRIPT_DIR/modules/myfeature.sh"
```

4. Add to installation steps:
```bash
execute_step "My Feature" setup_myfeature
```

## Features Explained

### USB Autosuspend Disabled
Prevents USB devices from suspending, which can cause issues with peripherals. Configured via udev rules.

### Kolibri Shell Setup
Automatically clones, builds, and installs your Flutter-based taskbar from https://github.com/dotsem/kolibri-shell.

### Error Recovery
All steps track errors but continue installation. Failed steps are reported at the end.

### Progress Tracking
`apres-setup` saves progress to a file, allowing you to:
- Stop and resume installation
- Survive system reboots
- Skip already-installed packages

## Troubleshooting

### Installation Failed
1. Check the log file: `~/arch_setup.log`
2. Run `sysunit` to identify issues
3. Re-run the installer (it skips already-installed packages)

### Package Installation Fails
1. Update mirrors: `sudo pacman-mirrors --fasttrack`
2. Sync databases: `sudo pacman -Syy`
3. Try manual installation: `yay -S package-name`

### Apres-Setup Won't Start
```bash
# Check status
apres-setup status

# If stuck, reset and restart
apres-setup reset
apres-setup start
```

### System Tests Fail
Run sysunit to see which tests fail, then check the relevant module:
```bash
sysunit | grep "✗"  # Show only failed tests
```

## Logs

- Main log: `~/arch_setup.log`
- Apres-setup log: `~/.cache/apres-setup.log`

## Contributing

Feel free to:
- Add new modules
- Improve error handling
- Add more system tests
- Optimize package lists

## License

This is a personal setup script. Use at your own risk. Always review scripts before running them on your system.

## Credits

Created by Sem VB for personal Arch Linux installations.
