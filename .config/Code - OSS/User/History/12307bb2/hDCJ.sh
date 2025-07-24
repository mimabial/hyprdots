#!/usr/bin/env bash

#====================================================================
# Custom Theme Selection Script
# Replaces DENv's theme selection functionality
# Provides interactive theme browsing, preview, and selection
#====================================================================

# Set script directory and load configuration
SCRIPT_DIR="$(dirname "$(realpath "$0")")"
source "${SCRIPT_DIR}/config_manager.sh"

#====================================================================
# THEME SELECTION CONFIGURATION
#====================================================================

# Selection interface modes
SELECTION_MODES=(
    "rofi"          # GUI selection with rofi
    "fzf"           # Terminal fuzzy finder
    "menu"          # Simple numbered menu
    "dmenu"         # dmenu interface
    "grid"          # Grid layout with thumbnails
)

# Display information levels
INFO_LEVELS=(
    "minimal"       # Just theme name
    "basic"         # Name + description
    "detailed"      # Full theme information
    "preview"       # Visual preview with colors
)

# Preview options
PREVIEW_SIZE="400x300"          # Preview window size
PREVIEW_COLUMNS=3               # Number of columns in grid view
SHOW_WALLPAPER_COUNT=5          # Max wallpapers to show in preview

# Global variable for interactive menu selection (avoids subshell issues)
SELECTED_THEME=""

#====================================================================
# HELPER FUNCTIONS
#====================================================================

# Display usage information
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Interactive theme selection and preview system.

OPTIONS:
    -m, --mode MODE         Selection interface mode
    -i, --info LEVEL        Information detail level
    -p, --preview           Show theme preview before selection
    -s, --sort FIELD        Sort themes by field (name, date, author)
    -f, --filter PATTERN    Filter themes by pattern
    -c, --current           Highlight current theme
    --no-wallpapers        Don't show wallpaper previews
    --no-colors            Don't show color previews
    --grid                 Use grid layout (for GUI modes)
    --vertical             Use vertical layout
    --large-previews       Use larger preview images
    --debug               Enable debug output for troubleshooting
    --confirm             Always ask for confirmation before applying (all modes)
    --no-confirm          Never ask for confirmation (apply immediately)
    -q, --quiet            Minimal output
    -h, --help             Show this help message

SELECTION MODES:
    rofi        GUI selection with thumbnails and previews
    fzf         Terminal fuzzy finder with live preview
    menu        Simple numbered selection menu
    dmenu       Minimalist dmenu interface
    grid        Grid layout with visual previews

INFO LEVELS:
    minimal     Show only theme names
    basic       Show name and description
    detailed    Show full theme metadata
    preview     Show colors, wallpapers, and metadata

SORT OPTIONS:
    name        Sort alphabetically by name
    date        Sort by creation/modification date
    author      Sort by theme author
    size        Sort by number of wallpapers

EXAMPLES:
    $0                              # Default rofi selection (applies immediately)
    $0 --mode fzf --preview         # Terminal with preview (applies immediately)
    $0 --mode menu --info detailed  # Detailed menu selection (asks for confirmation)
    $0 --mode rofi --confirm        # Force confirmation even for rofi
    $0 --mode menu --no-confirm     # Apply immediately even for menu
    $0 --filter "dark"              # Show only themes with "dark" in name
    $0 --sort date --current        # Sort by date, highlight current

BEHAVIOR:
    Default:      Menu mode asks for confirmation, GUI modes apply immediately
    --confirm:    Always ask for confirmation (all modes)
    --no-confirm: Never ask for confirmation (all modes apply immediately)
    --quiet:      Only outputs theme name, doesn't apply

ENVIRONMENT VARIABLES:
    ROFI_WALLPAPER_FONT     Font for rofi interface (default: Inter)
    ROFI_WALLPAPER_SCALE    Font size for rofi interface (default: 11)
    THEME_ROFI_OPACITY      Background opacity 0.0-1.0 (default: 0.95)
    THEME_ROFI_BLUR         Enable background blur (true/false)
    THEME_ROFI_COLUMNS      Number of columns in grid (auto-calculated)
    THEME_ROFI_ICON_SIZE    Icon size in pixels (default: 64)
    Enter/Return    Select theme and apply
    Escape         Exit without selection
    Up/Down        Navigate themes
    Left/Right     Navigate themes (grid view)
    Ctrl+P         Toggle preview mode (fzf)
    Ctrl+K/J       Alternative navigation
    Page Up/Down   Fast navigation
EOF
}

