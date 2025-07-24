#!/usr/bin/env bash
# This line tells the system to run this script using bash shell
# The "#!/usr/bin/env bash" is called a "shebang" - it specifies which interpreter to use

# shellcheck disable=SC1091
# This comment tells shellcheck (a bash linting tool) to ignore a specific warning
# SC1091 warns about sourcing files that shellcheck can't find

# =============================================================================
# XDG BASE DIRECTORY SPECIFICATION SETUP
# =============================================================================
# XDG stands for "X Desktop Group" - these are standard directories for Linux
# The "${VARIABLE:-default}" syntax means: "use VARIABLE if it exists, otherwise use default"

# Main configuration directory (where apps store their config files)
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"

# Data directory (where apps store their data files)
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"

# Cache directory (where apps store temporary/cache files)
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"

# State directory (where apps store state information)
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"

# Runtime directory (for temporary files that need to persist during session)
# $(id -u) gets the current user's ID number
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

# The next line is commented out because it causes issues (see GitHub link)
# ! export XDG_DATA_DIRS="$XDG_DATA_HOME/denv:/usr/local/share/denv/:/usr/share/denv/:$XDG_DATA_DIRS" # Causes issues https://github.com/DENv-Project/DENv/issues/308#issuecomment-2691229673

# =============================================================================
# HYDE-SPECIFIC ENVIRONMENT VARIABLES
# =============================================================================
# These variables define where DENv (the desktop environment) stores its files

# DENv's main configuration directory
export HYDE_CONFIG_HOME="${XDG_CONFIG_HOME}/denv"

# DENv's data directory
export HYDE_DATA_HOME="${XDG_DATA_HOME}/denv"

# DENv's cache directory
export HYDE_CACHE_HOME="${XDG_CACHE_HOME}/denv"

# DENv's state directory
export HYDE_STATE_HOME="${XDG_STATE_HOME}/denv"

# DENv's runtime directory
export HYDE_RUNTIME_DIR="${XDG_RUNTIME_DIR}/denv"

# Directory for storing icon files
export ICONS_DIR="${XDG_DATA_HOME}/icons"

# Directory for storing font files
export FONTS_DIR="${XDG_DATA_HOME}/fonts"

# Directory for storing theme files
export THEMES_DIR="${XDG_DATA_HOME}/themes"

#legacy denv envs // should be deprecated

# =============================================================================
# LEGACY HYDE ENVIRONMENT VARIABLES
# =============================================================================
# These are older variable names that should be deprecated but are kept for compatibility
# "Deprecated" means they're old and shouldn't be used in new code, but kept for backward compatibility

export confDir="${XDG_CONFIG_HOME:-$HOME/.config}"    # Legacy: main config directory
export denvConfDir="$HYDE_CONFIG_HOME"                # Legacy: DENv config directory
export cacheDir="$HYDE_CACHE_HOME"                    # Legacy: cache directory
export thmbDir="$HYDE_CACHE_HOME/thumbs"              # Legacy: thumbnails directory
export dcolDir="$HYDE_CACHE_HOME/dcols"               # Legacy: dynamic colors directory
export iconsDir="$ICONS_DIR"                          # Legacy: icons directory
export themesDir="$THEMES_DIR"                        # Legacy: themes directory
export fontsDir="$FONTS_DIR"                          # Legacy: fonts directory
export hashMech="sha1sum"                             # Legacy: hash mechanism (for file checksums)

# =============================================================================
# FUNCTION: get_hashmap
# =============================================================================
# This function creates a "hash map" of wallpapers - it scans directories for image files
# and creates a list of their SHA1 hashes (unique fingerprints) and file paths
# This is used to track and manage wallpaper files efficiently

