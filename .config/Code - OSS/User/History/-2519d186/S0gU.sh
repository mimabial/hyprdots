#!/usr/bin/env bash

#====================================================================
# Custom Theme Switching Script
# Replaces DENv's themeswitch.sh functionality
# Manages theme switching with wallpaper and color mode support
#====================================================================

# Set script directory and load configuration
SCRIPT_DIR="$(dirname "$(realpath "$0")")"
source "${SCRIPT_DIR}/config_manager.sh"

#====================================================================
# THEME SWITCHING CONFIGURATION
#====================================================================

# Theme switching modes
THEME_MODES=(
    "theme"     # Use theme-defined colors only
    "auto"      # Automatically adjust based on wallpaper brightness
    "dark"      # Force dark mode
    "light"     # Force light mode
)

# Theme selection methods
SELECTION_METHODS=(
    "next"      # Switch to next theme in list
    "prev"      # Switch to previous theme in list
    "random"    # Select random theme
    "menu"      # Show interactive menu
    "specific"  # Switch to specific theme by name
)

#====================================================================
# HELPER FUNCTIONS
#====================================================================

# Display usage information
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS] [THEME_NAME]

Switch between themes with automatic wallpaper and color management.

OPTIONS:
    -n, --next             Switch to next theme
    -p, --prev             Switch to previous theme
    -r, --random           Switch to random theme
    -m, --menu             Show interactive theme selection menu
    -l, --list             List available themes
    -s, --set THEME        Switch to specific theme
    -w, --wallpaper-mode MODE  Set wallpaper color mode
    -t, --toggle-mode      Toggle wallpaper color mode
    --rofi                 Use rofi for theme selection (GUI)
    --preview THEME        Preview theme without applying
    --reload               Reload applications after switching
    --no-wallpaper        Don't change wallpaper when switching theme
    --no-cache            Don't generate cache during theme switch
    -h, --help            Show this help message

WALLPAPER MODES:
    theme      Use colors defined in theme files (mode 0)
    auto       Adapt colors based on wallpaper brightness (mode 1)
    dark       Force dark color scheme (mode 2)
    light      Force light color scheme (mode 3)

EXAMPLES:
    $0 --next                      # Switch to next theme
    $0 --menu                      # Show theme selection menu
    $0 --set "Dark Blue"           # Switch to specific theme
    $0 --wallpaper-mode auto       # Set auto wallpaper mode
    $0 --rofi                      # GUI theme selector
    $0 --preview "Gruvbox" --no-wallpaper  # Preview without wallpaper

THEME STRUCTURE:
    ~/.config/custom-themes/themes/THEME_NAME/
    ├── colors.conf               # Theme color definitions
    ├── wallpaper.jpg            # Default wallpaper (optional)
    ├── theme.conf               # Theme metadata
    └── assets/                  # Additional theme assets
EOF
}

# Get current theme index in the theme list
get_current_theme_index() {
    local current_theme="$1"
    
    get_themes  # Populate THEME_LIST array
    
    for i in "${!THEME_LIST[@]}"; do
        if [ "${THEME_LIST[i]}" = "$current_theme" ]; then
            echo "$i"
            return 0
        fi
    done
    
    echo "0"  # Default to first theme if current not found
}

