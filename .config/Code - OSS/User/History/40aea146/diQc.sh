#!/usr/bin/env bash

#|---| Script to generate color palette from image |---|#

#// DEFAULT CONFIGURATION SECTION
# These variables set the default behavior when no options are provided

# Default color profile - affects how vibrant/muted the colors will be
colorProfile="default"

# This is a curve that defines brightness vs saturation for accent colors
# Format: "brightness saturation\n..." where \n means newline
# Each pair controls how bright and saturated accent colors will be
wallbashCurve="32 50\n42 46\n49 40\n56 39\n64 38\n76 37\n90 33\n94 29\n100 20"

# How to sort the extracted colors (auto/dark/light)
sortMode="auto"

#// COMMAND LINE ARGUMENT PARSING
# This while loop processes command line arguments (like -v, --vibrant, etc.)
# $# = number of arguments passed to script
# [ $# -gt 0 ] means "while there are arguments left to process"
while [ $# -gt 0 ]; do
    # case statement - like switch/case in other languages
    # $1 is the first remaining argument
    case "$1" in
    
    # -v OR --vibrant flag
    -v | --vibrant)
        colorProfile="vibrant"
        # Different curve for more vibrant colors (higher saturation values)
        wallbashCurve="18 99\n32 97\n48 95\n55 90\n70 80\n80 70\n88 60\n94 40\n99 24"
        ;;
        
    # -p OR --pastel flag  
    -p | --pastel)
        colorProfile="pastel"
        # Pastel curve (lower saturation for softer colors)
        wallbashCurve="10 99\n17 66\n24 49\n39 41\n51 37\n58 34\n72 30\n84 26\n99 22"
        ;;
        
    # -m OR --mono flag (monochrome/grayscale)
    -m | --mono)
        colorProfile="mono"
        # All saturation values set to 0 (no color, only gray tones)
        wallbashCurve="10 0\n17 0\n24 0\n39 0\n51 0\n58 0\n72 0\n84 0\n99 0"
        ;;
        
    # -c OR --custom flag (user provides their own curve)
    -c | --custom)
        shift  # Move to next argument (the custom curve data)
        
        # [ -n "${1}" ] checks if argument is not empty
        # [[ "${1}" =~ regex ]] checks if argument matches the pattern
        # REGEX BREAKDOWN: ^([0-9]+[[:space:]][0-9]+\\n){8}[0-9]+[[:space:]][0-9]+$
        # ^ = start of string
        # ([0-9]+[[:space:]][0-9]+\\n) = group containing:
        #   [0-9]+ = one or more digits
        #   [[:space:]] = any whitespace character (space, tab, etc.)
        #   [0-9]+ = one or more digits  
        #   \\n = literal newline character (escaped)
        # {8} = repeat the group exactly 8 times
        # [0-9]+[[:space:]][0-9]+ = final pair without newline
        # $ = end of string
        # This ensures format: "number space number newline" repeated 8 times, then final pair
        if [ -n "${1}" ] && [[ "${1}" =~ ^([0-9]+[[:space:]][0-9]+\\n){8}[0-9]+[[:space:]][0-9]+$ ]]; then
            colorProfile="custom"
            wallbashCurve="${1}"  # Use the provided curve
        else
            # If format is wrong, show error and exit
            echo "Error: Custom color curve format is incorrect ${1}"
            exit 1  # Exit with error code 1
        fi
        ;;
        
    # -d OR --dark flag (force dark mode sorting)
    -d | --dark)
        sortMode="dark"
        colSort=""  # Empty means normal sort order
        ;;
        
    # -l OR --light flag (force light mode sorting)  
    -l | --light)
        sortMode="light"
        colSort="-r"  # -r means reverse sort order
        ;;
        
    # Default case - any other argument
    *)
        break  # Stop processing arguments, treat as filename
        ;;
    esac
    shift  # Move to next argument
done

#// SET MAIN VARIABLES
# After processing flags, $1 should be the image filename

wallbashImg="${1}"  # Input image file
wallbashColors=4   # Number of primary colors to extract
wallbashFuzz=70    # ImageMagick fuzz factor (color tolerance when grouping similar colors)

# Set output filenames - if $2 is provided use it, otherwise use $1
# ${2:-"${wallbashImg}"} means "use $2 if it exists, otherwise use wallbashImg"
wallbashRaw="${2:-"${wallbashImg}"}.mpc"    # Temporary processed image cache
wallbashOut="${2:-"${wallbashImg}"}.dcol"   # Output color file
wallbashCache="${2:-"${wallbashImg}"}.cache" # Additional cache file