get_hashmap() {
    # "unset" removes these variables if they existed before, giving us a clean start
    unset wallHash    # Array to store file hashes (unique fingerprints)
    unset wallList    # Array to store file paths
    unset skipStrays  # Flag to skip directories without wallpapers
    unset filetypes   # Variable for file types (currently unused)

    # Nested function to list supported file extensions
    list_extensions() {
        # "local" makes variables only exist within this function
        # This is an array (list) of supported image/video file extensions
        local supported_files=(
            "gif"     # Animated images
            "jpg"     # JPEG images
            "jpeg"    # JPEG images (alternative extension)
            "png"     # PNG images
            "${WALLPAPER_FILETYPES[@]}"  # Additional types from environment variable
        )
        
        # If user has defined custom filetypes, use those instead
        # The -n test checks if a variable is not empty
        if [ -n "${WALLPAPER_OVERRIDE_FILETYPES}" ]; then
            supported_files=("${WALLPAPER_OVERRIDE_FILETYPES[@]}")
        fi

        # Create find command options for each file type
        # printf outputs each extension in the format needed for find command
        # The "sed" command removes the trailing " -o " from the last item
        printf -- "-iname \"*.%s\" -o " "${supported_files[@]}" | sed 's/ -o $//'
    }

    # Nested function to find wallpaper files in a directory
    find_wallpapers() {
        local wallSource="$1"  # Get the directory path from first parameter

        # Check if the directory path is empty
        if [ -z "${wallSource}" ]; then
            print_log -err "ERROR: wallSource is empty"  # Log error message
            return 1  # Return with error code (1 = failure, 0 = success)
        fi

        # Build the find command to search for image files
        # This is a complex command built as a string:
        # - find: search for files
        # - -type f: only find regular files (not directories)
        # - \( ... \): group the file type conditions
        # - ! -path "*/logo/*": exclude files in "logo" directories
        # - -exec "${hashMech}" {} +: run hash command on found files
        local find_command
        find_command="find \"${wallSource}\" -type f \\( $(list_extensions) \\) ! -path \"*/logo/*\" -exec \"${hashMech}\" {} +"

        # If debug logging is enabled, show the command being run
        [ "${LOG_LEVEL}" == "debug" ] && print_log -g "DEBUG:" -b "Running command:" "${find_command}"

        # Create a temporary file to capture error messages
        tmpfile=$(mktemp)  # mktemp creates a unique temporary file
        
        # Run the find command:
        # - eval executes the command string
        # - 2>"$tmpfile": redirect error messages to temp file
        # - | sort -k2: sort results by filename (second column)
        eval "${find_command}" 2>"$tmpfile" | sort -k2
        
        # Read any error messages and clean up temp file
        error_output=$(<"$tmpfile") && rm -f "$tmpfile"  # $(<file) reads file content
        
        # If there were errors, log them
        [ -n "${error_output}" ] && print_log -err "ERROR:" -b "found an error: " -r "${error_output}" -y " skipping..."
    }

    # Main loop: process each directory passed as parameter to this function
    # "$@" represents all parameters passed to the function
    for wallSource in "$@"; do

        # Debug logging: show what parameter we're processing
        [ "${LOG_LEVEL}" == "debug" ] && print_log -g "DEBUG:" -b "arg:" "${wallSource}"

        # Skip empty parameters
        [ -z "${wallSource}" ] && continue
        
        # Handle special flags passed as parameters
        [ "${wallSource}" == "--no-notify" ] && no_notify=1 && continue    # Don't show notifications
        [ "${wallSource}" == "--skipstrays" ] && skipStrays=1 && continue  # Skip dirs without wallpapers
        [ "${wallSource}" == "--verbose" ] && verboseMap=1 && continue     # Show detailed output

        # Convert relative path to absolute path
        wallSource="$(realpath "${wallSource}")"

        # Check if the directory/file actually exists
        # The || syntax means "if the previous command fails, do this"
        [ -e "${wallSource}" ] || {
            print_log -err "ERROR:" -b "wallpaper source does not exist:" "${wallSource}" -y " skipping..."
            continue  # Skip to next iteration of the loop
        }

        # Debug logging: show the resolved path
        [ "${LOG_LEVEL}" == "debug" ] && print_log -g "DEBUG:" -b "wallSource path:" "${wallSource}"

        # Get the hash map (list of hashes and file paths) for this directory
        hashMap=$(find_wallpapers "${wallSource}")

        # If no wallpapers were found in this directory
        if [ -z "${hashMap}" ]; then
            no_wallpapers+=("${wallSource}")  # Add to list of directories without wallpapers
            print_log -warn "No compatible wallpapers found in: " "${wallSource}"
            continue  # Skip to next directory
        fi

        # Process each line of the hash map
        # Each line contains: "hash filename"
        # The <<< syntax feeds the string to the while loop
        while read -r hash image; do
            wallHash+=("${hash}")    # Add hash to array
            wallList+=("${image}")   # Add image path to array
        done <<<"${hashMap}"
    done

    # Report directories that had no compatible wallpapers
    if [ "${#no_wallpapers[@]}" -gt 0 ]; then
        # "${#array[@]}" gets the length of an array
        print_log -warn "No compatible wallpapers found in:" "${no_wallpapers[*]}"
        # Note: "${array[*]}" joins all array elements with spaces
    fi

    # Check if we found any wallpapers at all
    # [[ ]] is an enhanced version of [ ] with more features
    if [ -z "${#wallList[@]}" ] || [[ "${#wallList[@]}" -eq 0 ]]; then
        if [[ "${skipStrays}" -eq 1 ]]; then
            return 1  # Return failure but don't exit the script
        else
            echo "ERROR: No image found in any source"
            # Send desktop notification if not disabled
            [ -n "${no_notify}" ] && notify-send -a "DENv Alert" "WARNING: No compatible wallpapers found in: ${no_wallpapers[*]}"
            exit 1  # Exit the entire script with error
        fi
    fi

    # If verbose mode is enabled, show the complete hash map
    if [[ "${verboseMap}" -eq 1 ]]; then
        echo "// Hash Map //"
        # Loop through array indices
        # "${!array[@]}" gives you the indices of the array
        for indx in "${!wallHash[@]}"; do
            echo ":: \${wallHash[${indx}]}=\"${wallHash[indx]}\" :: \${wallList[${indx}]}=\"${wallList[indx]}\""
        done
    fi
}

