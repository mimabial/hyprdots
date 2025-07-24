#!/usr/bin/env bash

#====================================================================
# Custom Configuration Manager
# Replaces DENv's globalcontrol.sh functionality
# Manages themes, configurations, and environment variables
#====================================================================

#====================================================================
# DIRECTORY CONFIGURATION
#====================================================================

# Set up XDG Base Directory compliance
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"

# Main configuration directories
export THEME_CONFIG_DIR="${XDG_CONFIG_HOME}/custom-themes"
export THEME_CACHE_DIR="${XDG_CACHE_HOME}/custom-themes"
export THEME_DATA_DIR="${XDG_DATA_HOME}/custom-themes"
export THEME_STATE_DIR="${XDG_STATE_HOME}/custom-themes"

# Subdirectories for different components
export WALLPAPER_DIR="${THEME_DATA_DIR}/wallpapers"     # User wallpaper collection
export THUMBNAIL_DIR="${THEME_CACHE_DIR}/thumbnails"    # Generated thumbnails
export COLOR_DIR="${THEME_CACHE_DIR}/colors"            # Extracted color palettes
export TEMPLATE_DIR="${THEME_CONFIG_DIR}/templates"     # Application templates
export THEMES_DIR="${THEME_CONFIG_DIR}/themes"          # Theme definitions
export ICONS_DIR="${THEME_DATA_DIR}/icons"              # Custom icons for theming
export FONTS_DIR="${THEME_DATA_DIR}/fonts"              # Custom fonts for theming

# Configuration files
export THEME_CONFIG_FILE="${THEME_CONFIG_DIR}/theme.conf"
export STATE_FILE="${THEME_STATE_DIR}/current.state"
export USER_PREFS_FILE="${THEME_CONFIG_DIR}/user.conf"

#====================================================================
# GLOBAL VARIABLES
#====================================================================

# Current theme information
CURRENT_THEME=""
CURRENT_WALLPAPER=""
WALLPAPER_MODE="0"  # 0=theme, 1=auto, 2=dark, 3=light

# Theme arrays (populated by get_themes function)
declare -a THEME_LIST=()
declare -a THEME_SORT=()
declare -a THEME_WALLPAPERS=()

# Default applications and fonts
DEFAULT_GTK_THEME="Adwaita-dark"
DEFAULT_ICON_THEME="Adwaita"
DEFAULT_CURSOR_THEME="Adwaita"
DEFAULT_CURSOR_SIZE="24"
DEFAULT_FONT="Inter"
DEFAULT_FONT_SIZE="11"
DEFAULT_MONO_FONT="JetBrains Mono"
DEFAULT_MONO_FONT_SIZE="10"

#====================================================================
# UTILITY FUNCTIONS
#====================================================================

# Create necessary directories
init_directories() {
    local dirs=(
        "$THEME_CONFIG_DIR"
        "$THEME_CACHE_DIR" 
        "$THEME_DATA_DIR"
        "$THEME_STATE_DIR"
        "$WALLPAPER_DIR"
        "$THUMBNAIL_DIR"
        "$COLOR_DIR"
        "$TEMPLATE_DIR"
        "$THEMES_DIR"
        "$ICONS_DIR"
        "$FONTS_DIR"
    )
    
    for dir in "${dirs[@]}"; do
        if [ ! -d "$dir" ]; then
            mkdir -p "$dir"
            echo "Created directory: $dir"
        fi
    done
}

# Logging function with different levels
print_log() {
    local level=""
    local section=""
    local status=""
    local message=""
    
    # Parse arguments based on flags
    while [[ $# -gt 0 ]]; do
        case $1 in
            -r) level="\033[31m[ERROR]\033[0m"; shift ;;
            -y) level="\033[33m[WARN]\033[0m"; shift ;;
            -g) level="\033[32m[INFO]\033[0m"; shift ;;
            -b) level="\033[34m[INFO]\033[0m"; shift ;;
            -n) level="[NOTE]"; shift ;;
            -sec) section="[$2]"; shift 2 ;;
            -stat) status="[$2]"; shift 2 ;;
            -warn) level="\033[33m[WARN]\033[0m"; shift ;;
            *) message="$message $1"; shift ;;
        esac
    done
    
    # Print formatted message
    local timestamp="$(date '+%H:%M:%S')"
    echo -e "[$timestamp]${level}${section}${status} $message"
}

