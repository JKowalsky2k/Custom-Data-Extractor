#!/bin/bash

PROGRAM_NAME="CDE"
ROOT_DIR_PATH="$HOME"/"$PROGRAM_NAME"
MOUNT_POINT="$ROOT_DIR_PATH"/mnt
COPY_POINT="$ROOT_DIR_PATH"/data
declare -rA FILE_SYSTEMS=(  ["vfat"]="Virtual FAT" \
                            ["hfsplus"]="Mac OS Extended (Case-sensitive, Journaled)" \
                            ["exfat"]="ExFAT")
TIMESTAMP=$(date +'%Y-%m-%d %H:%M:%S')

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

mount_dev () {
    mkdir -p "$1"
    sudo mount -o ro "$2" "$1"
    if [ $? -eq 0 ]
    then
        echo ["$TIMESTAMP"] Device $2 mounted successfully | tee -a tee -a "$LOG_FILE_PATH"
    fi
}

umount_dev () {
    sudo umount "$1"
    if [ $? -eq 0 ]
    then
        echo ["$TIMESTAMP"] Device $DEVICE unmounted successfully | tee -a tee -a "$LOG_FILE_PATH"
    fi
    rmdir "$1"
}

copy_all_data () {
    CP_START_TIME=$(date +%s)
    echo ["$TIMESTAMP"] Copying started | tee -a "$LOG_FILE_PATH"
    sudo cp -a "$1"/. "$2"
    CP_END_TIME=$(date +%s)
    CP_RUNTIME=$(( CP_END_TIME-CP_START_TIME ))
    echo ["$TIMESTAMP"] Copying finished after "$CP_RUNTIME" sec | tee -a "$LOG_FILE_PATH"
}

detect_filesystem () {
    FILE_SYSTEM=$(lsblk -n -o FSTYPE "$1")
    echo [DEBUG] File system: $FILE_SYSTEM| tee -a "$LOG_FILE_PATH"
    echo File system: "${FILE_SYSTEMS["$FILE_SYSTEM"]}" \("$FILE_SYSTEM"\)
}

get_info () {
    sudo fdisk -l "$1" | tee -a "$2"/"$3"/log_"$3".log
}

create_iso_image () {
    DD_START_TIME=$(date +%s)
    echo ["$TIMESTAMP"] Making image started | tee -a "$LOG_FILE_PATH"
    sudo dc3dd if="$1" hof="$2" hash=sha512
    DD_END_TIME=$(date +%s)
    DD_RUNTIME=$(( DD_END_TIME-DD_START_TIME ))
    echo ["$TIMESTAMP"] Making image finished after "$DD_RUNTIME" sec | tee -a "$LOG_FILE_PATH"
}

create_raport () {
    cat /dev/null > "$RAPORT_FILE_PATH"
    
    if [ -n "$USER" ]
    then
        echo User: "$USER" >> "$RAPORT_FILE_PATH"
    else
        echo User: Anon >> "$RAPORT_FILE_PATH"
    fi
    
    echo Scan started at: $(date -u -d @$START_TIME +%H:%M:%S) >> "$RAPORT_FILE_PATH"
    echo Device: "$DEVICE" >> "$RAPORT_FILE_PATH"
    
    DEVICE_SERIAL_NUMBER=$(udevadm info --name=$(echo $DEVICE | tr -d '0123456789') | grep ID_SERIAL_SHORT | cut --delimiter "=" --fields 2)
    echo DSN: $DEVICE_SERIAL_NUMBER
    if [ -n "$DEVICE_SERIAL_NUMBER" ]
    then
        echo Serial Number: "$DEVICE_SERIAL_NUMBER" >> "$RAPORT_FILE_PATH"
    else
        echo Serial Number: \<empty\> >> "$RAPORT_FILE_PATH"
    fi
    
    sudo fdisk -l $DEVICE >> "$RAPORT_FILE_PATH"

    echo Scan ended at: $(date -u -d @$END_TIME +%H:%M:%S) >> "$RAPORT_FILE_PATH"
    echo Runtime: $RUNTIME sec >> "$RAPORT_FILE_PATH"
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
            echo "$COUNTER": "$DEVICE"

            DEVICE_NAME=$(echo "$DEVICE" | cut --delimiter "/" --fields 3)
            DEVICE_MOUNT_PATH="$MOUNT_POINT"/"$DEVICE_NAME"
            DEVICE_DIR_PATH="$COPY_POINT"/"$DEVICE_NAME"
            ROOT_DIR_PATH_PATH="$DEVICE_DIR_PATH"/data
            LOG_FILE_PATH="$DEVICE_DIR_PATH"/log_"$DEVICE_NAME".log
            IMAGE_FILE_PATH="$DEVICE_DIR_PATH"/image_"$DEVICE_NAME".img
            RAPORT_FILE_PATH="$DEVICE_DIR_PATH"/raport_"$DEVICE_NAME".txt

            START_TIME=$(date +%s)

            mkdir -p "$DEVICE_DIR_PATH"
            mkdir -p "$ROOT_DIR_PATH"

            cat /dev/null > "$LOG_FILE_PATH"
            echo ["$TIMESTAMP"] Scan started | tee -a "$LOG_FILE_PATH"
            echo ["$TIMESTAMP"] Device: "$DEVICE_NAME" | tee -a "$LOG_FILE_PATH"
            mount_dev "$DEVICE_MOUNT_PATH" "$DEVICE"
            detect_filesystem "$DEVICE"
            copy_all_data "$DEVICE_MOUNT_PATH" "$ROOT_DIR_PATH"
            create_iso_image "$DEVICE" "$IMAGE_FILE_PATH"
            ls -la "$ROOT_DIR_PATH"
            umount_dev "$DEVICE_MOUNT_PATH"
            
            END_TIME=$(date +%s)
            RUNTIME=$(( END_TIME-START_TIME ))

            create_raport

            echo ["$TIMESTAMP"] Runtime: "$DEVICE_NAME" \("$RUNTIME" sec\) | tee -a "$LOG_FILE_PATH"
        done
    else
        echo No devices detected!
    fi
    echo "-----------------------------"
    RAPORTS_PATH=$(find $ROOT_DIR_PATH/ *.txt | grep raport)
    for RAPORT in $RAPORTS_PATH
    do
        cat $RAPORT
        echo "-----------------------------"
    done
}

while getopts ":u:s:" opt; do
    case $opt in
        u)
        USER=$OPTARG
        echo User: $USER
        ;;
        s)
        SN=$OPTARG
        echo SN: $SN
        ;;
        \?)
        echo "Option -$OPTARG requires an argument." >&2
        exit 1
        ;;
    esac
done
run