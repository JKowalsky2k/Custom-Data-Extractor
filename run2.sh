#!/bin/bash

CUSTOM_USER="Anonymous"
CUSTOM_SERIAL_NUMBER=""
SAVE_DIR_PATH="/home/"$USER""

DEBUG=false
DISPLAY_RAPORT=false

for ARG in $@
do
    if [ $ARG = "--user" -o $ARG = "-u" ]
    then
        CUSTOM_USER="$2"
    elif [ $ARG = "--serial-number" -o $ARG = "-sn" ]
    then
        CUSTOM_SERIAL_NUMBER="$2"
    elif [ $ARG = "--save-dir" -o $ARG = "-sd" ]
        SAVE_DIR_PATH="$2"
    then
        CUSTOM_SERIAL_NUMBER="$2"
    elif [ $ARG = "--debug" -o $ARG = "-d" ]
    then
        DEBUG=true
    elif [ $ARG = "--display-raport" -o $ARG = "-dr" ]
    then
        DISPLAY_RAPORT=true
    else
        echo -n ""
    fi 
done

PROGRAM_NAME="CDE"
ROOT_DIR_PATH="$SAVE_DIR_PATH"/"$PROGRAM_NAME"
MOUNT_DIR_PATH="$ROOT_DIR_PATH"/mnt
COPY_DIR_PATH="$ROOT_DIR_PATH"/devices

TIMESTAMP=$(date +'%Y-%m-%d %H:%M:%S')

log () {
    echo ["$TIMESTAMP"] "$@" | tee -a "$LOG_FILE_PATH"
}

discover () {
    echo "Disconnect the flash drive"
    mkdir -p "$ROOT_DIR_PATH"
    read -p "When ready press any key to continue..." EMPTY_ANSWER
    ls -l /dev/sd* | grep ^b.*[0-9]$ | rev | cut --delimiter " " --fields 1 | rev > "$ROOT_DIR_PATH"/before.txt
    echo "Connect flash drive!"
    i=1
    sp="/-\|"
    echo -n "Detecting... "
    until [ -n "$DISCOVERED_DEVICES" ]
    do
        printf "\b${sp:i++%${#sp}:1}"
        sleep 0.25
        ls -l /dev/sd* | grep ^b.*[0-9]$ | rev | cut --delimiter " " --fields 1 | rev > "$ROOT_DIR_PATH"/after.txt
        DISCOVERED_DEVICES=$(diff "$ROOT_DIR_PATH"/before.txt "$ROOT_DIR_PATH"/after.txt | rev | cut --only-delimited --delimiter " " --fields 1 | rev)
    done
}

mount_device () {
    if [ "$DEBUG" = "true" ]
    then
        log "[DEBUG] ["mount_device"] [ARGUMENT]" "$1"\, "$2" 
    fi

    log "Mounting ("$1")..."
    mkdir -p "$2"
    sudo mount -o ro "$1" "$2"
    if [ $? -eq 0 ]
    then
        log "Device "$1" mounted successfully"
    else
        log "Error during mounting"
        exit 0
    fi
}

umount_device () {
    if [ "$DEBUG" = "true" ]
    then
        log "[DEBUG] [umount_device] [ARGUMENT] "$1"" 
    fi

    log "Unmounting ("$1")..."
    sudo umount "$1"
    if [ $? -eq 0 ]
    then
        log "Device "$1" unmounted successfully"
    else
        log "Error during unmounting"
        exit 0
    fi
    rmdir "$1"
}

detect_filesystem () {
    FILE_SYSTEM=$(sudo fdisk -l $(echo "$1" | tr -d '0123456789') | tail -n 1 | rev | cut --delimiter " " --fields 1 | rev)
    if [ "$DEBUG" = "true" ]
    then
        log "[DEBUG] [detect_filesystem] [ARGUMENT] "$1""
        log "[DEBUG] [detect_filesystem] [RETURN] "$FILE_SYSTEM""
    fi
    if [ -n "$FILE_SYSTEM" ]
    then
        log "Detected file system: "$FILE_SYSTEM""
    else
        log "File system detection error (could not recognize)"
    fi

}

copy_all_data () {
    if [ "$DEBUG" = "true" ]
    then
        log "[DEBUG] [copy_all_data] [ARGUMENT] "$1", "$2""
    fi

    CP_START_TIME=$(date +%s)
    log "Copying..."
    
    sudo cp -a "$1"/. "$2"
    
    CP_END_TIME=$(date +%s)
    CP_RUNTIME=$(( CP_END_TIME-CP_START_TIME ))
    log "Copying finished after "$CP_RUNTIME" sec"
}