# Get theme metadata from theme.conf file
get_theme_metadata() {
    local theme_name="$1"
    local theme_dir="${THEMES_DIR}/${theme_name}"
    local theme_conf="${theme_dir}/theme.conf"
    
    # Initialize default values
    local name="$theme_name"
    local description="No description available"
    local author="Unknown"
    local version="1.0"
    local created="Unknown"
    local wallpapers_count=0
    local colors_available=false
    
    # Read metadata from theme.conf if it exists
    if [ -f "$theme_conf" ]; then
        # Extract values from theme.conf
        name=$(get_config_value "name" "$theme_conf" "$theme_name" | tr -d '"')
        description=$(get_config_value "description" "$theme_conf" "$description" | tr -d '"')
        author=$(get_config_value "author" "$theme_conf" "$author" | tr -d '"')
        version=$(get_config_value "version" "$theme_conf" "$version" | tr -d '"')
        created=$(get_config_value "created" "$theme_conf" "$created" | tr -d '"')
    fi
    
    # Count wallpapers
    local wallpaper_dirs=(
        "${theme_dir}/wallpapers"
        "${theme_dir}"
    )
    
    for wallpaper_dir in "${wallpaper_dirs[@]}"; do
        if [ -d "$wallpaper_dir" ]; then
            wallpapers_count=$(find "$wallpaper_dir" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" \) | wc -l)
            break
        fi
    done
    
    # Check for colors
    if [ -f "${theme_dir}/colors.conf" ]; then
        colors_available=true
    fi
    
    # Export metadata for use by calling functions
    export THEME_META_NAME="$name"
    export THEME_META_DESCRIPTION="$description"
    export THEME_META_AUTHOR="$author"
    export THEME_META_VERSION="$version"
    export THEME_META_CREATED="$created"
    export THEME_META_WALLPAPERS="$wallpapers_count"
    export THEME_META_COLORS="$colors_available"
    export THEME_META_PATH="$theme_dir"
}

# Format theme information based on info level
format_theme_info() {
    local theme_name="$1"
    local info_level="$2"
    local is_current="${3:-false}"
    
    get_theme_metadata "$theme_name"
    
    local current_marker=""
    if [ "$is_current" = "true" ]; then
        current_marker="● "
    fi
    
    case "$info_level" in
        "minimal")
            echo "${current_marker}${THEME_META_NAME}"
            ;;
        "basic")
            printf "%s%-30s %s\n" "$current_marker" "$THEME_META_NAME" "$THEME_META_DESCRIPTION"
            ;;
        "detailed")
            cat << EOF
${current_marker}Theme: $THEME_META_NAME
  Description: $THEME_META_DESCRIPTION
  Author: $THEME_META_AUTHOR
  Version: $THEME_META_VERSION
  Created: $THEME_META_CREATED
  Wallpapers: $THEME_META_WALLPAPERS
  Colors: $([ "$THEME_META_COLORS" = "true" ] && echo "Available" || echo "Not available")
  Path: $THEME_META_PATH
EOF
            ;;
        "preview")
            format_theme_preview "$theme_name"
            ;;
    esac
}