# =============================================================================
# FUNCTION: get_themes
# =============================================================================
# This function scans for available themes and sorts them
# It also fixes broken symbolic links to wallpapers

# shellcheck disable=SC2120
# This comment tells shellcheck to ignore warning about function not using parameters
get_themes() {
    # Clear any existing theme data
    unset thmSortS  # Array for theme sort orders (temporary)
    unset thmListS  # Array for theme names (temporary)
    unset thmWallS  # Array for theme wallpapers (temporary)
    unset thmSort   # Array for final sorted theme sort orders
    unset thmList   # Array for final sorted theme names
    unset thmWall   # Array for final sorted theme wallpapers

    # First pass: collect all theme information
    # The < <(...) syntax is called "process substitution" - it treats command output like a file
    while read -r thmDir; do
        # realWallPath will store the actual file that wall.set points to
        local realWallPath
        
        # readlink shows where a symbolic link points to
        # A symbolic link is like a shortcut - it points to another file
        realWallPath="$(readlink "${thmDir}/wall.set")"
        
        # Check if the file that the symbolic link points to actually exists
        if [ ! -e "${realWallPath}" ]; then
            # If the link is broken, fix it by finding wallpapers in the theme directory
            get_hashmap "${thmDir}" --skipstrays || continue  # Skip this theme if no wallpapers found
            echo "fixing link :: ${thmDir}/wall.set"
            # Create new symbolic link to the first wallpaper found
            # ln -fs: f=force (overwrite existing), s=symbolic
            ln -fs "${wallList[0]}" "${thmDir}/wall.set"
        fi
        
        # Read the sort order for this theme (if .sort file exists)
        # head -1 reads just the first line
        # The && || syntax: if first command succeeds do second, otherwise do third
        [ -f "${thmDir}/.sort" ] && thmSortS+=("$(head -1 "${thmDir}/.sort")") || thmSortS+=("0")
        
        # Store the wallpaper path
        thmWallS+=("${realWallPath}")
        
        # Get just the theme name (directory name without full path)
        # ${variable##*/} removes everything up to and including the last /
        # This is faster than using basename command
        thmListS+=("${thmDir##*/}")
        
    # Find all theme directories (exactly 1 level deep)
    done < <(find "${HYDE_CONFIG_HOME}/themes" -mindepth 1 -maxdepth 1 -type d)

    # Second pass: sort themes by their sort order and name
    # This uses process substitution with paste command to combine arrays
    while IFS='|' read -r sort theme wall; do
        # IFS='|' sets the field separator to | for this read command
        thmSort+=("${sort}")   # Add to final sorted arrays
        thmList+=("${theme}")
        thmWall+=("${wall}")
    # paste combines multiple inputs column by column
    # printf creates one line per array element
    # sort -n -k 1 -k 2: sort numerically by first column, then by second column
    done < <(paste -d '|' <(printf "%s\n" "${thmSortS[@]}") <(printf "%s\n" "${thmListS[@]}") <(printf "%s\n" "${thmWallS[@]}") | sort -n -k 1 -k 2)
    
    #! The commented line below shows an alternative using GNU parallel, but it's overkill and slower
    #!  done < <(parallel --link echo "{1}\|{2}\|{3}" ::: "${thmSortS[@]}" ::: "${thmListS[@]}" ::: "${thmWallS[@]}" | sort -n -k 1 -k 2) # This is overkill and slow
    
    # If verbose mode requested, show all theme information
    if [ "${1}" == "--verbose" ]; then
        echo "// Theme Control //"
        for indx in "${!thmList[@]}"; do
            # echo -e enables interpretation of backslash escapes (like \n for newline)
            echo -e ":: \${thmSort[${indx}]}=\"${thmSort[indx]}\" :: \${thmList[${indx}]}=\"${thmList[indx]}\" :: \${thmWall[${indx}]}=\"${thmWall[indx]}\""
        done
    fi
}

# =============================================================================
# LOAD CONFIGURATION FILES
# =============================================================================
# Source (load) various configuration files if they exist
# "source" or "." runs the commands in another file in the current shell context

# Load runtime environment variables
[ -f "${HYDE_RUNTIME_DIR}/environment" ] && source "${HYDE_RUNTIME_DIR}/environment"

# Load state configuration
[ -f "$HYDE_STATE_HOME/staterc" ] && source "$HYDE_STATE_HOME/staterc"

# Load main configuration
[ -f "$HYDE_STATE_HOME/config" ] && source "$HYDE_STATE_HOME/config"

# =============================================================================
# VALIDATE AND SET DEFAULT VALUES
# =============================================================================

# Validate enableWallDcol variable (should be 0, 1, 2, or 3)
case "${enableWallDcol}" in
0 | 1 | 2 | 3) ;;  # Valid values - do nothing
*) enableWallDcol=0 ;;  # Invalid value - set to default (0)
esac

# Set default theme if none is set or if the theme directory doesn't exist
if [ -z "${HYDE_THEME}" ] || [ ! -d "${HYDE_CONFIG_HOME}/themes/${HYDE_THEME}" ]; then
    get_themes          # Load available themes
    HYDE_THEME="${thmList[0]}"  # Use the first theme as default
