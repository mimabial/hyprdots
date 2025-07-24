#!/usr/bin/env bash

#====================================================================
# System Update Script
# Checks for system updates and provides waybar integration
# Multi-distribution support
#====================================================================

# Set script directory and load configuration
SCRIPT_DIR="$(dirname "$(realpath "$0")")"
source "${SCRIPT_DIR}/config_manager.sh"

#====================================================================
# CONFIGURATION
#====================================================================

# Cache file for update information (replaces DENV_RUNTIME_DIR)
UPDATE_CACHE_FILE="${THEME_CACHE_DIR}/update_info"
mkdir -p "$(dirname "$UPDATE_CACHE_FILE")"

# Terminal to use for update process
UPDATE_TERMINAL="${TERMINAL:-kitty}"

# Distribution detection
DISTRO=$(detect_package_manager)

#====================================================================
# UTILITY FUNCTIONS
#====================================================================

# Get AUR helper for Arch systems
get_aur_helper() {
    if command -v yay &>/dev/null; then
        echo "yay"
    elif command -v paru &>/dev/null; then
        echo "paru"
    else
        echo ""
    fi
}

# Check for official package updates by distribution
check_official_updates() {
    case "$DISTRO" in
        "pacman")
            # Arch Linux - use checkupdates
            if command -v checkupdates &>/dev/null; then
                CHECKUPDATES_DB=$(mktemp -u) checkupdates | wc -l
            else
                # Fallback method
                pacman -Qu | wc -l
            fi
            ;;
        "apt")
            # Debian/Ubuntu
            apt list --upgradable 2>/dev/null | grep -v "^Listing" | wc -l
            ;;
        "dnf")
            # Fedora
            dnf check-update -q | grep -v "^$" | wc -l 2>/dev/null || echo "0"
            ;;
        "yum")
            # RHEL/CentOS
            yum check-update -q | grep -v "^$" | wc -l 2>/dev/null || echo "0"
            ;;
        "zypper")
            # openSUSE
            zypper lu | grep -c "^v " 2>/dev/null || echo "0"
            ;;
        "brew")
            # macOS
            brew outdated | wc -l
            ;;
        "nix")
            # NixOS - check if nix-env has updates
            nix-env -u --dry-run 2>/dev/null | grep -c "would be" || echo "0"
            ;;
        *)
            echo "0"
            ;;
    esac
}

# Check for AUR updates (Arch only)
check_aur_updates() {
    if [ "$DISTRO" = "pacman" ]; then
        local aur_helper=$(get_aur_helper)
        if [ -n "$aur_helper" ]; then
            $aur_helper -Qua 2>/dev/null | wc -l
        else
            echo "0"
        fi
    else
        echo "0"
    fi
}

# Check for flatpak updates
check_flatpak_updates() {
    if command -v flatpak &>/dev/null; then
        flatpak remote-ls --updates 2>/dev/null | wc -l
    else
        echo "0"
    fi
}

# Check for snap updates (Ubuntu/derivatives)
check_snap_updates() {
    if command -v snap &>/dev/null; then
        snap refresh --list 2>/dev/null | grep -v "^All snaps up to date" | wc -l
    else
        echo "0"
    fi
}

# Generate update command based on distribution
get_update_command() {
    local official="$1"
    local aur="$2"
    local flatpak="$3"
    local snap="$4"
    
    case "$DISTRO" in
        "pacman")
            local aur_helper=$(get_aur_helper)
            if [ -n "$aur_helper" ] && [ "$aur" -gt 0 ]; then
                echo "$aur_helper -Syu"
            else
                echo "sudo pacman -Syu"
            fi
            ;;
        "apt")
            echo "sudo apt update && sudo apt upgrade"
            ;;
        "dnf")
            echo "sudo dnf upgrade"
            ;;
        "yum")
            echo "sudo yum update"
            ;;
        "zypper")
            echo "sudo zypper update"
            ;;
        "brew")
            echo "brew update && brew upgrade"
            ;;
        "nix")
            echo "nix-env -u"
            ;;
        *)
            echo "echo 'Unknown package manager: $DISTRO'"
            ;;
    esac
}

# Get distribution display name
get_distro_name() {
    case "$DISTRO" in
        "pacman") echo "Arch" ;;
        "apt") echo "APT" ;;
        "dnf") echo "DNF" ;;
        "yum") echo "YUM" ;;
        "zypper") echo "Zypper" ;;
        "brew") echo "Homebrew" ;;
        "nix") echo "Nix" ;;
        *) echo "Unknown" ;;
    esac
}

