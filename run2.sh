#!/bin/bash

# Zmienne (z domyslnymi wartsciami) zawierajace flagi i stale, ktre modyfikuja dzialanie programu
CUSTOM_USER="Anonymous"
CUSTOM_SERIAL_NUMBER=""
SAVE_DIR_PATH="/home/"$USER""
DEBUG=false
DISPLAY_RAPORT=false

# Modyfikowanie wczesniejszych zmiennych na podstawie danych z CLI
for ARG in $@
do
    if [ $ARG = "--user" -o $ARG = "-u" ]
    then
        CUSTOM_USER="$2"
    elif [ $ARG = "--serial-number" -o $ARG = "-sn" ]
    then
        CUSTOM_SERIAL_NUMBER="$2"
    elif [ $ARG = "--save-dir" -o $ARG = "-sd" ]
    then
        SAVE_DIR_PATH="$4"
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

# Sciezki definiujace podstawowe trzewo katalogow
PROGRAM_NAME="CDE"
ROOT_DIR_PATH="$SAVE_DIR_PATH"/"$PROGRAM_NAME"
MOUNT_DIR_PATH="$ROOT_DIR_PATH"/mnt
COPY_DIR_PATH="$ROOT_DIR_PATH"/devices

# Zmianna zawierajaca obecna date (wykorzystywane do tworzenia logow)
TIMESTAMP=$(date +'%Y-%m-%d %H:%M:%S')

# Funkcja odpowiadajaca za dopisywanie zdarzen do pliku z logami
log () {
    echo ["$TIMESTAMP"] "$@" | tee -a "$LOG_FILE_PATH"
}