fi

# Set up theme-related variables
HYDE_THEME_DIR="${HYDE_CONFIG_HOME}/themes/${HYDE_THEME}"  # Current theme directory

# Array of directories where wallbash scripts might be located
# wallbash scripts are used to apply wallpaper-based color schemes
wallbashDirs=(
    "${HYDE_CONFIG_HOME}/wallbash"        # User's personal wallbash directory
    "${XDG_DATA_HOME}/denv/wallbash"       # User's data wallbash directory
    "/usr/local/share/denv/wallbash"       # System-wide local wallbash directory
    "/usr/share/denv/wallbash"             # System-wide wallbash directory
)

# Export variables so they're available to other scripts and programs
export HYDE_THEME \
    HYDE_THEME_DIR \
    wallbashDirs \
    enableWallDcol

# =============================================================================
# HYPRLAND-SPECIFIC VARIABLES
# =============================================================================
# Get border and width settings from Hyprland (if running under Hyprland)

# Check if we're running under Hyprland window manager
# HYPRLAND_INSTANCE_SIGNATURE is set by Hyprland when it's running
if [ -n "$HYPRLAND_INSTANCE_SIGNATURE" ]; then
    # Get border rounding value from Hyprland configuration
    # hyprctl is Hyprland's control utility
    # -j flag requests JSON output
    # jq is a tool for processing JSON data
    # .int extracts the integer value from the JSON
    hypr_border="$(hyprctl -j getoption decoration:rounding | jq '.int')"
    
    # Get border width value from Hyprland configuration
    hypr_width="$(hyprctl -j getoption general:border_size | jq '.int')"

    # Set default values if the variables are empty
    # ${variable:-default} syntax provides fallback values
    export hypr_border=${hypr_border:-0}
    export hypr_width=${hypr_width:-0}
fi

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

# Function to check if a package is installed
pkg_installed() {
    local pkgIn=$1  # Get package name from first parameter
    
    # Try multiple ways to check if package is installed:
    
    # Method 1: Check if command exists in PATH
    # command -v checks if a command exists without running it
    # &>/dev/null redirects all output to nowhere (silence it)
    if command -v "${pkgIn}" &>/dev/null; then
        return 0  # Package found
    # Method 2: Check if it's a Flatpak application
    elif command -v "flatpak" &>/dev/null && flatpak info "${pkgIn}" &>/dev/null; then
        return 0  # Package found via Flatpak
    # Method 3: Use Hyde's package manager script to query
    elif denv-shell pm.sh pq "${pkgIn}" &>/dev/null; then
        return 0  # Package found via Hyde's package manager
    else
        return 1  # Package not found
    fi
}

# Function to detect which AUR (Arch User Repository) helper is installed
get_aurhlpr() {
    # Check for yay (Yet Another Yaourt)
    if pkg_installed yay; then
        aurhlpr="yay"
    # Check for paru (Paru is a AUR helper)
    elif pkg_installed paru; then
        # shellcheck disable=SC2034
        # This comment tells shellcheck to ignore "unused variable" warning
        aurhlpr="paru"
    fi
}

# Function to set configuration values in the state file
set_conf() {
    local varName="${1}"   # Variable name to set
    local varData="${2}"   # Value to set
    
    # Create the state file if it doesn't exist
    touch "${XDG_STATE_HOME}/denv/staterc"

    # Check if the variable already exists in the file
    # grep -c counts the number of matches
    # ^${varName}= looks for lines starting with "varName="
    if [ "$(grep -c "^${varName}=" "${XDG_STATE_HOME}/denv/staterc")" -eq 1 ]; then
        # Variable exists - update it
        # sed -i edits the file in place
        # /pattern/c replaces the entire line that matches pattern
        sed -i "/^${varName}=/c${varName}=\"${varData}\"" "${XDG_STATE_HOME}/denv/staterc"
    else
        # Variable doesn't exist - add it
        # >> appends to the end of the file
        echo "${varName}=\"${varData}\"" >>"${XDG_STATE_HOME}/denv/staterc"
    fi
}

# Function to calculate hash (unique fingerprint) of a file
set_hash() {
    local hashImage="${1}"  # File path to hash
    # Run hash command and extract just the hash value (first field)
    # awk '{print $1}' prints the first column
    "${hashMech}" "${hashImage}" | awk '{print $1}'
}

