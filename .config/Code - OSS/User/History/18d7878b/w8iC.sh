#!/usr/bin/env bash

# shellcheck disable=SC2154
# This disables a specific shellcheck warning (SC2154) about variables that appear undefined
# shellcheck is a tool that checks bash scripts for common errors

#=============================================================================
# SECTION 1: VARIABLE SETUP AND INITIALIZATION
#=============================================================================

# Get the directory where this script is located
# $0 is the name/path of the current script
# realpath converts it to an absolute path
# dirname gets just the directory part (removes the filename)
scrDir="$(dirname "$(realpath "$0")")"

# Source (load) the globalcontrol.sh script from the same directory
# This imports functions and variables from that file
# shellcheck disable=SC1091 - disables warning about not being able to follow the source
source "${scrDir}/globalcontrol.sh"

# Check if DENV_THEME variable is set, if not, show error and exit
# [ -z "${DENV_THEME}" ] checks if the variable is empty (zero length)
# && means "and" - if the first condition is true, execute the next commands
# exit 1 means exit with error code 1 (non-zero means error)
[ -z "${DENV_THEME}" ] && echo "ERROR: unable to detect theme" && exit 1

# Call the get_themes function (defined in globalcontrol.sh)
# This populates the thmList array with available themes
get_themes

# Set configuration directory path
# XDG_CONFIG_HOME is a standard environment variable for config location
# If it's not set, use the result of 'xdg-user-dir CONFIG' as fallback
# ${VAR:-default} syntax means "use VAR if set, otherwise use default"
confDir="${XDG_CONFIG_HOME:-$(xdg-user-dir CONFIG)}"

#=============================================================================
# SECTION 2: FUNCTION DEFINITIONS
#=============================================================================