# Generate theme preview with colors and wallpaper info
format_theme_preview() {
    local theme_name="$1"
    local theme_dir="${THEMES_DIR}/${theme_name}"
    
    get_theme_metadata "$theme_name"
    
    echo "╭─ $THEME_META_NAME ─────────────────────────────────────"
    echo "│ $THEME_META_DESCRIPTION"
    echo "│ by $THEME_META_AUTHOR (v$THEME_META_VERSION)"
    echo "├─ Colors ─────────────────────────────────────────────"
    
    # Show color palette if available
    local colors_file="${theme_dir}/colors.conf"
    if [ -f "$colors_file" ]; then
        local primary_colors=()
        while IFS='=' read -r key value; do
            if [[ "$key" =~ ^color_pry[1-4]$ ]]; then
                value=$(echo "$value" | tr -d '"' | tr -d "'")
                primary_colors+=("$value")
            fi
        done < "$colors_file"
        
        if [ ${#primary_colors[@]} -gt 0 ]; then
            printf "│ Colors: "
            for color in "${primary_colors[@]}"; do
                printf "#%s " "$color"
            done
            echo ""
        else
            echo "│ Colors: Configuration available"
        fi
    else
        echo "│ Colors: Not configured"
    fi
    
    echo "├─ Wallpapers ─────────────────────────────────────────"
    echo "│ Count: $THEME_META_WALLPAPERS wallpapers"
    
    # Show sample wallpapers
    local wallpaper_dirs=(
        "${theme_dir}/wallpapers"
        "${theme_dir}"
    )
    
    local wallpaper_count=0
    for wallpaper_dir in "${wallpaper_dirs[@]}"; do
        if [ -d "$wallpaper_dir" ]; then
            while IFS= read -r -d '' wallpaper_file && [ $wallpaper_count -lt $SHOW_WALLPAPER_COUNT ]; do
                local wallpaper_name=$(basename "$wallpaper_file")
                echo "│   $wallpaper_name"
                ((wallpaper_count++))
            done < <(find "$wallpaper_dir" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" \) -print0 2>/dev/null)
            break
        fi
    done
    
    if [ $wallpaper_count -eq 0 ]; then
        echo "│   No wallpapers found"
    elif [ $wallpaper_count -eq $SHOW_WALLPAPER_COUNT ] && [ $THEME_META_WALLPAPERS -gt $SHOW_WALLPAPER_COUNT ]; then
        echo "│   ... and $((THEME_META_WALLPAPERS - SHOW_WALLPAPER_COUNT)) more"
    fi
    
    echo "╰───────────────────────────────────────────────────────"
}

# Filter themes based on pattern
filter_themes() {
    local filter_pattern="$1"
    local themes=("${@:2}")
    local filtered_themes=()
    
    if [ -z "$filter_pattern" ]; then
        printf '%s\n' "${themes[@]}"
        return
    fi
    
    for theme in "${themes[@]}"; do
        get_theme_metadata "$theme"
        
        # Check if pattern matches name, description, or author
        if [[ "$THEME_META_NAME" =~ $filter_pattern ]] || \
           [[ "$THEME_META_DESCRIPTION" =~ $filter_pattern ]] || \
           [[ "$THEME_META_AUTHOR" =~ $filter_pattern ]]; then
            filtered_themes+=("$theme")
        fi
    done
    
    printf '%s\n' "${filtered_themes[@]}"
}

# Sort themes by specified field
sort_themes() {
    local sort_field="$1"
    local themes=("${@:2}")
    
    case "$sort_field" in
        "name")
            printf '%s\n' "${themes[@]}" | sort
            ;;
        "date")
            # Sort by theme directory modification time
            for theme in "${themes[@]}"; do
                local theme_dir="${THEMES_DIR}/${theme}"
                local mod_time=$(stat -c %Y "$theme_dir" 2>/dev/null || echo "0")
                echo "$mod_time:$theme"
            done | sort -n -r | cut -d: -f2
            ;;
        "author")
            # Sort by author name
            for theme in "${themes[@]}"; do
                get_theme_metadata "$theme"
                echo "$THEME_META_AUTHOR:$theme"
            done | sort | cut -d: -f2
            ;;
        "size")
            # Sort by number of wallpapers
            for theme in "${themes[@]}"; do
                get_theme_metadata "$theme"
                printf "%03d:%s\n" "$THEME_META_WALLPAPERS" "$theme"
            done | sort -n -r | cut -d: -f2
            ;;
        *)
            printf '%s\n' "${themes[@]}"
            ;;
    esac
}