# Function for colored logging output
print_log() {
    # Loop through all parameters passed to this function
    while (("$#")); do  # While there are still parameters to process
        case "$1" in    # Check the first parameter
        # Color codes for different types of messages
        -r | +r)  # Red color
            echo -ne "\e[31m$2\e[0m" >&2  # \e[31m = red, \e[0m = reset color
            shift 2  # Remove two parameters (flag and text)
            ;;
        -g | +g)  # Green color
            echo -ne "\e[32m$2\e[0m" >&2
            shift 2
            ;;
        -y | +y)  # Yellow color
            echo -ne "\e[33m$2\e[0m" >&2
            shift 2
            ;;
        -b | +b)  # Blue color
            echo -ne "\e[34m$2\e[0m" >&2
            shift 2
            ;;
        -m | +m)  # Magenta color
            echo -ne "\e[35m$2\e[0m" >&2
            shift 2
            ;;
        -c | +c)  # Cyan color
            echo -ne "\e[36m$2\e[0m" >&2
            shift 2
            ;;
        -wt | +w)  # White color
            echo -ne "\e[37m$2\e[0m" >&2
            shift 2
            ;;
        -n | +n)  # Neon/bright cyan
            echo -ne "\e[96m$2\e[0m" >&2
            shift 2
            ;;
        -stat)  # Status message (dark text on cyan background)
            echo -ne "\e[4;30;46m $2 \e[0m :: " >&2
            shift 2
            ;;
        -crit)  # Critical message (dark text on red background)
            echo -ne "\e[30;41m $2 \e[0m :: " >&2
            shift 2
            ;;
        -warn)  # Warning message (dark text on yellow background)
            echo -ne "WARNING :: \e[30;43m $2 \e[0m :: " >&2
            shift 2
            ;;
        +)  # Custom color (specify color number)
            echo -ne "\e[38;5;$2m$3\e[0m" >&2  # \e[38;5;Nm sets 256-color mode
            shift 3  # Remove three parameters (flag, color number, text)
            ;;
        -sec)  # Section header (green brackets)
            echo -ne "\e[32m[$2] \e[0m" >&2
            shift 2
            ;;
        -err)  # Error message (underlined red)
            echo -ne "ERROR :: \e[4;31m$2 \e[0m" >&2  # \e[4m = underline
            shift 2
            ;;
        *)  # Default case - print text as-is
            echo -ne "$1" >&2
            shift  # Remove one parameter
            ;;
        esac
    done
    echo "" >&2  # Print a newline at the end
    # Note: >&2 sends output to stderr (error stream) instead of stdout
}

# Function to check if required packages are installed
check_package() {
    # Create lock file directory
    local lock_file="${XDG_RUNTIME_DIR:-/tmp}/denv/__package.lock"
    mkdir -p "${XDG_RUNTIME_DIR:-/tmp}/denv"

    # If lock file exists, assume packages were already checked
    if [ -f "$lock_file" ]; then
        return 0  # Exit successfully
    fi

    # Check each package passed as parameter
    for pkg in "$@"; do
        if ! pkg_installed "${pkg}"; then
            print_log -err "Package is not installed" "'${pkg}'"
            rm -f "$lock_file"  # Remove lock file
            exit 1  # Exit with error
        fi
    done

    # Create lock file to indicate packages are installed
    touch "$lock_file"
}

# =============================================================================
# FUNCTION: get_hyprConf
# =============================================================================