# Funkcja odpowiadajaca za wykrycie nowo podlaczonych urzadzen
discover () {
    echo "Disconnect the flash drive"
    # Stworzenie glownego folderu
    mkdir -p "$ROOT_DIR_PATH"
``` # Czekanie na informacje od uzytkownika
    read -p "When ready press any key to continue..." EMPTY_ANSWER
    # Sparsowanie akutalnie podlaczonych urzadzen
    ls -l /dev/sd* | grep ^b.*[0-9]$ | rev | cut --delimiter " " --fields 1 | rev > "$ROOT_DIR_PATH"/before.txt
    echo "Connect flash drive!"
    i=1
    sp="/-\|"
    echo -n "Detecting... "
    # Wykrywanie nowo podlaczonych urzadzen
    until [ -n "$DISCOVERED_DEVICES" ]
    do
        # Animacja krecacego sie kola
        printf "\b${sp:i++%${#sp}:1}"
        sleep 0.25
        # Sparsowanie aktualnie podlacoznych urzadzen
        ls -l /dev/sd* | grep ^b.*[0-9]$ | rev | cut --delimiter " " --fields 1 | rev > "$ROOT_DIR_PATH"/after.txt
        # Wykrycie nowych urzadzen na podstawie porownania plikow before.txt i after.txt
        DISCOVERED_DEVICES=$(diff "$ROOT_DIR_PATH"/before.txt "$ROOT_DIR_PATH"/after.txt | rev | cut --only-delimited --delimiter " " --fields 1 | rev)
    done
}

# Funkcja odpowiadajaca za zamontowanie urzadzenia w trybie Read-Only 
mount_device () {
    
    # Warunek czy wyswietlac dodatkowe informacje
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

# Funckja odpowiadajaca za odmontowanie urzadzenia 
umount_device () {
    
    # Warunek czy wyswietlac dodatkowe informacje
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

# Funckja odpowiadajca za wykrycie systemu plikow z urzadzenia
detect_filesystem () {
    
    # Sparsowanie informacji z "fdisk -l" aby wyciagnc infromacje o systemie plikow
    FILE_SYSTEM=$(sudo fdisk -l $(echo "$1" | tr -d '0123456789') | tail -n 1 | rev | cut --delimiter " " --fields 1 | rev)
    
    # Warunek czy wyswietlac dodatkowe informacje
    if [ "$DEBUG" = "true" ]
    then
        log "[DEBUG] [detect_filesystem] [ARGUMENT] "$1""
        log "[DEBUG] [detect_filesystem] [RETURN] "$FILE_SYSTEM""
    fi
    
    # Sprawdzenie czy udalo sie odczytac system plikow
    if [ -n "$FILE_SYSTEM" ]
    then
        log "Detected file system: "$FILE_SYSTEM""
    else
        log "File system detection error (could not recognize)"
    fi

}

# Funckja odpowieadajca za skopiowanie danych z nosnika 
copy_all_data () {
    
    # Warunek czy wyswietlac dodatkowe informacje
    if [ "$DEBUG" = "true" ]
    then
        log "[DEBUG] [copy_all_data] [ARGUMENT] "$1", "$2""
    fi

    # Rozpoczecie liczenia czasu operacji kopiowania
    CP_START_TIME=$(date +%s)
    log "Copying..."
    
    # Wykorzystanie polecenia cp do prostego skopiowania pikow 
    sudo cp -a "$1"/. "$2"
    
    # Zakoczenie liczenia czasu i oblicznia ile trwala operacja kopiowania
    CP_END_TIME=$(date +%s)
    CP_RUNTIME=$(( CP_END_TIME-CP_START_TIME ))
    log "Copying finished after "$CP_RUNTIME" sec"
}

# Funckja odpowiedzialna za wykonanie obrazu nosnika
create_iso_image () {
    
    # Warunek czy wyswietlac dodatkowe informacje
    if [ $DEBUG = true ]
    then
        log "[DEBUG] [create_iso_image] [ARGUMENT] "$1", "$2""
    fi

    # Rozpoczecie liczenia czasu operacji tworzenia obrazu
    DD_START_TIME=$(date +%s)
    log "Making image..."

    # Wykorzystanie programu dc3dd do stowrzenia obrazu nosnika
    # Program dodatkowo liczy funkcje skrotu
    sudo dc3dd if="$1" hof="$2" hash=sha512 hlog="$DEVICE_DIR_PATH"/dc3dd_hash.log
    
    # Sparsowanie danych z programu aby wyciagnac HASHe i zapisac jest w zmiennch
    INPUT_HASH=$(cat "$DEVICE_DIR_PATH"/dc3dd_hash.log | grep "input" -A 1 | tail -n 1 | cut --delimiter " " --fields 4)
    log  "Input HASH (SHA512): "$INPUT_HASH""
    OUTPUT_HASH=$(cat "$DEVICE_DIR_PATH"/dc3dd_hash.log | grep "output" -A 1 | tail -n 1 | cut --delimiter " " --fields 5)
    log  "Output HASH (SHA512): "$OUTPUT_HASH""

    # Zakoczenie liczenia czasu i oblicznia ile trwala operacja tworzenia obazu
    DD_END_TIME=$(date +%s)
    DD_RUNTIME=$(( DD_END_TIME-DD_START_TIME ))
    log "Making image finished after "$DD_RUNTIME" sec"
}

# Funckja wyciagania nummeru seryjnego z urzadzenia
get_device_serial_number () {
    echo $(udevadm info --name=$(echo $1 | tr -d '0123456789') | grep ID_SERIAL_SHORT | cut --delimiter "=" --fields 2)
}

# Funckja odpowiedzialna za stowrzenie pilku z raportem
create_raport () {

    # Stworzenie pustego pliku
    cat /dev/null > "$RAPORT_FILE_PATH"
    
    # Umieszczenie inforamcji o autorze skanowania
    echo User: "$CUSTOM_USER" >> "$RAPORT_FILE_PATH"
    
    # Umieszczenie informacji o dacie rozpoczecia skanowania danego urzadzenia 
    echo Scan started at: $(date -u -d @$START_TIME +%H:%M:%S) >> "$RAPORT_FILE_PATH"
    
    # Umieszczenie informacji o urzadzeniu
    echo Device: "$DEVICE" >> "$RAPORT_FILE_PATH"
    
    # Umieszczenie informacji o numerze seryjnym
    DEVICE_SERIAL_NUMBER=$(get_device_serial_number "$DEVICE")
    # Sprawdzenie czy udalo sie odczytac numer seryjny
    if [ -n "$DEVICE_SERIAL_NUMBER" ]
    then
        echo Serial Number: "$DEVICE_SERIAL_NUMBER" >> "$RAPORT_FILE_PATH"
    else
        echo Serial Number: \<empty\> >> "$RAPORT_FILE_PATH"
    fi

    # Umieszczenie informacji o systemie plikow
    echo File system: "$FILE_SYSTEM" >> "$RAPORT_FILE_PATH"

    # Umieszczenie informacji o warosci HASHa dla urzadzenia
    echo "Input HASH (SHA512): "$INPUT_HASH"" >> "$RAPORT_FILE_PATH"

    # Umieszczenie informacji o wartosci HASHa dla obrazu
    echo "Output HASH (SHA512): "$OUTPUT_HASH"" >> "$RAPORT_FILE_PATH"
    
    # Umieszczenie dodatkowych informacji urzadzeniu
    sudo fdisk -l "$DEVICE" >> "$RAPORT_FILE_PATH"

    # Umieszczenie informacji o zakonczeniu raportu i czasie calego skanu
    echo Scan ended at: $(date -u -d @$END_TIME +%H:%M:%S) >> "$RAPORT_FILE_PATH"
    echo Runtime: $RUNTIME sec >> "$RAPORT_FILE_PATH"
}

# Funkcja odpowiadajaca za wykoanie skanu wykrytych urzadzen i zebranie wszystkich informacji
scan () {

    # Sparsowanie nazwy uzadzania z katalogu na podstawie listingu z katalogu /dev
    DEVICE_NAME=$(echo "$DEVICE" | cut --delimiter "/" --fields 3)
    
    # Sciezki do potrzebnych katalogow
    DEVICE_MOUNT_PATH="$MOUNT_DIR_PATH"/"$DEVICE_NAME"
    DEVICE_DIR_PATH="$COPY_DIR_PATH"/"$DEVICE_NAME"
    DEVICE_COPY_DIR_PATH="$DEVICE_DIR_PATH"/data
    
    # Sciezki do plikow diagnostycznych
    LOG_FILE_PATH="$DEVICE_DIR_PATH"/log_"$DEVICE_NAME".log
    IMAGE_FILE_PATH="$DEVICE_DIR_PATH"/image_"$DEVICE_NAME".img
    RAPORT_FILE_PATH="$DEVICE_DIR_PATH"/raport_"$DEVICE_NAME".txt

    # Rozpoczecia licznia czasu dla procesu skanowania
    START_TIME=$(date +%s)

    # Stworzenie potzrbnych katalogow
    mkdir -p "$DEVICE_DIR_PATH"
    mkdir -p "$DEVICE_COPY_DIR_PATH"

    # Wyszyczenie pliku z logami
    cat /dev/null > "$LOG_FILE_PATH"

    # Wypisanie inforamcji, ktore i jakie urzadzenie jest skanowane
    log "Scan No. "$COUNTER" started (Device: "$DEVICE")"

    # Pobranie inforamcji z i o urzadzeniu
    mount_device "$DEVICE" "$DEVICE_MOUNT_PATH" 
    detect_filesystem "$DEVICE"
    copy_all_data "$DEVICE_MOUNT_PATH" "$DEVICE_COPY_DIR_PATH"
    create_iso_image "$DEVICE" "$IMAGE_FILE_PATH"
    ls -la "$DEVICE_COPY_DIR_PATH"
    umount_device "$DEVICE_MOUNT_PATH"
    
    # Zakoczenie liczenia czasu i oblicznia ile trwala operacja skanowania
    END_TIME=$(date +%s)
    RUNTIME=$(( END_TIME-START_TIME ))

    # Wygenerowanie rapotu dla aktualnie skanowanego urzadzenia
    create_raport

    # Wypisanie informacji o czasie skanowania
    log "Runtime: "$DEVICE" ("$RUNTIME" sec)"
}

# Funckja odpowiedzialna za wyswietlanie wszystkich wygenerowanych raportow  
display_raports () {
    echo "-----------------------------"
    # Znalezienie sciezek bezwzgledncyh wszystkich wygenerowanych raportow
    RAPORTS_PATH=$(find $ROOT_DIR_PATH -name "*.txt" | grep raport)
    for RAPORT in $RAPORTS_PATH
    do
        cat $RAPORT
        echo "-----------------------------"
    done
}

# Funckja zawierajaca glowna logike programu 
run () {

    # Wykrycie nowych urzadzen
    discover

    # Sprawdzenie czy wykryto jakiekolwiek urzadznie 
    if [ -n "$DISCOVERED_DEVICES" ]
    then
        COUNTER=0
        # Iterowanie sie przez wszystkie urzadzenia
        for DEVICE in $DISCOVERED_DEVICES
        do
            COUNTER=$(( COUNTER+1 ))
            echo

            # Rozpczecie skanu dla danego urzadzenia
            scan
        done
    else
        
        # Wyswieltenie informacji o nie znalezieniu urzadzen
        log No devices detected
    fi

    # Warunek na sprawdzenie czy wyswietlic dodatkowo raporty w konsoli
    if [ $DISPLAY_RAPORT = true ]
    then
        log "Print summary raport"
        
        # wyswietlenie raportow  
        display_raports
    fi
}

run