# Display system information using available tools
show_system_info() {
    if command -v fastfetch &>/dev/null; then
        fastfetch
    elif command -v neofetch &>/dev/null; then
        neofetch
    else
        echo "System: $(uname -srm)"
        echo "Distribution: $(get_distro_name)"
        echo "Updates available:"
    fi
}

#====================================================================
# UPDATE FUNCTIONS
#====================================================================

# Perform system updates
perform_updates() {
    local update_cache="$UPDATE_CACHE_FILE"
    
    if [ ! -f "$update_cache" ]; then
        echo "No update info found. Please run the script without parameters first."
        return 1
    fi
    
    # Read cached update information
    local official=0 aur=0 flatpak=0 snap=0
    while IFS="=" read -r key value; do
        case "$key" in
            OFFICIAL_UPDATES) official="$value" ;;
            AUR_UPDATES) aur="$value" ;;
            FLATPAK_UPDATES) flatpak="$value" ;;
            SNAP_UPDATES) snap="$value" ;;
        esac
    done < "$update_cache"
    
    # Generate update commands
    local main_update_cmd=$(get_update_command "$official" "$aur" "$flatpak" "$snap")
    local flatpak_cmd=""
    local snap_cmd=""
    
    if [ "$flatpak" -gt 0 ] && command -v flatpak &>/dev/null; then
        flatpak_cmd="flatpak update"
    fi
    
    if [ "$snap" -gt 0 ] && command -v snap &>/dev/null; then
        snap_cmd="sudo snap refresh"
    fi
    
    # Create update script
    local distro_name=$(get_distro_name)
    local update_script="
        show_system_info
        printf '[${distro_name}]    %-10s\n' '$official'
        $([ "$aur" -gt 0 ] && echo "printf '[AUR]       %-10s\n' '$aur'")
        $([ "$flatpak" -gt 0 ] && echo "printf '[Flatpak]   %-10s\n' '$flatpak'")
        $([ "$snap" -gt 0 ] && echo "printf '[Snap]      %-10s\n' '$snap'")
        echo ''
        echo 'Starting updates...'
        echo ''
        $main_update_cmd
        $([ -n "$flatpak_cmd" ] && echo "$flatpak_cmd")
        $([ -n "$snap_cmd" ] && echo "$snap_cmd")
        echo ''
        echo 'Updates completed!'
        read -n 1 -p 'Press any key to continue...'
    "
    
    # Execute in terminal
    case "$UPDATE_TERMINAL" in
        "kitty")
            kitty --title "System Update" sh -c "$update_script"
            ;;
        "alacritty")
            alacritty --title "System Update" -e sh -c "$update_script"
            ;;
        "gnome-terminal")
            gnome-terminal --title="System Update" -- sh -c "$update_script"
            ;;
        "konsole")
            konsole --title "System Update" -e sh -c "$update_script"
            ;;
        "xterm")
            xterm -title "System Update" -e sh -c "$update_script"
            ;;
        *)
            # Fallback to current terminal
            sh -c "$update_script"
            ;;
    esac
    
    # Signal waybar to refresh (if running)
    if pgrep -x waybar &>/dev/null; then
        pkill -RTMIN+20 waybar 2>/dev/null || true
    fi
}

# Check for updates and cache results
check_updates() {
    print_log "Checking for system updates..."
    
    # Check all update sources
    local official=$(check_official_updates)
    local aur=$(check_aur_updates)
    local flatpak=$(check_flatpak_updates)
    local snap=$(check_snap_updates)
    
    # Calculate total updates
    local total=$((official + aur + flatpak + snap))
    
    # Cache update information
    cat > "$UPDATE_CACHE_FILE" << EOF
OFFICIAL_UPDATES=$official
AUR_UPDATES=$aur
FLATPAK_UPDATES=$flatpak
SNAP_UPDATES=$snap
TOTAL_UPDATES=$total
LAST_CHECK=$(date +%s)
EOF
    
    print_log "Found $total total updates:"
    print_log "  $(get_distro_name): $official"
    [ "$aur" -gt 0 ] && print_log "  AUR: $aur"
    [ "$flatpak" -gt 0 ] && print_log "  Flatpak: $flatpak"
    [ "$snap" -gt 0 ] && print_log "  Snap: $snap"
    
    # Return values for waybar integration
    echo "$total $official $aur $flatpak $snap"
}