# Function to change theme to next or previous
Theme_Change() {
  # $1 is the first parameter passed to this function
  # 'local' makes this variable only exist within this function
  local x_switch=$1

  # Loop through all indices of the thmList array
  # ${!thmList[@]} expands to all the indices (0, 1, 2, etc.)
  # [@] means "all elements" and ! means "indices of"
  for i in "${!thmList[@]}"; do
    # Check if current theme matches the theme at index i
    # ${thmList[i]} gets the element at index i
    if [ "${thmList[i]}" == "${DENV_THEME}" ]; then
      
      # If switch direction is 'n' (next)
      if [ "${x_switch}" == 'n' ]; then
        # Calculate next index with wraparound
        # ${#thmList[@]} gets the length of the array
        # % is modulo operator (remainder after division)
        # This ensures we wrap around to 0 when we reach the end
        setIndex=$(((i + 1) % ${#thmList[@]}))
        
      # If switch direction is 'p' (previous)
      elif [ "${x_switch}" == 'p' ]; then
        # Simply subtract 1 for previous theme
        setIndex=$((i - 1))
      fi
      
      # Set the new theme based on calculated index
      themeSet="${thmList[setIndex]}"
      
      # Exit the loop since we found our current theme
      break
    fi
  done
}

# Function to clean up and sanitize Hyprland theme configuration
sanitize_hypr_theme() {
  # Function parameters (local to this function)
  input_file="${1}"   # Source file to clean
  output_file="${2}"  # Destination file for cleaned content
  
  # Create a temporary file for processing
  # mktemp creates a unique temporary file
  buffer_file="$(mktemp)"

  # Remove the first line from input file and save to buffer
  # sed '1d' means "delete line 1"
  # > redirects output to the buffer file
  sed '1d' "${input_file}" >"${buffer_file}"
  
  # Define array of regex patterns to remove from the config
  # These are configuration lines that might cause issues
  dirty_regex=(
    "^ *exec"                              # Lines starting with 'exec'
    "^ *decoration[^:]*: *drop_shadow"     # Drop shadow decoration settings
    "^ *drop_shadow"                       # Direct drop shadow settings
    "^ *decoration[^:]*: *shadow *="       # Shadow decoration assignments
    "^ *decoration[^:]*: *col.shadow* *="  # Shadow color assignments
    "^ *shadow_"                           # Any shadow-related settings
    "^ *col.shadow*"                       # Shadow color definitions
  )

  # Add any additional patterns from HYPR_CONFIG_SANITIZE array
  # += appends to the existing array
  dirty_regex+=("${HYPR_CONFIG_SANITIZE[@]}")

  # Loop through each pattern to remove matching lines
  for pattern in "${dirty_regex[@]}"; do
    # Find lines matching the pattern and process each one
    # grep -E uses extended regular expressions
    # | (pipe) sends output to the while loop
    grep -E "${pattern}" "${buffer_file}" | while read -r line; do
      # Remove the matching line from buffer file
      # sed -i edits the file in place
      # \|${line}|d means delete lines matching exactly this line
      sed -i "\|${line}|d" "${buffer_file}"
      
      # Log what was removed (for debugging)
      print_log -sec "theme" -warn "sanitize" "${line}"
    done
  done
  
  # Copy cleaned content to final output file
  cat "${buffer_file}" >"${output_file}"
  
  # Clean up temporary file
  rm -f "${buffer_file}"
}

#=============================================================================
# SECTION 3: COMMAND LINE OPTION PROCESSING
#=============================================================================

# Set default for quiet mode
quiet=false

# Process command line options using getopts
# "qnps:" defines the valid options:
# q = quiet mode (no argument)
# n = next theme (no argument) 
# p = previous theme (no argument)
# s = specific theme (requires argument, indicated by :)
while getopts "qnps:" option; do
  # $option contains the current option being processed
  case $option in

  n) # Handle -n option (next theme)
    Theme_Change n                    # Call function with 'n' parameter
    export xtrans="grow"              # Set transition effect
    ;;

  p) # Handle -p option (previous theme)  
    Theme_Change p                    # Call function with 'p' parameter
    export xtrans="outer"             # Set different transition effect
    ;;

  s) # Handle -s option (specific theme)
    themeSet="$OPTARG"               # OPTARG contains the argument for -s
    ;;
    
  q) # Handle -q option (quiet mode)
    quiet=true                       # Set quiet flag
    ;;
    
  *) # Handle invalid options (anything not defined above)
    echo "... invalid option ..."
    echo "$(basename "${0}") -[option]"    # basename removes path, shows just script name
    echo "n : set next theme"
    echo "p : set previous theme" 
    echo "s : set input theme"
    exit 1                                 # Exit with error
    ;;
  esac
done

#=============================================================================
# SECTION 4: THEME VALIDATION AND CONTROL FILE UPDATE
#=============================================================================

# Validate that the selected theme exists in our theme list
# [[ ]] is an enhanced test command in bash
# =~ is the regex match operator
# " ${thmList[*]} " creates a string with all themes separated by spaces
# If themeSet is not found in the list, fall back to current theme
[[ ! " ${thmList[*]} " =~ " ${themeSet} " ]] && themeSet="${DENV_THEME}"

# Update the configuration file with the new theme
set_conf "DENV_THEME" "${themeSet}"

# Log the theme change
print_log -sec "theme" -stat "apply" "${themeSet}"

# Set reload flag and re-source the global control script
export reload_flag=1
source "${scrDir}/globalcontrol.sh"

#=============================================================================
# SECTION 5: HYPRLAND COMPOSITOR CONFIGURATION
#=============================================================================

# Configure Hyprland (a Wayland compositor)
# Check if we're running under Hyprland by checking for its signature
# [[ -n $VAR ]] checks if variable is not empty
# hyprctl is Hyprland's control utility
# -q means quiet (no output)
[[ -n $HYPRLAND_INSTANCE_SIGNATURE ]] && hyprctl keyword misc:disable_autoreload 1 -q