# OPTIMIZED Function to get configuration values from Hyprland theme files
# This function tries multiple methods to extract config values, with fallbacks
# PERFORMANCE IMPROVEMENTS: Reads file once, uses single awk calls instead of pipes
get_hyprConf() {
    # Get function parameters
    local hyVar="${1}"        # First parameter: variable name to search for
    local file="${2:-"$HYDE_THEME_DIR/hypr.theme"}"  # Second parameter: file path (with default)
    
    # The "${2:-default}" syntax means: use $2 if it exists, otherwise use "default"
    
    # ===== METHOD 1: Try using 'hyq' tool (fastest method) =====
    # Check if 'hyq' command exists and is available
    if command -v hyq &>/dev/null; then
        # 'command -v' checks if a command exists
        # '&>/dev/null' redirects both stdout and stderr to nowhere (silence output)
        
        local hyq_result  # Declare local variable to store result
        
        # Try hyq with source option (-s) for accurate results
        # The query looks for variables like "$VARIABLE_NAME"
        hyq_result=$(hyq -s --query "\$${hyVar}" "${file}" 2>/dev/null)
        # '$()' captures command output into variable
        # '2>/dev/null' redirects error messages to nowhere
        
        # If the result is empty, try without source option
        if [ -z "${hyq_result}" ]; then
            # '[ -z "string" ]' tests if string is empty
            hyq_result=$(hyq --query "\$${hyVar}" "${file}" 2>/dev/null)
        fi
        
        # If we got a result, print it and exit successfully
        if [ -n "${hyq_result}" ]; then
            # '[ -n "string" ]' tests if string is NOT empty
            echo "${hyq_result}" && return 0
            # 'return 0' means success, 'return 1' would mean failure
        fi
    fi

    # ===== OPTIMIZATION: Read file once into memory =====
    # Instead of reading the file multiple times in different methods,
    # read it once and store in a variable for all subsequent processing
    local file_content
    file_content=$(cat "${file}" 2>/dev/null)
    
    # If file doesn't exist or can't be read, skip file-based methods
    if [ -z "${file_content}" ]; then
        # Jump directly to fallback methods that don't need this file
        local gsVal=""  # Set empty to trigger fallback logic
    else
        # ===== METHOD 2: OPTIMIZED - Single awk call instead of grep|cut|sed pipeline =====
        # BEFORE: grep "pattern" file | cut -d '=' -f2 | sed 's/pattern//'  (3 processes + 2 pipes)
        # AFTER:  single awk command (1 process, much faster)
        local gsVal
        gsVal=$(echo "${file_content}" | awk -v var="${hyVar}" '
            # awk script explanation:
            # -v var="${hyVar}" passes the variable name into awk as "var"
            # $0 is the entire line, ~ means "matches pattern"
            $0 ~ "^[[:space:]]*\\$" var "[[:space:]]*=" {
                # Found a line like: $VARIABLE = value
                # Remove everything up to and including the = sign
                sub(/^[[:space:]]*\$[^=]*=[[:space:]]*/, "")
                # Remove trailing whitespace
                sub(/[[:space:]]*$/, "")
                # Print the cleaned value and exit (first match wins)
                print
                exit
            }
        ')
        
        # If we found a value and it doesn't start with $, use it
        if [ -n "${gsVal}" ] && [[ "${gsVal}" != \$* ]]; then
            # '[[ string != pattern ]]' is pattern matching
            # '\$*' means "starts with $ followed by anything"
            echo "${gsVal}" && return 0
        fi
        
        # ===== METHOD 3: OPTIMIZED - Map variables to gsettings keys =====
        # Create an associative array (like a dictionary/hash map)
        declare -A gsMap=(
            [GTK_THEME]="gtk-theme"
            [ICON_THEME]="icon-theme"
            [COLOR_SCHEME]="color-scheme"
            [CURSOR_THEME]="cursor-theme"
            [CURSOR_SIZE]="cursor-size"
            [FONT]="font-name"
            [DOCUMENT_FONT]="document-font-name"
            [MONOSPACE_FONT]="monospace-font-name"
            [FONT_SIZE]="font-size"
            [DOCUMENT_FONT_SIZE]="document-font-size"
            [MONOSPACE_FONT_SIZE]="monospace-font-size"
        )

        # Try to parse gsettings commands if our variable maps to a gsettings key
        if [[ -n "${gsMap[$hyVar]}" ]]; then
            # Check if our variable exists in the gsMap array
            # OPTIMIZATION: Use the file_content we already read, single awk call
            gsVal=$(echo "${file_content}" | awk -F"[\"']" -v gskey="${gsMap[$hyVar]}" '
                # awk script explanation:
                # -F sets field separator to quotes (single or double)
                # -v gskey passes the gsettings key into awk
                # Look for lines like: exec = gsettings set org.gnome.desktop.interface gtk-theme "value"
                $0 ~ "^[[:space:]]*exec[[:space:]]*=[[:space:]]*gsettings[[:space:]]*set[[:space:]]*org.gnome.desktop.interface[[:space:]]*" gskey "[[:space:]]*" {
                    # Found matching gsettings line
                    # $2 contains the value between quotes (due to field separator)
                    last = $2
                }
                END {
                    # Print the last match found (in case there are multiple)
                    if (last) print last
                }
            ')
            
            # Breaking down this optimized awk command:
            # 1. We pass the gsettings key as a variable to avoid complex string concatenation
            # 2. We use the file_content we already read instead of reading file again
            # 3. Single awk process instead of the original complex pipeline
        fi
    fi

    # ===== METHOD 4: OPTIMIZED Final fallbacks =====
    # If still no value found, or if value starts with $
    if [ -z "${gsVal}" ] || [[ "${gsVal}" == \$* ]]; then
        # Use a case statement to handle special variables
        case "${hyVar}" in
            "CODE_THEME") 
                echo "Wallbash"    # Hardcoded default
                ;;
            "SDDM_THEME") 
                echo ""            # Empty default
                ;;
            *)  
                # For all other variables, search in multiple config files
                # OPTIMIZATION: REPLACED grep|cut|sed|head PIPELINE WITH SINGLE AWK
                # 
                # ORIGINAL CODE (SLOW - 4 processes + 3 pipes):
                # grep "^[[:space:]]*\$default.${hyVar}\s*=" \
                #     "file1" "file2" "file3" "file4" "file5" "file6" 2>/dev/null |
                #     cut -d '=' -f2 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | head -n 1
                #
                # NEW CODE (FAST - 1 process, 0 pipes):
                
                # Array of possible config file locations
                local config_files=(
                    "XDG_DATA_HOME/denv/denv.conf"
                    "$XDG_DATA_HOME/denv/hyprland.conf"
                    "/usr/local/share/denv/denv.conf"
                    "/usr/local/share/denv/hyprland.conf"
                    "/usr/share/denv/denv.conf"
                    "/usr/share/denv/hyprland.conf"
                )
                
                # Single awk call replaces the entire grep|cut|sed|head pipeline
                awk -v var="${hyVar}" '
                    # Look for lines like: $default.VARIABLE = value
                    $0 ~ "^[[:space:]]*\\$default\\." var "[[:space:]]*=" {
                        # Remove everything up to and including the = sign
                        sub(/^[[:space:]]*\$default\.[^=]*=[[:space:]]*/, "")
                        # Remove trailing whitespace  
                        sub(/[[:space:]]*$/, "")
                        # Print the value and exit immediately (replaces head -n 1)
                        print
                        exit
                    }
                ' "${config_files[@]}" 2>/dev/null
                
                # Why this awk approach is much faster:
                # BEFORE: grep reads all files → cut processes all matches → sed cleans all → head takes first
                # AFTER:  awk reads files sequentially and exits on FIRST match (no unnecessary processing)
                ;;
        esac
    else
        # If we found a value through gsettings parsing, use it
        echo "${gsVal}"
    fi
}

