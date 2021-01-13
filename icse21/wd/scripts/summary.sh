#!/bin/bash

shopt -s nullglob
set -euo pipefail

DIR=$1
ROW=${2:-MED}

PROGS=(  id uname cat mv ln date join sort ls )
PROGS+=( grin pylint unison bibtex2html cloc ack )
PROGS+=( vsftpd ngircd )

FILES=($DIR/*.csv)
if [[ ${#FILES[@]} -eq 0 ]]; then
    echo "Not found any .csv files in '$DIR'"
    exit 1
fi

getname() {
    fname=${1##*/}
    NAME="${fname%.csv}"
}

printfile() {
    f="$1"
    getname "$f"
    echo -n "$NAME,"
    cat "$f" | grep -m 1 "^$ROW,"
    if [[ $? -ne 0 ]]; then
        echo \n\n"Not found row '$ROW' in '$f'"
        exit 1
    fi
}

######

echo -n "name,"
head -1 "${FILES[0]}"

declare -A PRINTED
for n in "${PROGS[@]}"; do
    f="$DIR/$n.csv"
    if [[ -f "$f" ]]; then
        printfile "$f"
    fi
    PRINTED[$n]=1
done

for f in "${FILES[@]}"; do
    getname $f
    if [[ -z ${PRINTED[$NAME]:-} ]]; then
        printfile "$f"
    fi
done
