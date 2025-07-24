#!/usr/bin/env bash

scrDir="$(dirname "$(realpath "$0")")"
# shellcheck source=$HOME/.local/lib/denv/globalcontrol.sh
# shellcheck disable=SC1091
source "${scrDir}/globalcontrol.sh"

lockscreen="${LOCKSCREEN:-hyprlock}"

if ! denv-shell "${lockscreen}.sh" "${@}" ; then
    printf "Executing raw command: %s\n" "${lockscreen}"
    "${lockscreen}" "${@}"
fi