# Generate waybar JSON output
generate_waybar_output() {
    local total="$1"
    local official="$2"
    local aur="$3"
    local flatpak="$4"
    local snap="$5"
    
    local distro_name=$(get_distro_name)
    
    if [ "$total" -eq 0 ]; then
        # No updates available
        echo "{\"text\":\"\", \"tooltip\":\"Packages are up to date\"}"
    else
        # Updates available
        local text="󰮯 $total"
        local tooltip="󱓽 $distro_name $official"
        
        [ "$aur" -gt 0 ] && tooltip="$tooltip\n󱓾 AUR $aur"
        [ "$flatpak" -gt 0 ] && tooltip="$tooltip\n󰏓 Flatpak $flatpak"
        [ "$snap" -gt 0 ] && tooltip="$tooltip\n󰏆 Snap $snap"
        
        echo "{\"text\":\"$text\", \"tooltip\":\"$tooltip\"}"
    fi
}

# Show update status in terminal
show_update_status() {
    local update_cache="$UPDATE_CACHE_FILE"
    
    if [ ! -f "$update_cache" ]; then
        print_log -y "No cached update information. Run without arguments to check for updates."
        return 1
    fi
    
    # Read cached information
    local official=0 aur=0 flatpak=0 snap=0 total=0 last_check=0
    while IFS="=" read -r key value; do
        case "$key" in
            OFFICIAL_UPDATES) official="$value" ;;
            AUR_UPDATES) aur="$value" ;;
            FLATPAK_UPDATES) flatpak="$value" ;;
            SNAP_UPDATES) snap="$value" ;;
            TOTAL_UPDATES) total="$value" ;;
            LAST_CHECK) last_check="$value" ;;
        esac
    done < "$update_cache"
    
    # Show status
    local distro_name=$(get_distro_name)
    print_log -g "System Update Status"
    echo "Distribution: $distro_name"
    echo "Last checked: $(date -d "@$last_check" 2>/dev/null || echo "Unknown")"
    echo ""
    
    if [ "$total" -eq 0 ]; then
        print_log -g "✓ System is up to date"
    else
        print_log -y "$total updates available:"
        printf "  %-12s %s\n" "$distro_name:" "$official"
        [ "$aur" -gt 0 ] && printf "  %-12s %s\n" "AUR:" "$aur"
        [ "$flatpak" -gt 0 ] && printf "  %-12s %s\n" "Flatpak:" "$flatpak"
        [ "$snap" -gt 0 ] && printf "  %-12s %s\n" "Snap:" "$snap"
        echo ""
        echo "Run with 'up' parameter to update, or 'update' for full update"
    fi
}

#====================================================================
# COMMAND LINE HANDLING
#====================================================================

case "${1:-check}" in
    "up"|"update")
        # Perform updates
        perform_updates
        ;;
    "check")
        # Check for updates (default mode)
        read -r total official aur flatpak snap < <(check_updates)
        generate_waybar_output "$total" "$official" "$aur" "$flatpak" "$snap"
        ;;
    "status")
        # Show detailed status
        show_update_status
        ;;
    "waybar")
        # Force waybar output from cached data
        local update_cache="$UPDATE_CACHE_FILE"
        if [ -f "$update_cache" ]; then
            local official=0 aur=0 flatpak=0 snap=0 total=0
            while IFS="=" read -r key value; do
                case "$key" in
                    OFFICIAL_UPDATES) official="$value" ;;
                    AUR_UPDATES) aur="$value" ;;
                    FLATPAK_UPDATES) flatpak="$value" ;;
                    SNAP_UPDATES) snap="$value" ;;
                    TOTAL_UPDATES) total="$value" ;;
                esac
            done < "$update_cache"
            generate_waybar_output "$total" "$official" "$aur" "$flatpak" "$snap"
        else
            echo "{\"text\":\"\", \"tooltip\":\"No update info cached\"}"
        fi
        ;;
    "-h"|"--help")
        cat << EOF
Usage: $0 [COMMAND]

System update checker and manager with waybar integration.

COMMANDS:
    check       Check for updates and output waybar JSON (default)
    up/update   Perform system updates in terminal
    status      Show detailed update status
    waybar      Output waybar JSON from cached data
    --help      Show this help message

WAYBAR INTEGRATION:
    Add to waybar config:
    "custom/updates": {
        "exec": "$0 check",
        "interval": 3600,
        "format": "{}",
        "on-click": "$0 up",
        "return-type": "json"
    }

SUPPORTED DISTRIBUTIONS:
    - Arch Linux (pacman + AUR)
    - Debian/Ubuntu (apt)
    - Fedora (dnf)
    - RHEL/CentOS (yum)
    - openSUSE (zypper)
    - macOS (homebrew)
    - NixOS (nix)
    - Flatpak (cross-platform)
    - Snap (Ubuntu/derivatives)

ENVIRONMENT VARIABLES:
    TERMINAL    Terminal to use for updates (default: kitty)
EOF
        ;;
    *)
        print_log -r "Unknown command: $1"
        print_log "Use --help for usage information"
        exit 1
        ;;
esac