# Clean and apply the theme configuration
sanitize_hypr_theme "${DENV_THEME_DIR}/hypr.theme" "${XDG_CONFIG_HOME}/hypr/themes/theme.conf"

#=============================================================================
# SECTION 6: THEME COMPONENT EXTRACTION
#=============================================================================

# Extract theme components from Hyprland config
# get_hyprConf is a function that reads configuration values

# Determine GTK theme based on wallpaper dynamic coloring setting
if [ "${enableWallDcol}" -eq 0 ]; then
  # If dynamic coloring is disabled, use theme's specified GTK theme
  GTK_THEME="$(get_hyprConf "GTK_THEME")"
else
  # If dynamic coloring is enabled, use Wallbash theme
  GTK_THEME="Wallbash-Gtk"
fi

# Get other theme components
GTK_ICON="$(get_hyprConf "ICON_THEME")"           # Icon theme name
CURSOR_THEME="$(get_hyprConf "CURSOR_THEME")"     # Mouse cursor theme
font_name="$(get_hyprConf "FONT")"                # Main font family
font_size="$(get_hyprConf "FONT_SIZE")"           # Font size
monospace_font_name="$(get_hyprConf "MONOSPACE_FONT")"  # Monospace font for terminals/code

#=============================================================================
# SECTION 7: ICON THEME EARLY LOADING
#=============================================================================

# Set icon theme immediately using dconf (GNOME configuration system)
# dconf write sets a configuration value
# ! negates the return value - if dconf write fails, the if condition is true
if ! dconf write /org/gnome/desktop/interface/icon-theme "'${GTK_ICON}'"; then
  print_log -sec "theme" -warn "dconf" "failed to set icon theme"
fi

#=============================================================================
# SECTION 8: THEME DIRECTORY RESOLUTION
#=============================================================================

# Handle different Linux distributions and theme locations
# Check if we're on NixOS (which uses /run/current-system structure)
if [ -d /run/current-system/sw/share/themes ]; then
  export themesDir=/run/current-system/sw/share/themes
fi

# If theme isn't in system directory but exists in user directory, link it
# [ ! -d ] checks if directory does NOT exist
if [ ! -d "${themesDir}/${GTK_THEME}" ] && [ -d "$HOME/.themes/${GTK_THEME}" ]; then
  # cp -rns: r=recursive, n=no-clobber, s=symbolic links
  cp -rns "$HOME/.themes/${GTK_THEME}" "${themesDir}/${GTK_THEME}"
fi

#=============================================================================
# SECTION 9: QT5 CONFIGURATION
#=============================================================================

# Configure Qt5 applications using qt5ct tool
# toml_write is a function that writes TOML configuration files

# Set icon theme for Qt5 apps
toml_write "${confDir}/qt5ct/qt5ct.conf" "Appearance" "icon_theme" "${GTK_ICON}"

# Set main font for Qt5 apps (the long string is Qt's font specification format)
toml_write "${confDir}/qt5ct/qt5ct.conf" "Fonts" "general" "\"${font_name},10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1,\""

# Set monospace font for Qt5 apps
toml_write "${confDir}/qt5ct/qt5ct.conf" "Fonts" "fixed" "\"${monospace_font_name},9,-1,5,400,0,0,0,0,0,0,0,0,0,0,1,\""

# Note: Color scheme settings are commented out (lines starting with #)
# toml_write "${confDir}/qt5ct/qt5ct.conf" "Appearance" "color_scheme_path" "${confDir}/qt5ct/colors/colors.conf"
# toml_write "${confDir}/qt5ct/qt5ct.conf" "Appearance" "custom_palette" "true"

#=============================================================================
# SECTION 10: QT6 CONFIGURATION  
#=============================================================================

