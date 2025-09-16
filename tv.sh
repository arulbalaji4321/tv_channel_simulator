#!/bin/bash

BASE_DIR="$(pwd)"

# ------------------------------
# Function: list channels
# ------------------------------
list_channels() {
    CHANNELS=()
    i=1
    for dir in "$BASE_DIR"/*/; do
        dir_name=$(basename "$dir")
        CHANNELS+=("$dir_name")
        echo "  $i) $dir_name"
        ((i++))
    done
}

# ------------------------------
# Function: choose channel by index
# ------------------------------
choose_channel() {
    list_channels
    echo -n "Select channel number: "
    read INDEX
    CHANNEL="${CHANNELS[$((INDEX-1))]}"
    if [ -z "$CHANNEL" ]; then
        echo "Invalid selection."
        return 1
    fi
    return 0
}

# ------------------------------
# Function: play a channel
# ------------------------------
play_channel() {
    if choose_channel; then
        CHANNEL_DIR="$BASE_DIR/$CHANNEL"
        SCRIPT="$CHANNEL_DIR/${CHANNEL,,}.sh"  # assuming script is lowercase like animes.sh
        if [ -f "$SCRIPT" ]; then
            bash "$SCRIPT"
        else
            echo "No script found for this channel ($SCRIPT)"
        fi
    fi
}

# ------------------------------
# Function: reset tracking
# ------------------------------
reset_tracking() {
    if choose_channel; then
        STATE_FILE="$BASE_DIR/$CHANNEL/state.txt"
        if [ -f "$STATE_FILE" ]; then
            echo 0 > "$STATE_FILE"
            echo "Progress for '$CHANNEL' reset."
        else
            echo "No progress file found for '$CHANNEL'."
        fi
    fi
}

# ------------------------------
# Function: schedule shows
# ------------------------------
schedule_shows() {
    if choose_channel; then
        CHANNEL_DIR="$BASE_DIR/$CHANNEL"
        
        # List shows in channel
        echo "Available shows in $CHANNEL:"
        SHOWS=()
        i=1
        for dir in "$CHANNEL_DIR"/*/; do
            show_name=$(basename "$dir")
            SHOWS+=("$show_name")
            echo "  $i) $show_name"
            ((i++))
        done

        # Select two shows
        echo -n "Select first show number: "
        read S1
        echo -n "Select second show number: "
        read S2

        SHOW1="${SHOWS[$((S1-1))]}"
        SHOW2="${SHOWS[$((S2-1))]}"

        # Enter times
        echo "Enter start and end time for $SHOW1 (format HH:MM AM/PM-HH:MM AM/PM):"
        read TIME1
        echo "Enter start and end time for $SHOW2 (format HH:MM AM/PM-HH:MM AM/PM):"
        read TIME2

        SCHED_FILE="$CHANNEL_DIR/schedule.txt"
        echo "$TIME1:'$SHOW1'" > "$SCHED_FILE"
        echo "$TIME2:'$SHOW2'" >> "$SCHED_FILE"
        echo "Schedule saved for channel $CHANNEL."
    fi
}

# ------------------------------
# Main menu
# ------------------------------
while true; do
    echo ""
    echo "===== TV Control Menu ====="
    echo "1) Play channel"
    echo "2) Reset progress"
    echo "3) Schedule shows"
    echo "4) Exit"
    echo -n "Select an option: "
    read OPTION

    case $OPTION in
        1) play_channel ;;
        2) reset_tracking ;;
        3) schedule_shows ;;
        4) exit 0 ;;
        *) echo "Invalid option, try again." ;;
    esac
done