#// COLOR MODULATION SETTINGS
# These numbers control how much to adjust brightness/saturation/hue
# when generating secondary colors

# Settings for primary colors on dark backgrounds
pryDarkBri=116  # Brightness adjustment (116% = slightly brighter)
pryDarkSat=110  # Saturation adjustment (110% = more saturated)  
pryDarkHue=88   # Hue adjustment (88% = slight hue shift)

# Settings for primary colors on light backgrounds
pryLightBri=100 # Brightness (100% = no change)
pryLightSat=100 # Saturation (100% = no change)
pryLightHue=114 # Hue (114% = slight hue shift)

# Text color brightness settings
txtDarkBri=188  # Bright text for dark backgrounds
txtLightBri=16  # Dark text for light backgrounds

#// INPUT VALIDATION
# Check if image file was provided and exists

# [ -z "${wallbashImg}" ] checks if variable is empty
# [ ! -f "${wallbashImg}" ] checks if file doesn't exist
if [ -z "${wallbashImg}" ] || [ ! -f "${wallbashImg}" ]; then
    echo "Error: Input file not found!"
    exit 1
fi

# Validate that the file is actually an image using ImageMagick
# magick -ping just reads image metadata without loading the full image
# -format "%t" gets the image type
# info: tells magick to output info instead of creating a file
# &>/dev/null redirects all output to nowhere (silent)
# ! negates the return code (if magick fails, condition becomes true)
if ! magick -ping "${wallbashImg}" -format "%t" info: &>/dev/null; then
    echo "Error: Unsuppoted image format ${wallbashImg}"
    exit 1
fi

# Print status message showing current settings
echo -e "wallbash ${colorProfile} profile :: ${sortMode} :: Colors ${wallbashColors} :: Fuzzy ${wallbashFuzz} :: \"${wallbashOut}\""

# Set up cache directories
# ${var:-default} means "use var if set, otherwise use default"
cacheDir="${cacheDir:-$XDG_CACHE_HOME/denv}"  # Main cache directory
thmDir="${thmDir:-$cacheDir/thumbs}"           # Thumbnails directory

# mkdir -p creates directory and all parent directories if they don't exist
mkdir -p "${cacheDir}/${thmDir}"

# : >"${wallbashOut}" is a bash trick to create/empty a file
# : is a no-op command, > redirects its (empty) output to the file
: >"${wallbashOut}"

#// FUNCTION DEFINITIONS
# Functions are reusable blocks of code