# Configure Qt6 applications (same as Qt5 but for newer Qt version)
toml_write "${confDir}/qt6ct/qt6ct.conf" "Appearance" "icon_theme" "${GTK_ICON}"
toml_write "${confDir}/qt6ct/qt6ct.conf" "Fonts" "general" "\"${font_name},10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1,\""
toml_write "${confDir}/qt6ct/qt6ct.conf" "Fonts" "fixed" "\"${monospace_font_name},9,-1,5,400,0,0,0,0,0,0,0,0,0,0,1,\""

#=============================================================================
# SECTION 11: KDE PLASMA CONFIGURATION
#=============================================================================

# Configure KDE Plasma desktop environment
toml_write "${confDir}/kdeglobals" "Icons" "Theme" "${GTK_ICON}"              # Icon theme
toml_write "${confDir}/kdeglobals" "General" "TerminalApplication" "${TERMINAL}"  # Default terminal
toml_write "${confDir}/kdeglobals" "UiSettings" "ColorScheme" "colors"       # Color scheme

# Set widget style to Kvantum (a Qt theme engine)
toml_write "${confDir}/kdeglobals" "KDE" "widgetStyle" "kvantum"

# Note: Background color setting is commented out - it's handled by wallbash
# toml_write "${confDir}/kdeglobals" "Colors:View" "BackgroundNormal" "#00000000"

#=============================================================================
# SECTION 12: CURSOR THEME CONFIGURATION
#=============================================================================

# Set default cursor theme in multiple locations for compatibility
# XDG_DATA_HOME is for user-specific data files
toml_write "${XDG_DATA_HOME}/icons/default/index.theme" "Icon Theme" "Inherits" "${CURSOR_THEME}"

# Also set in HOME directory for older applications
toml_write "${HOME}/.icons/default/index.theme" "Icon Theme" "Inherits" "${CURSOR_THEME}"

#=============================================================================
# SECTION 13: GTK2 CONFIGURATION
#=============================================================================

# Configure GTK2 applications using sed (stream editor)
# -i means edit file in place
# -e allows multiple edit commands
# /^pattern/c\replacement means "find lines starting with pattern and replace entire line"

sed -i -e "/^gtk-theme-name=/c\gtk-theme-name=\"${GTK_THEME}\"" \
  -e "/^include /c\include \"$HOME/.gtkrc-2.0.mime\"" \
  -e "/^gtk-cursor-theme-name=/c\gtk-cursor-theme-name=\"${CURSOR_THEME}\"" \
  -e "/^gtk-icon-theme-name=/c\gtk-icon-theme-name=\"${GTK_ICON}\"" "$HOME/.gtkrc-2.0"

#=============================================================================
# SECTION 14: GTK3 CONFIGURATION
#=============================================================================

# Configure GTK3 applications using TOML format
toml_write "${confDir}/gtk-3.0/settings.ini" "Settings" "gtk-theme-name" "${GTK_THEME}"
toml_write "${confDir}/gtk-3.0/settings.ini" "Settings" "gtk-icon-theme-name" "${GTK_ICON}"
toml_write "${confDir}/gtk-3.0/settings.ini" "Settings" "gtk-cursor-theme-name" "${CURSOR_THEME}"
toml_write "${confDir}/gtk-3.0/settings.ini" "Settings" "gtk-font-name" "${font_name} ${font_size}"

#=============================================================================
# SECTION 15: GTK4 CONFIGURATION
#=============================================================================

# Configure GTK4 applications
# Check if the selected theme has GTK4 support
if [ -d "${themesDir}/${GTK_THEME}/gtk-4.0" ]; then
  gtk4Theme="${GTK_THEME}"      # Use the selected theme
else
  gtk4Theme="Wallbash-Gtk"      # Fall back to Wallbash theme
  print_log -sec "theme" -stat "use" "'Wallbash-Gtk' as gtk4 theme"
fi

# Remove old GTK4 config and create symbolic link to theme
rm -rf "${confDir}/gtk-4.0"
ln -s "${themesDir}/${gtk4Theme}/gtk-4.0" "${confDir}/gtk-4.0"

#=============================================================================
# SECTION 16: FLATPAK APPL