create_iso_image () {
    if [ $DEBUG = true ]
    then
        log "[DEBUG] [create_iso_image] [ARGUMENT] "$1", "$2""
    fi

    DD_START_TIME=$(date +%s)
    log "Making image..."

    sudo dc3dd if="$1" hof="$2" hash=sha512

    DD_END_TIME=$(date +%s)
    DD_RUNTIME=$(( DD_END_TIME-DD_START_TIME ))
    log "Making image finished after "$DD_RUNTIME" sec"
}

get_device_serial_number () {
    echo $(udevadm info --name=$(echo $1 | tr -d '0123456789') | grep ID_SERIAL_SHORT | cut --delimiter "=" --fields 2)
}

create_raport () {
    cat /dev/null > "$RAPORT_FILE_PATH"
    
    echo User: "$CUSTOM_USER" >> "$RAPORT_FILE_PATH"
    
    echo Scan started at: $(date -u -d @$START_TIME +%H:%M:%S) >> "$RAPORT_FILE_PATH"
    echo Device: "$DEVICE" >> "$RAPORT_FILE_PATH"
    
    DEVICE_SERIAL_NUMBER=$(get_device_serial_number "$DEVICE")
    if [ -n "$DEVICE_SERIAL_NUMBER" ]
    then
        echo Serial Number: "$DEVICE_SERIAL_NUMBER" >> "$RAPORT_FILE_PATH"
    else
        echo Serial Number: \<empty\> >> "$RAPORT_FILE_PATH"
    fi

    echo File system: "$FILE_SYSTEM" >> "$RAPORT_FILE_PATH"
    
    sudo fdisk -l "$DEVICE" >> "$RAPORT_FILE_PATH"

    echo Scan ended at: $(date -u -d @$END_TIME +%H:%M:%S) >> "$RAPORT_FILE_PATH"
    echo Runtime: $RUNTIME sec >> "$RAPORT_FILE_PATH"
}

scan () {
    DEVICE_NAME=$(echo "$DEVICE" | cut --delimiter "/" --fields 3)
    DEVICE_MOUNT_PATH="$MOUNT_DIR_PATH"/"$DEVICE_NAME"
    DEVICE_DIR_PATH="$COPY_DIR_PATH"/"$DEVICE_NAME"
    DEVICE_COPY_DIR_PATH="$DEVICE_DIR_PATH"/data
    
    LOG_FILE_PATH="$DEVICE_DIR_PATH"/log_"$DEVICE_NAME".log
    IMAGE_FILE_PATH="$DEVICE_DIR_PATH"/image_"$DEVICE_NAME".img
    RAPORT_FILE_PATH="$DEVICE_DIR_PATH"/raport_"$DEVICE_NAME".txt

    START_TIME=$(date +%s)

    mkdir -p "$DEVICE_DIR_PATH"
    mkdir -p "$DEVICE_COPY_DIR_PATH"

    cat /dev/null > "$LOG_FILE_PATH"

    log "Scan No. "$COUNTER" started (Device: "$DEVICE")"

    mount_device "$DEVICE" "$DEVICE_MOUNT_PATH" 
    detect_filesystem "$DEVICE"
    copy_all_data "$DEVICE_MOUNT_PATH" "$DEVICE_COPY_DIR_PATH"
    create_iso_image "$DEVICE" "$IMAGE_FILE_PATH"
    ls -la "$DEVICE_COPY_DIR_PATH"
    umount_device "$DEVICE_MOUNT_PATH"
    
    END_TIME=$(date +%s)
    RUNTIME=$(( END_TIME-START_TIME ))

    create_raport

    log Runtime: "$DEVICE" \("$RUNTIME" sec\)
}

display_raports () {
    echo "-----------------------------"
    RAPORTS_PATH=$(find $ROOT_DIR_PATH -name "*.txt" | grep raport)
    for RAPORT in $RAPORTS_PATH
    do
        cat $RAPORT
        echo "-----------------------------"
    done
}

run () {
    discover
    if [ -n "$DISCOVERED_DEVICES" ]
    then
        COUNTER=0
        for DEVICE in $DISCOVERED_DEVICES
        do
            COUNTER=$(( COUNTER+1 ))
            echo
            
            scan
        done
    else
        log No devices detected
    fi

    if [ $DISPLAY_RAPORT = true ]
    then
        log "Print summary raport"
        display_raports
    fi
}

run