# Show rofi theme selector with previews
show_rofi_selector() {
    local themes=("$@")
    local info_level="${INFO_LEVEL:-basic}"
    local show_previews="${SHOW_PREVIEWS:-true}"
    
    # Check if rofi is available
    if ! command -v rofi &>/dev/null; then
        print_log -r "rofi not found. Please install rofi for GUI selection."
        return 1
    fi
    
    print_log "Preparing rofi theme selector..."
    
    # Prepare rofi entries with theme information and icons
    local rofi_entries=()
    local theme_data=()
    
    for theme in "${themes[@]}"; do
        local is_current=false
        if [ "$theme" = "$CURRENT_THEME" ]; then
            is_current=true
        fi
        
        get_theme_metadata "$theme"
        
        # Create rich theme entry with metadata
        local theme_entry=""
        local current_marker=""
        if [ "$is_current" = "true" ]; then
            current_marker="● "
        fi
        
        case "$info_level" in
            "minimal")
                theme_entry="${current_marker}${THEME_META_NAME}"
                ;;
            "basic")
                theme_entry="${current_marker}${THEME_META_NAME}\\n<span alpha='60%' size='small'>${THEME_META_DESCRIPTION}</span>"
                ;;
            "detailed")
                local wallpaper_info="${THEME_META_WALLPAPERS} wallpapers"
                local author_info="by ${THEME_META_AUTHOR}"
                theme_entry="${current_marker}${THEME_META_NAME}\\n<span alpha='60%' size='small'>${THEME_META_DESCRIPTION}</span>\\n<span alpha='40%' size='x-small'>${author_info} • ${wallpaper_info}</span>"
                ;;
        esac
        
        # Find theme icon or create one
        local theme_icon=""
        local theme_dir="${THEMES_DIR}/${theme}"
        
        # Priority order for icons
        local icon_candidates=(
            "${theme_dir}/icon.png"
            "${theme_dir}/icon.jpg"
            "${theme_dir}/logo.png"
            "${theme_dir}/logo.jpg"
        )
        
        # Check for existing theme icon
        for icon_candidate in "${icon_candidates[@]}"; do
            if [ -f "$icon_candidate" ]; then
                theme_icon="$icon_candidate"
                break
            fi
        done
        
        # If no icon found, use wallpaper thumbnail
        if [ -z "$theme_icon" ]; then
            local wallpaper_dirs=(
                "${theme_dir}/wallpapers"
                "${theme_dir}"
            )
            
            for wallpaper_dir in "${wallpaper_dirs[@]}"; do
                if [ -d "$wallpaper_dir" ]; then
                    local first_wallpaper=$(find "$wallpaper_dir" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" \) | head -1)
                    if [ -n "$first_wallpaper" ]; then
                        local wallpaper_hash=$(generate_hash "$first_wallpaper")
                        local thumbnail_path="${THUMBNAIL_DIR}/${wallpaper_hash}.sqre"
                        
                        # Generate thumbnail if it doesn't exist
                        if [ ! -f "$thumbnail_path" ] && command -v magick &>/dev/null; then
                            print_log "Generating thumbnail for $theme..."
                            magick "$first_wallpaper" -resize "300x300^" -gravity center -extent "300x300" "$thumbnail_path" &>/dev/null || true
                        fi
                        
                        if [ -f "$thumbnail_path" ]; then
                            theme_icon="$thumbnail_path"
                        else
                            theme_icon="$first_wallpaper"
                        fi
                        break
                    fi
                fi
            done
        fi
        
        # Create rofi entry with icon and markup
        if [ -n "$theme_icon" ] && [ -f "$theme_icon" ]; then
            rofi_entries+=("${theme_entry}\0icon\x1f${theme_icon}\0info\x1f${theme}\0markup-rows\x1ftrue")
        else
            rofi_entries+=("${theme_entry}\0info\x1f${theme}\0markup-rows\x1ftrue")
        fi
        
        theme_data+=("$theme")
    done
    
    # Get monitor information for proper sizing
    local monitor_width=1920
    local monitor_height=1080
    if [ -n "$HYPRLAND_INSTANCE_SIGNATURE" ] && command -v hyprctl &>/dev/null; then
        local monitor_info=$(hyprctl monitors -j | jq '.[] | select(.focused==true)' 2>/dev/null || echo '{}')
        if [ "$monitor_info" != "{}" ]; then
            monitor_width=$(echo "$monitor_info" | jq -r '.width // 1920')
            monitor_height=$(echo "$monitor_info" | jq -r '.height // 1080')
        fi
    fi
    
    # Calculate optimal dimensions
    local theme_count=${#themes[@]}
    local columns=3
    local lines=4
    
    # Adjust layout based on theme count and screen size
    if [ $theme_count -le 3 ]; then
        columns=$theme_count
        lines=1
    elif [ $theme_count -le 6 ]; then
        columns=3
        lines=2
    elif [ $theme_count -le 9 ]; then
        columns=3
        lines=3
    elif [ $theme_count -le 12 ]; then
        columns=4
        lines=3
    else
        columns=4
        lines=$(( (theme_count + 3) / 4 ))
        if [ $lines -gt 5 ]; then
            lines=5
        fi
    fi
    
    # Calculate window size (responsive)
    local window_width=$((monitor_width * 60 / 100))  # 60% of screen width
    local window_height=$((monitor_height * 70 / 100)) # 70% of screen height
    
    # Ensure minimum and maximum sizes
    if [ $window_width -lt 800 ]; then window_width=800; fi
    if [ $window_width -gt 1400 ]; then window_width=1400; fi
    if [ $window_height -lt 500 ]; then window_height=500; fi
    if [ $window_height -gt 900 ]; then window_height=900; fi
    
    # Font and styling configuration
    local font_name="${ROFI_WALLPAPER_FONT:-Inter}"
    local font_size="${ROFI_WALLPAPER_SCALE:-11}"
    local bg_opacity="${THEME_ROFI_OPACITY:-0.95}"
    local icon_size="${THEME_ROFI_ICON_SIZE:-64}"
    
    # Override columns if specified
    if [ -n "$THEME_ROFI_COLUMNS" ] && [[ "$THEME_ROFI_COLUMNS" =~ ^[0-9]+$ ]]; then
        columns="$THEME_ROFI_COLUMNS"
        lines=$(( (theme_count + columns - 1) / columns ))
        if [ $lines -gt 5 ]; then lines=5; fi
    fi
    
    # Create beautiful rofi theme with customizable options
    local rofi_theme="
* {
    background-color: transparent;
    text-color: #eceff4;
    font: \"${font_name} ${font_size}\";
}

window {
    background-color: rgba(46, 52, 64, ${bg_opacity});
    border: 2px solid rgba(136, 192, 208, 0.8);
    border-radius: 12px;
    width: ${window_width}px;
    height: ${window_height}px;
    location: center;
    anchor: center;
}

mainbox {
    background-color: transparent;
    padding: 20px;
    spacing: 15px;
}

inputbar {
    background-color: rgba(67, 76, 94, 0.8);
    border: 1px solid rgba(136, 192, 208, 0.5);
    border-radius: 8px;
    padding: 12px 16px;
    margin: 0px 0px 10px 0px;
    children: [ prompt, entry ];
}

prompt {
    background-color: transparent;
    text-color: rgba(136, 192, 208, 1);
    font: \"${font_name} Bold ${font_size}\";
    margin: 0px 10px 0px 0px;
}

entry {
    background-color: transparent;
    text-color: #eceff4;
    placeholder: \"Search themes...\";
    placeholder-color: rgba(236, 239, 244, 0.5);
}

listview {
    background-color: transparent;
    columns: ${columns};
    lines: ${lines};
    spacing: 8px;
    cycle: true;
    dynamic: true;
    scrollbar: true;
}

scrollbar {
    background-color: rgba(67, 76, 94, 0.5);
    handle-color: rgba(136, 192, 208, 0.7);
    border-radius: 4px;
    handle-width: 8px;
}

element {
    background-color: rgba(59, 66, 82, 0.6);
    border: 1px solid rgba(76, 86, 106, 0.3);
    border-radius: 8px;
    padding: 12px;
    spacing: 8px;
    orientation: vertical;
}

element normal.normal {
    background-color: rgba(59, 66, 82, 0.4);
    text-color: #eceff4;
}

element normal.active {
    background-color: rgba(143, 188, 187, 0.8);
    text-color: #2e3440;
    border-color: rgba(143, 188, 187, 1);
}

element selected.normal {
    background-color: rgba(136, 192, 208, 0.9);
    text-color: #2e3440;
    border-color: rgba(136, 192, 208, 1);
    border-width: 2px;
}

element selected.active {
    background-color: rgba(163, 190, 140, 0.9);
    text-color: #2e3440;
    border-color: rgba(163, 190, 140, 1);
}

element-icon {
    size: ${icon_size}px;
    margin: 0px 0px 8px 0px;
    border-radius: 6px;
}

element-text {
    background-color: transparent;
    text-color: inherit;
    horizontal-align: 0.5;
    vertical-align: 0.5;
}

message {
    background-color: rgba(191, 97, 106, 0.8);
    border: 1px solid rgba(191, 97, 106, 1);
    border-radius: 6px;
    padding: 8px;
    margin: 0px 0px 10px 0px;
}

textbox {
    background-color: transparent;
    text-color: #eceff4;
}
"
    
    # Show rofi with enhanced styling
    local selected_index
    selected_index=$(printf '%s\n' "${rofi_entries[@]}" | \
        rofi -dmenu \
        -i \
        -p "🎨 Select Theme" \
        -theme-str "$rofi_theme" \
        -show-icons \
        -markup-rows \
        -format 'i' \
        -selected-row 0 \
        -kb-accept-entry "Return,KP_Enter" \
        -kb-cancel "Escape,Control+c" \
        -kb-row-up "Up,Control+p,Control+k" \
        -kb-row-down "Down,Control+n,Control+j" \
        -kb-row-left "Left,Control+h" \
        -kb-row-right "Right,Control+l" \
        -kb-page-prev "Page_Up,Control+b" \
        -kb-page-next "Page_Down,Control+f")
    
    # Return selected theme
    if [ -n "$selected_index" ] && [ "$selected_index" -ge 0 ] && [ "$selected_index" -lt ${#theme_data[@]} ]; then
        local selected_theme="${theme_data[$selected_index]}"
        SELECTED_THEME="$selected_theme"
        return 0
    fi
    
    return 1
}

# Show fzf theme selector with live preview
show_fzf_selector() {
    local themes=("$@")
    local info_level="${INFO_LEVEL:-basic}"
    
    # Check if fzf is available
    if ! command -v fzf &>/dev/null; then
        print_log -r "fzf not found. Please install fzf for fuzzy selection."
        return 1
    fi
    
    # Prepare fzf input
    local fzf_input=""
    for theme in "${themes[@]}"; do
        local is_current=false
        if [ "$theme" = "$CURRENT_THEME" ]; then
            is_current=true
        fi
        
        local theme_info
        theme_info=$(format_theme_info "$theme" "$info_level" "$is_current")
        fzf_input+="$theme_info|$theme"$'\n'
    done
    
    # Set up preview command
    local preview_cmd=""
    if [ "${SHOW_PREVIEWS:-true}" = "true" ]; then
        preview_cmd="echo {2} | xargs -I {} $0 --preview-theme {}"
    fi
    
    # Show fzf selector
    local selection
    selection=$(echo "$fzf_input" | fzf \
        --delimiter='|' \
        --with-nth=1 \
        --preview="$preview_cmd" \
        --preview-window=right:50% \
        --header="Select theme (Tab: preview, Enter: select)" \
        --height=80% \
        --border \
        --info=inline)
    
    if [ -n "$selection" ]; then
        echo "$selection" | cut -d'|' -f2
        return 0
    fi
    
    return 1
}

# Show simple numbered menu
show_menu_selector() {
    local themes=("$@")
    local info_level="${INFO_LEVEL:-basic}"
    
    # Use a global variable to return the result instead of echo
    SELECTED_THEME=""
    
    # Use a loop instead of recursion to avoid return value issues
    while true; do
        echo ""
        print_log -g "Available themes:"
        echo ""
        
        # Display themes with numbers
        for i in "${!themes[@]}"; do
            local theme="${themes[i]}"
            local is_current=false
            if [ "$theme" = "$CURRENT_THEME" ]; then
                is_current=true
            fi
            
            local theme_info
            theme_info=$(format_theme_info "$theme" "$info_level" "$is_current")
            
            printf "%3d. %s\n" "$((i + 1))" "$theme_info"
            
            # Add spacing for detailed view
            if [ "$info_level" = "detailed" ] || [ "$info_level" = "preview" ]; then
                echo ""
            fi
        done
        
        echo ""
        echo "Commands:"
        echo "  1-${#themes[@]}     Select theme by number"
        echo "  p<num>     Preview theme (e.g., p1, p2)"
        echo "  i          Change info level (minimal/basic/detailed/preview)"
        echo "  r          Refresh theme list"
        echo "  q          Quit without selection"
        echo ""
        printf "Selection: "
        read -r selection
        
        case "$selection" in
            q|Q|quit|exit)
                return 1
                ;;
            r|R|refresh)
                # Refresh will just continue the loop and redisplay
                print_log "Refreshing theme list..."
                continue
                ;;
            i|I|info)
                # Cycle through info levels
                case "$info_level" in
                    "minimal") info_level="basic" ;;
                    "basic") info_level="detailed" ;;
                    "detailed") info_level="preview" ;;
                    "preview") info_level="minimal" ;;
                esac
                print_log "Info level: $info_level"
                continue
                ;;
            p*)
                # Preview mode
                local preview_num=$(echo "$selection" | sed 's/^[pP]//')
                if [[ "$preview_num" =~ ^[0-9]+$ ]] && [ "$preview_num" -ge 1 ] && [ "$preview_num" -le ${#themes[@]} ]; then
                    local preview_theme="${themes[$((preview_num - 1))]}"
                    echo ""
                    print_log -g "Preview: $preview_theme"
                    echo ""
                    format_theme_preview "$preview_theme"
                    echo ""
                    read -p "Press Enter to continue..." -r
                else
                    print_log -r "Invalid preview number: $preview_num (must be 1-${#themes[@]})"
                    read -p "Press Enter to continue..." -r
                fi
                continue
                ;;
            *)
                # Theme selection
                if [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -ge 1 ] && [ "$selection" -le ${#themes[@]} ]; then
                    local selected_theme="${themes[$((selection - 1))]}"
                    SELECTED_THEME="$selected_theme"
                    return 0
                else
                    print_log -r "Invalid selection: '$selection' (must be 1-${#themes[@]}, p<num>, i, r, or q)"
                    read -p "Press Enter to continue..." -r
                fi
                continue
                ;;
        esac
    done
}

# Show dmenu selector (minimal interface)
show_dmenu_selector() {
    local themes=("$@")
    
    # Check if dmenu is available
    if ! command -v dmenu &>/dev/null; then
        print_log -r "dmenu not found. Please install dmenu for minimal GUI selection."
        return 1
    fi
    
    # Prepare simple theme list
    local dmenu_input=""
    for theme in "${themes[@]}"; do
        local marker=""
        if [ "$theme" = "$CURRENT_THEME" ]; then
            marker="● "
        fi
        dmenu_input+="${marker}${theme}"$'\n'
    done
    
    # Show dmenu
    local selection
    selection=$(echo "$dmenu_input" | dmenu -i -p "Theme:")
    
    if [ -n "$selection" ]; then
        # Remove current marker if present
        selection=$(echo "$selection" | sed 's/^● //')
        echo "$selection"
        return 0
    fi
    
    return 1
}

# Preview theme (used internally and for external preview)
preview_theme_internal() {
    local theme_name="$1"
    
    if [ -z "$theme_name" ]; then
        echo "No theme specified for preview"
        return 1
    fi
    
    if [ ! -d "${THEMES_DIR}/${theme_name}" ]; then
        echo "Theme not found: $theme_name"
        return 1
    fi
    
    format_theme_preview "$theme_name"
}

# Main theme selection function
select_theme() {
    local selection_mode="${1:-rofi}"
    local info_level="${2:-basic}"
    local sort_field="${3:-name}"
    local filter_pattern="$4"
    local show_current="${5:-true}"
    
    # Clear the global variable
    SELECTED_THEME=""
    
    if [ "${DEBUG:-false}" = "true" ]; then
        print_log "DEBUG: select_theme called with mode=$selection_mode, info=$info_level"
        print_log "DEBUG: Current THEME_LIST has ${#THEME_LIST[@]} items: ${THEME_LIST[*]}"
    fi
    
    # Get all available themes (use existing THEME_LIST if already populated)
    if [ ${#THEME_LIST[@]} -eq 0 ]; then
        if [ "${DEBUG:-false}" = "true" ]; then
            print_log "DEBUG: THEME_LIST empty, calling get_themes"
        fi
        get_themes
    fi
    
    if [ ${#THEME_LIST[@]} -eq 0 ]; then
        print_log -r "No themes found in ${THEMES_DIR}"
        return 1
    fi
    
    if [ "${DEBUG:-false}" = "true" ]; then
        print_log "DEBUG: Found ${#THEME_LIST[@]} themes: ${THEME_LIST[*]}"
    fi
    
    # Filter themes if pattern specified
    local filtered_themes=()
    if [ -n "$filter_pattern" ]; then
        if [ "${DEBUG:-false}" = "true" ]; then
            print_log "DEBUG: Filtering themes with pattern: '$filter_pattern'"
        fi
        readarray -t filtered_themes < <(filter_themes "$filter_pattern" "${THEME_LIST[@]}")
    else
        filtered_themes=("${THEME_LIST[@]}")
    fi
    
    if [ ${#filtered_themes[@]} -eq 0 ]; then
        print_log -r "No themes match filter: $filter_pattern"
        return 1
    fi
    
    if [ "${DEBUG:-false}" = "true" ]; then
        print_log "DEBUG: After filtering: ${#filtered_themes[@]} themes: ${filtered_themes[*]}"
    fi
    
    # Sort themes
    if [ "${DEBUG:-false}" = "true" ]; then
        print_log "DEBUG: Sorting themes by: $sort_field"
    fi
    readarray -t sorted_themes < <(sort_themes "$sort_field" "${filtered_themes[@]}")
    
    if [ "${DEBUG:-false}" = "true" ]; then
        print_log "DEBUG: After sorting: ${sorted_themes[*]}"
        print_log "DEBUG: Calling ${selection_mode} selector with ${#sorted_themes[@]} themes"
    fi
    
    # Show appropriate selector
    case "$selection_mode" in
        "rofi")
            local rofi_result
            rofi_result=$(show_rofi_selector "${sorted_themes[@]}")
            if [ $? -eq 0 ] && [ -n "$rofi_result" ]; then
                SELECTED_THEME="$rofi_result"
                return 0
            fi
            ;;
        "fzf")
            local fzf_result
            fzf_result=$(show_fzf_selector "${sorted_themes[@]}")
            if [ $? -eq 0 ] && [ -n "$fzf_result" ]; then
                SELECTED_THEME="$fzf_result"
                return 0
            fi
            ;;
        "menu")
            if [ "${DEBUG:-false}" = "true" ]; then
                print_log "DEBUG: About to call show_menu_selector with themes: ${sorted_themes[*]}"
            fi
            # Call function directly and get result from global variable
            show_menu_selector "${sorted_themes[@]}"
            local menu_exit_code=$?
            if [ $menu_exit_code -eq 0 ] && [ -n "$SELECTED_THEME" ]; then
                return 0
            fi
            ;;
        "dmenu")
            local dmenu_result
            dmenu_result=$(show_dmenu_selector "${sorted_themes[@]}")
            if [ $? -eq 0 ] && [ -n "$dmenu_result" ]; then
                SELECTED_THEME="$dmenu_result"
                return 0
            fi
            ;;
        *)
            print_log -r "Unknown selection mode: $selection_mode"
            return 1
            ;;
    esac
    
    return 1
}

#====================================================================
# COMMAND LINE PARSING
#====================================================================

# Parse command line arguments
SELECTION_MODE="rofi"
INFO_LEVEL="basic"
SORT_FIELD="name"
FILTER_PATTERN=""
SHOW_CURRENT="true"
SHOW_PREVIEWS="true"
FORCE_CONFIRM=""  # empty=default, "true"=always confirm, "false"=never confirm
ACTION="select"

while [[ $# -gt 0 ]]; do
    case $1 in
        -m|--mode)
            SELECTION_MODE="$2"
            shift 2
            ;;
        -i|--info)
            INFO_LEVEL="$2"
            shift 2
            ;;
        -p|--preview)
            SHOW_PREVIEWS="true"
            shift
            ;;
        -s|--sort)
            SORT_FIELD="$2"
            shift 2
            ;;
        -f|--filter)
            FILTER_PATTERN="$2"
            shift 2
            ;;
        -c|--current)
            SHOW_CURRENT="true"
            shift
            ;;
        --no-wallpapers)
            SHOW_WALLPAPERS="false"
            shift
            ;;
        --no-colors)
            SHOW_COLORS="false"
            shift
            ;;
        --grid)
            LAYOUT="grid"
            shift
            ;;
        --vertical)
            LAYOUT="vertical"
            shift
            ;;
        --large-previews)
            PREVIEW_SIZE="600x450"
            shift
            ;;
        --preview-theme)
            ACTION="preview"
            PREVIEW_THEME="$2"
            shift 2
            ;;
        --debug)
            DEBUG="true"
            shift
            ;;
        --confirm)
            FORCE_CONFIRM="true"
            shift
            ;;
        --no-confirm)
            FORCE_CONFIRM="false"
            shift
            ;;
        -q|--quiet)
            QUIET="true"
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
            # If no action specified, treat as theme name to preview
            if [ -z "$ACTION" ] || [ "$ACTION" = "select" ]; then
                ACTION="preview"
                PREVIEW_THEME="$1"
            fi
            shift
            ;;
    esac