# Function to calculate the negative (opposite) color
rgb_negative() {
    local inCol=$1  # local makes variable only exist in this function
    
    # Extract RGB values from hex color (first 2 chars = red, next 2 = green, last 2 = blue)
    local r=${inCol:0:2}  # ${var:start:length} extracts substring
    local g=${inCol:2:2}
    local b=${inCol:4:2}
    
    # Convert hex to decimal using base 16
    # $((16#$r)) means "treat $r as base-16 number and convert to decimal"
    local r16=$((16#$r))
    local g16=$((16#$g))
    local b16=$((16#$b))
    
    # Calculate negative (255 - original value) and convert back to hex
    # printf "%02X" formats as 2-digit uppercase hexadecimal
    r=$(printf "%02X" $((255 - r16)))
    g=$(printf "%02X" $((255 - g16)))
    b=$(printf "%02X" $((255 - b16)))
    
    # Return the concatenated hex color
    echo "${r}${g}${b}"
}

# Function to convert hex color to RGBA format
rgba_convert() {
    local inCol=$1
    
    # Same hex extraction as above
    local r=${inCol:0:2}
    local g=${inCol:2:2}
    local b=${inCol:4:2}
    
    # Convert to decimal
    local r16=$((16#$r))
    local g16=$((16#$g))
    local b16=$((16#$b))
    
    # Print in RGBA format with \1341 (which becomes 1 after processing)
    printf "rgba(%d,%d,%d,\1341)\n" "$r16" "$g16" "$b16"
}

# Function to determine if a color/image is dark or light
fx_brightness() {
    local inCol="${1}"
    
    # Use ImageMagick to convert color to grayscale and get average brightness
    # -colorspace gray converts to grayscale
    # -format "%[fx:mean]" calculates the mean (average) brightness (0.0 to 1.0)
    fxb=$(magick "${inCol}" -colorspace gray -format "%[fx:mean]" info:)
    
    # AWK ARITHMETIC COMPARISON: awk -v fxb="${fxb}" 'BEGIN {exit !(fxb < 0.5)}'
    # awk -v variable=value passes a shell variable to awk
    # BEGIN { } executes before processing any input (since we have no input)
    # fxb < 0.5 compares the brightness value to 0.5
    # ! negates the result (true becomes false, false becomes true)  
    # exit code sets the return value of awk command
    # In bash: 0 = success/true, 1 = failure/false
    # So: if brightness < 0.5 (dark), exit with 0 (true)
    #     if brightness >= 0.5 (light), exit with 1 (false)
    # return 0 = true/dark, return 1 = false/light
    if awk -v fxb="${fxb}" 'BEGIN {exit !(fxb < 0.5)}'; then
        return 0 #// dark color
    else
        return 1 #// light color  
    fi
}

#// EXTRACT PRIMARY COLORS FROM IMAGE

# Process the input image and save as temporary MPC (ImageMagick cache format)
# -quiet suppresses warnings
# -regard-warnings makes ImageMagick pay attention to warnings
# [0] takes only the first frame (for animated images)
# -alpha off removes transparency
# +repage resets the image page geometry
magick -quiet -regard-warnings "${wallbashImg}"[0] -alpha off +repage "${wallbashRaw}"

# Extract colors using k-means clustering algorithm
# readarray -t arrayname <<<$(command) reads command output into array, one line per element
# <<< is "here string" - feeds the output as input to readarray
readarray -t dcolRaw <<<"$(magick "${wallbashRaw}" \
    -depth 8 \                    # Use 8-bit color depth
    -fuzz ${wallbashFuzz}% \      # Group similar colors within fuzz% tolerance
    +dither \                     # Don't use dithering
    -kmeans ${wallbashColors} \   # Cluster into wallbashColors groups
    -depth 8 \                    # Ensure 8-bit output
    -format "%c" \                # Output color histogram format
    histogram:info: | \           # Generate histogram
    sed -n 's/^[ ]*\(.*\):.*[#]\([0-9a-fA-F]*\) .*$/\1,\2/p' | \ # SED MAGIC - explained below
    sort -r -n -k 1 -t ",")"      # Sort by count (descending)

# SED COMMAND BREAKDOWN: sed -n 's/^[ ]*\(.*\):.*[#]\([0-9a-fA-F]*\) .*$/\1,\2/p'
# sed = Stream Editor (processes text line by line)
# -n = suppress automatic printing (only print when we say 'p')
# 's/pattern/replacement/flags' = substitute command
# 
# PATTERN BREAKDOWN: ^[ ]*\(.*\):.*[#]\([0-9a-fA-F]*\) .*$
# ^ = start of line
# [ ]* = zero or more spaces
# \(.*\) = GROUP 1: capture any characters (the color count)
#   \( and \) create a capture group in sed
#   .* matches any character (.) zero or more times (*)
# : = literal colon character
# .* = any characters (skip the color name/info)
# [#] = literal hash character (could also write \#)
# \([0-9a-fA-F]*\) = GROUP 2: capture hex color code
#   [0-9a-fA-F] = any hex digit (0-9, a-f, A-F)
#   * = zero or more times
# .* = any remaining characters
# $ = end of line
#
# REPLACEMENT: \1,\2
# \1 = first captured group (color count)
# , = literal comma
# \2 = second captured group (hex color)
#
# p = print the line if substitution was successful
# This transforms: "    1234: (some color info) #FF5733 srgb(255,87,51)"
# Into: "1234,FF5733"

# Check if we got enough colors, if not try again with more clusters
# ${#array[*]} gets the number of elements in an array
if [ ${#dcolRaw[*]} -lt ${wallbashColors} ]; then
    echo -e "RETRYING :: distinct colors ${#dcolRaw[*]} is less than ${wallbashColors} palette color..."
    # Try again with more colors in case some get filtered out
    readarray -t dcolRaw <<<"$(magick "${wallbashRaw}" \
        -depth 8 -fuzz ${wallbashFuzz}% +dither \
        -kmeans $((wallbashColors + 2)) \  # Add 2 extra colors
        -depth 8 -format "%c" histogram:info: | \
        sed -n 's/^[ ]*\(.*\):.*[#]\([0-9a-fA-F]*\) .*$/\1,\2/p' | \
        sort -r -n -k 1 -t ",")"
fi

#// DETERMINE COLOR SORTING ORDER

# If sortMode is auto, detect if image is dark or light
if [ "${sortMode}" == "auto" ]; then
    if fx_brightness "${wallbashRaw}"; then  # If function returns 0 (dark)
        sortMode="dark"
        colSort=""      # Normal sort order for dark images
    else                                     # If function returns 1 (light)
        sortMode="light"  
        colSort="-r"    # Reverse sort order for light images
    fi
fi

# Write the detected mode to output file
# >> appends to file (vs > which overwrites)
echo "dcol_mode=\"${sortMode}\"" >>"${wallbashOut}"

# Extract just the hex colors and sort them according to determined order
# mapfile is another way to read into array (same as readarray)
# echo -e interprets escape sequences like \n
# tr ' ' '\n' replaces spaces with newlines (tr = translate/transliterate)
# AWK COMMAND: awk -F ',' '{print $2}'
# awk = pattern scanning and processing language
# -F ',' = set Field separator to comma
# '{print $2}' = for each line, print field 2 (second field)
# awk automatically splits each line by the field separator
# $1 = first field, $2 = second field, etc.
# $0 = entire line, NF = number of fields
# In our case: "1234,FF5733" becomes $1="1234" and $2="FF5733"
# So this extracts just the hex color codes
# sort ${colSort:+"$colSort"} uses colSort if it's set, otherwise no extra args
mapfile -t dcolHex < <(echo -e "${dcolRaw[@]:0:$wallbashColors}" | \
    tr ' ' '\n' | \
    awk -F ',' '{print $2}' | \
    sort ${colSort:+"$colSort"})

# Check if image is grayscale by examining saturation
# -colorspace HSL converts to Hue-Saturation-Lightness
# -channel g -separate gets just the saturation channel
# +channel resets channel selection
greyCheck=$(magick "${wallbashRaw}" -colorspace HSL -channel g -separate +channel -format "%[fx:mean]" info:)

# If average saturation is very low (< 0.12), force monochrome curve
# ARITHMETIC EVALUATION IN AWK: awk 'BEGIN {print ('"$greyCheck"' < 0.12)}'
# This is a tricky construction - let's break it down:
# awk 'BEGIN {print ('"$greyCheck"' < 0.12)}'
# The single quotes end, then "$greyCheck" is expanded by bash, then single quotes resume
# So if greyCheck=0.08, this becomes: awk 'BEGIN {print (0.08 < 0.12)}'
# BEGIN { } executes before reading input
# print (condition) prints 1 if condition is true, 0 if false
# (( )) around the whole thing converts the result to bash arithmetic
# $(( )) evaluates arithmetic and returns the result
# So this whole expression returns 1 if grayscale, 0 if colorful
if (($(awk 'BEGIN {print ('"$greyCheck"' < 0.12)}'))); then
    wallbashCurve="10 0\n17 0\n24 0\n39 0\n51 0\n58 0\n72 0\n84 0\n99 0"
fi

#// GENERATE ALL COLOR VARIATIONS

# Loop through each primary color
# for ((init; condition; increment)) is C-style for loop
for ((i = 0; i < wallbashColors; i++)); do

    #// HANDLE MISSING PRIMARY COLORS
    # If we don't have enough colors, generate them from previous color
    
    if [ -z "${dcolHex[i]}" ]; then  # If this color slot is empty
        
        # Check if previous color is dark or light to determine modulation
        if fx_brightness "xc:#${dcolHex[i - 1]}"; then  # xc: creates a solid color image
            modBri=$pryDarkBri   # Use dark color settings
            modSat=$pryDarkSat
            modHue=$pryDarkHue
        else
            modBri=$pryLightBri  # Use light color settings
            modSat=$pryLightSat
            modHue=$pryLightHue
        fi

        echo -e "dcol_pry$((i + 1)) :: regen missing color"
        
        # Generate new color by modulating the previous one
        # -modulate brightness,saturation,hue adjusts these values
        # SED PATTERN (same as before): sed -n 's/^[ ]*\(.*\):.*[#]\([0-9a-fA-F]*\) .*$/\2/p'
        # This time we only want \2 (the hex color), not the count
        # \2 extracts just the second captured group (hex color code)
        dcolHex[i]=$(magick xc:"#${dcolHex[i - 1]}" \
            -depth 8 -normalize \
            -modulate ${modBri},${modSat},${modHue} \
            -depth 8 -format "%c" histogram:info: | \
            sed -n 's/^[ ]*\(.*\):.*[#]\([0-9a-fA-F]*\) .*$/\2/p')
    fi

    # Write primary color to output file
    # $((i + 1)) converts 0-based index to 1-based for output
    echo "dcol_pry$((i + 1))=\"${dcolHex[i]}\"" >>"${wallbashOut}"
    echo "dcol_pry$((i + 1))_rgba=\"$(rgba_convert "${dcolHex[i]}")\"" >>"${wallbashOut}"

    #// GENERATE TEXT COLORS
    # Create high-contrast text colors for each primary color
    
    # Get the negative color
    nTxt=$(rgb_negative "${dcolHex[i]}")

    # Determine brightness adjustment based on primary color brightness
    if fx_brightness "xc:#${dcolHex[i]}"; then
        modBri=$txtDarkBri   # Bright text for dark background
    else
        modBri=$txtLightBri  # Dark text for light background
    fi

    # Generate text color with low saturation (10) and normal hue (100)
    # SED EXTRACTION: same pattern, extracts just the hex color (\2)
    tcol=$(magick xc:"#${nTxt}" \
        -depth 8 -normalize \
        -modulate ${modBri},10,100 \
        -depth 8 -format "%c" histogram:info: | \
        sed -n 's/^[ ]*\(.*\):.*[#]\([0-9a-fA-F]*\) .*$/\2/p')
        
    echo "dcol_txt$((i + 1))=\"${tcol}\"" >>"${wallbashOut}"
    echo "dcol_txt$((i + 1))_rgba=\"$(rgba_convert "${tcol}")\"" >>"${wallbashOut}"

    #// GENERATE ACCENT COLORS
    # Create 9 accent variations of each primary color
    
    # Extract the hue from the primary color
    # COMPLEX AWK FIELD SEPARATION: awk -F '[hsb(,]' '{print $2}'
    # -F '[hsb(,]' sets field separator to ANY of these characters: h, s, b, (, or ,
    # This is a character class in regex - matches any single character from the set
    # Input example: "1: (255,255,255) hsb(240,100%,50%) srgb(0,128,255)"
    # Field separation with [hsb(,]:
    # Field 1: "1: (255,255,255) "
    # Field 2: "240"              <- This is what we want (the hue)
    # Field 3: "100%"
    # Field 4: "50%)"
    # Field 5: " srgb(0"
    # etc...
    # {print $2} extracts field 2, which is the hue value
    xHue=$(magick xc:"#${dcolHex[i]}" -colorspace HSB -format "%c" histogram:info: | \
        awk -F '[hsb(,]' '{print $2}')
    
    acnt=1  # Accent counter

    # Process the curve data to generate accent colors
    # echo -e interprets \n as actual newlines
    # sort -n sorts numerically, with optional reverse if colSort is set
    # while read -r reads each line into variables xBri and xSat
    # read -r prevents backslash interpretation (raw reading)
    echo -e "${wallbashCurve}" | sort -n ${colSort:+"$colSort"} | while read -r xBri xSat; do
        # Create color using HSB values: hue from original, brightness and saturation from curve
        # SED EXTRACTION: extracts hex color from ImageMagick output (same pattern as before)
        acol=$(magick xc:"hsb(${xHue},${xSat}%,${xBri}%)" \
            -depth 8 -format "%c" histogram:info: | \
            sed -n 's/^[ ]*\(.*\):.*[#]\([0-9a-fA-F]*\) .*$/\2/p')
            
        # Write accent color to output
        echo "dcol_$((i + 1))xa${acnt}=\"${acol}\"" >>"${wallbashOut}"
        echo "dcol_$((i + 1))xa${acnt}_rgba=\"$(rgba_convert "${acol}")\"" >>"${wallbashOut}"
        
        ((acnt++))  # Increment accent counter
    done

done

#// CLEANUP
# Remove temporary files
# -f flag makes rm not complain if files don't exist
rm -f "${wallbashRaw}" "${wallbashCache}"

#// ========================================================================
#// TEXT PROCESSING TOOLS SUMMARY FOR BEGINNERS
#// ========================================================================

# SED (Stream Editor) - processes text line by line
# Basic syntax: sed 'command' file
# Common commands:
#   s/pattern/replacement/flags  - substitute
#   -n                          - suppress automatic printing
#   p                           - print line
#   Capture groups: \(pattern\) and reference with \1, \2, etc.

# AWK - pattern scanning and data extraction language  
# Basic syntax: awk 'pattern { action }' file
# Built-in variables:
#   $0 = entire line, $1 = first field, $2 = second field, etc.
#   NF = number of fields, NR = line number
#   -F 'separator' sets field separator
#   -v var=value passes variables from shell to awk

# REGEX (Regular Expressions) - pattern matching language
# Common patterns:
#   ^ = start of line          $ = end of line
#   . = any character          * = zero or more of previous
#   + = one or more            ? = zero or one
#   [abc] = any of a, b, or c  [0-9] = any digit
#   [a-z] = any lowercase      [A-Z] = any uppercase
#   \( \) = capture groups (in sed/grep)
#   ( ) = groups (in modern regex)

# PIPELINE CONCEPTS:
# command1 | command2  - pipe output of command1 to input of command2
# $(command)           - command substitution (run command, use output)
# <<< "string"         - here string (feed string as input)
# < <(command)         - process substitution (treat command output as file)