# Check if a package/command is installed
pkg_installed() {
    local package="$1"
    
    # Check if command exists in PATH
    if command -v "$package" &>/dev/null; then
        return 0
    fi
    
    # Check flatpak applications
    if command -v flatpak &>/dev/null && flatpak list --app | grep -q "$package"; then
        return 0
    fi
    
    # Check with package manager
    case "$(command -v pacman yum apt dnf zypper 2>/dev/null | head -1)" in
        */pacman) pacman -Qi "$package" &>/dev/null ;;
        */yum) yum list installed "$package" &>/dev/null ;;
        */apt) dpkg -l "$package" &>/dev/null ;;
        */dnf) dnf list installed "$package" &>/dev/null ;;
        */zypper) zypper se -i "$package" &>/dev/null ;;
        *) return 1 ;;
    esac
}

# Generate hash for files (used for caching)
generate_hash() {
    local input="$1"
    
    if [ -f "$input" ]; then
        # Hash file content
        sha256sum "$input" | cut -d' ' -f1 | cut -c1-16
    else
        # Hash string content
        echo -n "$input" | sha256sum | cut -d' ' -f1 | cut -c1-16
    fi
}

# Read configuration value from file
get_config_value() {
    local key="$1"
    local config_file="${2:-$THEME_CONFIG_FILE}"
    local default_value="$3"
    
    if [ -f "$config_file" ]; then
        # Look for key=value format
        local value=$(grep "^${key}=" "$config_file" 2>/dev/null | cut -d'=' -f2- | tr -d '"' | head -1)
        echo "${value:-$default_value}"
    else
        echo "$default_value"
    fi
}

# Set configuration value in file
set_config_value() {
    local key="$1"
    local value="$2"
    local config_file="${3:-$THEME_CONFIG_FILE}"
    
    # Create config file if it doesn't exist
    mkdir -p "$(dirname "$config_file")"
    touch "$config_file"
    
    # Remove existing key and add new value
    grep -v "^${key}=" "$config_file" > "${config_file}.tmp" 2>/dev/null || true
    echo "${key}=\"${value}\"" >> "${config_file}.tmp"
    mv "${config_file}.tmp" "$config_file"
    
    print_log -g "Configuration updated: ${key}=${value}"
}

#====================================================================
# THEME MANAGEMENT FUNCTIONS
#====================================================================

# Get Hyprland configuration value (if Hyprland is running)
get_hypr_config() {
    local key="$1"
    local default_value="$2"
    
    # Check if Hyprland is running
    if [ -n "$HYPRLAND_INSTANCE_SIGNATURE" ] && command -v hyprctl &>/dev/null; then
        case "$key" in
            "GTK_THEME") 
                get_config_value "gtk_theme" "$THEME_CONFIG_FILE" "$DEFAULT_GTK_THEME"
                ;;
            "ICON_THEME")
                get_config_value "icon_theme" "$THEME_CONFIG_FILE" "$DEFAULT_ICON_THEME"
                ;;
            "CURSOR_THEME")
                get_config_value "cursor_theme" "$THEME_CONFIG_FILE" "$DEFAULT_CURSOR_THEME"
                ;;
            "CURSOR_SIZE")
                get_config_value "cursor_size" "$THEME_CONFIG_FILE" "$DEFAULT_CURSOR_SIZE"
                ;;
            "FONT")
                get_config_value "font" "$THEME_CONFIG_FILE" "$DEFAULT_FONT"
                ;;
            "FONT_SIZE")
                get_config_value "font_size" "$THEME_CONFIG_FILE" "$DEFAULT_FONT_SIZE"
                ;;
            "MONOSPACE_FONT")
                get_config_value "mono_font" "$THEME_CONFIG_FILE" "$DEFAULT_MONO_FONT"
                ;;
            "MONOSPACE_FONT_SIZE")
                get_config_value "mono_font_size" "$THEME_CONFIG_FILE" "$DEFAULT_MONO_FONT_SIZE"
                ;;
            "COLOR_SCHEME")
                get_config_value "color_scheme" "$THEME_CONFIG_FILE" "prefer-dark"
                ;;
            *)
                echo "$default_value"
                ;;
        esac
    else
        echo "$default_value"
    fi
}