done

#====================================================================
# MAIN EXECUTION
#====================================================================

# Validate selection mode
if [[ ! " ${SELECTION_MODES[*]} " =~ " $SELECTION_MODE " ]]; then
    print_log -r "Invalid selection mode: $SELECTION_MODE"
    print_log "Available modes: ${SELECTION_MODES[*]}"
    exit 1
fi

# Validate info level
if [[ ! " ${INFO_LEVELS[*]} " =~ " $INFO_LEVEL " ]]; then
    print_log -r "Invalid info level: $INFO_LEVEL"
    print_log "Available levels: ${INFO_LEVELS[*]}"
    exit 1
fi

# Execute action
case "$ACTION" in
    "select")
        if [ "${DEBUG:-false}" = "true" ]; then
            print_log "DEBUG: Starting theme selection with mode=$SELECTION_MODE"
            print_log "DEBUG: Parameters: info=$INFO_LEVEL, sort=$SORT_FIELD, filter='$FILTER_PATTERN'"
        fi
        
        # Call select_theme directly to avoid subshell issues with interactive functions
        select_theme "$SELECTION_MODE" "$INFO_LEVEL" "$SORT_FIELD" "$FILTER_PATTERN" "$SHOW_CURRENT"
        exit_code=$?
        
        # Get the selected theme from the function
        selected_theme="$SELECTED_THEME"
        
        if [ "${DEBUG:-false}" = "true" ]; then
            print_log "DEBUG: select_theme function completed with exit code $exit_code"
            print_log "DEBUG: Selected theme: '$selected_theme'"
        fi
        
        if [ $exit_code -eq 0 ] && [ -n "$selected_theme" ]; then
            if [ "${QUIET:-false}" = "false" ]; then
                print_log -g "Selected theme: $selected_theme"
                
                # Determine if we should ask for confirmation
                local should_confirm=false
                if [ "$FORCE_CONFIRM" = "true" ]; then
                    should_confirm=true
                elif [ "$FORCE_CONFIRM" = "false" ]; then
                    should_confirm=false
                elif [ "$SELECTION_MODE" = "menu" ]; then
                    # Default behavior: only confirm in menu mode
                    should_confirm=true
                fi
                
                if [ "$should_confirm" = "true" ]; then
                    echo ""
                    printf "Apply theme '%s'? [Y/n]: " "$selected_theme"
                    read -r apply_response
                    if [[ ! $apply_response =~ ^[Nn]$ ]]; then
                        print_log "Applying theme..."
                        if "${SCRIPT_DIR}/theme_switch.sh" --set "$selected_theme"; then
                            print_log -g "Theme '$selected_theme' applied successfully!"
                        else
                            print_log -r "Failed to apply theme '$selected_theme'"
                            exit 1
                        fi
                    else
                        print_log "Theme selection cancelled"
                    fi
                else
                    # Apply immediately without confirmation
                    print_log "Applying theme..."
                    if "${SCRIPT_DIR}/theme_switch.sh" --set "$selected_theme"; then
                        print_log -g "Theme '$selected_theme' applied successfully!"
                    else
                        print_log -r "Failed to apply theme '$selected_theme'"
                        exit 1
                    fi
                fi
            else
                # In quiet mode, just output the selected theme name
                echo "$selected_theme"
            fi
        else
            if [ "${QUIET:-false}" = "false" ]; then
                print_log "No theme selected (exit code: $exit_code)"
            fi
            exit 1
        fi
        ;;
    "preview")
        if [ -n "$PREVIEW_THEME" ]; then
            preview_theme_internal "$PREVIEW_THEME"
        else
            print_log -r "No theme specified for preview"
            exit 1
        fi
        ;;
    *)
        print_log -r "Unknown action: $ACTION"
        exit 1
        ;;
esac

exit 0
