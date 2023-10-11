#!/bin/sh

PROGRAM_NAME="CDE"
DATA_DIR="$HOME"/"$PROGRAM_NAME"

echo "Disconnect the flash drive"
mkdir -p "$DATA_DIR"
read -p "When ready press any key to continue..." EMPTY_ANSWER
ls -l /dev/sd* | grep ^b.*[0-9]$ | rev | cut --delimiter " " --fields 1 | rev > "$DATA_DIR"/before.txt
read -p "Connect flash drive press any key to continue..." EMPTY_ANSWER
ls -l /dev/sd* | grep ^b.*[0-9]$ | rev | cut --delimiter " " --fields 1 | rev > "$DATA_DIR"/after.txt
DISCOVERED_DEVICES=$(diff "$DATA_DIR"/before.txt "$DATA_DIR"/after.txt | rev | cut --only-delimited --delimiter " " --fields 1 | rev) ``
echo "$DISCOVERED_DEVICES"