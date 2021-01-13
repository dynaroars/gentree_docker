#!/bin/bash

if ! [[ -z ${1:-} ]] &&  [[ -d "$1" ]]; then
    SRC_DIR="$(realpath "$(dirname "${BASH_SOURCE[0]}")")"
    "$SRC_DIR/summary.sh" "$1" | "$SRC_DIR/viewcsv.sh"
else
    cat "${1:--}" | column -n -t -s, | less -S
fi
