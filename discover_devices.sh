#!/bin/sh

PROGRAM_NAME="CDE"
DATA_DIR="$HOME"/"$PROGRAM_NAME"
MOUNT_POINT="$DATA_DIR"/mnt

echo "Disconnect the flash drive"
mkdir -p "$DATA_DIR"
mkdir -p "$MOUNT_POINT"
read -p "When ready press any key to continue..." EMPTY_ANSWER
ls -l /dev/sd* | grep ^b.*[0-9]$ | rev | cut --delimiter " " --fields 1 | rev > "$DATA_DIR"/before.txt
read -p "Connect flash drive press any key to continue..." EMPTY_ANSWER
ls -l /dev/sd* | grep ^b.*[0-9]$ | rev | cut --delimiter " " --fields 1 | rev > "$DATA_DIR"/after.txt
DISCOVERED_DEVICES=$(diff "$DATA_DIR"/before.txt "$DATA_DIR"/after.txt | rev | cut --only-delimited --delimiter " " --fields 1 | rev)
# echo "$DISCOVERED_DEVICES"

if [ ! -z "$DISCOVERED_DEVICES" ]
then
    counter=0
    for device in $DISCOVERED_DEVICES
    do
        counter=$(( counter+1 ))
        echo $counter: $device
        sudo mount -o ro "$device" "$MOUNT_POINT"
        ls -la "$MOUNT_POINT"
        # sleep 1
        sudo umount "$MOUNT_POINT"
    done
else
    echo Device not detected!
fi