# Discover available themes
get_themes() {
    THEME_LIST=()
    THEME_SORT=()
    THEME_WALLPAPERS=()
    
    print_log -g "Scanning for available themes..."
    
    # Check if themes directory exists
    if [ ! -d "$THEMES_DIR" ]; then
        print_log -y "Themes directory not found: $THEMES_DIR"
        return 1
    fi
    
    # Find all theme directories
    local theme_count=0
    while IFS= read -r -d '' theme_dir; do
        local theme_name=$(basename "$theme_dir")
        local theme_config="${theme_dir}/theme.conf"
        local theme_wallpaper=""
        
        # Check if theme has a configuration file
        if [ -f "$theme_config" ]; then
            # Try to find a wallpaper for this theme
            local wallpaper_search=(
                "${theme_dir}/wallpaper.*"
                "${theme_dir}/wall.*"
                "${theme_dir}/"*.{jpg,jpeg,png,gif}
            )
            
            for pattern in "${wallpaper_search[@]}"; do
                wallpaper_files=(${pattern})
                if [ -f "${wallpaper_files[0]}" ]; then
                    theme_wallpaper="${wallpaper_files[0]}"
                    break
                fi
            done
            
            # Add theme to arrays
            THEME_LIST+=("$theme_name")
            THEME_SORT+=("$theme_count")
            THEME_WALLPAPERS+=("$theme_wallpaper")
            
            ((theme_count++))
            print_log "Found theme: $theme_name"
        fi
    done < <(find "$THEMES_DIR" -maxdepth 1 -type d -not -path "$THEMES_DIR" -print0)
    
    print_log -g "Found ${#THEME_LIST[@]} themes"
    
    # Set current theme if not already set
    if [ -z "$CURRENT_THEME" ] && [ ${#THEME_LIST[@]} -gt 0 ]; then
        CURRENT_THEME="${THEME_LIST[0]}"
        set_config_value "current_theme" "$CURRENT_THEME"
    fi
}

# Get wallpaper list and hashes for a given path
get_wallpaper_map() {
    local search_paths=("$@")
    local wallpaper_list=()
    local wallpaper_hashes=()
    
    # Find all image files in search paths
    for path in "${search_paths[@]}"; do
        if [ -d "$path" ]; then
            while IFS= read -r -d '' wallpaper; do
                local hash=$(generate_hash "$wallpaper")
                wallpaper_list+=("$wallpaper")
                wallpaper_hashes+=("$hash")
            done < <(find "$path" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" \) -print0)
        fi
    done
    
    # Export arrays for use by calling script
    export WALLPAPER_LIST=("${wallpaper_list[@]}")
    export WALLPAPER_HASHES=("${wallpaper_hashes[@]}")
}

#====================================================================
# CONFIGURATION FILE WRITERS
#====================================================================

# Write TOML-style configuration values
write_toml_config() {
    local config_file="$1"
    local section="$2"
    local key="$3"
    local value="$4"
    
    # Create config file if it doesn't exist
    mkdir -p "$(dirname "$config_file")"
    touch "$config_file"
    
    # Create temporary file for processing
    local temp_file="${config_file}.tmp"
    local section_found=false
    local key_updated=false
    
    # Process existing file
    if [ -s "$config_file" ]; then
        while IFS= read -r line; do
            # Check if we're in the target section
            if [[ "$line" =~ ^\[.*\]$ ]]; then
                local current_section=$(echo "$line" | tr -d '[]')
                if [ "$current_section" = "$section" ]; then
                    section_found=true
                    echo "$line" >> "$temp_file"
                else
                    # If we were in target section and now in a new section,
                    # add the key if it wasn't found
                    if [ "$section_found" = true ] && [ "$key_updated" = false ]; then
                        echo "${key}=${value}" >> "$temp_file"
                        key_updated=true
                    fi
                    section_found=false
                    echo "$line" >> "$temp_file"
                fi
            elif [ "$section_found" = true ] && [[ "$line" =~ ^${key}= ]]; then
                # Update existing key in target section
                echo "${key}=${value}" >> "$temp_file"
                key_updated=true
            else
                echo "$line" >> "$temp_file"
            fi
        done < "$config_file"
    fi
    
    # Add section and key if they don't exist
    if [ "$section_found" = false ]; then
        echo "" >> "$temp_file"
        echo "[$section]" >> "$temp_file"
        echo "${key}=${value}" >> "$temp_file"
    elif [ "$key_updated" = false ]; then
        echo "${key}=${value}" >> "$temp_file"
    fi
    
    # Replace original file
    mv "$temp_file" "$config_file"
}

#====================================================================
# STATE MANAGEMENT
#====================================================================

# Save current state to file
save_state() {
    mkdir -p "$(dirname "$STATE_FILE")"
    
    cat > "$STATE_FILE" << EOF
# Current theme state
# Generated on: $(date)

current_theme="$CURRENT_THEME"
current_wallpaper="$CURRENT_WALLPAPER"
wallpaper_mode="$WALLPAPER_MODE"

# Theme configuration
gtk_theme="$(get_hypr_config "GTK_THEME")"
icon_theme="$(get_hypr_config "ICON_THEME")"
cursor_theme="$(get_hypr_config "CURSOR_THEME")"
cursor_size="$(get_hypr_config "CURSOR_SIZE")"
font="$(get_hypr_config "FONT")"
font_size="$(get_hypr_config "FONT_SIZE")"
mono_font="$(get_hypr_config "MONOSPACE_FONT")"
mono_font_size="$(get_hypr_config "MONOSPACE_FONT_SIZE")"
color_scheme="$(get_hypr_config "COLOR_SCHEME")"
EOF
    
    print_log -g "State saved to: $STATE_FILE"
}

# Load state from file
load_state() {
    if [ -f "$STATE_FILE" ]; then
        source "$STATE_FILE"
        print_log -g "State loaded from: $STATE_FILE"
    else
        print_log -y "No state file found, using defaults"
    fi
}

#====================================================================
# INITIALIZATION
#====================================================================

# Initialize configuration system
init_config_system() {
    print_log -g "Initializing custom theme configuration system..."
    
    # Create necessary directories
    init_directories
    
    # Load existing state
    load_state
    
    # Load user preferences if they exist
    if [ -f "$USER_PREFS_FILE" ]; then
        source "$USER_PREFS_FILE"
        print_log -g "User preferences loaded"
    fi
    
    # Discover available themes
    get_themes
    
    # Get Hyprland window information if available
    if [ -n "$HYPRLAND_INSTANCE_SIGNATURE" ] && command -v hyprctl &>/dev/null; then
        export HYPR_BORDER="$(hyprctl -j getoption decoration:rounding | jq '.int' 2>/dev/null || echo "0")"
        export HYPR_WIDTH="$(hyprctl -j getoption general:border_size | jq '.int' 2>/dev/null || echo "0")"
    else
        export HYPR_BORDER="0"
        export HYPR_WIDTH="0"
    fi
    
    print_log -g "Configuration system initialized"
}

#====================================================================
# EXPORTS AND CLEANUP
#====================================================================

# Export configuration functions for use by other scripts
export -f print_log
export -f pkg_installed
export -f generate_hash
export -f get_config_value
export -f set_config_value
export -f get_hypr_config
export -f get_themes
export -f get_wallpaper_map
export -f write_toml_config
export -f save_state
export -f load_state

# Auto-initialize when sourced (unless NO_AUTO_INIT is set)
if [ -z "$NO_AUTO_INIT" ]; then
    init_config_system
fi