# Switch to theme by index
switch_to_theme_index() {
    local target_index="$1"
    local apply_wallpaper="${2:-true}"
    local generate_cache="${3:-true}"
    
    get_themes  # Populate THEME_LIST array
    
    if [ ${#THEME_LIST[@]} -eq 0 ]; then
        print_log -r "No themes available"
        return 1
    fi
    
    # Wrap around if index is out of bounds
    if [ "$target_index" -lt 0 ]; then
        target_index=$((${#THEME_LIST[@]} - 1))
    elif [ "$target_index" -ge ${#THEME_LIST[@]} ]; then
        target_index=0
    fi
    
    local target_theme="${THEME_LIST[target_index]}"
    switch_to_theme "$target_theme" "$apply_wallpaper" "$generate_cache"
}

# Switch to next theme
switch_next_theme() {
    local apply_wallpaper="${1:-true}"
    local generate_cache="${2:-true}"
    
    local current_index=$(get_current_theme_index "$CURRENT_THEME")
    local next_index=$((current_index + 1))
    
    switch_to_theme_index "$next_index" "$apply_wallpaper" "$generate_cache"
}

# Switch to previous theme
switch_prev_theme() {
    local apply_wallpaper="${1:-true}"
    local generate_cache="${2:-true}"
    
    local current_index=$(get_current_theme_index "$CURRENT_THEME")
    local prev_index=$((current_index - 1))
    
    switch_to_theme_index "$prev_index" "$apply_wallpaper" "$generate_cache"
}

# Switch to random theme
switch_random_theme() {
    local apply_wallpaper="${1:-true}"
    local generate_cache="${2:-true}"
    
    get_themes  # Populate THEME_LIST array
    
    if [ ${#THEME_LIST[@]} -eq 0 ]; then
        print_log -r "No themes available"
        return 1
    fi
    
    # Get random index, avoiding current theme if possible
    local random_index
    local current_index=$(get_current_theme_index "$CURRENT_THEME")
    
    if [ ${#THEME_LIST[@]} -eq 1 ]; then
        random_index=0
    else
        # Keep trying until we get a different theme
        do
            random_index=$((RANDOM % ${#THEME_LIST[@]}))
        while [ "$random_index" -eq "$current_index" ]
    fi
    
    local target_theme="${THEME_LIST[random_index]}"
    print_log -g "Randomly selected theme: $target_theme"
    
    switch_to_theme_index "$random_index" "$apply_wallpaper" "$generate_cache"
}

# Preview theme without applying
preview_theme() {
    local theme_name="$1"
    
    local theme_dir="${THEMES_DIR}/${theme_name}"
    if [ ! -d "$theme_dir" ]; then
        print_log -r "Theme not found: $theme_name"
        return 1
    fi
    
    print_log -g "Theme Preview: $theme_name"
    print_log "Location: $theme_dir"
    
    # Show theme metadata if available
    local theme_config="${theme_dir}/theme.conf"
    if [ -f "$theme_config" ]; then
        echo ""
        echo "Theme Configuration:"
        while IFS='=' read -r key value; do
            # Skip comments and empty lines
            [[ $key =~ ^[[:space:]]*# ]] && continue
            [[ -z $key ]] && continue
            
            # Clean up key and value
            key=$(echo "$key" | tr -d '"' | tr -d "'")
            value=$(echo "$value" | tr -d '"' | tr -d "'")
            
            echo "  $key: $value"
        done < "$theme_config"
    fi
    
    # Show available wallpapers
    local wallpapers=()
    while IFS= read -r -d '' wallpaper; do
        wallpapers+=("$wallpaper")
    done < <(find "$theme_dir" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" \) -print0 2>/dev/null)
    
    if [ ${#wallpapers[@]} -gt 0 ]; then
        echo ""
        echo "Available wallpapers (${#wallpapers[@]}):"
        for wallpaper in "${wallpapers[@]}"; do
            echo "  $(basename "$wallpaper")"
        done
    fi
    
    # Show color information if available
    local color_file="${theme_dir}/colors.conf"
    if [ -f "$color_file" ]; then
        echo ""
        echo "Color scheme:"
        grep -E "^color_pry[1-4]=" "$color_file" | while IFS='=' read -r key value; do
            value=$(echo "$value" | tr -d '"' | tr -d "'")
            echo "  $key: $value"
        done
    fi
}

# Main theme switching function
switch_to_theme() {
    local theme_name="$1"
    local apply_wallpaper="${2:-true}"
    local generate_cache="${3:-true}"
    local reload_apps="${4:-false}"
    
    if [ -z "$theme_name" ]; then
        print_log -r "No theme name specified"
        return 1
    fi
    
    local theme_dir="${THEMES_DIR}/${theme_name}"
    if [ ! -d "$theme_dir" ]; then
        print_log -r "Theme not found: $theme_name"
        return 1
    fi
    
    print_log -g "Switching to theme: $theme_name"
    
    # Update current theme in configuration
    set_config_value "current_theme" "$theme_name"
    CURRENT_THEME="$theme_name"
    
    # Apply theme wallpaper if requested
    if [ "$apply_wallpaper" = "true" ]; then
        local theme_wallpaper=""
        local theme_wallpapers_dir="${theme_dir}/wallpapers"
        
        # First priority: Check for wallpapers directory
        if [ -d "$theme_wallpapers_dir" ]; then
            # Use first wallpaper from theme wallpapers directory
            while IFS= read -r -d '' wallpaper; do
                theme_wallpaper="$wallpaper"
                break
            done < <(find "$theme_wallpapers_dir" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" \) -print0 2>/dev/null)
        fi
        
        # Second priority: Look for default wallpaper in theme root
        if [ -z "$theme_wallpaper" ]; then
            local wallpaper_files=(
                "${theme_dir}/wallpaper.jpg"
                "${theme_dir}/wallpaper.jpeg"
                "${theme_dir}/wallpaper.png"
                "${theme_dir}/wall.jpg"
                "${theme_dir}/wall.jpeg"
                "${theme_dir}/wall.png"
            )
            
            for wallpaper_file in "${wallpaper_files[@]}"; do
                if [ -f "$wallpaper_file" ]; then
                    theme_wallpaper="$wallpaper_file"
                    break
                fi
            done
        fi
        
        # Third priority: Use any image file in theme directory
        if [ -z "$theme_wallpaper" ]; then
            while IFS= read -r -d '' wallpaper; do
                theme_wallpaper="$wallpaper"
                break
            done < <(find "$theme_dir" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" \) -print0 2>/dev/null)
        fi
        
        if [ -n "$theme_wallpaper" ]; then
            print_log "Applying theme wallpaper: $(basename "$theme_wallpaper")"
            "${SCRIPT_DIR}/wallpaper_manager.sh" --set "$theme_wallpaper" --global
        else
            print_log -y "No wallpaper found for theme: $theme_name"
            print_log "Consider adding wallpapers to: ${theme_wallpapers_dir}/"
        fi
    fi
    
    # Generate cache for theme wallpapers if requested
    if [ "$generate_cache" = "true" ]; then
        print_log "Generating cache for theme wallpapers..."
        "${SCRIPT_DIR}/cache_manager.sh" --theme "$theme_name" &>/dev/null &
    fi
    
    # Apply theme colors
    local theme_colors="${theme_dir}/colors.conf"
    if [ -f "$theme_colors" ]; then
        print_log "Applying theme colors..."
        "${SCRIPT_DIR}/theme_apply.sh" --colors "$theme_colors" $([ "$reload_apps" = "true" ] && echo "--reload")
    else
        print_log -y "No color configuration found for theme: $theme_name"
    fi
    
    # Save current state
    save_state
    
    print_log -g "Theme switch completed: $theme_name"
    
    # Send notification if available
    if command -v notify-send &>/dev/null; then
        local notification_icon="${theme_dir}/icon.png"
        if [ ! -f "$notification_icon" ]; then
            notification_icon="${THEME_CACHE_DIR}/current_thumbnail"
        fi
        
        notify-send "Theme Changed" "$theme_name" -i "$notification_icon" &>/dev/null || true
    fi
}

# Toggle wallpaper color mode
toggle_wallpaper_mode() {
    local current_mode=$(get_config_value "wallpaper_mode" "$THEME_CONFIG_FILE" "0")
    local next_mode=$(((current_mode + 1) % ${#THEME_MODES[@]}))
    
    set_wallpaper_mode "$next_mode"
}

# Set wallpaper color mode
set_wallpaper_mode() {
    local mode="$1"
    
    # Convert mode name to number if necessary
    case "$mode" in
        "theme"|"0") mode=0 ;;
        "auto"|"1") mode=1 ;;
        "dark"|"2") mode=2 ;;
        "light"|"3") mode=3 ;;
        *)
            print_log -r "Invalid wallpaper mode: $mode"
            return 1
            ;;
    esac
    
    if [ "$mode" -lt 0 ] || [ "$mode" -ge ${#THEME_MODES[@]} ]; then
        print_log -r "Invalid wallpaper mode: $mode"
        return 1
    fi
    
    local mode_name="${THEME_MODES[mode]}"
    print_log -g "Setting wallpaper mode: $mode_name"
    
    # Update configuration
    set_config_value "wallpaper_mode" "$mode"
    WALLPAPER_MODE="$mode"
    
    # Reapply current theme with new mode
    if [ -n "$CURRENT_THEME" ]; then
        print_log "Reapplying theme with new wallpaper mode..."
        switch_to_theme "$CURRENT_THEME" "false" "false" "false"
    fi
    
    # Send notification
    if command -v notify-send &>/dev/null; then
        notify-send "Wallpaper Mode" "$mode_name mode activated" &>/dev/null || true
    fi
}

# Show interactive theme menu
show_theme_menu() {
    get_themes  # Populate THEME_LIST array
    
    if [ ${#THEME_LIST[@]} -eq 0 ]; then
        print_log -r "No themes available"
        return 1
    fi
    
    print_log -g "Available themes:"
    echo ""
    
    for i in "${!THEME_LIST[@]}"; do
        local theme="${THEME_LIST[i]}"
        local marker="  "
        
        # Mark current theme
        if [ "$theme" = "$CURRENT_THEME" ]; then
            marker="* "
        fi
        
        echo "$((i + 1)). $marker$theme"
    done
    
    echo ""
    echo "Enter theme number (1-${#THEME_LIST[@]}), 'q' to quit, or 'r' for random:"
    read -r selection
    
    case "$selection" in
        q|Q|quit|exit)
            print_log "Theme selection cancelled"
            return 0
            ;;
        r|R|random)
            switch_random_theme
            ;;
        *)
            if [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -ge 1 ] && [ "$selection" -le ${#THEME_LIST[@]} ]; then
                local theme_index=$((selection - 1))
                switch_to_theme_index "$theme_index"
            else
                print_log -r "Invalid selection: $selection"
                return 1
            fi
            ;;
    esac
}

# Show rofi theme selector
show_rofi_selector() {
    # Check if rofi is available
    if ! command -v rofi &>/dev/null; then
        print_log -r "rofi not found. Please install rofi for GUI selection."
        return 1
    fi
    
    get_themes  # Populate THEME_LIST array
    
    if [ ${#THEME_LIST[@]} -eq 0 ]; then
        print_log -r "No themes available"
        return 1
    fi
    
    # Create rofi entries with preview information
    local rofi_entries=()
    for theme in "${THEME_LIST[@]}"; do
        local theme_dir="${THEMES_DIR}/${theme}"
        local theme_icon="${theme_dir}/icon.png"
        
        # Use thumbnail if no icon available
        if [ ! -f "$theme_icon" ]; then
            local theme_wallpapers=(${theme_dir}/*.{jpg,jpeg,png,gif})
            if [ -f "${theme_wallpapers[0]}" ]; then
                local wallpaper_hash=$(generate_hash "${theme_wallpapers[0]}")
                theme_icon="${THUMBNAIL_DIR}/${wallpaper_hash}.sqre"
            fi
        fi
        
        # Mark current theme
        local theme_label="$theme"
        if [ "$theme" = "$CURRENT_THEME" ]; then
            theme_label="● $theme"
        fi
        
        if [ -f "$theme_icon" ]; then
            rofi_entries+=("${theme_label}\0icon\x1f${theme_icon}")
        else
            rofi_entries+=("$theme_label")
        fi
    done
    
    # Show rofi selector
    local selected=$(printf '%s\n' "${rofi_entries[@]}" | \
        rofi -dmenu \
        -i \
        -p "Select Theme" \
        -theme-str "listview { lines: 8; columns: 1; }" \
        -show-icons \
        -format 's')
    
    if [ -n "$selected" ]; then
        # Remove current theme marker if present
        selected=$(echo "$selected" | sed 's/^● //')
        print_log -g "Selected theme: $selected"
        switch_to_theme "$selected" "true" "true" "true"
    fi
}

#====================================================================
# COMMAND LINE PARSING
#====================================================================

# Parse command line arguments
ACTION=""
THEME_NAME=""
WALLPAPER_MODE_ARG=""
APPLY_WALLPAPER="true"
GENERATE_CACHE="true"
RELOAD_APPS="false"

while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--next)
            ACTION="next"
            shift
            ;;
        -p|--prev)
            ACTION="prev"
            shift
            ;;
        -r|--random)
            ACTION="random"
            shift
            ;;
        -m|--menu)
            ACTION="menu"
            shift
            ;;
        -l|--list)
            ACTION="list"
            shift
            ;;
        -s|--set)
            ACTION="set"
            THEME_NAME="$2"
            shift 2
            ;;
        -w|--wallpaper-mode)
            WALLPAPER_MODE_ARG="$2"
            shift 2
            ;;
        -t|--toggle-mode)
            ACTION="toggle_mode"
            shift
            ;;
        --rofi)
            ACTION="rofi"
            shift
            ;;
        --preview)
            ACTION="preview"
            THEME_NAME="$2"
            shift 2
            ;;
        --reload)
            RELOAD_APPS="true"
            shift
            ;;
        --no-wallpaper)
            APPLY_WALLPAPER="false"
            shift
            ;;
        --no-cache)
            GENERATE_CACHE="false"
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        -*)
            print_log -r "Unknown option: $1"
            show_usage
            exit 1
            ;;
        *)
            if [ -z "$THEME_NAME" ]; then
                ACTION="set"
                THEME_NAME="$1"
            fi
            shift
            ;;
    esac
done

#====================================================================
# MAIN EXECUTION
#====================================================================

# Set wallpaper mode if specified
if [ -n "$WALLPAPER_MODE_ARG" ]; then
    set_wallpaper_mode "$WALLPAPER_MODE_ARG"
fi

# Execute action
case "$ACTION" in
    "next")
        switch_next_theme "$APPLY_WALLPAPER" "$GENERATE_CACHE"
        ;;
    "prev")
        switch_prev_theme "$APPLY_WALLPAPER" "$GENERATE_CACHE"
        ;;
    "random")
        switch_random_theme "$APPLY_WALLPAPER" "$GENERATE_CACHE"
        ;;
    "menu")
        show_theme_menu
        ;;
    "list")
        get_themes
        print_log -g "Available themes (${#THEME_LIST[@]}):"
        for i in "${!THEME_LIST[@]}"; do
            local theme="${THEME_LIST[i]}"
            local marker="  "
            
            if [ "$theme" = "$CURRENT_THEME" ]; then
                marker="* "
            fi
            
            echo "$marker$theme"
        done
        ;;
    "set")
        if [ -z "$THEME_NAME" ]; then
            print_log -r "No theme name specified"
            exit 1
        fi
        switch_to_theme "$THEME_NAME" "$APPLY_WALLPAPER" "$GENERATE_CACHE" "$RELOAD_APPS"
        ;;
    "toggle_mode")
        toggle_wallpaper_mode
        ;;
    "rofi")
        show_rofi_selector
        ;;
    "preview")
        if [ -z "$THEME_NAME" ]; then
            print_log -r "No theme name specified for preview"
            exit 1
        fi
        preview_theme "$THEME_NAME"
        ;;
    *)
        # Default action: show current theme and wallpaper mode
        print_log -g "Current theme: ${CURRENT_THEME:-"Not set"}"
        print_log "Wallpaper mode: ${THEME_MODES[${WALLPAPER_MODE:-0}]}"
        
        if [ -z "$ACTION" ]; then
            echo ""
            echo "Use --help for available options"
        fi
        ;;
esac

exit 0