# =============================================================================
# FUNCTION: get_rofi_pos
# =============================================================================
# This function calculates where to position rofi (application launcher) based on cursor position

get_rofi_pos() {
    # Get current cursor position as array
    # readarray reads lines into an array
    # -t removes trailing newlines
    # < <(...) is process substitution - treats command output like a file
    readarray -t curPos < <(hyprctl cursorpos -j | jq -r '.x,.y')
    
    # Get monitor information and extract relevant values
    # eval executes the string as shell commands
    # This complex command gets monitor resolution, scale, position, and reserved areas
    eval "$(hyprctl -j monitors | jq -r '.[] | select(.focused==true) |
        "monRes=(\(.width) \(.height) \(.scale) \(.x) \(.y)) offRes=(\(.reserved | join(" ")))"')"

    # Convert scale factor from decimal to integer (remove decimal point)
    # ${variable//find/replace} replaces all occurrences
    monRes[2]="${monRes[2]//./}"
    
    # Adjust resolution for scale factor
    # $(( )) is arithmetic expansion for math calculations
    monRes[0]=$((monRes[0] * 100 / monRes[2]))  # Adjust width
    monRes[1]=$((monRes[1] * 100 / monRes[2]))  # Adjust height
    
    # Convert cursor position to monitor-relative coordinates
    curPos[0]=$((curPos[0] - monRes[3]))  # Subtract monitor X offset
    curPos[1]=$((curPos[1] - monRes[4]))  # Subtract monitor Y offset
    
    # Parse reserved areas (space taken by panels, bars, etc.)
    # This converts space-separated string to array
    offRes=("${offRes// / }")

    # Determine horizontal position (left or right half of screen)
    if [ "${curPos[0]}" -ge "$((monRes[0] / 2))" ]; then
        # Cursor is in right half - position rofi on the right (east)
        local x_pos="east"
        local x_off="-$((monRes[0] - curPos[0] - offRes[2]))"  # Negative offset from right edge
    else
        # Cursor is in left half - position rofi on the left (west)
        local x_pos="west"
        local x_off="$((curPos[0] - offRes[0]))"  # Positive offset from left edge
    fi

    # Determine vertical position (top or bottom half of screen)
    if [ "${curPos[1]}" -ge "$((monRes[1] / 2))" ]; then
        # Cursor is in bottom half - position rofi at bottom (south)
        local y_pos="south"
        local y_off="-$((monRes[1] - curPos[1] - offRes[3]))"  # Negative offset from bottom
    else
        # Cursor is in top half - position rofi at top (north)
        local y_pos="north"
        local y_off="$((curPos[1] - offRes[1]))"  # Positive offset from top
    fi

    # Build rofi position string
    local coordinates="window{location:${x_pos} ${y_pos};anchor:${x_pos} ${y_pos};x-offset:${x_off}px;y-offset:${y_off}px;}"
    echo "${coordinates}"
}

# =============================================================================
# FUNCTION: paste_string
# =============================================================================
# This function handles pasting text, but ignores certain applications (like terminals)

paste_string() {
    # Check if wtype (Wayland typing tool) is available
    if ! command -v wtype >/dev/null; then exit 0; fi
    
    # Path to file containing applications to ignore when pasting
    ignore_paste_file="$HYDE_STATE_HOME/ignore.paste"

    # Create ignore file with default applications if it doesn't exist
    if [[ ! -e "${ignore_paste_file}" ]]; then
        # Here document (cat <<EOF) writes multiple lines to file
        cat <<EOF >"${ignore_paste_file}"
kitty
org.kde.konsole
terminator
XTerm
Alacritty
xterm-256color
EOF
    fi

    # Extract ignore class from command line arguments
    # awk -F sets field separator, then extracts second field
    ignore_class=$(echo "$@" | awk -F'--ignore=' '{print $2}')
    
    # If ignore class is specified, add it to ignore file and exit
    [ -n "${ignore_class}" ] && echo "${ignore_class}" >>"${ignore_paste_file}" && print_prompt -y "[ignore]" "'$ignore_class'" && exit 0
    
    # Get the class (application type) of currently active window
    class=$(hyprctl -j activewindow | jq -r '.initialClass')
    
    # If current application is not in ignore list, simulate Ctrl+V keypress
    if ! grep -q "${class}" "${ignore_paste_file}"; then
        # hyprctl dispatch exec runs a command
        # wtype simulates keyboard input: -M = press modifier, -m = release modifier
        hyprctl -q dispatch exec 'wtype -M ctrl V -m ctrl'
    fi
}

