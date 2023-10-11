#!/bin/sh

PROGRAM_NAME="CDE"
DATA_DIR="$HOME"/"$PROGRAM_NAME"
MOUNT_POINT="$DATA_DIR"/mnt
COPY_POINT="$DATA_DIR"/backup

discover () {
    echo "Disconnect the flash drive"
    mkdir -p "$DATA_DIR"
    read -p "When ready press any key to continue..." EMPTY_ANSWER
    ls -l /dev/sd* | grep ^b.*[0-9]$ | rev | cut --delimiter " " --fields 1 | rev > "$DATA_DIR"/before.txt
    read -p "Connect flash drive press any key to continue..." EMPTY_ANSWER
    ls -l /dev/sd* | grep ^b.*[0-9]$ | rev | cut --delimiter " " --fields 1 | rev > "$DATA_DIR"/after.txt
    DISCOVERED_DEVICES=$(diff "$DATA_DIR"/before.txt "$DATA_DIR"/after.txt | rev | cut --only-delimited --delimiter " " --fields 1 | rev)
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
    echo $1 -> $2
    mkdir -p "$COPY_POINT"/"$2"
    cp -a "$1"/. "$COPY_POINT"/"$2"
}

run () {
    if [ ! -z "$DISCOVERED_DEVICES" ]
    then
        counter=0
        for DEVICE in $DISCOVERED_DEVICES
        do
            counter=$(( counter+1 ))
            echo $counter: $DEVICE
            DEVICE_NAME=$(echo $DEVICE | cut -d "/" -f 3)
            DEVICE_MOUNT_PATH="$MOUNT_POINT"/"$DEVICE_NAME"
            mount_dev $DEVICE_MOUNT_PATH $DEVICE
            copy_all_data $DEVICE_MOUNT_PATH $DEVICE_NAME
            ls -la $COPY_POINT/$DEVICE_NAME
            umount_dev $DEVICE_MOUNT_PATH
        done
    else
        echo No devices detected!
    fi
}

discover
run