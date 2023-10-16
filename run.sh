#!/bin/bash

PROGRAM_NAME="CDE"
DATA_DIR="$HOME"/"$PROGRAM_NAME"
MOUNT_POINT="$DATA_DIR"/mnt
COPY_POINT="$DATA_DIR"/backup
declare -rA FILE_SYSTEMS=(  ["vfat"]="Virtual FAT" \
                            ["hfsplus"]="Mac OS Extended (Case-sensitive, Journaled)" \
                            ["exfat"]="ExFAT")
discover () {
    echo "Disconnect the flash drive"
    mkdir -p "$DATA_DIR"
    read -p "When ready press any key to continue..." EMPTY_ANSWER
    ls -l /dev/sd* | grep ^b.*[0-9]$ | rev | cut --delimiter " " --fields 1 | rev > "$DATA_DIR"/before.txt
    echo "Connect flash drive!"
    i=1
    sp="/-\|"
    echo -n "Detecting... "
    until [ ! -z $DISCOVERED_DEVICES ]
    do
        printf "\b${sp:i++%${#sp}:1}"
        sleep 0.25
        ls -l /dev/sd* | grep ^b.*[0-9]$ | rev | cut --delimiter " " --fields 1 | rev > "$DATA_DIR"/after.txt
        DISCOVERED_DEVICES=$(diff "$DATA_DIR"/before.txt "$DATA_DIR"/after.txt | rev | cut --only-delimited --delimiter " " --fields 1 | rev)
    done
}

mount_dev () {
    mkdir -p "$1"
    sudo mount -o ro "$2" "$1"
}

umount_dev () {
    sudo umount "$1"
    rmdir "$1"
}

copy_all_data () {
    mkdir -p "$COPY_POINT"/"$2"
    sudo cp -a "$1"/. "$COPY_POINT"/"$2"
}

detect_filesystem () {
    FILE_SYSTEM=$(lsblk -n -o FSTYPE $1)
    echo File system: "${FILE_SYSTEMS["$FILE_SYSTEM"]}" \("$FILE_SYSTEM"\)
}

make_image () {
    sudo dd if=$1 of=$2/$3/image_$3.img bs=4M status=progress
}

run () {
    discover
    if [ ! -z "$DISCOVERED_DEVICES" ]
    then
        COUNTER=0
        for DEVICE in $DISCOVERED_DEVICES
        do
            COUNTER=$(( COUNTER+1 ))
            echo "$COUNTER": "$DEVICE"
            DEVICE_NAME=$(echo $DEVICE | cut -d "/" -f 3)
            DEVICE_MOUNT_PATH="$MOUNT_POINT"/"$DEVICE_NAME"
            mount_dev "$DEVICE_MOUNT_PATH" "$DEVICE"
            detect_filesystem $DEVICE
            copy_all_data "$DEVICE_MOUNT_PATH" "$DEVICE_NAME"
            make_image "$DEVICE" "$COPY_POINT" "$DEVICE_NAME"
            ls -la "$COPY_POINT"/"$DEVICE_NAME"
            umount_dev "$DEVICE_MOUNT_PATH"
        done
    else
        echo No devices detected!
    fi
}

run