# =============================================================================
# FUNCTION: is_hovered
# =============================================================================
# This function checks if the mouse cursor is hovering over the active window

is_hovered() {
    # Get cursor position and active window info in one command
    # --batch runs multiple hyprctl commands together (more efficient)
    # jq -s treats multiple JSON inputs as an array and merges them
    data=$(hyprctl --batch -j "cursorpos;activewindow" | jq -s '.[0] * .[1]')
    
    # Extract values from JSON and convert to shell variables
    # @sh formats the output as shell-safe quoted strings
    # The backslashes escape the quotes in the jq expression
    eval "$(echo "$data" | jq -r '@sh "cursor_x=\(.x) cursor_y=\(.y) window_x=\(.at[0]) window_y=\(.at[1]) window_size_x=\(.size[0]) window_size_y=\(.size[1])"')"

    # Handle null values by providing defaults
    # // is jq's "alternative operator" - use right side if left side is null
    cursor_x=${cursor_x:-$(jq -r '.x // 0' <<<"$data")}
    cursor_y=${cursor_y:-$(jq -r '.y // 0' <<<"$data")}
    window_x=${window_x:-$(jq -r '.at[0] // 0' <<<"$data")}
    window_y=${window_y:-$(jq -r '.at[1] // 0' <<<"$data")}
    window_size_x=${window_size_x:-$(jq -r '.size[0] // 0' <<<"$data")}
    window_size_y=${window_size_y:-$(jq -r '.size[1] // 0' <<<"$data")}
    
    # Check if cursor is within window boundaries
    # (( )) allows C-style arithmetic expressions with comparison operators
    if ((cursor_x >= window_x && cursor_x <= window_x + window_size_x && cursor_y >= window_y && cursor_y <= window_y + window_size_y)); then
        return 0  # Cursor is hovering over window
    fi
    return 1  # Cursor is not hovering over window
}

# =============================================================================
# FUNCTION: toml_write
# =============================================================================
# This function writes configuration values to TOML format files

toml_write() {
    local config_file=$1  # Configuration file path
    local group=$2        # Section/group name in TOML file
    local key=$3          # Setting key name
    local value=$4        # Setting value

    # Try using kwriteconfig6 (KDE configuration tool) first
    # 2>/dev/null suppresses error messages
    if ! kwriteconfig6 --file "${config_file}" --group "${group}" --key "${key}" "${value}" 2>/dev/null; then
        # If kwriteconfig6 fails, manually edit the file
        
        # Check if the group section exists in the file
        if ! grep -q "^\[${group}\]" "${config_file}"; then
            # Group doesn't exist - add it with the key=value
            echo -e "\n[${group}]\n${key}=${value}" >>"${config_file}"
        elif ! grep -q "^${key}=" "${config_file}"; then
            # Group exists but key doesn't - add key after group header
            # sed -i edits file in place
            # /pattern/a appends line after the matching pattern
            sed -i "/^\[${group}\]/a ${key}=${value}" "${config_file}"
        fi
        # If both group and key exist, we don't update (could add update logic here)
    fi
}

# =============================================================================
# FUNCTION: extract_thumbnail
# =============================================================================
# This function extracts a thumbnail image from a video file

# shellcheck disable=SC2317
# This comment tells shellcheck to ignore "unreachable code" warning
extract_thumbnail() {
    local x_wall="${1}"      # Input video file path
    x_wall=$(realpath "${x_wall}")  # Convert to absolute path
    local temp_image="${2}"  # Output thumbnail image path
    
    # Use ffmpeg to extract thumbnail from video
    # -y: overwrite output file if it exists
    # -i: input file
    # -vf: video filter chain
    # "thumbnail,scale=1000:-1": extract best thumbnail and scale to 1000px wide (keep aspect ratio)
    # -frames:v 1: extract only 1 video frame
    # -update 1: update the output file
    # &>/dev/null: suppress all output messages
    ffmpeg -y -i "${x_wall}" -vf "thumbnail,scale=1000:-1" -frames:v 1 -update 1 "${temp_image}" &>/dev/null
}

# =============================================================================
# FUNCTION: accepted_mime_types
# =============================================================================
# This function checks if a file type is supported by the wallpaper backend

accepted_mime_types() {
    local mime_types_array=${1}  # Array of accepted MIME types (passed by name, not value)
    local file=${2}              # File to check

    # Loop through each accepted MIME type
    for mime_type in "${mime_types_array[@]}"; do
        # Use 'file' command to detect actual file type
        # --mime-type: output MIME type only
        # -b: brief mode (no filename in output)
        # grep -q: quiet mode (no output, just return status)
        # ^${mime_type}: MIME type must match from start of line
        if file --mime-type -b "${file}" | grep -q "^${mime_type}"; then
            return 0  # File type is supported
        else
            # File type not supported - show error message and notification
            print_log err "File type not supported for this wallpaper backend."
            notify-send -u critical -a "DENv-Alert" "File type not supported for this wallpaper backend."
        fi
    done
    # If we get here, no MIME types matched (function will return non-zero)
}
